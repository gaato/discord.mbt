//! Native transport AEAD shim for discord.mbt voice support.
//!
//! Status codes shared by every fallible entry point:
//!
//! - `0`: success
//! - `-1`: invalid pointer, length, mode-specific nonce, or output argument
//! - `-2`: unsupported encryption mode
//! - `-3`: authentication failed while opening a ciphertext
//! - `-4`: cryptographic operation failed
//! - `-5`: a Rust panic was caught at the FFI boundary

// Raw-pointer entry points are unsafe for Rust callers. Every exported entry
// point still validates nullness and lengths before constructing references;
// the actual dereferences remain in documented `unsafe` blocks below.
#![deny(unsafe_op_in_unsafe_fn)]

use std::cell::RefCell;
use std::ffi::{c_char, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;

use aes_gcm::aead::{Aead, KeyInit, Payload};
use aes_gcm::{Aes256Gcm, Nonce as AesNonce};
use chacha20poly1305::{XChaCha20Poly1305, XNonce};

const ABI_VERSION: u16 = 3;
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
    if length > isize::MAX as usize {
        return Err(FfiError::new(
            STATUS_INVALID_ARGUMENT,
            format!("{name} is too large"),
        ));
    }
    // SAFETY: the caller promises that non-null inputs point to `length`
    // readable bytes for the duration of this synchronous call. The length is
    // also within Rust's `isize::MAX` slice bound.
    Ok(unsafe { std::slice::from_raw_parts(pointer, length) })
}

unsafe fn initialize_output_slots(out: *mut *mut u8, out_len: *mut usize) -> Result<(), FfiError> {
    if out.is_null() || out_len.is_null() {
        return Err(FfiError::new(
            STATUS_INVALID_ARGUMENT,
            "out and out_len must not be null",
        ));
    }
    // SAFETY: both slots were checked above and the caller promises that they
    // are writable for this synchronous call.
    unsafe {
        *out = ptr::null_mut();
        *out_len = 0;
    }
    Ok(())
}

unsafe fn return_buffer(output: Vec<u8>, out: *mut *mut u8, out_len: *mut usize) {
    if output.is_empty() {
        return;
    }
    let boxed = output.into_boxed_slice();
    let length = boxed.len();
    let pointer = Box::into_raw(boxed).cast::<u8>();
    // SAFETY: `initialize_output_slots` established writable slots. Ownership
    // transfers to the caller, which must invoke `vs_free(pointer, length)`.
    unsafe {
        *out = pointer;
        *out_len = length;
    }
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

#[allow(
    clippy::too_many_arguments,
    clippy::type_complexity,
    reason = "the adapter deliberately mirrors the C AEAD ABI"
)]
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
    // SAFETY: output pointers are validated and initialized before any other
    // argument can fail.
    unsafe { initialize_output_slots(out, out_len) }?;
    if key.is_null() {
        return Err(FfiError::new(
            STATUS_INVALID_ARGUMENT,
            "key must not be null",
        ));
    }
    // SAFETY: all slices are confined to this call and validated for null and
    // representable lengths.
    let key = unsafe { input_slice(key, 32, "key") }?;
    let nonce = unsafe { input_slice(nonce, nonce_len, "nonce") }?;
    let aad = unsafe { input_slice(aad, aad_len, "aad") }?;
    let input = unsafe { input_slice(input, input_len, "input") }?;
    let output = operation(mode, key, nonce, aad, input)?;
    // SAFETY: output slots were initialized above and remain live.
    unsafe { return_buffer(output, out, out_len) };
    Ok(())
}

/// Return the C ABI version implemented by this shared library.
#[no_mangle]
pub extern "C" fn vs_abi_version() -> u16 {
    catch_unwind(|| ABI_VERSION).unwrap_or(0)
}

