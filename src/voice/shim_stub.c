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

static void *discord_voice_library_open(const char *path) {
  return (void *)LoadLibraryA(path);
}

static void discord_voice_library_error(char *error, size_t error_len) {
  DWORD code = GetLastError();
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

static void *discord_voice_open(char *reason, size_t reason_len) {
  char detail[256] = {0};
  const char *override = getenv("DISCORD_VOICE_SHIM_PATH");
  if (override != NULL && override[0] != '\0') {
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
  const char *candidate = "discord_voice_shim.dll";
#elif defined(__APPLE__)
  const char *candidate = "libdiscord_voice_shim.dylib";
#else
  const char *candidate = "libdiscord_voice_shim.so";
#endif
  void *library = discord_voice_library_open(candidate);
  if (library != NULL) {
    return library;
  }
  discord_voice_library_error(detail, sizeof(detail));
  snprintf(reason, reason_len, "failed to load %s: %s", candidate, detail);
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
