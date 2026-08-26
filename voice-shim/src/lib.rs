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
//! - `-20`: an invalid DAVE commit/welcome requires recovery
//! - `-21`: an obsolete or already-applied DAVE transition can be ignored
//! - `-22`: another DAVE commit/welcome failure occurred

// These functions are consumed through a C ABI, where Rust's `unsafe fn`
// contract is not expressible. Every exported entry point validates nullness
// and lengths before constructing references; the actual dereferences remain
// in documented `unsafe` blocks below.
#![allow(clippy::not_unsafe_ptr_arg_deref)]
#![deny(unsafe_op_in_unsafe_fn)]

use std::cell::RefCell;
use std::ffi::{c_char, CStr, CString};
use std::num::NonZeroU16;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;

use aes_gcm::aead::{Aead, KeyInit, Payload};
use aes_gcm::{Aes256Gcm, Nonce as AesNonce};
use chacha20poly1305::{XChaCha20Poly1305, XNonce};
use davey::errors::{ProcessCommitError, ProcessWelcomeError};
use davey::{DaveSession, MediaType, ProposalsOperationType, SessionStatus, DAVE_PROTOCOL_VERSION};
use openmls::prelude::{DeserializeBytes, MlsMessageIn, ProcessMessageError, ValidationError};

const ABI_VERSION: u16 = 2;
const STATUS_OK: i32 = 0;
const STATUS_INVALID_ARGUMENT: i32 = -1;
const STATUS_UNSUPPORTED_MODE: i32 = -2;
const STATUS_AUTHENTICATION_FAILED: i32 = -3;
const STATUS_CRYPTO_ERROR: i32 = -4;
const STATUS_PANIC: i32 = -5;
const STATUS_DAVE_INVALID_TRANSITION: i32 = -20;
const STATUS_DAVE_IGNORABLE_TRANSITION: i32 = -21;
const STATUS_DAVE_INTERNAL_ERROR: i32 = -22;

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

