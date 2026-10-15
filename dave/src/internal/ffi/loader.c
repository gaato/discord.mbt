/* Dynamic MoonBit binding for the official libdave v1.2.0 C API.
 *
 * libdave-owned output buffers are copied into MoonBit Bytes and released
 * before returning. Successful dynamic-library handles intentionally remain
 * loaded because GC finalizers call through the resolved function table.
 */
#include <moonbit.h>

#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MBT_DAVE_UNAVAILABLE (-100)
#define MBT_DAVE_MISSING_SYMBOL (-101)
#define MBT_DAVE_INVALID_ARGUMENT (-102)
#define MBT_DAVE_OUTPUT_TOO_LARGE (-103)
#define MBT_DAVE_ALLOCATION_FAILURE (-104)
#define MBT_DAVE_CALL_FAILURE (-105)

typedef struct DAVESessionHandle_s *DAVESessionHandle;
typedef struct DAVECommitResultHandle_s *DAVECommitResultHandle;
typedef struct DAVEWelcomeResultHandle_s *DAVEWelcomeResultHandle;
typedef struct DAVEKeyRatchetHandle_s *DAVEKeyRatchetHandle;
typedef struct DAVEEncryptorHandle_s *DAVEEncryptorHandle;
typedef struct DAVEDecryptorHandle_s *DAVEDecryptorHandle;

typedef enum {
  DAVE_CODEC_UNKNOWN = 0,
  DAVE_CODEC_OPUS = 1,
  DAVE_CODEC_VP8 = 2,
  DAVE_CODEC_VP9 = 3,
  DAVE_CODEC_H264 = 4,
  DAVE_CODEC_H265 = 5,
  DAVE_CODEC_AV1 = 6
} DAVECodec;

typedef enum {
  DAVE_MEDIA_TYPE_AUDIO = 0,
  DAVE_MEDIA_TYPE_VIDEO = 1
} DAVEMediaType;

typedef enum {
  DAVE_ENCRYPTOR_RESULT_CODE_SUCCESS = 0,
  DAVE_ENCRYPTOR_RESULT_CODE_ENCRYPTION_FAILURE = 1,
  DAVE_ENCRYPTOR_RESULT_CODE_MISSING_KEY_RATCHET = 2,
  DAVE_ENCRYPTOR_RESULT_CODE_MISSING_CRYPTOR = 3,
  DAVE_ENCRYPTOR_RESULT_CODE_TOO_MANY_ATTEMPTS = 4
} DAVEEncryptorResultCode;

typedef enum {
  DAVE_DECRYPTOR_RESULT_CODE_SUCCESS = 0,
  DAVE_DECRYPTOR_RESULT_CODE_DECRYPTION_FAILURE = 1,
  DAVE_DECRYPTOR_RESULT_CODE_MISSING_KEY_RATCHET = 2,
  DAVE_DECRYPTOR_RESULT_CODE_INVALID_NONCE = 3,
  DAVE_DECRYPTOR_RESULT_CODE_MISSING_CRYPTOR = 4
} DAVEDecryptorResultCode;

typedef enum {
  DAVE_LOGGING_SEVERITY_VERBOSE = 0,
  DAVE_LOGGING_SEVERITY_INFO = 1,
  DAVE_LOGGING_SEVERITY_WARNING = 2,
  DAVE_LOGGING_SEVERITY_ERROR = 3,
  DAVE_LOGGING_SEVERITY_NONE = 4
} DAVELoggingSeverity;

typedef void (*DAVEMLSFailureCallback)(const char *, const char *, void *);
typedef void (*DAVEPairwiseFingerprintCallback)(const uint8_t *, size_t,
                                                 void *);
typedef void (*DAVELogSinkCallback)(DAVELoggingSeverity, const char *, int,
                                    const char *);

typedef uint16_t (*dave_max_supported_protocol_version_fn)(void);
typedef void (*dave_free_fn)(void *);
typedef DAVESessionHandle (*dave_session_create_fn)(
    void *, const char *, DAVEMLSFailureCallback, void *);
typedef void (*dave_session_destroy_fn)(DAVESessionHandle);
typedef void (*dave_session_init_fn)(DAVESessionHandle, uint16_t, uint64_t,
                                     const char *);
typedef void (*dave_session_reset_fn)(DAVESessionHandle);
typedef void (*dave_session_set_protocol_version_fn)(DAVESessionHandle,
                                                      uint16_t);
typedef uint16_t (*dave_session_get_protocol_version_fn)(DAVESessionHandle);
typedef void (*dave_session_get_bytes_fn)(DAVESessionHandle, uint8_t **,
                                          size_t *);
typedef void (*dave_session_set_external_sender_fn)(DAVESessionHandle,
                                                     const uint8_t *, size_t);
typedef void (*dave_session_process_proposals_fn)(
    DAVESessionHandle, const uint8_t *, size_t, const char **, size_t,
    uint8_t **, size_t *);
typedef DAVECommitResultHandle (*dave_session_process_commit_fn)(
    DAVESessionHandle, const uint8_t *, size_t);
typedef DAVEWelcomeResultHandle (*dave_session_process_welcome_fn)(
    DAVESessionHandle, const uint8_t *, size_t, const char **, size_t);
typedef DAVEKeyRatchetHandle (*dave_session_get_key_ratchet_fn)(
    DAVESessionHandle, const char *);
typedef void (*dave_session_get_pairwise_fingerprint_fn)(
    DAVESessionHandle, uint16_t, const char *,
    DAVEPairwiseFingerprintCallback, void *);
typedef void (*dave_key_ratchet_destroy_fn)(DAVEKeyRatchetHandle);
typedef bool (*dave_commit_result_predicate_fn)(DAVECommitResultHandle);
typedef void (*dave_commit_result_get_ids_fn)(DAVECommitResultHandle,
                                               uint64_t **, size_t *);
typedef void (*dave_commit_result_get_signature_fn)(DAVECommitResultHandle,
                                                     uint64_t, uint8_t **,
                                                     size_t *);
typedef void (*dave_commit_result_destroy_fn)(DAVECommitResultHandle);
typedef void (*dave_welcome_result_get_ids_fn)(DAVEWelcomeResultHandle,
                                                uint64_t **, size_t *);
typedef void (*dave_welcome_result_get_signature_fn)(DAVEWelcomeResultHandle,
                                                      uint64_t, uint8_t **,
                                                      size_t *);
typedef void (*dave_welcome_result_destroy_fn)(DAVEWelcomeResultHandle);
typedef DAVEEncryptorHandle (*dave_encryptor_create_fn)(void);
typedef void (*dave_encryptor_destroy_fn)(DAVEEncryptorHandle);
typedef void (*dave_encryptor_set_key_ratchet_fn)(DAVEEncryptorHandle,
                                                   DAVEKeyRatchetHandle);
typedef void (*dave_encryptor_set_passthrough_fn)(DAVEEncryptorHandle, bool);
typedef void (*dave_encryptor_assign_ssrc_fn)(DAVEEncryptorHandle, uint32_t,
                                              DAVECodec);
typedef uint16_t (*dave_encryptor_get_protocol_version_fn)(DAVEEncryptorHandle);
typedef size_t (*dave_encryptor_get_max_ciphertext_fn)(DAVEEncryptorHandle,
                                                       DAVEMediaType, size_t);
typedef bool (*dave_encryptor_predicate_fn)(DAVEEncryptorHandle);
typedef DAVEEncryptorResultCode (*dave_encryptor_encrypt_fn)(
    DAVEEncryptorHandle, DAVEMediaType, uint32_t, const uint8_t *, size_t,
    uint8_t *, size_t, size_t *);
typedef DAVEDecryptorHandle (*dave_decryptor_create_fn)(void);
typedef void (*dave_decryptor_destroy_fn)(DAVEDecryptorHandle);
typedef void (*dave_decryptor_set_key_ratchet_fn)(DAVEDecryptorHandle,
                                                   DAVEKeyRatchetHandle);
typedef void (*dave_decryptor_set_passthrough_fn)(DAVEDecryptorHandle, bool);
typedef DAVEDecryptorResultCode (*dave_decryptor_decrypt_fn)(
    DAVEDecryptorHandle, DAVEMediaType, const uint8_t *, size_t, uint8_t *,
    size_t, size_t *);
typedef size_t (*dave_decryptor_get_max_plaintext_fn)(DAVEDecryptorHandle,
                                                      DAVEMediaType, size_t);
typedef void (*dave_set_log_sink_fn)(DAVELogSinkCallback);

