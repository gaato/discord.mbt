/* Runtime loader for the discord.mbt Rust transport AEAD shim.
 *
 * Loader status codes:
 *   0     loaded and ABI-compatible
 *  -100   shared library unavailable
 *  -101   ABI version mismatch
 *  -102   required symbol missing
 *
 * Rust output allocations are copied into MoonBit Bytes and immediately
 * released with vs_free, so allocator ownership never crosses into MoonBit.
 */
#include <moonbit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define DISCORD_VOICE_SHIM_ABI_VERSION 3
#define DISCORD_VOICE_SHIM_UNAVAILABLE (-100)
#define DISCORD_VOICE_SHIM_ABI_MISMATCH (-101)
#define DISCORD_VOICE_SHIM_MISSING_SYMBOL (-102)

typedef uint16_t (*vs_abi_version_fn)(void);
typedef void (*vs_free_fn)(uint8_t *, size_t);
typedef const char *(*vs_last_error_fn)(void);
typedef int32_t (*vs_aead_fn)(int32_t, const uint8_t *, const uint8_t *,
                              size_t, const uint8_t *, size_t,
                              const uint8_t *, size_t, uint8_t **, size_t *);

typedef struct {
  int32_t status;
  void *library;
  vs_abi_version_fn abi_version;
  vs_free_fn free_output;
  vs_last_error_fn last_error;
  vs_aead_fn seal;
  vs_aead_fn open;
  char reason[512];
} DiscordVoiceShimApi;

#if defined(_WIN32)
#include <windows.h>
#define DISCORD_THREAD_LOCAL __declspec(thread)

#ifndef LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR
#define LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR 0x00000100
#endif
#ifndef LOAD_LIBRARY_SEARCH_SYSTEM32
#define LOAD_LIBRARY_SEARCH_SYSTEM32 0x00000800
#endif

static DWORD discord_voice_windows_last_library_error;

static int discord_voice_windows_environment_utf8(const wchar_t *name,
                                                   char *output,
                                                   size_t output_len) {
  SetLastError(ERROR_SUCCESS);
  DWORD required_wide = GetEnvironmentVariableW(name, NULL, 0);
  if (required_wide == 0) {
    DWORD error = GetLastError();
    return error == ERROR_SUCCESS || error == ERROR_ENVVAR_NOT_FOUND ? 0 : -1;
  }
  if (required_wide == 1) {
    // GetEnvironmentVariableW reports one wchar for an explicitly empty
    // value. Treat it exactly like an unset optional override.
    if (output_len != 0) {
      output[0] = '\0';
    }
    return 0;
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

static void *discord_voice_library_open(const char *path) {
  int required = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1,
                                     NULL, 0);
  if (required <= 0) {
    discord_voice_windows_last_library_error = GetLastError();
    if (discord_voice_windows_last_library_error == ERROR_SUCCESS) {
      discord_voice_windows_last_library_error = ERROR_NO_UNICODE_TRANSLATION;
    }
    return NULL;
  }
  wchar_t *wide = malloc((size_t)required * sizeof(wchar_t));
  if (wide == NULL) {
    discord_voice_windows_last_library_error = ERROR_NOT_ENOUGH_MEMORY;
    return NULL;
  }
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide,
                          required) != required) {
    discord_voice_windows_last_library_error = GetLastError();
    free(wide);
    return NULL;
  }
  DWORD flags = strchr(path, '/') != NULL || strchr(path, '\\') != NULL
                    ? LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR |
                          LOAD_LIBRARY_SEARCH_SYSTEM32
                    : 0;
  HMODULE library = LoadLibraryExW(wide, NULL, flags);
  discord_voice_windows_last_library_error =
      library == NULL ? GetLastError() : ERROR_SUCCESS;
  free(wide);
  return (void *)library;
}

static void discord_voice_library_error(char *error, size_t error_len) {
  DWORD code = discord_voice_windows_last_library_error;
  DWORD length = FormatMessageA(
      FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, NULL, code,
      MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), error, (DWORD)error_len, NULL);
  if (length == 0) {
    snprintf(error, error_len, "Windows error %lu", (unsigned long)code);
    return;
  }
  while (length > 0 &&
         (error[length - 1] == '\r' || error[length - 1] == '\n')) {
    error[--length] = '\0';
  }
}