fn ffi_i32(operation: impl FnOnce() -> Result<i32, FfiError>) -> i32 {
    match catch_unwind(AssertUnwindSafe(operation)) {
        Ok(Ok(value)) => {
            clear_last_error();
            value
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

fn ffi_pointer<T>(operation: impl FnOnce() -> Result<*mut T, FfiError>) -> *mut T {
    match catch_unwind(AssertUnwindSafe(operation)) {
        Ok(Ok(pointer)) => {
            clear_last_error();
            pointer
        }
        Ok(Err(error)) => {
            set_last_error(&error.message);
            ptr::null_mut()
        }
        Err(payload) => {
            set_last_error(&format!("panic: {}", panic_message(payload)));
            ptr::null_mut()
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

unsafe fn user_id(pointer: *const c_char, name: &str) -> Result<u64, FfiError> {
    if pointer.is_null() {
        return Err(FfiError::new(
            STATUS_INVALID_ARGUMENT,
            format!("{name} must not be null"),
        ));
    }
    // SAFETY: the caller promises that `pointer` refers to a readable,
    // NUL-terminated C string for the duration of this synchronous call.
    let value = unsafe { CStr::from_ptr(pointer) }
        .to_str()
        .map_err(|_| FfiError::new(STATUS_INVALID_ARGUMENT, format!("{name} is not UTF-8")))?;
    value.parse::<u64>().map_err(|_| {
        FfiError::new(
            STATUS_INVALID_ARGUMENT,
            format!("{name} must be an unsigned decimal 64-bit integer"),
        )
    })
}

unsafe fn recognized_user_ids(
    pointers: *const *const c_char,
    length: usize,
) -> Result<Option<Vec<u64>>, FfiError> {
    if length == 0 {
        return Ok(None);
    }
    if pointers.is_null() {
        return Err(FfiError::new(
            STATUS_INVALID_ARGUMENT,
            "recognized_user_ids is null with non-zero length",
        ));
    }
    // SAFETY: the caller promises that `pointers` addresses `length` readable
    // C-string pointers for the duration of this synchronous call.
    let pointers = unsafe { std::slice::from_raw_parts(pointers, length) };
    pointers
        .iter()
        .enumerate()
        .map(|(index, pointer)| {
            // SAFETY: each element is subject to the same C-string contract as
            // a standalone user ID argument.
            unsafe { user_id(*pointer, &format!("recognized_user_ids[{index}]")) }
        })
        .collect::<Result<Vec<_>, _>>()
        .map(Some)
}

fn parse_protocol_version(value: u16) -> Result<NonZeroU16, FfiError> {
    NonZeroU16::new(value)
        .ok_or_else(|| FfiError::new(STATUS_INVALID_ARGUMENT, "protocol_version must not be zero"))
}

unsafe fn output_slots(out: *mut *mut u8, out_len: *mut usize, name: &str) -> Result<(), FfiError> {
    if out.is_null() || out_len.is_null() {
        return Err(FfiError::new(
            STATUS_INVALID_ARGUMENT,
            format!("{name} and {name}_len must not be null"),
        ));
    }
    // SAFETY: both output slots were checked above and the caller promises
    // they are writable for this synchronous call.
    unsafe {
        *out = ptr::null_mut();
        *out_len = 0;
    }
    Ok(())
}

unsafe fn return_buffer(output: Vec<u8>, out: *mut *mut u8, out_len: *mut usize) {
    let boxed = output.into_boxed_slice();
    let length = boxed.len();
    let pointer = Box::into_raw(boxed).cast::<u8>();
    // SAFETY: the caller supplied writable output slots. Ownership transfers
    // to the caller, which must pass the exact pair to `vs_free`.
    unsafe {
        *out = pointer;
        *out_len = length;
    }
}

/// Opaque owner of a davey session and the IDs needed by davey's `reinit` API.
pub struct VsDaveSession {
    inner: DaveSession,
    user_id: u64,
    channel_id: u64,
}

unsafe fn dave_session_mut<'a>(
    pointer: *mut VsDaveSession,
) -> Result<&'a mut VsDaveSession, FfiError> {
    if pointer.is_null() {
        return Err(FfiError::new(
            STATUS_INVALID_ARGUMENT,
            "session must not be null",
        ));
    }
    // SAFETY: the caller promises exclusive access to a live pointer returned
    // by `vs_dave_session_create` for the duration of this call.
    Ok(unsafe { &mut *pointer })
}

fn dave_error(error: impl std::fmt::Display) -> FfiError {
    FfiError::new(STATUS_CRYPTO_ERROR, error.to_string())
}

fn incoming_commit_is_old(commit: &[u8], session: &DaveSession) -> bool {
    let Some(current_epoch) = session.epoch() else {
        return false;
    };
    MlsMessageIn::tls_deserialize_exact_bytes(commit)
        .ok()
        .and_then(|message| message.try_into_protocol_message().ok())
        .is_some_and(|message| message.epoch() < current_epoch)
}

fn process_commit_error(
    error: ProcessCommitError,
    commit: &[u8],
    session: &DaveSession,
) -> FfiError {
    // davey wraps OpenMLS errors without retaining the incoming epoch in the
    // error. `WrongEpoch` is ignorable only when the decoded commit is older;
    // a future or undecodable epoch is recovery-requiring per the ABI rule.
    let status = match &error {
        ProcessCommitError::ProcessingMessageFailed(ProcessMessageError::ValidationError(
            ValidationError::NoPastEpochData,
        )) => STATUS_DAVE_IGNORABLE_TRANSITION,
        ProcessCommitError::ProcessingMessageFailed(ProcessMessageError::ValidationError(
            ValidationError::WrongEpoch,
        )) if incoming_commit_is_old(commit, session) => STATUS_DAVE_IGNORABLE_TRANSITION,
        ProcessCommitError::MergingPendingCommitFailed(_)
        | ProcessCommitError::MergingStagedCommitFailed(_)
        | ProcessCommitError::UpdatingRatchetsFailed(_)
        | ProcessCommitError::ProcessingMessageFailed(ProcessMessageError::LibraryError(_))
        | ProcessCommitError::ProcessingMessageFailed(ProcessMessageError::StorageError(_)) => {
            STATUS_DAVE_INTERNAL_ERROR
        }
        // Deserialize, authentication/validation, group/state mismatch, and
        // unclassified errors require recovery. The ABI explicitly requires
        // unknown cases to use -20 rather than assuming they are obsolete.
        _ => STATUS_DAVE_INVALID_TRANSITION,
    };
    FfiError::new(status, error.to_string())
}

fn process_welcome_error(error: ProcessWelcomeError) -> FfiError {
    // `AlreadyInGroup` is davey's explicit signal that a Welcome was already
    // applied. OpenMLS Welcome errors carry no comparable epoch, so ambiguous
    // key/epoch failures must remain recovery-requiring (-20).
    let status = match &error {
        ProcessWelcomeError::AlreadyInGroup => STATUS_DAVE_IGNORABLE_TRANSITION,
        ProcessWelcomeError::DeletingPendingGroupFailed(_)
        | ProcessWelcomeError::UpdatingRatchetsFailed(_) => STATUS_DAVE_INTERNAL_ERROR,
        ProcessWelcomeError::CreatingStagedWelcomeFailed(
            openmls::group::WelcomeError::LibraryError(_),
        )
        | ProcessWelcomeError::CreatingStagedWelcomeFailed(
            openmls::group::WelcomeError::StorageError(_),
        ) => STATUS_DAVE_INTERNAL_ERROR,
        _ => STATUS_DAVE_INVALID_TRANSITION,
    };
    FfiError::new(status, error.to_string())
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

/// Return the maximum DAVE protocol version supported by davey.
#[no_mangle]
pub extern "C" fn vs_dave_max_protocol_version() -> u16 {
    catch_unwind(|| DAVE_PROTOCOL_VERSION).unwrap_or(0)
}

/// Create a DAVE session with an internally generated signing key.
#[no_mangle]
pub extern "C" fn vs_dave_session_create(
    protocol_version: u16,
    user_id_pointer: *const c_char,
    channel_id: u64,
) -> *mut VsDaveSession {
    ffi_pointer(|| {
        let protocol_version = parse_protocol_version(protocol_version)?;
        // SAFETY: validation and conversion are confined to this call.
        let user_id = unsafe { user_id(user_id_pointer, "user_id") }?;
        let inner =
            DaveSession::new(protocol_version, user_id, channel_id, None).map_err(dave_error)?;
        Ok(Box::into_raw(Box::new(VsDaveSession {
            inner,
            user_id,
            channel_id,
        })))
    })
}

/// Destroy a DAVE session returned by `vs_dave_session_create`.
#[no_mangle]
pub extern "C" fn vs_dave_session_destroy(session: *mut VsDaveSession) {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if session.is_null() {
            return;
        }
        // SAFETY: the caller must pass a live pointer returned by
        // `vs_dave_session_create` exactly once.
        unsafe { drop(Box::from_raw(session)) };
    }));
    match result {
        Ok(()) => clear_last_error(),
        Err(payload) => set_last_error(&format!("panic: {}", panic_message(payload))),
    }
}

/// Reset and reinitialize a DAVE session, preserving its user and channel IDs.
#[no_mangle]
pub extern "C" fn vs_dave_session_reinit(
    session: *mut VsDaveSession,
    protocol_version: u16,
) -> i32 {
    ffi_status(|| {
        let protocol_version = parse_protocol_version(protocol_version)?;
        // SAFETY: the pointer is validated before it is dereferenced.
        let session = unsafe { dave_session_mut(session) }?;
        session
            .inner
            .reinit(protocol_version, session.user_id, session.channel_id, None)
            .map_err(dave_error)
    })
}

/// Configure the serialized MLS external sender for a DAVE session.
#[no_mangle]
pub extern "C" fn vs_dave_set_external_sender(
    session: *mut VsDaveSession,
    data: *const u8,
    len: usize,
) -> i32 {
    ffi_status(|| {
        // SAFETY: raw inputs are validated and borrowed only for this call.
        let session = unsafe { dave_session_mut(session) }?;
        let data = unsafe { input_slice(data, len, "data") }?;
        session.inner.set_external_sender(data).map_err(dave_error)
    })
}

/// Create a fresh, single-use MLS key package.
#[no_mangle]
pub extern "C" fn vs_dave_get_key_package(
    session: *mut VsDaveSession,
    out: *mut *mut u8,
    out_len: *mut usize,
) -> i32 {
    ffi_status(|| {
        // SAFETY: output slots and session pointer are validated locally.
        unsafe { output_slots(out, out_len, "out") }?;
        let session = unsafe { dave_session_mut(session) }?;
        let output = session.inner.create_key_package().map_err(dave_error)?;
        // SAFETY: `output_slots` established writable output locations.
        unsafe { return_buffer(output, out, out_len) };
        Ok(())
    })
}

/// Process gateway proposals and optionally return a commit and welcome.
#[no_mangle]
pub extern "C" fn vs_dave_process_proposals(
    session: *mut VsDaveSession,
    op_type: i32,
    data: *const u8,
    len: usize,
    recognized_user_ids_pointer: *const *const c_char,
    n_ids: usize,
    commit_out: *mut *mut u8,
    commit_len: *mut usize,
    welcome_out: *mut *mut u8,
    welcome_len: *mut usize,
) -> i32 {
    ffi_status(|| {
        // Initialize both optional outputs before any operation can fail.
        unsafe { output_slots(commit_out, commit_len, "commit_out") }?;
        unsafe { output_slots(welcome_out, welcome_len, "welcome_out") }?;
        let operation_type = match op_type {
            0 => ProposalsOperationType::APPEND,
            1 => ProposalsOperationType::REVOKE,
            _ => {
                return Err(FfiError::new(
                    STATUS_INVALID_ARGUMENT,
                    format!("unsupported proposals operation type {op_type}"),
                ));
            }
        };
        // SAFETY: all raw inputs are validated and borrowed only for this call.
        let session = unsafe { dave_session_mut(session) }?;
        let data = unsafe { input_slice(data, len, "data") }?;
        let recognized_user_ids =
            unsafe { recognized_user_ids(recognized_user_ids_pointer, n_ids) }?;
        let Some(result) = session
            .inner
            .process_proposals(operation_type, data, recognized_user_ids.as_deref())
            .map_err(dave_error)?
        else {
            return Ok(());
        };

        // SAFETY: both output pairs were validated and initialized above.
        unsafe { return_buffer(result.commit, commit_out, commit_len) };
        if let Some(welcome) = result.welcome {
            unsafe { return_buffer(welcome, welcome_out, welcome_len) };
        }
        Ok(())
    })
}

/// Process an MLS commit transition.
#[no_mangle]
pub extern "C" fn vs_dave_process_commit(
    session: *mut VsDaveSession,
    data: *const u8,
    len: usize,
) -> i32 {
    ffi_status(|| {
        // SAFETY: raw inputs are validated and borrowed only for this call.
        let session = unsafe { dave_session_mut(session) }?;
        let data = unsafe { input_slice(data, len, "data") }?;
        session
            .inner
            .process_commit(data)
            .map_err(|error| process_commit_error(error, data, &session.inner))
    })
}

/// Process an MLS welcome transition.
#[no_mangle]
pub extern "C" fn vs_dave_process_welcome(
    session: *mut VsDaveSession,
    data: *const u8,
    len: usize,
    recognized_user_ids_pointer: *const *const c_char,
    n_ids: usize,
) -> i32 {
    ffi_status(|| {
        // davey 0.1.4 does not expose recognized-user validation for Welcome
        // (its implementation has a TODO). Validate the ABI input now so a
        // future davey API can consume it without changing this boundary.
        let _recognized_user_ids =
            unsafe { recognized_user_ids(recognized_user_ids_pointer, n_ids) }?;
        // SAFETY: raw inputs are validated and borrowed only for this call.
        let session = unsafe { dave_session_mut(session) }?;
        let data = unsafe { input_slice(data, len, "data") }?;
        session
            .inner
            .process_welcome(data)
            .map_err(process_welcome_error)
    })
}

/// Encrypt one Opus frame. davey 0.1.4 does not require an SSRC.
#[no_mangle]
pub extern "C" fn vs_dave_encrypt_opus(
    session: *mut VsDaveSession,
    frame: *const u8,
    len: usize,
    out: *mut *mut u8,
    out_len: *mut usize,
) -> i32 {
    ffi_status(|| {
        // SAFETY: all pointers are validated and borrowed only for this call.
        unsafe { output_slots(out, out_len, "out") }?;
        let session = unsafe { dave_session_mut(session) }?;
        let frame = unsafe { input_slice(frame, len, "frame") }?;
        let output = session
            .inner
            .encrypt_opus(frame)
            .map_err(dave_error)?
            .into_owned();
        // SAFETY: `output_slots` established writable output locations.
        unsafe { return_buffer(output, out, out_len) };
        Ok(())
    })
}

/// Decrypt one DAVE audio frame from `user_id`.
#[no_mangle]
pub extern "C" fn vs_dave_decrypt(
    session: *mut VsDaveSession,
    user_id_pointer: *const c_char,
    frame: *const u8,
    len: usize,
    out: *mut *mut u8,
    out_len: *mut usize,
) -> i32 {
    ffi_status(|| {
        // SAFETY: all pointers are validated and borrowed only for this call.
        unsafe { output_slots(out, out_len, "out") }?;
        let session = unsafe { dave_session_mut(session) }?;
        let user_id = unsafe { user_id(user_id_pointer, "user_id") }?;
        let frame = unsafe { input_slice(frame, len, "frame") }?;
        let output = session
            .inner
            .decrypt(user_id, MediaType::AUDIO, frame)
            .map_err(dave_error)?;
        // SAFETY: `output_slots` established writable output locations.
        unsafe { return_buffer(output, out, out_len) };
        Ok(())
    })
}

/// Return 0 (inactive), 1 (pending), or 2 (active).
#[no_mangle]
pub extern "C" fn vs_dave_session_status(session: *mut VsDaveSession) -> i32 {
    ffi_i32(|| {
        // SAFETY: the pointer is validated before it is dereferenced.
        let session = unsafe { dave_session_mut(session) }?;
        Ok(match session.inner.status() {
            SessionStatus::INACTIVE => 0,
            SessionStatus::PENDING | SessionStatus::AWAITING_RESPONSE => 1,
            SessionStatus::ACTIVE => 2,
        })
    })
}

/// Return the displayable pairwise verification code for `user_id`.
#[no_mangle]
pub extern "C" fn vs_dave_get_verification_code(
    session: *mut VsDaveSession,
    user_id_pointer: *const c_char,
    out: *mut *mut u8,
    out_len: *mut usize,
) -> i32 {
    ffi_status(|| {
        // SAFETY: all pointers are validated and borrowed only for this call.
        unsafe { output_slots(out, out_len, "out") }?;
        let session = unsafe { dave_session_mut(session) }?;
        let user_id = unsafe { user_id(user_id_pointer, "user_id") }?;
        let output = session
            .inner
            .get_verification_code(user_id)
            .map_err(dave_error)?
            .into_bytes();
        // SAFETY: `output_slots` established writable output locations.
        unsafe { return_buffer(output, out, out_len) };
        Ok(())
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use openmls::prelude::tls_codec::Serialize;
    use openmls::prelude::{
        BasicCredential, Ciphersuite, ExternalProposal, ExternalSender, GroupEpoch, GroupId,
        KeyPackageIn, OpenMlsProvider, ProtocolVersion, SenderExtensionIndex, VLBytes,
    };
    use openmls_basic_credential::SignatureKeyPair;
    use openmls_rust_crypto::OpenMlsRustCrypto;

    const ALICE_ID: &str = "100000000000000001";
    const BOB_ID: &str = "100000000000000002";
    const CHANNEL_ID: u64 = 200_000_000_000_000_001;

    struct TestSession(*mut VsDaveSession);

    impl TestSession {
        fn new(user_id: &CString) -> Self {
            let pointer = vs_dave_session_create(1, user_id.as_ptr(), CHANNEL_ID);
            assert!(!pointer.is_null(), "{}", last_error());
            Self(pointer)
        }
    }

    impl Drop for TestSession {
        fn drop(&mut self) {
            vs_dave_session_destroy(self.0);
        }
    }

    fn last_error() -> String {
        // SAFETY: `vs_last_error` returns a thread-local NUL-terminated string
        // that remains live until the next shim call on this thread.
        unsafe { CStr::from_ptr(vs_last_error()) }
            .to_string_lossy()
            .into_owned()
    }

    fn call_output(call: impl FnOnce(*mut *mut u8, *mut usize) -> i32) -> Vec<u8> {
        let mut pointer = ptr::null_mut();
        let mut length = 0;
        let status = call(&mut pointer, &mut length);
        assert_eq!(status, STATUS_OK, "{}", last_error());
        assert!(!pointer.is_null());
        // SAFETY: the successful call returned `length` readable bytes and the
        // exact pointer/length pair is released through the public C ABI.
        let output = unsafe { std::slice::from_raw_parts(pointer, length) }.to_vec();
        vs_free(pointer, length);
        output
    }

    fn key_package(session: *mut VsDaveSession) -> Vec<u8> {
        call_output(|out, out_len| vs_dave_get_key_package(session, out, out_len))
    }

    fn external_sender() -> (Vec<u8>, SignatureKeyPair) {
        let ciphersuite = Ciphersuite::MLS_128_DHKEMP256_AES128GCM_SHA256_P256;
        let signer = SignatureKeyPair::new(ciphersuite.signature_algorithm()).unwrap();
        let credential: openmls::prelude::Credential =
            BasicCredential::new(b"delivery-service".to_vec()).into();
        let sender = ExternalSender::new(signer.public().to_vec().into(), credential);
        (sender.tls_serialize_detached().unwrap(), signer)
    }

    fn add_proposal(key_package: &[u8], signer: &SignatureKeyPair) -> Vec<u8> {
        let provider = OpenMlsRustCrypto::default();
        let key_package = KeyPackageIn::tls_deserialize_exact_bytes(key_package)
            .unwrap()
            .validate(provider.crypto(), ProtocolVersion::Mls10)
            .unwrap();
        let message = ExternalProposal::new_add::<OpenMlsRustCrypto>(
            key_package,
            GroupId::from_slice(&CHANNEL_ID.to_be_bytes()),
            GroupEpoch::from(0),
            signer,
            SenderExtensionIndex::new(0),
        )
        .unwrap()
        .tls_serialize_detached()
        .unwrap();
        VLBytes::from(message).tls_serialize_detached().unwrap()
    }

    fn process_add_proposal(
        session: *mut VsDaveSession,
        proposal: &[u8],
        recognized_id: &CString,
    ) -> (Vec<u8>, Vec<u8>) {
        let ids = [recognized_id.as_ptr()];
        let mut commit_pointer = ptr::null_mut();
        let mut commit_length = 0;
        let mut welcome_pointer = ptr::null_mut();
        let mut welcome_length = 0;
        let status = vs_dave_process_proposals(
            session,
            0,
            proposal.as_ptr(),
            proposal.len(),
            ids.as_ptr(),
            ids.len(),
            &mut commit_pointer,
            &mut commit_length,
            &mut welcome_pointer,
            &mut welcome_length,
        );
        assert_eq!(status, STATUS_OK, "{}", last_error());
        assert!(!commit_pointer.is_null());
        assert!(!welcome_pointer.is_null());
        // SAFETY: successful proposal processing returned both buffers.
        let commit = unsafe { std::slice::from_raw_parts(commit_pointer, commit_length) }.to_vec();
        let welcome =
            unsafe { std::slice::from_raw_parts(welcome_pointer, welcome_length) }.to_vec();
        vs_free(commit_pointer, commit_length);
        vs_free(welcome_pointer, welcome_length);
        (commit, welcome)
    }

    #[test]
    fn dave_c_abi_two_member_group_and_error_classification() {
        let alice_id = CString::new(ALICE_ID).unwrap();
        let bob_id = CString::new(BOB_ID).unwrap();
        let alice = TestSession::new(&alice_id);
        let bob = TestSession::new(&bob_id);

        assert_eq!(vs_abi_version(), 2);
        assert_eq!(vs_dave_max_protocol_version(), 1);
        assert_eq!(vs_dave_session_status(alice.0), 0);

        let (external_sender, external_signer) = external_sender();
        for session in [alice.0, bob.0] {
            assert_eq!(
                vs_dave_set_external_sender(
                    session,
                    external_sender.as_ptr(),
                    external_sender.len(),
                ),
                STATUS_OK,
                "{}",
                last_error()
            );
            assert_eq!(vs_dave_session_status(session), 1);
        }

        let empty_proposals = VLBytes::from(Vec::<u8>::new())
            .tls_serialize_detached()
            .unwrap();
        let mut absent_commit = ptr::dangling_mut();
        let mut absent_commit_len = 1;
        let mut absent_welcome = ptr::dangling_mut();
        let mut absent_welcome_len = 1;
        assert_eq!(
            vs_dave_process_proposals(
                alice.0,
                0,
                empty_proposals.as_ptr(),
                empty_proposals.len(),
                ptr::null(),
                0,
                &mut absent_commit,
                &mut absent_commit_len,
                &mut absent_welcome,
                &mut absent_welcome_len,
            ),
            STATUS_OK,
            "{}",
            last_error()
        );
        assert!(absent_commit.is_null());
        assert_eq!(absent_commit_len, 0);
        assert!(absent_welcome.is_null());
        assert_eq!(absent_welcome_len, 0);

        // davey promises a newly generated, single-use KeyPackage on every
        // call; exercise that promise through the C allocation boundary.
        let first_key_package = key_package(bob.0);
        let second_key_package = key_package(bob.0);
        assert_ne!(first_key_package, second_key_package);

        let proposal = add_proposal(&second_key_package, &external_signer);
        let (commit, welcome) = process_add_proposal(alice.0, &proposal, &bob_id);
        assert_eq!(vs_dave_session_status(alice.0), 1);

        assert_eq!(
            vs_dave_process_commit(alice.0, commit.as_ptr(), commit.len()),
            STATUS_OK,
            "{}",
            last_error()
        );
        let recognized_ids = [alice_id.as_ptr(), bob_id.as_ptr()];
        assert_eq!(
            vs_dave_process_welcome(
                bob.0,
                welcome.as_ptr(),
                welcome.len(),
                recognized_ids.as_ptr(),
                recognized_ids.len(),
            ),
            STATUS_OK,
            "{}",
            last_error()
        );
        assert_eq!(vs_dave_session_status(alice.0), 2);
        assert_eq!(vs_dave_session_status(bob.0), 2);

        let opus_frame = [0x78, 0x11, 0x22, 0x33, 0x44, 0x55];
        let encrypted = call_output(|out, out_len| {
            vs_dave_encrypt_opus(alice.0, opus_frame.as_ptr(), opus_frame.len(), out, out_len)
        });
        assert_ne!(encrypted, opus_frame);
        let decrypted = call_output(|out, out_len| {
            vs_dave_decrypt(
                bob.0,
                alice_id.as_ptr(),
                encrypted.as_ptr(),
                encrypted.len(),
                out,
                out_len,
            )
        });
        assert_eq!(decrypted, opus_frame);

        let alice_code = call_output(|out, out_len| {
            vs_dave_get_verification_code(alice.0, bob_id.as_ptr(), out, out_len)
        });
        let bob_code = call_output(|out, out_len| {
            vs_dave_get_verification_code(bob.0, alice_id.as_ptr(), out, out_len)
        });
        assert_eq!(alice_code, bob_code);
        assert!(!alice_code.is_empty());

        // A malformed commit requires recovery, while replaying the already
        // applied epoch-0 commit at epoch 1 is safely ignorable.
        let malformed_commit = [0xff];
        assert_eq!(
            vs_dave_process_commit(alice.0, malformed_commit.as_ptr(), malformed_commit.len(),),
            STATUS_DAVE_INVALID_TRANSITION
        );
        assert_eq!(
            vs_dave_process_commit(alice.0, commit.as_ptr(), commit.len()),
            STATUS_DAVE_IGNORABLE_TRANSITION
        );
        assert_eq!(
            vs_dave_process_welcome(
                bob.0,
                welcome.as_ptr(),
                welcome.len(),
                recognized_ids.as_ptr(),
                recognized_ids.len(),
            ),
            STATUS_DAVE_IGNORABLE_TRANSITION
        );
    }
}