typedef struct {
  int32_t status;
  char reason[768];
  void *library;
  dave_max_supported_protocol_version_fn max_supported_protocol_version;
  dave_free_fn free_output;
  dave_session_create_fn session_create;
  dave_session_destroy_fn session_destroy;
  dave_session_init_fn session_init;
  dave_session_reset_fn session_reset;
  dave_session_set_protocol_version_fn session_set_protocol_version;
  dave_session_get_protocol_version_fn session_get_protocol_version;
  dave_session_get_bytes_fn session_get_last_epoch_authenticator;
  dave_session_set_external_sender_fn session_set_external_sender;
  dave_session_process_proposals_fn session_process_proposals;
  dave_session_process_commit_fn session_process_commit;
  dave_session_process_welcome_fn session_process_welcome;
  dave_session_get_bytes_fn session_get_key_package;
  dave_session_get_key_ratchet_fn session_get_key_ratchet;
  dave_session_get_pairwise_fingerprint_fn session_get_pairwise_fingerprint;
  dave_key_ratchet_destroy_fn key_ratchet_destroy;
  dave_commit_result_predicate_fn commit_result_is_failed;
  dave_commit_result_predicate_fn commit_result_is_ignored;
  dave_commit_result_get_ids_fn commit_result_get_ids;
  dave_commit_result_get_signature_fn commit_result_get_signature;
  dave_commit_result_destroy_fn commit_result_destroy;
  dave_welcome_result_get_ids_fn welcome_result_get_ids;
  dave_welcome_result_get_signature_fn welcome_result_get_signature;
  dave_welcome_result_destroy_fn welcome_result_destroy;
  dave_encryptor_create_fn encryptor_create;
  dave_encryptor_destroy_fn encryptor_destroy;
  dave_encryptor_set_key_ratchet_fn encryptor_set_key_ratchet;
  dave_encryptor_set_passthrough_fn encryptor_set_passthrough;
  dave_encryptor_assign_ssrc_fn encryptor_assign_ssrc;
  dave_encryptor_get_protocol_version_fn encryptor_get_protocol_version;
  dave_encryptor_get_max_ciphertext_fn encryptor_get_max_ciphertext;
  dave_encryptor_predicate_fn encryptor_has_key;
  dave_encryptor_predicate_fn encryptor_is_passthrough;
  dave_encryptor_encrypt_fn encryptor_encrypt;
  dave_decryptor_create_fn decryptor_create;
  dave_decryptor_destroy_fn decryptor_destroy;
  dave_decryptor_set_key_ratchet_fn decryptor_set_key_ratchet;
  dave_decryptor_set_passthrough_fn decryptor_set_passthrough;
  dave_decryptor_decrypt_fn decryptor_decrypt;
  dave_decryptor_get_max_plaintext_fn decryptor_get_max_plaintext;
  dave_set_log_sink_fn set_log_sink;
} MbtDaveApi;

static MbtDaveApi mbt_dave_global_api;

#if defined(_WIN32)
#include <windows.h>

#ifndef LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR
#define LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR 0x00000100
#endif
#ifndef LOAD_LIBRARY_SEARCH_SYSTEM32
#define LOAD_LIBRARY_SEARCH_SYSTEM32 0x00000800
#endif

static DWORD mbt_dave_windows_last_library_error;

static int mbt_dave_windows_environment_utf8(const wchar_t *name,
                                              char *output,
                                              size_t output_len) {
  SetLastError(ERROR_SUCCESS);
  DWORD required_wide = GetEnvironmentVariableW(name, NULL, 0);
  if (required_wide == 0) {
    DWORD error = GetLastError();
    return error == ERROR_SUCCESS || error == ERROR_ENVVAR_NOT_FOUND ? 0 : -1;
  }
  wchar_t *wide = malloc((size_t)required_wide * sizeof(wchar_t));
  if (wide == NULL) {
    return -1;
  }
  DWORD copied = GetEnvironmentVariableW(name, wide, required_wide);
  if (copied == 0 || copied >= required_wide) {
    free(wide);
    return -1;
  }
  int required_utf8 =
      WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide, -1, NULL, 0,
                          NULL, NULL);
  if (required_utf8 <= 0 || (size_t)required_utf8 > output_len) {
    free(wide);
    return -1;
  }
  int converted =
      WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide, -1, output,
                          required_utf8, NULL, NULL);
  free(wide);
  return converted == required_utf8 ? 1 : -1;
}

static void *mbt_dave_library_open(const char *path) {
  int required = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1,
                                     NULL, 0);
  if (required <= 0) {
    mbt_dave_windows_last_library_error = GetLastError();
    if (mbt_dave_windows_last_library_error == ERROR_SUCCESS) {
      mbt_dave_windows_last_library_error = ERROR_NO_UNICODE_TRANSLATION;
    }
    return NULL;
  }
  wchar_t *wide = malloc((size_t)required * sizeof(wchar_t));
  if (wide == NULL) {
    mbt_dave_windows_last_library_error = ERROR_NOT_ENOUGH_MEMORY;
    return NULL;
  }
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide,
                          required) != required) {
    mbt_dave_windows_last_library_error = GetLastError();
    free(wide);
    return NULL;
  }
  HMODULE library = LoadLibraryExW(
      wide, NULL,
      LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
  mbt_dave_windows_last_library_error =
      library == NULL ? GetLastError() : ERROR_SUCCESS;
  free(wide);
  return (void *)library;
}

static void mbt_dave_library_close(void *library) {
  if (library != NULL) {
    FreeLibrary((HMODULE)library);
  }
}

static int mbt_dave_library_symbol(void *library, const char *name,
                                   void *destination,
                                   size_t destination_size, char *reason,
                                   size_t reason_len) {
  FARPROC symbol = GetProcAddress((HMODULE)library, name);
  if (symbol == NULL) {
    snprintf(reason, reason_len,
             "official libdave is missing symbol %s (Windows error %lu)",
             name, (unsigned long)GetLastError());
    return 0;
  }
  if (destination_size != sizeof(symbol)) {
    snprintf(reason, reason_len,
             "function pointer size is unsupported while loading %s", name);
    return 0;
  }
  memcpy(destination, &symbol, sizeof(symbol));
  return 1;
}

static void mbt_dave_open_error(char *reason, size_t reason_len,
                                const char *path) {
  snprintf(reason, reason_len, "failed to load %s (Windows error %lu)", path,
           (unsigned long)mbt_dave_windows_last_library_error);
}
#else
#include <dlfcn.h>
#include <pthread.h>

static void *mbt_dave_library_open(const char *path) {
  return dlopen(path, RTLD_NOW | RTLD_LOCAL);
}

static void mbt_dave_library_close(void *library) {
  if (library != NULL) {
    dlclose(library);
  }
}

static int mbt_dave_library_symbol(void *library, const char *name,
                                   void *destination,
                                   size_t destination_size, char *reason,
                                   size_t reason_len) {
  (void)dlerror();
  void *symbol = dlsym(library, name);
  const char *detail = dlerror();
  if (detail != NULL) {
    snprintf(reason, reason_len,
             "official libdave is missing symbol %s: %s", name, detail);
    return 0;
  }
  if (destination_size != sizeof(symbol)) {
    snprintf(reason, reason_len,
             "function pointer size is unsupported while loading %s", name);
    return 0;
  }
  memcpy(destination, &symbol, sizeof(symbol));
  return 1;
}

static void mbt_dave_open_error(char *reason, size_t reason_len,
                                const char *path) {
  const char *detail = dlerror();
  snprintf(reason, reason_len, "failed to load %s: %s", path,
           detail == NULL ? "unknown loader error" : detail);
}
#endif

static int mbt_dave_join_path(char *output, size_t output_len,
                              const char *base, const char *relative) {
  if (base == NULL || base[0] == '\0' || relative == NULL) {
    return 0;
  }
  size_t base_len = strlen(base);
  int has_separator = base_len != 0 &&
                      (base[base_len - 1] == '/' ||
                       base[base_len - 1] == '\\');
  int written = snprintf(output, output_len, has_separator ? "%s%s" : "%s/%s",
                         base, relative);
  return written >= 0 && (size_t)written < output_len;
}

static int mbt_dave_path_is_absolute(const char *path) {
  if (path == NULL || path[0] == '\0') {
    return 0;
  }
#if defined(_WIN32)
  int first_is_separator = path[0] == '/' || path[0] == '\\';
  int second_is_separator = path[1] == '/' || path[1] == '\\';
  return (first_is_separator && second_is_separator) ||
         (((path[0] >= 'A' && path[0] <= 'Z') ||
           (path[0] >= 'a' && path[0] <= 'z')) &&
          path[1] == ':' && (path[2] == '/' || path[2] == '\\'));
#else
  return path[0] == '/';
#endif
}

static const char *mbt_dave_asset_id(void) {
#if defined(_WIN32) && (defined(_M_X64) || defined(__x86_64__))
  return "windows-x64";
#elif defined(__APPLE__) &&                                                    \
    (defined(__aarch64__) || defined(__arm64__) || defined(_M_ARM64))
  return "macos-arm64";
#elif defined(__APPLE__) && (defined(__x86_64__) || defined(_M_X64))
  return "macos-x64";
#elif defined(__linux__) && (defined(__aarch64__) || defined(_M_ARM64))
  return "linux-arm64";
#elif defined(__linux__) && (defined(__x86_64__) || defined(_M_X64))
  return "linux-x64";
#else
  return NULL;
#endif
}