static int discord_voice_library_symbol(void *library, const char *name,
                                        void *slot, size_t slot_size,
                                        char *error, size_t error_len) {
  FARPROC symbol = GetProcAddress((HMODULE)library, name);
  if (symbol == NULL) {
    discord_voice_windows_last_library_error = GetLastError();
    discord_voice_library_error(error, error_len);
    return 0;
  }
  if (slot_size != sizeof(symbol)) {
    snprintf(error, error_len,
             "function pointer size is incompatible with GetProcAddress");
    return 0;
  }
  memcpy(slot, &symbol, sizeof(symbol));
  return 1;
}

static void discord_voice_library_close(void *library) {
  (void)FreeLibrary((HMODULE)library);
}
#else
#include <dlfcn.h>
#include <pthread.h>
#define DISCORD_THREAD_LOCAL _Thread_local

static void *discord_voice_library_open(const char *path) {
  return dlopen(path, RTLD_NOW | RTLD_LOCAL);
}

static void discord_voice_library_error(char *error, size_t error_len) {
  const char *message = dlerror();
  snprintf(error, error_len, "%s",
           message == NULL ? "unknown dynamic-loader error" : message);
}

static int discord_voice_library_symbol(void *library, const char *name,
                                        void *slot, size_t slot_size,
                                        char *error, size_t error_len) {
  (void)dlerror();
  void *symbol = dlsym(library, name);
  const char *message = dlerror();
  if (message != NULL) {
    snprintf(error, error_len, "%s", message);
    return 0;
  }
  if (slot_size != sizeof(symbol)) {
    snprintf(error, error_len,
             "function pointer size is incompatible with dlsym");
    return 0;
  }
  memcpy(slot, &symbol, sizeof(symbol));
  return 1;
}

static void discord_voice_library_close(void *library) {
  (void)dlclose(library);
}
#endif

static DiscordVoiceShimApi discord_voice_api;

