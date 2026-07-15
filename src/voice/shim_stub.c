/* Runtime loader for the discord.mbt Rust voice shim.
 *
 * Loader status codes:
 *   0     loaded and ABI-compatible
 *  -100   shared library unavailable
 *  -101   ABI version mismatch
 *  -102   required symbol missing
 *
 * Rust AEAD status codes (-1 through -5) are passed through unchanged. Rust
 * output allocations are copied into MoonBit Bytes and immediately released
 * with vs_free, so no allocator ownership crosses into MoonBit.
 */
#include <moonbit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define DISCORD_VOICE_SHIM_ABI_VERSION 1
#define DISCORD_VOICE_SHIM_UNAVAILABLE (-100)
#define DISCORD_VOICE_SHIM_ABI_MISMATCH (-101)
#define DISCORD_VOICE_SHIM_MISSING_SYMBOL (-102)

typedef uint16_t (*vs_abi_version_fn)(void);
typedef void (*vs_free_fn)(uint8_t *, size_t);
typedef const char *(*vs_last_error_fn)(void);
typedef int (*vs_aead_fn)(int, const uint8_t *, const uint8_t *, size_t,
                          const uint8_t *, size_t, const uint8_t *, size_t,
                          uint8_t **, size_t *);

typedef struct {
  int status;
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

static void *discord_voice_library_symbol(void *library, const char *name) {
  return (void *)GetProcAddress((HMODULE)library, name);
}
#else
#include <dlfcn.h>
#define DISCORD_THREAD_LOCAL _Thread_local

static void *discord_voice_library_open(const char *path) {
  return dlopen(path, RTLD_NOW | RTLD_LOCAL);
}

static void *discord_voice_library_symbol(void *library, const char *name) {
  return dlsym(library, name);
}
#endif

static void *discord_voice_open(char *reason, size_t reason_len) {
  const char *override = getenv("DISCORD_VOICE_SHIM_PATH");
  if (override != NULL && override[0] != '\0') {
    void *library = discord_voice_library_open(override);
    if (library == NULL) {
      snprintf(reason, reason_len,
               "failed to load DISCORD_VOICE_SHIM_PATH: %s", override);
    }
    return library;
  }

  static const char *const candidates[] = {
      "libdiscord_voice_shim.so",
      "libdiscord_voice_shim.dylib",
      "discord_voice_shim.dll",
      NULL,
  };
  for (int i = 0; candidates[i] != NULL; i++) {
    void *library = discord_voice_library_open(candidates[i]);
    if (library != NULL) {
      return library;
    }
  }
  snprintf(reason, reason_len,
           "discord voice shim not found in the platform library path");
  return NULL;
}

static const DiscordVoiceShimApi *discord_voice_shim_api(void) {
  static DiscordVoiceShimApi api;
  static int attempted = 0;
  if (!attempted) {
    attempted = 1;
    api.status = DISCORD_VOICE_SHIM_UNAVAILABLE;
    void *library = discord_voice_open(api.reason, sizeof(api.reason));
    if (library != NULL) {
      api.abi_version = (vs_abi_version_fn)discord_voice_library_symbol(
          library, "vs_abi_version");
      api.free_output =
          (vs_free_fn)discord_voice_library_symbol(library, "vs_free");
      api.last_error = (vs_last_error_fn)discord_voice_library_symbol(
          library, "vs_last_error");
      api.seal =
          (vs_aead_fn)discord_voice_library_symbol(library, "vs_aead_seal");
      api.open =
          (vs_aead_fn)discord_voice_library_symbol(library, "vs_aead_open");
      if (api.abi_version == NULL || api.free_output == NULL ||
          api.last_error == NULL || api.seal == NULL || api.open == NULL) {
        api.status = DISCORD_VOICE_SHIM_MISSING_SYMBOL;
        snprintf(api.reason, sizeof(api.reason),
                 "discord voice shim is missing one or more ABI v1 symbols");
      } else {
        uint16_t actual_version = api.abi_version();
        if (actual_version != DISCORD_VOICE_SHIM_ABI_VERSION) {
          api.status = DISCORD_VOICE_SHIM_ABI_MISMATCH;
          snprintf(api.reason, sizeof(api.reason),
                   "discord voice shim ABI mismatch: expected %d, got %u",
                   DISCORD_VOICE_SHIM_ABI_VERSION, actual_version);
        } else {
          api.status = 0;
          api.reason[0] = '\0';
        }
      }
    }
  }
  return &api;
}

static DISCORD_THREAD_LOCAL int32_t discord_voice_last_status = 0;

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
  return discord_voice_bytes_from_c(api->last_error());
}

static moonbit_bytes_t discord_voice_aead_call(
    vs_aead_fn operation, int32_t mode, moonbit_bytes_t key,
    moonbit_bytes_t nonce, moonbit_bytes_t aad, moonbit_bytes_t input) {
  const DiscordVoiceShimApi *api = discord_voice_shim_api();
  discord_voice_last_status = api->status;
  if (api->status != 0 || operation == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  if (key == NULL || nonce == NULL || aad == NULL || input == NULL ||
      Moonbit_array_length(key) != 32) {
    discord_voice_last_status = -1;
    return moonbit_make_bytes(0, 0);
  }

  uint8_t *output = NULL;
  size_t output_len = 0;
  discord_voice_last_status = operation(
      mode, key, nonce, (size_t)Moonbit_array_length(nonce), aad,
      (size_t)Moonbit_array_length(aad), input,
      (size_t)Moonbit_array_length(input), &output, &output_len);
  if (discord_voice_last_status != 0 || output == NULL ||
      output_len > INT32_MAX) {
    if (output != NULL) {
      api->free_output(output, output_len);
    }
    if (discord_voice_last_status == 0) {
      discord_voice_last_status = -1;
    }
    return moonbit_make_bytes(0, 0);
  }

  moonbit_bytes_t result = moonbit_make_bytes((int32_t)output_len, 0);
  if (output_len > 0) {
    memcpy(result, output, output_len);
  }
  api->free_output(output, output_len);
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