static const char *mbt_dave_library_relative_path(void) {
#if defined(_WIN32)
  return "bin/libdave.dll";
#elif defined(__APPLE__)
  return "lib/libdave.dylib";
#else
  return "lib/libdave.so";
#endif
}

static int mbt_dave_default_cache_base(char *output, size_t output_len) {
#if defined(_WIN32)
  char environment_path[4096];
  int environment_status = mbt_dave_windows_environment_utf8(
      L"LOCALAPPDATA", environment_path, sizeof(environment_path));
  if (environment_status == 1 &&
      mbt_dave_path_is_absolute(environment_path)) {
    int written = snprintf(output, output_len, "%s", environment_path);
    return written >= 0 && (size_t)written < output_len;
  }
  environment_status = mbt_dave_windows_environment_utf8(
      L"USERPROFILE", environment_path, sizeof(environment_path));
  if (environment_status != 1) {
    environment_status = mbt_dave_windows_environment_utf8(
        L"HOME", environment_path, sizeof(environment_path));
  }
  return environment_status == 1 &&
         mbt_dave_path_is_absolute(environment_path) &&
         mbt_dave_join_path(output, output_len, environment_path,
                            "AppData/Local");
#elif defined(__APPLE__)
  const char *home = getenv("HOME");
  return mbt_dave_path_is_absolute(home) &&
         mbt_dave_join_path(output, output_len, home,
                            "Library/Caches");
#else
  const char *xdg_cache = getenv("XDG_CACHE_HOME");
  if (mbt_dave_path_is_absolute(xdg_cache)) {
    int written = snprintf(output, output_len, "%s", xdg_cache);
    return written >= 0 && (size_t)written < output_len;
  }
  const char *home = getenv("HOME");
  return mbt_dave_path_is_absolute(home) &&
         mbt_dave_join_path(output, output_len, home, ".cache");
#endif
}

static void *mbt_dave_try_root(const char *root, char *path,
                               size_t path_len) {
  if (!mbt_dave_path_is_absolute(root) ||
      !mbt_dave_join_path(path, path_len, root,
                          mbt_dave_library_relative_path())) {
    return NULL;
  }
  return mbt_dave_library_open(path);
}

static void *mbt_dave_open_library(char *reason, size_t reason_len) {
#if defined(_WIN32)
  char override_storage[4096];
  int override_status = mbt_dave_windows_environment_utf8(
      L"MBT_DAVE_NATIVE_LIB", override_storage, sizeof(override_storage));
  if (override_status < 0) {
    snprintf(reason, reason_len,
             "MBT_DAVE_NATIVE_LIB is too long or is not valid Unicode");
    return NULL;
  }
  const char *override = override_status == 1 ? override_storage : NULL;
#else
  const char *override = getenv("MBT_DAVE_NATIVE_LIB");
#endif
  if (override != NULL && override[0] != '\0') {
    if (!mbt_dave_path_is_absolute(override)) {
      snprintf(reason, reason_len,
               "MBT_DAVE_NATIVE_LIB must be an absolute path");
      return NULL;
    }
    void *library = mbt_dave_library_open(override);
    if (library == NULL) {
      mbt_dave_open_error(reason, reason_len, override);
    }
    return library;
  }

  char path[4096];
#if defined(_WIN32)
  char native_root_storage[4096];
  int native_root_status = mbt_dave_windows_environment_utf8(
      L"MBT_DAVE_NATIVE_ROOT", native_root_storage,
      sizeof(native_root_storage));
  if (native_root_status < 0) {
    snprintf(reason, reason_len,
             "MBT_DAVE_NATIVE_ROOT is too long or is not valid Unicode");
    return NULL;
  }
  const char *native_root =
      native_root_status == 1 ? native_root_storage : NULL;
#else
  const char *native_root = getenv("MBT_DAVE_NATIVE_ROOT");
#endif
  if (native_root != NULL && native_root[0] != '\0' &&
      !mbt_dave_path_is_absolute(native_root)) {
    snprintf(reason, reason_len,
             "MBT_DAVE_NATIVE_ROOT must be an absolute path");
    return NULL;
  }
  if (mbt_dave_path_is_absolute(native_root)) {
    if (!mbt_dave_join_path(path, sizeof(path), native_root,
                            mbt_dave_library_relative_path())) {
      snprintf(reason, reason_len,
               "MBT_DAVE_NATIVE_ROOT resolves to a path that is too long");
      return NULL;
    }
    void *library = mbt_dave_library_open(path);
    if (library == NULL) {
      mbt_dave_open_error(reason, reason_len, path);
    }
    return library;
  }

  const char *asset_id = mbt_dave_asset_id();
  if (asset_id != NULL) {
    char cache_base[4096];
#if defined(_WIN32)
    char cache_override_storage[4096];
    int cache_override_status = mbt_dave_windows_environment_utf8(
        L"MBT_DAVE_NATIVE_CACHE_DIR", cache_override_storage,
        sizeof(cache_override_storage));
    if (cache_override_status < 0) {
      snprintf(
          reason, reason_len,
          "MBT_DAVE_NATIVE_CACHE_DIR is too long or is not valid Unicode");
      return NULL;
    }
    const char *cache_override =
        cache_override_status == 1 ? cache_override_storage : NULL;
#else
    const char *cache_override = getenv("MBT_DAVE_NATIVE_CACHE_DIR");
#endif
    if (cache_override != NULL && cache_override[0] != '\0' &&
        !mbt_dave_path_is_absolute(cache_override)) {
      snprintf(reason, reason_len,
               "MBT_DAVE_NATIVE_CACHE_DIR must be an absolute path");
      return NULL;
    }
    int have_cache_base = 0;
    if (mbt_dave_path_is_absolute(cache_override)) {
      int written = snprintf(cache_base, sizeof(cache_base), "%s",
                             cache_override);
      have_cache_base =
          written >= 0 && (size_t)written < sizeof(cache_base);
    } else {
      have_cache_base =
          mbt_dave_default_cache_base(cache_base, sizeof(cache_base));
    }
    if (have_cache_base) {
      char cache_root[4096];
      char cache_suffix[256];
      int suffix_written = snprintf(
          cache_suffix, sizeof(cache_suffix),
          "gaato-dave/libdave/v1.2.0-cpp/%s", asset_id);
      if (suffix_written >= 0 &&
          (size_t)suffix_written < sizeof(cache_suffix) &&
          mbt_dave_join_path(cache_root, sizeof(cache_root), cache_base,
                             cache_suffix)) {
        void *library =
            mbt_dave_try_root(cache_root, path, sizeof(path));
        if (library != NULL) {
          return library;
        }
      }
    }
  }

  snprintf(reason, reason_len,
           "official libdave was not found at MBT_DAVE_NATIVE_ROOT or the "
           "deterministic v1.2.0-cpp cache; run the native bootstrap or set "
           "an absolute MBT_DAVE_NATIVE_LIB");
  return NULL;
}

static void mbt_dave_noop_log_sink(DAVELoggingSeverity severity,
                                   const char *file, int line,
                                   const char *message) {
  (void)severity;
  (void)file;
  (void)line;
  (void)message;
}

static int mbt_dave_load_symbol(void *library, void *destination,
                                size_t destination_size, const char *name,
                                char *reason, size_t reason_len) {
  return mbt_dave_library_symbol(library, name, destination,
                                 destination_size, reason, reason_len);
}

#define MBT_DAVE_LOAD(field, symbol_name)                                      \
  do {                                                                         \
    if (!mbt_dave_load_symbol(api->library, &api->field, sizeof(api->field),   \
                              symbol_name, api->reason, sizeof(api->reason))) { \
      goto missing_symbol;                                                      \
    }                                                                          \
  } while (0)