static int discord_voice_join_path(char *output, size_t output_len,
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

static int discord_voice_path_is_absolute(const char *path) {
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

static const char *discord_voice_asset_id(void) {
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

static const char *discord_voice_library_filename(void) {
#if defined(_WIN32)
  return "discord_voice_shim.dll";
#elif defined(__APPLE__)
  return "libdiscord_voice_shim.dylib";
#else
  return "libdiscord_voice_shim.so";
#endif
}

static int discord_voice_default_cache_base(char *output, size_t output_len) {
#if defined(_WIN32)
  char environment_path[4096];
  int environment_status = discord_voice_windows_environment_utf8(
      L"LOCALAPPDATA", environment_path, sizeof(environment_path));
  if (environment_status == 1 &&
      discord_voice_path_is_absolute(environment_path)) {
    int written = snprintf(output, output_len, "%s", environment_path);
    return written >= 0 && (size_t)written < output_len;
  }
  environment_status = discord_voice_windows_environment_utf8(
      L"USERPROFILE", environment_path, sizeof(environment_path));
  if (environment_status != 1) {
    environment_status = discord_voice_windows_environment_utf8(
        L"HOME", environment_path, sizeof(environment_path));
  }
  return environment_status == 1 &&
         discord_voice_path_is_absolute(environment_path) &&
         discord_voice_join_path(output, output_len, environment_path,
                                 "AppData/Local");
#elif defined(__APPLE__)
  const char *home = getenv("HOME");
  return discord_voice_path_is_absolute(home) &&
         discord_voice_join_path(output, output_len, home, "Library/Caches");
#else
  const char *xdg_cache = getenv("XDG_CACHE_HOME");
  if (discord_voice_path_is_absolute(xdg_cache)) {
    int written = snprintf(output, output_len, "%s", xdg_cache);
    return written >= 0 && (size_t)written < output_len;
  }
  const char *home = getenv("HOME");
  return discord_voice_path_is_absolute(home) &&
         discord_voice_join_path(output, output_len, home, ".cache");
#endif
}

static void *discord_voice_try_root(const char *root, char *path,
                                    size_t path_len) {
  if (!discord_voice_path_is_absolute(root) ||
      !discord_voice_join_path(path, path_len, root,
                               discord_voice_library_filename())) {
    return NULL;
  }
  return discord_voice_library_open(path);
}

static void *discord_voice_open(char *reason, size_t reason_len) {
  char detail[256] = {0};
#if defined(_WIN32)
  char override_storage[4096];
  int override_status = discord_voice_windows_environment_utf8(
      L"DISCORD_VOICE_SHIM_PATH", override_storage,
      sizeof(override_storage));
  if (override_status < 0) {
    snprintf(reason, reason_len,
             "DISCORD_VOICE_SHIM_PATH is too long or is not valid Unicode");
    return NULL;
  }
  const char *override = override_status == 1 ? override_storage : NULL;
#else
  const char *override = getenv("DISCORD_VOICE_SHIM_PATH");
#endif
  if (override != NULL && override[0] != '\0') {
    if (!discord_voice_path_is_absolute(override)) {
      snprintf(reason, reason_len,
               "DISCORD_VOICE_SHIM_PATH must be an absolute path");
      return NULL;
    }
    void *library = discord_voice_library_open(override);
    if (library == NULL) {
      discord_voice_library_error(detail, sizeof(detail));
      snprintf(reason, reason_len,
               "failed to load DISCORD_VOICE_SHIM_PATH %s: %s", override,
               detail);
    }
    return library;
  }

#if defined(_WIN32)
  char root_storage[4096];
  int root_status = discord_voice_windows_environment_utf8(
      L"DISCORD_VOICE_SHIM_ROOT", root_storage, sizeof(root_storage));
  if (root_status < 0) {
    snprintf(reason, reason_len,
             "DISCORD_VOICE_SHIM_ROOT is too long or is not valid Unicode");
    return NULL;
  }
  const char *root = root_status == 1 ? root_storage : NULL;
#else
  const char *root = getenv("DISCORD_VOICE_SHIM_ROOT");
#endif
  if (root != NULL && root[0] != '\0') {
    if (!discord_voice_path_is_absolute(root)) {
      snprintf(reason, reason_len,
               "DISCORD_VOICE_SHIM_ROOT must be an absolute path");
      return NULL;
    }
    char path[4096] = {0};
    void *library = discord_voice_try_root(root, path, sizeof(path));
    if (library == NULL) {
      if (path[0] == '\0') {
        snprintf(reason, reason_len,
                 "DISCORD_VOICE_SHIM_ROOT resolves to a path that is too "
                 "long");
        return NULL;
      }
      discord_voice_library_error(detail, sizeof(detail));
      snprintf(reason, reason_len,
               "failed to load DISCORD_VOICE_SHIM_ROOT runtime %s: %s", path,
               detail);
    }
    return library;
  }

  const char *asset_id = discord_voice_asset_id();
  if (asset_id != NULL) {
    char cache_base[4096];
#if defined(_WIN32)
    char cache_override_storage[4096];
    int cache_override_status = discord_voice_windows_environment_utf8(
        L"DISCORD_VOICE_SHIM_CACHE_DIR", cache_override_storage,
        sizeof(cache_override_storage));
    if (cache_override_status < 0) {
      snprintf(reason, reason_len,
               "DISCORD_VOICE_SHIM_CACHE_DIR is too long or is not valid "
               "Unicode");
      return NULL;
    }
    const char *cache_override =
        cache_override_status == 1 ? cache_override_storage : NULL;
#else
    const char *cache_override = getenv("DISCORD_VOICE_SHIM_CACHE_DIR");
#endif
    if (cache_override != NULL && cache_override[0] != '\0' &&
        !discord_voice_path_is_absolute(cache_override)) {
      snprintf(reason, reason_len,
               "DISCORD_VOICE_SHIM_CACHE_DIR must be an absolute path");
      return NULL;
    }
    int have_cache_base = 0;
    if (discord_voice_path_is_absolute(cache_override)) {
      int written = snprintf(cache_base, sizeof(cache_base), "%s",
                             cache_override);
      have_cache_base =
          written >= 0 && (size_t)written < sizeof(cache_base);
    } else {
      have_cache_base =
          discord_voice_default_cache_base(cache_base, sizeof(cache_base));
    }
    if (have_cache_base) {
      char cache_root[4096];
      char cache_suffix[256];
      int suffix_written = snprintf(
          cache_suffix, sizeof(cache_suffix),
          "gaato-discord/voice-shim/v0.1.0/%s", asset_id);
      if (suffix_written >= 0 &&
          (size_t)suffix_written < sizeof(cache_suffix) &&
          discord_voice_join_path(cache_root, sizeof(cache_root), cache_base,
                                  cache_suffix)) {
        char path[4096];
        void *library =
            discord_voice_try_root(cache_root, path, sizeof(path));
        if (library != NULL) {
          return library;
        }
      }
    }
  }

  const char *candidate = discord_voice_library_filename();
  void *library = discord_voice_library_open(candidate);
  if (library != NULL) {
    return library;
  }
  discord_voice_library_error(detail, sizeof(detail));
  snprintf(reason, reason_len,
           "voice shim was not found at DISCORD_VOICE_SHIM_ROOT, the "
           "deterministic v0.1.0 cache, or the platform library path (%s: %s)",
           candidate, detail);
  return NULL;
}

static void discord_voice_shim_initialize(void) {
  DiscordVoiceShimApi *api = &discord_voice_api;
  memset(api, 0, sizeof(*api));
  api->status = DISCORD_VOICE_SHIM_UNAVAILABLE;

  void *library = discord_voice_open(api->reason, sizeof(api->reason));
  if (library == NULL) {
    return;
  }

  char symbol_error[256] = {0};
  const char *missing_symbol = NULL;
  if (!discord_voice_library_symbol(
          library, "vs_abi_version", &api->abi_version,
          sizeof(api->abi_version), symbol_error, sizeof(symbol_error))) {
    missing_symbol = "vs_abi_version";
  } else if (!discord_voice_library_symbol(
                 library, "vs_free", &api->free_output,
                 sizeof(api->free_output), symbol_error,
                 sizeof(symbol_error))) {
    missing_symbol = "vs_free";
  } else if (!discord_voice_library_symbol(
                 library, "vs_last_error", &api->last_error,
                 sizeof(api->last_error), symbol_error,
                 sizeof(symbol_error))) {
    missing_symbol = "vs_last_error";
  } else if (!discord_voice_library_symbol(
                 library, "vs_aead_seal", &api->seal, sizeof(api->seal),
                 symbol_error, sizeof(symbol_error))) {
    missing_symbol = "vs_aead_seal";
  } else if (!discord_voice_library_symbol(
                 library, "vs_aead_open", &api->open, sizeof(api->open),
                 symbol_error, sizeof(symbol_error))) {
    missing_symbol = "vs_aead_open";
  }

  if (missing_symbol != NULL) {
    api->status = DISCORD_VOICE_SHIM_MISSING_SYMBOL;
    snprintf(api->reason, sizeof(api->reason),
             "discord voice shim is missing ABI v3 symbol %s: %s",
             missing_symbol, symbol_error);
    discord_voice_library_close(library);
    return;
  }

  uint16_t actual_version = api->abi_version();
  if (actual_version != DISCORD_VOICE_SHIM_ABI_VERSION) {
    api->status = DISCORD_VOICE_SHIM_ABI_MISMATCH;
    snprintf(api->reason, sizeof(api->reason),
             "discord voice shim ABI mismatch: expected %d, got %u",
             DISCORD_VOICE_SHIM_ABI_VERSION, actual_version);
    discord_voice_library_close(library);
    return;
  }

  api->library = library;
  api->status = 0;
  api->reason[0] = '\0';
}

#if defined(_WIN32)
static INIT_ONCE discord_voice_once = INIT_ONCE_STATIC_INIT;

static BOOL CALLBACK discord_voice_shim_initialize_once(
    PINIT_ONCE once, PVOID parameter, PVOID *context) {
  (void)once;
  (void)parameter;
  (void)context;
  discord_voice_shim_initialize();
  return TRUE;
}

static const DiscordVoiceShimApi *discord_voice_shim_api(void) {
  (void)InitOnceExecuteOnce(&discord_voice_once,
                            discord_voice_shim_initialize_once, NULL, NULL);
  return &discord_voice_api;
}
#else
static pthread_once_t discord_voice_once = PTHREAD_ONCE_INIT;

static const DiscordVoiceShimApi *discord_voice_shim_api(void) {
  (void)pthread_once(&discord_voice_once, discord_voice_shim_initialize);
  return &discord_voice_api;
}
#endif

static DISCORD_THREAD_LOCAL int32_t discord_voice_last_status = 0;
static DISCORD_THREAD_LOCAL char discord_voice_local_error[256];

static void discord_voice_clear_local_error(void) {
  discord_voice_local_error[0] = '\0';
}

static void discord_voice_set_local_error(const char *message) {
  snprintf(discord_voice_local_error, sizeof(discord_voice_local_error), "%s",
           message);
}

static moonbit_bytes_t discord_voice_bytes_from_c(const char *value) {
  if (value == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  size_t length = strlen(value);
  if (length > INT32_MAX) {
    length = INT32_MAX;
  }
  moonbit_bytes_t result = moonbit_make_bytes((int32_t)length, 0);
  memcpy(result, value, length);
  return result;
}

MOONBIT_FFI_EXPORT
int32_t discord_voice_shim_status(void) {
  return discord_voice_shim_api()->status;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t discord_voice_shim_unavailable_reason(void) {
  return discord_voice_bytes_from_c(discord_voice_shim_api()->reason);
}

MOONBIT_FFI_EXPORT
int32_t discord_voice_shim_last_status(void) {
  return discord_voice_last_status;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t discord_voice_shim_last_error(void) {
  const DiscordVoiceShimApi *api = discord_voice_shim_api();
  if (api->status != 0) {
    return discord_voice_bytes_from_c(api->reason);
  }
  if (discord_voice_local_error[0] != '\0') {
    return discord_voice_bytes_from_c(discord_voice_local_error);
  }
  return discord_voice_bytes_from_c(api->last_error());
}

static moonbit_bytes_t discord_voice_aead_call(
    vs_aead_fn operation, int32_t mode, moonbit_bytes_t key,
    moonbit_bytes_t nonce, moonbit_bytes_t aad, moonbit_bytes_t input) {
  const DiscordVoiceShimApi *api = discord_voice_shim_api();
  discord_voice_last_status = api->status;
  discord_voice_clear_local_error();
  if (api->status != 0 || operation == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  if (key == NULL || nonce == NULL || aad == NULL || input == NULL) {
    discord_voice_last_status = -1;
    discord_voice_set_local_error("AEAD inputs must not be null");
    return moonbit_make_bytes(0, 0);
  }
  if (Moonbit_array_length(key) != 32) {
    discord_voice_last_status = -1;
    discord_voice_set_local_error("AEAD key must contain exactly 32 bytes");
    return moonbit_make_bytes(0, 0);
  }

  uint8_t *output = NULL;
  size_t output_len = 0;
  discord_voice_last_status = operation(
      mode, key, nonce, (size_t)Moonbit_array_length(nonce), aad,
      (size_t)Moonbit_array_length(aad), input,
      (size_t)Moonbit_array_length(input), &output, &output_len);
  if (discord_voice_last_status != 0) {
    if (output != NULL) {
      api->free_output(output, output_len);
    }
    return moonbit_make_bytes(0, 0);
  }
  if (output_len > INT32_MAX || (output == NULL && output_len != 0)) {
    if (output != NULL) {
      api->free_output(output, output_len);
    }
    discord_voice_last_status = -1;
    discord_voice_set_local_error("AEAD shim returned an invalid output");
    return moonbit_make_bytes(0, 0);
  }

  moonbit_bytes_t result = moonbit_make_bytes((int32_t)output_len, 0);
  if (output_len > 0) {
    memcpy(result, output, output_len);
  }
  if (output != NULL) {
    api->free_output(output, output_len);
  }
  return result;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t discord_voice_shim_aead_seal(
    int32_t mode, moonbit_bytes_t key, moonbit_bytes_t nonce,
    moonbit_bytes_t aad, moonbit_bytes_t plaintext) {
  const DiscordVoiceShimApi *api = discord_voice_shim_api();
  return discord_voice_aead_call(api->seal, mode, key, nonce, aad, plaintext);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t discord_voice_shim_aead_open(
    int32_t mode, moonbit_bytes_t key, moonbit_bytes_t nonce,
    moonbit_bytes_t aad, moonbit_bytes_t ciphertext) {
  const DiscordVoiceShimApi *api = discord_voice_shim_api();
  return discord_voice_aead_call(api->open, mode, key, nonce, aad, ciphertext);
}