/// Release an output buffer returned by this shared library.
///
/// `pointer` and `length` must be the exact non-empty pair returned through an
/// output slot by this library. A null pointer is accepted as a no-op.
///
/// # Safety
///
/// A non-null `pointer` must be paired with the exact `length` returned by this
/// library, and the pair must not have been freed previously.
#[no_mangle]
pub unsafe extern "C" fn vs_free(pointer: *mut u8, length: usize) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if pointer.is_null() {
            return;
        }
        // SAFETY: the C ABI requires the exact pair returned by this library.
        unsafe {
            drop(Box::from_raw(std::ptr::slice_from_raw_parts_mut(
                pointer, length,
            )));
        }
    }));
}

/// Return a thread-local, NUL-terminated description of the last failure.
///
/// The pointer remains valid until the next shim operation on the same thread.
#[no_mangle]
pub extern "C" fn vs_last_error() -> *const c_char {
    static PANIC_MESSAGE: &[u8] = b"failed to access last error\0";
    catch_unwind(|| LAST_ERROR.with(|slot| slot.borrow().as_ptr()))
        .unwrap_or(PANIC_MESSAGE.as_ptr().cast())
}

/// Seal plaintext and return `ciphertext || 16-byte tag` through `out`.
///
/// # Safety
///
/// `key` must address 32 readable bytes. Every other input must address its
/// stated length when non-zero. `out` and `out_len` must be writable slots.
#[no_mangle]
pub unsafe extern "C" fn vs_aead_seal(
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
///
/// # Safety
///
/// `key` must address 32 readable bytes. Every other input must address its
/// stated length when non-zero. `out` and `out_len` must be writable slots.
#[no_mangle]
pub unsafe extern "C" fn vs_aead_open(
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CStr;
    use std::ptr::NonNull;

    fn last_error() -> String {
        // SAFETY: `vs_last_error` returns a thread-local NUL-terminated string
        // that remains live until the next shim operation on this thread.
        unsafe { CStr::from_ptr(vs_last_error()) }
            .to_string_lossy()
            .into_owned()
    }

    fn call_output(call: impl FnOnce(*mut *mut u8, *mut usize) -> i32) -> Result<Vec<u8>, i32> {
        let mut pointer = ptr::null_mut();
        let mut length = 0;
        let status = call(&mut pointer, &mut length);
        if status != STATUS_OK {
            assert!(pointer.is_null());
            assert_eq!(length, 0);
            return Err(status);
        }
        if length == 0 {
            assert!(pointer.is_null());
            return Ok(Vec::new());
        }
        assert!(!pointer.is_null());
        // SAFETY: the successful call returned `length` readable bytes and the
        // exact pointer/length pair is released through the public C ABI.
        let output = unsafe { std::slice::from_raw_parts(pointer, length) }.to_vec();
        // SAFETY: this is the exact non-empty pair returned by the ABI call.
        unsafe { vs_free(pointer, length) };
        Ok(output)
    }

    fn seal_via_abi(mode: i32, key: &[u8; 32], nonce: &[u8], aad: &[u8], input: &[u8]) -> Vec<u8> {
        call_output(|out, out_len| {
            // SAFETY: slices remain live for the synchronous call and output
            // slots are writable.
            unsafe {
                vs_aead_seal(
                    mode,
                    key.as_ptr(),
                    nonce.as_ptr(),
                    nonce.len(),
                    aad.as_ptr(),
                    aad.len(),
                    input.as_ptr(),
                    input.len(),
                    out,
                    out_len,
                )
            }
        })
        .unwrap_or_else(|status| panic!("seal failed with {status}: {}", last_error()))
    }

    fn open_via_abi(
        mode: i32,
        key: &[u8; 32],
        nonce: &[u8],
        aad: &[u8],
        input: &[u8],
    ) -> Result<Vec<u8>, i32> {
        call_output(|out, out_len| {
            // SAFETY: slices remain live for the synchronous call and output
            // slots are writable.
            unsafe {
                vs_aead_open(
                    mode,
                    key.as_ptr(),
                    nonce.as_ptr(),
                    nonce.len(),
                    aad.as_ptr(),
                    aad.len(),
                    input.as_ptr(),
                    input.len(),
                    out,
                    out_len,
                )
            }
        })
    }

    #[test]
    fn reports_transport_only_abi_version() {
        assert_eq!(vs_abi_version(), 3);
        // SAFETY: null is explicitly accepted as a no-op.
        unsafe { vs_free(ptr::null_mut(), 0) };
    }

    #[test]
    fn aes_known_answer_and_empty_plaintext_round_trip() {
        let key = [0; 32];
        let nonce = [0; 12];
        let plaintext = [0; 16];
        let ciphertext = seal_via_abi(MODE_AES_256_GCM, &key, &nonce, &[], &plaintext);
        assert_eq!(
            ciphertext,
            [
                0xce, 0xa7, 0x40, 0x3d, 0x4d, 0x60, 0x6b, 0x6e, 0x07, 0x4e, 0xc5, 0xd3, 0xba, 0xf3,
                0x9d, 0x18, 0xd0, 0xd1, 0xc8, 0xa7, 0x99, 0x99, 0x6b, 0xf0, 0x26, 0x5b, 0x98, 0xb5,
                0xd4, 0x8a, 0xb9, 0x19,
            ]
        );
        assert_eq!(
            open_via_abi(MODE_AES_256_GCM, &key, &nonce, &[], &ciphertext),
            Ok(plaintext.to_vec())
        );

        let empty_ciphertext = seal_via_abi(MODE_AES_256_GCM, &key, &nonce, &[], &[]);
        assert_eq!(
            open_via_abi(MODE_AES_256_GCM, &key, &nonce, &[], &empty_ciphertext),
            Ok(Vec::new())
        );
    }

    #[test]
    fn xchacha_round_trip_and_authentication_failure() {
        let key = [0x42; 32];
        let nonce = [0x24; 24];
        let aad = b"rtp header";
        let plaintext = b"opus frame";
        let mut ciphertext = seal_via_abi(MODE_XCHACHA20_POLY1305, &key, &nonce, aad, plaintext);
        assert_eq!(
            open_via_abi(MODE_XCHACHA20_POLY1305, &key, &nonce, aad, &ciphertext,),
            Ok(plaintext.to_vec())
        );
        ciphertext[0] ^= 1;
        assert_eq!(
            open_via_abi(MODE_XCHACHA20_POLY1305, &key, &nonce, aad, &ciphertext,),
            Err(STATUS_AUTHENTICATION_FAILED)
        );
        assert_eq!(last_error(), "XChaCha20-Poly1305 authentication failed");
    }

    #[test]
    fn invalid_arguments_reset_output_slots() {
        let key = [0; 32];
        let nonce = [0; 12];
        let mut output = NonNull::<u8>::dangling().as_ptr();
        let mut output_len = 99;
        // SAFETY: non-null inputs and output slots are live; null inputs have
        // zero length.
        let status = unsafe {
            vs_aead_seal(
                99,
                key.as_ptr(),
                nonce.as_ptr(),
                nonce.len(),
                ptr::null(),
                0,
                ptr::null(),
                0,
                &mut output,
                &mut output_len,
            )
        };
        assert_eq!(status, STATUS_UNSUPPORTED_MODE);
        assert!(output.is_null());
        assert_eq!(output_len, 0);

        // SAFETY: deliberately passes an invalid null/non-zero input pair to
        // verify validation occurs before dereference. Other pointers are live.
        let status = unsafe {
            vs_aead_seal(
                MODE_AES_256_GCM,
                key.as_ptr(),
                nonce.as_ptr(),
                nonce.len(),
                ptr::null(),
                0,
                ptr::null(),
                1,
                &mut output,
                &mut output_len,
            )
        };
        assert_eq!(status, STATUS_INVALID_ARGUMENT);
        assert_eq!(last_error(), "input is null with non-zero length");
        assert!(output.is_null());
        assert_eq!(output_len, 0);
    }
}