static void mbt_dave_initialize(void) {
  MbtDaveApi *api = &mbt_dave_global_api;
  memset(api, 0, sizeof(*api));
  api->status = MBT_DAVE_UNAVAILABLE;
  api->library = mbt_dave_open_library(api->reason, sizeof(api->reason));
  if (api->library == NULL) {
    return;
  }

  MBT_DAVE_LOAD(max_supported_protocol_version,
                "daveMaxSupportedProtocolVersion");
  MBT_DAVE_LOAD(free_output, "daveFree");
  MBT_DAVE_LOAD(session_create, "daveSessionCreate");
  MBT_DAVE_LOAD(session_destroy, "daveSessionDestroy");
  MBT_DAVE_LOAD(session_init, "daveSessionInit");
  MBT_DAVE_LOAD(session_reset, "daveSessionReset");
  MBT_DAVE_LOAD(session_set_protocol_version,
                "daveSessionSetProtocolVersion");
  MBT_DAVE_LOAD(session_get_protocol_version,
                "daveSessionGetProtocolVersion");
  MBT_DAVE_LOAD(session_get_last_epoch_authenticator,
                "daveSessionGetLastEpochAuthenticator");
  MBT_DAVE_LOAD(session_set_external_sender, "daveSessionSetExternalSender");
  MBT_DAVE_LOAD(session_process_proposals, "daveSessionProcessProposals");
  MBT_DAVE_LOAD(session_process_commit, "daveSessionProcessCommit");
  MBT_DAVE_LOAD(session_process_welcome, "daveSessionProcessWelcome");
  MBT_DAVE_LOAD(session_get_key_package,
                "daveSessionGetMarshalledKeyPackage");
  MBT_DAVE_LOAD(session_get_key_ratchet, "daveSessionGetKeyRatchet");
  MBT_DAVE_LOAD(session_get_pairwise_fingerprint,
                "daveSessionGetPairwiseFingerprint");
  MBT_DAVE_LOAD(key_ratchet_destroy, "daveKeyRatchetDestroy");
  MBT_DAVE_LOAD(commit_result_is_failed, "daveCommitResultIsFailed");
  MBT_DAVE_LOAD(commit_result_is_ignored, "daveCommitResultIsIgnored");
  MBT_DAVE_LOAD(commit_result_get_ids,
                "daveCommitResultGetRosterMemberIds");
  MBT_DAVE_LOAD(commit_result_get_signature,
                "daveCommitResultGetRosterMemberSignature");
  MBT_DAVE_LOAD(commit_result_destroy, "daveCommitResultDestroy");
  MBT_DAVE_LOAD(welcome_result_get_ids,
                "daveWelcomeResultGetRosterMemberIds");
  MBT_DAVE_LOAD(welcome_result_get_signature,
                "daveWelcomeResultGetRosterMemberSignature");
  MBT_DAVE_LOAD(welcome_result_destroy, "daveWelcomeResultDestroy");
  MBT_DAVE_LOAD(encryptor_create, "daveEncryptorCreate");
  MBT_DAVE_LOAD(encryptor_destroy, "daveEncryptorDestroy");
  MBT_DAVE_LOAD(encryptor_set_key_ratchet, "daveEncryptorSetKeyRatchet");
  MBT_DAVE_LOAD(encryptor_set_passthrough,
                "daveEncryptorSetPassthroughMode");
  MBT_DAVE_LOAD(encryptor_assign_ssrc, "daveEncryptorAssignSsrcToCodec");
  MBT_DAVE_LOAD(encryptor_get_protocol_version,
                "daveEncryptorGetProtocolVersion");
  MBT_DAVE_LOAD(encryptor_get_max_ciphertext,
                "daveEncryptorGetMaxCiphertextByteSize");
  MBT_DAVE_LOAD(encryptor_has_key, "daveEncryptorHasKeyRatchet");
  MBT_DAVE_LOAD(encryptor_is_passthrough,
                "daveEncryptorIsPassthroughMode");
  MBT_DAVE_LOAD(encryptor_encrypt, "daveEncryptorEncrypt");
  MBT_DAVE_LOAD(decryptor_create, "daveDecryptorCreate");
  MBT_DAVE_LOAD(decryptor_destroy, "daveDecryptorDestroy");
  MBT_DAVE_LOAD(decryptor_set_key_ratchet,
                "daveDecryptorTransitionToKeyRatchet");
  MBT_DAVE_LOAD(decryptor_set_passthrough,
                "daveDecryptorTransitionToPassthroughMode");
  MBT_DAVE_LOAD(decryptor_decrypt, "daveDecryptorDecrypt");
  MBT_DAVE_LOAD(decryptor_get_max_plaintext,
                "daveDecryptorGetMaxPlaintextByteSize");
  MBT_DAVE_LOAD(set_log_sink, "daveSetLogSinkCallback");

  api->set_log_sink(mbt_dave_noop_log_sink);
  api->status = 0;
  api->reason[0] = '\0';
  return;

missing_symbol:
  api->status = MBT_DAVE_MISSING_SYMBOL;
  mbt_dave_library_close(api->library);
  api->library = NULL;
}

#if defined(_WIN32)
static INIT_ONCE mbt_dave_init_once = INIT_ONCE_STATIC_INIT;

static BOOL CALLBACK mbt_dave_initialize_once(PINIT_ONCE once, PVOID parameter,
                                               PVOID *context) {
  (void)once;
  (void)parameter;
  (void)context;
  mbt_dave_initialize();
  return TRUE;
}

static const MbtDaveApi *mbt_dave_api(void) {
  InitOnceExecuteOnce(&mbt_dave_init_once, mbt_dave_initialize_once, NULL,
                      NULL);
  return &mbt_dave_global_api;
}
#else
static pthread_once_t mbt_dave_init_once = PTHREAD_ONCE_INIT;

static const MbtDaveApi *mbt_dave_api(void) {
  pthread_once(&mbt_dave_init_once, mbt_dave_initialize);
  return &mbt_dave_global_api;
}
#endif

