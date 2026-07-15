//! Native cryptographic shim for discord.mbt voice support.
//!
//! Status codes shared by every fallible entry point:
//!
//! - `0`: success
//! - `-1`: invalid pointer, length, mode-specific nonce, or output argument
//! - `-2`: unsupported encryption mode
//! - `-3`: authentication failed while opening a ciphertext
//! - `-4`: cryptographic operation failed
//! - `-5`: a Rust panic was caught at the FFI boundary

use std::cell::RefCell;
use std::ffi::{c_char, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;

use aes_gcm::aead::{Aead, KeyInit, Payload};
use aes_gcm::{Aes256Gcm, Nonce as AesNonce};
use chacha20poly1305::{XChaCha20Poly1305, XNonce};

const ABI_VERSION: u16 = 1;
const STATUS_OK: i32 = 0;
const STATUS_INVALID_ARGUMENT: i32 = -1;
const STATUS_UNSUPPORTED_MODE: i32 = -2;
const STATUS_AUTHENTICATION_FAILED: i32 = -3;
const STATUS_CRYPTO_ERROR: i32 = -4;
const STATUS_PANIC: i32 = -5;

const MODE_AES_256_GCM: i32 = 0;
const MODE_XCHACHA20_POLY1305: i32 = 1;

#[derive(Debug)]
struct FfiError {
    status: i32,
    message: String,
}

impl FfiError {
    fn new(status: i32, message: impl Into<String>) -> Self {
        Self {
            status,
            message: message.into(),
        }
    }
}

thread_local! {
    static LAST_ERROR: RefCell<CString> = RefCell::new(
        CString::new(Vec::<u8>::new()).expect("an empty CString is valid")
    );
}

fn set_last_error(message: &str) {
    let sanitized = message.replace('\0', "\\0");
    let value = CString::new(sanitized)
        .unwrap_or_else(|_| CString::new("invalid error message").expect("literal is valid"));
    LAST_ERROR.with(|slot| *slot.borrow_mut() = value);
}

fn clear_last_error() {
    set_last_error("");
}

fn panic_message(payload: Box<dyn std::any::Any + Send>) -> String {
    if let Some(message) = payload.downcast_ref::<&str>() {
        (*message).to_owned()
    } else if let Some(message) = payload.downcast_ref::<String>() {
        message.clone()
    } else {
        "unknown Rust panic".to_owned()
    }
}

fn ffi_status(operation: impl FnOnce() -> Result<(), FfiError>) -> i32 {
    match catch_unwind(AssertUnwindSafe(operation)) {
        Ok(Ok(())) => {
            clear_last_error();
            STATUS_OK
        }
        Ok(Err(error)) => {
            set_last_error(&error.message);
            error.status
        }
        Err(payload) => {
            set_last_error(&format!("panic: {}", panic_message(payload)));
            STATUS_PANIC
        }
    }
}

unsafe fn input_slice<'a>(
    pointer: *const u8,
    length: usize,
    name: &str,
) -> Result<&'a [u8], FfiError> {
    if length == 0 {
        return Ok(&[]);
    }
    if pointer.is_null() {
        return Err(FfiError::new(
            STATUS_INVALID_ARGUMENT,
            format!("{name} is null with non-zero length"),
        ));
    }
    // SAFETY: the caller promises that non-null inputs point to `length`
    // readable bytes for the duration of this synchronous call.
    Ok(unsafe { std::slice::from_raw_parts(pointer, length) })
}

fn seal(
    mode: i32,
    key: &[u8],
    nonce: &[u8],
    aad: &[u8],
    plaintext: &[u8],
) -> Result<Vec<u8>, FfiError> {
    let payload = Payload {
        msg: plaintext,
        aad,
    };
    match mode {
        MODE_AES_256_GCM => {
            if nonce.len() != 12 {
                return Err(FfiError::new(
                    STATUS_INVALID_ARGUMENT,
                    "AES-256-GCM requires a 12-byte nonce",
                ));
            }
            let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| {
                FfiError::new(STATUS_INVALID_ARGUMENT, "key must contain exactly 32 bytes")
            })?;
            cipher
                .encrypt(AesNonce::from_slice(nonce), payload)
                .map_err(|_| FfiError::new(STATUS_CRYPTO_ERROR, "AES-256-GCM seal failed"))
        }
        MODE_XCHACHA20_POLY1305 => {
            if nonce.len() != 24 {
                return Err(FfiError::new(
                    STATUS_INVALID_ARGUMENT,
                    "XChaCha20-Poly1305 requires a 24-byte nonce",
                ));
            }
            let cipher = XChaCha20Poly1305::new_from_slice(key).map_err(|_| {
                FfiError::new(STATUS_INVALID_ARGUMENT, "key must contain exactly 32 bytes")
            })?;
            cipher
                .encrypt(XNonce::from_slice(nonce), payload)
                .map_err(|_| FfiError::new(STATUS_CRYPTO_ERROR, "XChaCha20-Poly1305 seal failed"))
        }
        _ => Err(FfiError::new(
            STATUS_UNSUPPORTED_MODE,
            format!("unsupported AEAD mode {mode}"),
        )),
    }
}