static moonbit_bytes_t mbt_dave_copy_bytes(const uint8_t *data, size_t length) {
  if (length > INT32_MAX || (length != 0 && data == NULL)) {
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t result = moonbit_make_bytes_raw((int32_t)length);
  if (length != 0) {
    memcpy(result, data, length);
  }
  return result;
}

static moonbit_bytes_t mbt_dave_copy_string(const char *text) {
  if (text == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  return mbt_dave_copy_bytes((const uint8_t *)text, strlen(text));
}

MOONBIT_FFI_EXPORT int32_t mbt_dave_loader_status(void) {
  return mbt_dave_api()->status;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t mbt_dave_loader_reason(void) {
  return mbt_dave_copy_string(mbt_dave_api()->reason);
}

MOONBIT_FFI_EXPORT uint16_t mbt_dave_max_supported_protocol_version(void) {
  const MbtDaveApi *api = mbt_dave_api();
  if (api->status != 0) {
    return 0;
  }
  return api->max_supported_protocol_version();
}

typedef struct {
  DAVESessionHandle handle;
  int32_t last_status;
  char *failure_source;
  char *failure_reason;
} MbtDaveSession;

typedef struct {
  DAVEKeyRatchetHandle handle;
} MbtDaveKeyRatchet;

typedef struct {
  DAVEEncryptorHandle handle;
  int32_t last_status;
} MbtDaveEncryptor;

typedef struct {
  DAVEDecryptorHandle handle;
  int32_t last_status;
} MbtDaveDecryptor;

static char *mbt_dave_duplicate_string(const char *value) {
  if (value == NULL) {
    return NULL;
  }
  size_t length = strlen(value);
  char *copy = (char *)malloc(length + 1);
  if (copy != NULL) {
    memcpy(copy, value, length + 1);
  }
  return copy;
}

static void mbt_dave_session_clear_failure(MbtDaveSession *session) {
  char *source = session->failure_source;
  char *reason = session->failure_reason;
  session->failure_source = NULL;
  session->failure_reason = NULL;
  free(source);
  free(reason);
}

static void mbt_dave_session_set_failure(MbtDaveSession *session,
                                         const char *source,
                                         const char *reason) {
  char *source_copy = mbt_dave_duplicate_string(source == NULL ? "" : source);
  char *reason_copy = mbt_dave_duplicate_string(reason == NULL ? "" : reason);
  mbt_dave_session_clear_failure(session);
  session->failure_source = source_copy;
  session->failure_reason = reason_copy;
}

static void mbt_dave_mls_failure(const char *source, const char *reason,
                                 void *user_data) {
  MbtDaveSession *session = (MbtDaveSession *)user_data;
  if (session != NULL) {
    mbt_dave_session_set_failure(session, source, reason);
  }
}

static void mbt_dave_session_binding_failure(MbtDaveSession *session,
                                             int32_t status,
                                             const char *reason) {
  if (session != NULL) {
    session->last_status = status;
    mbt_dave_session_set_failure(session, "gaato/dave binding", reason);
  }
}

static void mbt_dave_session_protocol_failure_if_empty(
    MbtDaveSession *session, const char *reason) {
  if (session->failure_source == NULL && session->failure_reason == NULL) {
    mbt_dave_session_set_failure(session, "libdave", reason);
  }
}

static int mbt_dave_session_begin(MbtDaveSession *session) {
  const MbtDaveApi *api = mbt_dave_api();
  if (session == NULL) {
    return 0;
  }
  mbt_dave_session_clear_failure(session);
  session->last_status = 0;
  if (api->status != 0) {
    mbt_dave_session_binding_failure(session, api->status, api->reason);
    return 0;
  }
  if (session->handle == NULL) {
    mbt_dave_session_binding_failure(session, MBT_DAVE_INVALID_ARGUMENT,
                                     "invalid session handle");
    return 0;
  }
  return 1;
}

static void mbt_dave_session_finalize(void *pointer) {
  MbtDaveSession *session = (MbtDaveSession *)pointer;
  if (session->handle != NULL) {
    const MbtDaveApi *api = mbt_dave_api();
    if (api->status == 0) {
      api->session_destroy(session->handle);
    }
    session->handle = NULL;
  }
  mbt_dave_session_clear_failure(session);
}

static void mbt_dave_key_ratchet_finalize(void *pointer) {
  MbtDaveKeyRatchet *key_ratchet = (MbtDaveKeyRatchet *)pointer;
  if (key_ratchet->handle != NULL) {
    const MbtDaveApi *api = mbt_dave_api();
    if (api->status == 0) {
      api->key_ratchet_destroy(key_ratchet->handle);
    }
    key_ratchet->handle = NULL;
  }
}

static void mbt_dave_encryptor_finalize(void *pointer) {
  MbtDaveEncryptor *encryptor = (MbtDaveEncryptor *)pointer;
  if (encryptor->handle != NULL) {
    const MbtDaveApi *api = mbt_dave_api();
    if (api->status == 0) {
      api->encryptor_destroy(encryptor->handle);
    }
    encryptor->handle = NULL;
  }
}

static void mbt_dave_decryptor_finalize(void *pointer) {
  MbtDaveDecryptor *decryptor = (MbtDaveDecryptor *)pointer;
  if (decryptor->handle != NULL) {
    const MbtDaveApi *api = mbt_dave_api();
    if (api->status == 0) {
      api->decryptor_destroy(decryptor->handle);
    }
    decryptor->handle = NULL;
  }
}

MOONBIT_FFI_EXPORT MbtDaveSession *
mbt_dave_session_new(moonbit_bytes_t auth_session_id,
                     int32_t has_auth_session_id) {
  MbtDaveSession *session = (MbtDaveSession *)moonbit_make_external_object(
      mbt_dave_session_finalize, sizeof(MbtDaveSession));
  session->handle = NULL;
  session->last_status = 0;
  session->failure_source = NULL;
  session->failure_reason = NULL;

  const MbtDaveApi *api = mbt_dave_api();
  if (api->status != 0) {
    mbt_dave_session_binding_failure(session, api->status, api->reason);
    return session;
  }
  if (has_auth_session_id != 0 && auth_session_id == NULL) {
    mbt_dave_session_binding_failure(session, MBT_DAVE_INVALID_ARGUMENT,
                                     "invalid auth session id");
    return session;
  }
  char *auth = NULL;
  if (has_auth_session_id != 0) {
    size_t auth_length = (size_t)Moonbit_array_length(auth_session_id);
    if (memchr(auth_session_id, '\0', auth_length) != NULL) {
      mbt_dave_session_binding_failure(
          session, MBT_DAVE_INVALID_ARGUMENT,
          "auth session id contains an embedded NUL byte");
      return session;
    }
    auth = (char *)malloc(auth_length + 1);
    if (auth == NULL) {
      mbt_dave_session_binding_failure(session, MBT_DAVE_ALLOCATION_FAILURE,
                                       "could not copy auth session id");
      return session;
    }
    if (auth_length != 0) {
      memcpy(auth, auth_session_id, auth_length);
    }
    auth[auth_length] = '\0';
  }
  session->handle =
      api->session_create(NULL, auth, mbt_dave_mls_failure, session);
  free(auth);
  if (session->handle == NULL) {
    mbt_dave_session_binding_failure(session, MBT_DAVE_CALL_FAILURE,
                                     "daveSessionCreate returned null");
  }
  return session;
}

MOONBIT_FFI_EXPORT int32_t
mbt_dave_session_is_valid(MbtDaveSession *session) {
  return session != NULL && session->handle != NULL &&
                 mbt_dave_api()->status == 0
             ? 1
             : 0;
}

static void mbt_dave_format_user_id(uint64_t user_id, char output[21]) {
  snprintf(output, 21, "%" PRIu64, user_id);
}

MOONBIT_FFI_EXPORT void mbt_dave_session_init(MbtDaveSession *session,
                                               uint16_t protocol_version,
                                               uint64_t group_id,
                                               uint64_t self_user_id) {
  if (!mbt_dave_session_begin(session)) {
    return;
  }
  char user_id[21];
  mbt_dave_format_user_id(self_user_id, user_id);
  mbt_dave_api()->session_init(session->handle, protocol_version, group_id,
                               user_id);
}

MOONBIT_FFI_EXPORT void mbt_dave_session_reset(MbtDaveSession *session) {
  if (mbt_dave_session_begin(session)) {
    mbt_dave_api()->session_reset(session->handle);
  }
}

MOONBIT_FFI_EXPORT uint16_t
mbt_dave_session_protocol_version(MbtDaveSession *session) {
  if (!mbt_dave_session_begin(session)) {
    return 0;
  }
  return mbt_dave_api()->session_get_protocol_version(session->handle);
}

MOONBIT_FFI_EXPORT void mbt_dave_session_set_protocol_version(
    MbtDaveSession *session, uint16_t protocol_version) {
  if (mbt_dave_session_begin(session)) {
    mbt_dave_api()->session_set_protocol_version(session->handle,
                                                  protocol_version);
  }
}

static moonbit_bytes_t mbt_dave_take_output(MbtDaveSession *session,
                                            uint8_t *output,
                                            size_t output_length) {
  const MbtDaveApi *api = mbt_dave_api();
  moonbit_bytes_t result;
  if (output_length > INT32_MAX || (output_length != 0 && output == NULL)) {
    mbt_dave_session_binding_failure(
        session, MBT_DAVE_OUTPUT_TOO_LARGE,
        "libdave returned an invalid or oversized output buffer");
    result = moonbit_make_bytes(0, 0);
  } else {
    result = mbt_dave_copy_bytes(output, output_length);
  }
  if (output != NULL) {
    api->free_output(output);
  }
  return result;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t
mbt_dave_session_last_epoch_authenticator(MbtDaveSession *session) {
  if (!mbt_dave_session_begin(session)) {
    return moonbit_make_bytes(0, 0);
  }
  uint8_t *output = NULL;
  size_t output_length = 0;
  mbt_dave_api()->session_get_last_epoch_authenticator(
      session->handle, &output, &output_length);
  return mbt_dave_take_output(session, output, output_length);
}

MOONBIT_FFI_EXPORT void mbt_dave_session_set_external_sender(
    MbtDaveSession *session, moonbit_bytes_t external_sender) {
  if (!mbt_dave_session_begin(session)) {
    return;
  }
  if (external_sender == NULL || Moonbit_array_length(external_sender) == 0) {
    mbt_dave_session_binding_failure(session, MBT_DAVE_INVALID_ARGUMENT,
                                     "external sender bytes must not be empty");
    return;
  }
  mbt_dave_api()->session_set_external_sender(
      session->handle, external_sender,
      (size_t)Moonbit_array_length(external_sender));
}

MOONBIT_FFI_EXPORT moonbit_bytes_t
mbt_dave_session_key_package(MbtDaveSession *session) {
  if (!mbt_dave_session_begin(session)) {
    return moonbit_make_bytes(0, 0);
  }
  uint8_t *output = NULL;
  size_t output_length = 0;
  mbt_dave_api()->session_get_key_package(session->handle, &output,
                                           &output_length);
  return mbt_dave_take_output(session, output, output_length);
}

typedef struct {
  const char **values;
  char *storage;
  size_t length;
} MbtDaveUserIds;

static const char *mbt_dave_empty_user_ids[1] = {NULL};

static int mbt_dave_user_ids_init(MbtDaveSession *session,
                                  const uint64_t *ids, size_t length,
                                  MbtDaveUserIds *result) {
  result->values = mbt_dave_empty_user_ids;
  result->storage = NULL;
  result->length = length;
  if (length == 0) {
    return 1;
  }
  if (ids == NULL || length > SIZE_MAX / sizeof(char *) ||
      length > SIZE_MAX / 21) {
    mbt_dave_session_binding_failure(session, MBT_DAVE_INVALID_ARGUMENT,
                                     "invalid recognized user id array");
    return 0;
  }
  result->values = (const char **)malloc(length * sizeof(char *));
  result->storage = (char *)malloc(length * 21);
  if (result->values == NULL || result->storage == NULL) {
    free((void *)result->values);
    free(result->storage);
    result->values = mbt_dave_empty_user_ids;
    result->storage = NULL;
    mbt_dave_session_binding_failure(session, MBT_DAVE_ALLOCATION_FAILURE,
                                     "could not format recognized user ids");
    return 0;
  }
  for (size_t index = 0; index < length; index += 1) {
    char *slot = result->storage + index * 21;
    mbt_dave_format_user_id(ids[index], slot);
    result->values[index] = slot;
  }
  return 1;
}

static void mbt_dave_user_ids_destroy(MbtDaveUserIds *ids) {
  if (ids->values != mbt_dave_empty_user_ids) {
    free((void *)ids->values);
  }
  free(ids->storage);
  ids->values = mbt_dave_empty_user_ids;
  ids->storage = NULL;
  ids->length = 0;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t mbt_dave_session_process_proposals(
    MbtDaveSession *session, moonbit_bytes_t proposals,
    const uint64_t *recognized_user_ids) {
  if (!mbt_dave_session_begin(session)) {
    return moonbit_make_bytes(0, 0);
  }
  if (proposals == NULL || Moonbit_array_length(proposals) == 0 ||
      recognized_user_ids == NULL) {
    mbt_dave_session_binding_failure(session, MBT_DAVE_INVALID_ARGUMENT,
                                     "proposal bytes must not be empty");
    return moonbit_make_bytes(0, 0);
  }
  MbtDaveUserIds ids;
  size_t ids_length = (size_t)Moonbit_array_length(recognized_user_ids);
  if (!mbt_dave_user_ids_init(session, recognized_user_ids, ids_length,
                              &ids)) {
    return moonbit_make_bytes(0, 0);
  }
  uint8_t *output = NULL;
  size_t output_length = 0;
  mbt_dave_api()->session_process_proposals(
      session->handle, proposals, (size_t)Moonbit_array_length(proposals),
      ids.values, ids.length, &output, &output_length);
  mbt_dave_user_ids_destroy(&ids);
  return mbt_dave_take_output(session, output, output_length);
}

static moonbit_bytes_t *mbt_dave_tagged_result(uint8_t tag) {
  moonbit_bytes_t *result =
      (moonbit_bytes_t *)moonbit_make_ref_array_raw(1);
  result[0] = moonbit_make_bytes_raw(1);
  result[0][0] = tag;
  return result;
}

typedef struct {
  uint64_t user_id;
  uint8_t *signature;
  size_t signature_length;
} MbtDaveRosterRecord;

static void mbt_dave_free_roster_records(const MbtDaveApi *api,
                                         MbtDaveRosterRecord *records,
                                         size_t length) {
  if (records != NULL) {
    for (size_t index = 0; index < length; index += 1) {
      if (records[index].signature != NULL) {
        api->free_output(records[index].signature);
      }
    }
    free(records);
  }
}

static moonbit_bytes_t *mbt_dave_copy_roster(
    MbtDaveSession *session, DAVECommitResultHandle commit_result,
    DAVEWelcomeResultHandle welcome_result) {
  const MbtDaveApi *api = mbt_dave_api();
  uint64_t *roster_ids = NULL;
  size_t roster_length = 0;
  if (commit_result != NULL) {
    api->commit_result_get_ids(commit_result, &roster_ids, &roster_length);
  } else {
    api->welcome_result_get_ids(welcome_result, &roster_ids, &roster_length);
  }
  if ((roster_length != 0 && roster_ids == NULL) ||
      roster_length > (size_t)INT32_MAX - 1 ||
      roster_length > SIZE_MAX / sizeof(MbtDaveRosterRecord)) {
    if (roster_ids != NULL) {
      api->free_output(roster_ids);
    }
    mbt_dave_session_binding_failure(session, MBT_DAVE_OUTPUT_TOO_LARGE,
                                     "libdave returned an invalid roster");
    return mbt_dave_tagged_result(2);
  }

  if (roster_length == 0) {
    if (roster_ids != NULL) {
      api->free_output(roster_ids);
    }
    return mbt_dave_tagged_result(0);
  }

  MbtDaveRosterRecord *records =
      (MbtDaveRosterRecord *)calloc(roster_length, sizeof(*records));
  if (records == NULL) {
    if (roster_ids != NULL) {
      api->free_output(roster_ids);
    }
    mbt_dave_session_binding_failure(session, MBT_DAVE_ALLOCATION_FAILURE,
                                     "could not copy the libdave roster");
    return mbt_dave_tagged_result(2);
  }

  size_t populated = 0;
  for (; populated < roster_length; populated += 1) {
    records[populated].user_id = roster_ids[populated];
    if (commit_result != NULL) {
      api->commit_result_get_signature(
          commit_result, records[populated].user_id,
          &records[populated].signature,
          &records[populated].signature_length);
    } else {
      api->welcome_result_get_signature(
          welcome_result, records[populated].user_id,
          &records[populated].signature,
          &records[populated].signature_length);
    }
    size_t signature_length = records[populated].signature_length;
    if ((signature_length != 0 && records[populated].signature == NULL) ||
        signature_length > (size_t)INT32_MAX - 8) {
      populated += 1;
      if (roster_ids != NULL) {
        api->free_output(roster_ids);
      }
      mbt_dave_free_roster_records(api, records, populated);
      mbt_dave_session_binding_failure(
          session, MBT_DAVE_CALL_FAILURE,
          "libdave returned an invalid roster signature");
      return mbt_dave_tagged_result(2);
    }
  }

  if (roster_ids != NULL) {
    api->free_output(roster_ids);
  }
  moonbit_bytes_t *result = (moonbit_bytes_t *)moonbit_make_ref_array_raw(
      (int32_t)roster_length + 1);
  result[0] = moonbit_make_bytes_raw(1);
  result[0][0] = 0;
  for (size_t index = 0; index < roster_length; index += 1) {
    size_t record_length = 8 + records[index].signature_length;
    moonbit_bytes_t record = moonbit_make_bytes_raw((int32_t)record_length);
    uint64_t user_id = records[index].user_id;
    for (size_t byte_index = 0; byte_index < 8; byte_index += 1) {
      record[byte_index] =
          (uint8_t)(user_id >> ((7 - byte_index) * 8));
    }
    if (records[index].signature_length != 0) {
      memcpy(record + 8, records[index].signature,
             records[index].signature_length);
    }
    result[index + 1] = record;
  }
  mbt_dave_free_roster_records(api, records, roster_length);
  return result;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t *mbt_dave_session_process_commit(
    MbtDaveSession *session, moonbit_bytes_t commit) {
  if (!mbt_dave_session_begin(session)) {
    return mbt_dave_tagged_result(2);
  }
  if (commit == NULL || Moonbit_array_length(commit) == 0) {
    mbt_dave_session_binding_failure(session, MBT_DAVE_INVALID_ARGUMENT,
                                     "commit bytes must not be empty");
    return mbt_dave_tagged_result(2);
  }
  const MbtDaveApi *api = mbt_dave_api();
  DAVECommitResultHandle result = api->session_process_commit(
      session->handle, commit, (size_t)Moonbit_array_length(commit));
  if (result == NULL) {
    mbt_dave_session_binding_failure(session, MBT_DAVE_CALL_FAILURE,
                                     "daveSessionProcessCommit returned null");
    return mbt_dave_tagged_result(2);
  }
  if (api->commit_result_is_failed(result)) {
    api->commit_result_destroy(result);
    mbt_dave_session_protocol_failure_if_empty(session,
                                               "commit processing failed");
    return mbt_dave_tagged_result(2);
  }
  if (api->commit_result_is_ignored(result)) {
    api->commit_result_destroy(result);
    return mbt_dave_tagged_result(1);
  }
  moonbit_bytes_t *copied = mbt_dave_copy_roster(session, result, NULL);
  api->commit_result_destroy(result);
  return copied;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t *mbt_dave_session_process_welcome(
    MbtDaveSession *session, moonbit_bytes_t welcome,
    const uint64_t *recognized_user_ids) {
  if (!mbt_dave_session_begin(session)) {
    return mbt_dave_tagged_result(2);
  }
  if (welcome == NULL || Moonbit_array_length(welcome) == 0 ||
      recognized_user_ids == NULL) {
    mbt_dave_session_binding_failure(session, MBT_DAVE_INVALID_ARGUMENT,
                                     "welcome bytes must not be empty");
    return mbt_dave_tagged_result(2);
  }
  MbtDaveUserIds ids;
  size_t ids_length = (size_t)Moonbit_array_length(recognized_user_ids);
  if (!mbt_dave_user_ids_init(session, recognized_user_ids, ids_length,
                              &ids)) {
    return mbt_dave_tagged_result(2);
  }
  const MbtDaveApi *api = mbt_dave_api();
  DAVEWelcomeResultHandle result = api->session_process_welcome(
      session->handle, welcome, (size_t)Moonbit_array_length(welcome),
      ids.values, ids.length);
  mbt_dave_user_ids_destroy(&ids);
  if (result == NULL) {
    mbt_dave_session_protocol_failure_if_empty(session,
                                               "welcome processing failed");
    return mbt_dave_tagged_result(2);
  }
  moonbit_bytes_t *copied = mbt_dave_copy_roster(session, NULL, result);
  api->welcome_result_destroy(result);
  return copied;
}

MOONBIT_FFI_EXPORT MbtDaveKeyRatchet *
mbt_dave_session_key_ratchet(MbtDaveSession *session, uint64_t user_id) {
  MbtDaveKeyRatchet *result =
      (MbtDaveKeyRatchet *)moonbit_make_external_object(
          mbt_dave_key_ratchet_finalize, sizeof(MbtDaveKeyRatchet));
  result->handle = NULL;
  if (!mbt_dave_session_begin(session)) {
    return result;
  }
  char user_id_string[21];
  mbt_dave_format_user_id(user_id, user_id_string);
  result->handle = mbt_dave_api()->session_get_key_ratchet(session->handle,
                                                            user_id_string);
  return result;
}

MOONBIT_FFI_EXPORT int32_t
mbt_dave_key_ratchet_is_valid(MbtDaveKeyRatchet *key_ratchet) {
  return key_ratchet != NULL && key_ratchet->handle != NULL &&
                 mbt_dave_api()->status == 0
             ? 1
             : 0;
}

typedef struct {
  uint8_t *bytes;
  size_t length;
  int completed;
  int allocation_failed;
#if defined(_WIN32)
  CRITICAL_SECTION mutex;
  CONDITION_VARIABLE condition;
#else
  pthread_mutex_t mutex;
  pthread_cond_t condition;
#endif
} MbtDaveFingerprintCapture;

static int
mbt_dave_fingerprint_capture_init(MbtDaveFingerprintCapture *capture) {
  capture->bytes = NULL;
  capture->length = 0;
  capture->completed = 0;
  capture->allocation_failed = 0;
#if defined(_WIN32)
  InitializeCriticalSection(&capture->mutex);
  InitializeConditionVariable(&capture->condition);
  return 1;
#else
  if (pthread_mutex_init(&capture->mutex, NULL) != 0) {
    return 0;
  }
  if (pthread_cond_init(&capture->condition, NULL) != 0) {
    pthread_mutex_destroy(&capture->mutex);
    return 0;
  }
  return 1;
#endif
}

static void
mbt_dave_fingerprint_capture_destroy(MbtDaveFingerprintCapture *capture) {
#if defined(_WIN32)
  DeleteCriticalSection(&capture->mutex);
#else
  pthread_cond_destroy(&capture->condition);
  pthread_mutex_destroy(&capture->mutex);
#endif
  free(capture->bytes);
  capture->bytes = NULL;
}

static void
mbt_dave_fingerprint_capture_lock(MbtDaveFingerprintCapture *capture) {
#if defined(_WIN32)
  EnterCriticalSection(&capture->mutex);
#else
  pthread_mutex_lock(&capture->mutex);
#endif
}

static void
mbt_dave_fingerprint_capture_unlock(MbtDaveFingerprintCapture *capture) {
#if defined(_WIN32)
  LeaveCriticalSection(&capture->mutex);
#else
  pthread_mutex_unlock(&capture->mutex);
#endif
}

static void
mbt_dave_fingerprint_capture_signal(MbtDaveFingerprintCapture *capture) {
#if defined(_WIN32)
  WakeConditionVariable(&capture->condition);
#else
  pthread_cond_signal(&capture->condition);
#endif
}

static void
mbt_dave_fingerprint_capture_wait(MbtDaveFingerprintCapture *capture) {
  mbt_dave_fingerprint_capture_lock(capture);
  while (!capture->completed) {
#if defined(_WIN32)
    SleepConditionVariableCS(&capture->condition, &capture->mutex, INFINITE);
#else
    pthread_cond_wait(&capture->condition, &capture->mutex);
#endif
  }
  mbt_dave_fingerprint_capture_unlock(capture);
}

static void mbt_dave_capture_fingerprint(const uint8_t *fingerprint,
                                         size_t length, void *user_data) {
  MbtDaveFingerprintCapture *capture =
      (MbtDaveFingerprintCapture *)user_data;
  mbt_dave_fingerprint_capture_lock(capture);
  capture->length = length;
  if (length != 0 && (fingerprint == NULL || length > INT32_MAX)) {
    capture->allocation_failed = 1;
  } else if (length != 0) {
    capture->bytes = (uint8_t *)malloc(length);
    if (capture->bytes == NULL) {
      capture->allocation_failed = 1;
    } else {
      memcpy(capture->bytes, fingerprint, length);
    }
  }
  capture->completed = 1;
  mbt_dave_fingerprint_capture_signal(capture);
  mbt_dave_fingerprint_capture_unlock(capture);
}

MOONBIT_FFI_EXPORT moonbit_bytes_t mbt_dave_session_pairwise_fingerprint(
    MbtDaveSession *session, uint64_t user_id, uint16_t fingerprint_version) {
  if (!mbt_dave_session_begin(session)) {
    return moonbit_make_bytes(0, 0);
  }
  char user_id_string[21];
  mbt_dave_format_user_id(user_id, user_id_string);
  MbtDaveFingerprintCapture capture;
  if (!mbt_dave_fingerprint_capture_init(&capture)) {
    mbt_dave_session_binding_failure(
        session, MBT_DAVE_ALLOCATION_FAILURE,
        "could not initialize pairwise fingerprint synchronization");
    return moonbit_make_bytes(0, 0);
  }
  mbt_dave_api()->session_get_pairwise_fingerprint(
      session->handle, fingerprint_version, user_id_string,
      mbt_dave_capture_fingerprint, &capture);
  /*
   * libdave v1.2.0 computes the fingerprint on a detached worker. Its C API
   * offers neither cancellation nor a completion handle, so waiting without a
   * timeout is the only policy that guarantees userData remains alive without
   * leaking an abandoned capture.
   */
  mbt_dave_fingerprint_capture_wait(&capture);
  if (capture.allocation_failed) {
    mbt_dave_session_binding_failure(
        session, MBT_DAVE_ALLOCATION_FAILURE,
        "could not copy the pairwise fingerprint");
    mbt_dave_fingerprint_capture_destroy(&capture);
    return moonbit_make_bytes(0, 0);
  }
  if (capture.length != 64) {
    mbt_dave_session_protocol_failure_if_empty(
        session, capture.length == 0
                     ? "pairwise fingerprint generation failed"
                     : "libdave returned a malformed pairwise fingerprint");
    mbt_dave_fingerprint_capture_destroy(&capture);
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t result =
      mbt_dave_copy_bytes(capture.bytes, capture.length);
  mbt_dave_fingerprint_capture_destroy(&capture);
  return result;
}

MOONBIT_FFI_EXPORT int32_t
mbt_dave_session_last_status(MbtDaveSession *session) {
  return session == NULL ? MBT_DAVE_INVALID_ARGUMENT : session->last_status;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t
mbt_dave_session_failure_source(MbtDaveSession *session) {
  return mbt_dave_copy_string(session == NULL ? "" : session->failure_source);
}

MOONBIT_FFI_EXPORT moonbit_bytes_t
mbt_dave_session_failure_reason(MbtDaveSession *session) {
  return mbt_dave_copy_string(session == NULL ? "" : session->failure_reason);
}

static int mbt_dave_encryptor_begin(MbtDaveEncryptor *encryptor) {
  const MbtDaveApi *api = mbt_dave_api();
  if (encryptor == NULL) {
    return 0;
  }
  encryptor->last_status = 0;
  if (api->status != 0) {
    encryptor->last_status = api->status;
    return 0;
  }
  if (encryptor->handle == NULL) {
    encryptor->last_status = MBT_DAVE_INVALID_ARGUMENT;
    return 0;
  }
  return 1;
}

MOONBIT_FFI_EXPORT MbtDaveEncryptor *mbt_dave_encryptor_new(void) {
  MbtDaveEncryptor *encryptor =
      (MbtDaveEncryptor *)moonbit_make_external_object(
          mbt_dave_encryptor_finalize, sizeof(MbtDaveEncryptor));
  encryptor->handle = NULL;
  encryptor->last_status = 0;
  const MbtDaveApi *api = mbt_dave_api();
  if (api->status != 0) {
    encryptor->last_status = api->status;
    return encryptor;
  }
  encryptor->handle = api->encryptor_create();
  if (encryptor->handle == NULL) {
    encryptor->last_status = MBT_DAVE_CALL_FAILURE;
  }
  return encryptor;
}

MOONBIT_FFI_EXPORT int32_t
mbt_dave_encryptor_is_valid(MbtDaveEncryptor *encryptor) {
  return encryptor != NULL && encryptor->handle != NULL &&
                 mbt_dave_api()->status == 0
             ? 1
             : 0;
}

MOONBIT_FFI_EXPORT void mbt_dave_encryptor_set_key_ratchet(
    MbtDaveEncryptor *encryptor, MbtDaveKeyRatchet *key_ratchet) {
  if (!mbt_dave_encryptor_begin(encryptor)) {
    return;
  }
  if (key_ratchet == NULL || key_ratchet->handle == NULL) {
    encryptor->last_status = MBT_DAVE_INVALID_ARGUMENT;
    return;
  }
  mbt_dave_api()->encryptor_set_key_ratchet(encryptor->handle,
                                             key_ratchet->handle);
}

MOONBIT_FFI_EXPORT void
mbt_dave_encryptor_set_passthrough(MbtDaveEncryptor *encryptor,
                                   int32_t enabled) {
  if (mbt_dave_encryptor_begin(encryptor)) {
    mbt_dave_api()->encryptor_set_passthrough(encryptor->handle,
                                               enabled != 0);
  }
}

MOONBIT_FFI_EXPORT void mbt_dave_encryptor_assign_ssrc(
    MbtDaveEncryptor *encryptor, uint32_t ssrc, int32_t codec) {
  if (!mbt_dave_encryptor_begin(encryptor)) {
    return;
  }
  if (codec < 0 || codec > 6) {
    encryptor->last_status = MBT_DAVE_INVALID_ARGUMENT;
    return;
  }
  mbt_dave_api()->encryptor_assign_ssrc(encryptor->handle, ssrc, codec);
}

MOONBIT_FFI_EXPORT uint16_t
mbt_dave_encryptor_protocol_version(MbtDaveEncryptor *encryptor) {
  if (!mbt_dave_encryptor_begin(encryptor)) {
    return 0;
  }
  return mbt_dave_api()->encryptor_get_protocol_version(encryptor->handle);
}

MOONBIT_FFI_EXPORT int32_t
mbt_dave_encryptor_has_key(MbtDaveEncryptor *encryptor) {
  if (!mbt_dave_encryptor_begin(encryptor)) {
    return 0;
  }
  return mbt_dave_api()->encryptor_has_key(encryptor->handle) ? 1 : 0;
}

MOONBIT_FFI_EXPORT int32_t
mbt_dave_encryptor_is_passthrough(MbtDaveEncryptor *encryptor) {
  if (!mbt_dave_encryptor_begin(encryptor)) {
    return 0;
  }
  return mbt_dave_api()->encryptor_is_passthrough(encryptor->handle) ? 1 : 0;
}

static int mbt_dave_valid_media_type(int32_t media_type) {
  return media_type == DAVE_MEDIA_TYPE_AUDIO ||
         media_type == DAVE_MEDIA_TYPE_VIDEO;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t mbt_dave_encryptor_encrypt(
    MbtDaveEncryptor *encryptor, int32_t media_type, uint32_t ssrc,
    moonbit_bytes_t frame) {
  if (!mbt_dave_encryptor_begin(encryptor)) {
    return moonbit_make_bytes(0, 0);
  }
  if (!mbt_dave_valid_media_type(media_type) || frame == NULL) {
    encryptor->last_status = MBT_DAVE_INVALID_ARGUMENT;
    return moonbit_make_bytes(0, 0);
  }
  const MbtDaveApi *api = mbt_dave_api();
  size_t frame_length = (size_t)Moonbit_array_length(frame);
  size_t capacity = api->encryptor_get_max_ciphertext(
      encryptor->handle, (DAVEMediaType)media_type, frame_length);
  if (capacity > INT32_MAX) {
    encryptor->last_status = MBT_DAVE_OUTPUT_TOO_LARGE;
    return moonbit_make_bytes(0, 0);
  }
  uint8_t *output = (uint8_t *)malloc(capacity == 0 ? 1 : capacity);
  if (output == NULL) {
    encryptor->last_status = MBT_DAVE_ALLOCATION_FAILURE;
    return moonbit_make_bytes(0, 0);
  }
  size_t written = 0;
  DAVEEncryptorResultCode result = api->encryptor_encrypt(
      encryptor->handle, (DAVEMediaType)media_type, ssrc, frame, frame_length,
      output, capacity, &written);
  encryptor->last_status = (int32_t)result;
  if (result != DAVE_ENCRYPTOR_RESULT_CODE_SUCCESS) {
    free(output);
    return moonbit_make_bytes(0, 0);
  }
  if (written > capacity || written > INT32_MAX) {
    free(output);
    encryptor->last_status = MBT_DAVE_OUTPUT_TOO_LARGE;
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t copied = mbt_dave_copy_bytes(output, written);
  free(output);
  return copied;
}

MOONBIT_FFI_EXPORT int32_t
mbt_dave_encryptor_last_status(MbtDaveEncryptor *encryptor) {
  return encryptor == NULL ? MBT_DAVE_INVALID_ARGUMENT
                           : encryptor->last_status;
}

static int mbt_dave_decryptor_begin(MbtDaveDecryptor *decryptor) {
  const MbtDaveApi *api = mbt_dave_api();
  if (decryptor == NULL) {
    return 0;
  }
  decryptor->last_status = 0;
  if (api->status != 0) {
    decryptor->last_status = api->status;
    return 0;
  }
  if (decryptor->handle == NULL) {
    decryptor->last_status = MBT_DAVE_INVALID_ARGUMENT;
    return 0;
  }
  return 1;
}

MOONBIT_FFI_EXPORT MbtDaveDecryptor *mbt_dave_decryptor_new(void) {
  MbtDaveDecryptor *decryptor =
      (MbtDaveDecryptor *)moonbit_make_external_object(
          mbt_dave_decryptor_finalize, sizeof(MbtDaveDecryptor));
  decryptor->handle = NULL;
  decryptor->last_status = 0;
  const MbtDaveApi *api = mbt_dave_api();
  if (api->status != 0) {
    decryptor->last_status = api->status;
    return decryptor;
  }
  decryptor->handle = api->decryptor_create();
  if (decryptor->handle == NULL) {
    decryptor->last_status = MBT_DAVE_CALL_FAILURE;
  }
  return decryptor;
}

MOONBIT_FFI_EXPORT int32_t
mbt_dave_decryptor_is_valid(MbtDaveDecryptor *decryptor) {
  return decryptor != NULL && decryptor->handle != NULL &&
                 mbt_dave_api()->status == 0
             ? 1
             : 0;
}

MOONBIT_FFI_EXPORT void mbt_dave_decryptor_transition_to_key_ratchet(
    MbtDaveDecryptor *decryptor, MbtDaveKeyRatchet *key_ratchet) {
  if (!mbt_dave_decryptor_begin(decryptor)) {
    return;
  }
  if (key_ratchet == NULL || key_ratchet->handle == NULL) {
    decryptor->last_status = MBT_DAVE_INVALID_ARGUMENT;
    return;
  }
  mbt_dave_api()->decryptor_set_key_ratchet(decryptor->handle,
                                             key_ratchet->handle);
}

MOONBIT_FFI_EXPORT void mbt_dave_decryptor_transition_to_passthrough(
    MbtDaveDecryptor *decryptor, int32_t enabled) {
  if (mbt_dave_decryptor_begin(decryptor)) {
    mbt_dave_api()->decryptor_set_passthrough(decryptor->handle,
                                               enabled != 0);
  }
}

MOONBIT_FFI_EXPORT moonbit_bytes_t mbt_dave_decryptor_decrypt(
    MbtDaveDecryptor *decryptor, int32_t media_type, moonbit_bytes_t frame) {
  if (!mbt_dave_decryptor_begin(decryptor)) {
    return moonbit_make_bytes(0, 0);
  }
  if (!mbt_dave_valid_media_type(media_type) || frame == NULL) {
    decryptor->last_status = MBT_DAVE_INVALID_ARGUMENT;
    return moonbit_make_bytes(0, 0);
  }
  const MbtDaveApi *api = mbt_dave_api();
  size_t frame_length = (size_t)Moonbit_array_length(frame);
  size_t capacity = api->decryptor_get_max_plaintext(
      decryptor->handle, (DAVEMediaType)media_type, frame_length);
  if (capacity > INT32_MAX) {
    decryptor->last_status = MBT_DAVE_OUTPUT_TOO_LARGE;
    return moonbit_make_bytes(0, 0);
  }
  uint8_t *output = (uint8_t *)malloc(capacity == 0 ? 1 : capacity);
  if (output == NULL) {
    decryptor->last_status = MBT_DAVE_ALLOCATION_FAILURE;
    return moonbit_make_bytes(0, 0);
  }
  size_t written = 0;
  DAVEDecryptorResultCode result = api->decryptor_decrypt(
      decryptor->handle, (DAVEMediaType)media_type, frame, frame_length,
      output, capacity, &written);
  decryptor->last_status = (int32_t)result;
  if (result != DAVE_DECRYPTOR_RESULT_CODE_SUCCESS) {
    free(output);
    return moonbit_make_bytes(0, 0);
  }
  if (written > capacity || written > INT32_MAX) {
    free(output);
    decryptor->last_status = MBT_DAVE_OUTPUT_TOO_LARGE;
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t copied = mbt_dave_copy_bytes(output, written);
  free(output);
  return copied;
}

MOONBIT_FFI_EXPORT int32_t
mbt_dave_decryptor_last_status(MbtDaveDecryptor *decryptor) {
  return decryptor == NULL ? MBT_DAVE_INVALID_ARGUMENT
                           : decryptor->last_status;
}