fn open(
    mode: i32,
    key: &[u8],
    nonce: &[u8],
    aad: &[u8],
    ciphertext: &[u8],
) -> Result<Vec<u8>, FfiError> {
    if ciphertext.len() < 16 {
        return Err(FfiError::new(
            STATUS_INVALID_ARGUMENT,
            "ciphertext is shorter than its 16-byte authentication tag",
        ));
    }
    let payload = Payload {
        msg: ciphertext,
        aad,
    };
    match mode {
        MODE_AES_256_GCM => {
            if nonce.len() != 12 {
                return Err(FfiError::new(
                    STATUS_INVALID_ARGUMENT,
                    "AES-256-GCM requires a 12-byte nonce",
                ));
            }
            let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| {
                FfiError::new(STATUS_INVALID_ARGUMENT, "key must contain exactly 32 bytes")
            })?;
            cipher
                .decrypt(AesNonce::from_slice(nonce), payload)
                .map_err(|_| {
                    FfiError::new(
                        STATUS_AUTHENTICATION_FAILED,
                        "AES-256-GCM authentication failed",
                    )
                })
        }
        MODE_XCHACHA20_POLY1305 => {
            if nonce.len() != 24 {
                return Err(FfiError::new(
                    STATUS_INVALID_ARGUMENT,
                    "XChaCha20-Poly1305 requires a 24-byte nonce",
                ));
            }
            let cipher = XChaCha20Poly1305::new_from_slice(key).map_err(|_| {
                FfiError::new(STATUS_INVALID_ARGUMENT, "key must contain exactly 32 bytes")
            })?;
            cipher
                .decrypt(XNonce::from_slice(nonce), payload)
                .map_err(|_| {
                    FfiError::new(
                        STATUS_AUTHENTICATION_FAILED,
                        "XChaCha20-Poly1305 authentication failed",
                    )
                })
        }
        _ => Err(FfiError::new(
            STATUS_UNSUPPORTED_MODE,
            format!("unsupported AEAD mode {mode}"),
        )),
    }
}

unsafe fn run_aead(
    mode: i32,
    key: *const u8,
    nonce: *const u8,
    nonce_len: usize,
    aad: *const u8,
    aad_len: usize,
    input: *const u8,
    input_len: usize,
    out: *mut *mut u8,
    out_len: *mut usize,
    operation: fn(i32, &[u8], &[u8], &[u8], &[u8]) -> Result<Vec<u8>, FfiError>,
) -> Result<(), FfiError> {
    if key.is_null() || out.is_null() || out_len.is_null() {
        return Err(FfiError::new(
            STATUS_INVALID_ARGUMENT,
            "key, out, and out_len must not be null",
        ));
    }
    // SAFETY: output pointers were validated above and are writable by the
    // caller for this synchronous call.
    unsafe {
        *out = ptr::null_mut();
        *out_len = 0;
    }
    // SAFETY: all slices are confined to this call and validated for null.
    let key = unsafe { input_slice(key, 32, "key") }?;
    let nonce = unsafe { input_slice(nonce, nonce_len, "nonce") }?;
    let aad = unsafe { input_slice(aad, aad_len, "aad") }?;
    let input = unsafe { input_slice(input, input_len, "input") }?;
    let output = operation(mode, key, nonce, aad, input)?;
    let boxed = output.into_boxed_slice();
    let length = boxed.len();
    let pointer = Box::into_raw(boxed).cast::<u8>();
    // SAFETY: output pointers were validated above. Ownership of `pointer`
    // transfers to the caller, which must invoke `vs_free(pointer, length)`.
    unsafe {
        *out = pointer;
        *out_len = length;
    }
    Ok(())
}

/// Return the C ABI version implemented by this shared library.
#[no_mangle]
pub extern "C" fn vs_abi_version() -> u16 {
    catch_unwind(|| ABI_VERSION).unwrap_or(0)
}

/// Release an output buffer returned by this shared library.
#[no_mangle]
pub extern "C" fn vs_free(pointer: *mut u8, length: usize) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if pointer.is_null() {
            return;
        }
        // SAFETY: `pointer` and `length` must be the exact pair returned by
        // this library. Rebuilding the boxed slice releases its allocation.
        unsafe {
            drop(Box::from_raw(std::ptr::slice_from_raw_parts_mut(
                pointer, length,
            )));
        }
    }));
}

/// Return a thread-local, NUL-terminated description of the last failure.
#[no_mangle]
pub extern "C" fn vs_last_error() -> *const c_char {
    static PANIC_MESSAGE: &[u8] = b"failed to access last error\0";
    catch_unwind(|| LAST_ERROR.with(|slot| slot.borrow().as_ptr()))
        .unwrap_or(PANIC_MESSAGE.as_ptr().cast())
}

/// Seal plaintext and return `ciphertext || 16-byte tag` through `out`.
#[no_mangle]
pub extern "C" fn vs_aead_seal(
    mode: i32,
    key: *const u8,
    nonce: *const u8,
    nonce_len: usize,
    aad: *const u8,
    aad_len: usize,
    plaintext: *const u8,
    plaintext_len: usize,
    out: *mut *mut u8,
    out_len: *mut usize,
) -> i32 {
    ffi_status(|| {
        // SAFETY: all raw-pointer validation and slice construction happens
        // inside `run_aead`; no pointer escapes the call.
        unsafe {
            run_aead(
                mode,
                key,
                nonce,
                nonce_len,
                aad,
                aad_len,
                plaintext,
                plaintext_len,
                out,
                out_len,
                seal,
            )
        }
    })
}

/// Open `ciphertext || tag` and return plaintext through `out`.
#[no_mangle]
pub extern "C" fn vs_aead_open(
    mode: i32,
    key: *const u8,
    nonce: *const u8,
    nonce_len: usize,
    aad: *const u8,
    aad_len: usize,
    ciphertext: *const u8,
    ciphertext_len: usize,
    out: *mut *mut u8,
    out_len: *mut usize,
) -> i32 {
    ffi_status(|| {
        // SAFETY: all raw-pointer validation and slice construction happens
        // inside `run_aead`; no pointer escapes the call.
        unsafe {
            run_aead(
                mode,
                key,
                nonce,
                nonce_len,
                aad,
                aad_len,
                ciphertext,
                ciphertext_len,
                out,
                out_len,
                open,
            )
        }
    })
}
