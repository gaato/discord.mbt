/* Runtime loader for the discord.mbt Rust voice shim.
 *
 * Loader status codes:
 *   0     loaded and ABI-compatible
 *  -100   shared library unavailable
 *  -101   ABI version mismatch
 *  -102   required symbol missing
 *
 * Rust AEAD and DAVE status codes are passed through unchanged. Rust output
 * allocations are copied into MoonBit Bytes and immediately released with
 * vs_free, so no allocator ownership crosses into MoonBit.
 */
#include <moonbit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define DISCORD_VOICE_SHIM_ABI_VERSION 2
#define DISCORD_VOICE_SHIM_UNAVAILABLE (-100)
#define DISCORD_VOICE_SHIM_ABI_MISMATCH (-101)
#define DISCORD_VOICE_SHIM_MISSING_SYMBOL (-102)

typedef uint16_t (*vs_abi_version_fn)(void);
typedef void (*vs_free_fn)(uint8_t *, size_t);
typedef const char *(*vs_last_error_fn)(void);
typedef int (*vs_aead_fn)(int, const uint8_t *, const uint8_t *, size_t,
                          const uint8_t *, size_t, const uint8_t *, size_t,
                          uint8_t **, size_t *);
typedef uint16_t (*vs_dave_max_protocol_version_fn)(void);
typedef void *(*vs_dave_session_create_fn)(uint16_t, const char *, uint64_t);
typedef void (*vs_dave_session_destroy_fn)(void *);
typedef int32_t (*vs_dave_session_reinit_fn)(void *, uint16_t);
typedef int32_t (*vs_dave_set_external_sender_fn)(void *, const uint8_t *,
                                                   size_t);
typedef int32_t (*vs_dave_get_key_package_fn)(void *, uint8_t **, size_t *);
typedef int32_t (*vs_dave_process_proposals_fn)(
    void *, int32_t, const uint8_t *, size_t, const char *const *, size_t,
    uint8_t **, size_t *, uint8_t **, size_t *);
typedef int32_t (*vs_dave_process_message_fn)(void *, const uint8_t *, size_t);
typedef int32_t (*vs_dave_process_welcome_fn)(void *, const uint8_t *, size_t,
                                               const char *const *, size_t);
typedef int32_t (*vs_dave_output_fn)(void *, const uint8_t *, size_t,
                                     uint8_t **, size_t *);
typedef int32_t (*vs_dave_decrypt_fn)(void *, const char *, const uint8_t *,
                                      size_t, uint8_t **, size_t *);
typedef int32_t (*vs_dave_session_status_fn)(void *);
typedef int32_t (*vs_dave_get_verification_code_fn)(void *, const char *,
                                                     uint8_t **, size_t *);

typedef struct {
  int status;
  vs_abi_version_fn abi_version;
  vs_free_fn free_output;
  vs_last_error_fn last_error;
  vs_aead_fn seal;
  vs_aead_fn open;
  vs_dave_max_protocol_version_fn dave_max_protocol_version;
  vs_dave_session_create_fn dave_session_create;
  vs_dave_session_destroy_fn dave_session_destroy;
  vs_dave_session_reinit_fn dave_session_reinit;
  vs_dave_set_external_sender_fn dave_set_external_sender;
  vs_dave_get_key_package_fn dave_get_key_package;
  vs_dave_process_proposals_fn dave_process_proposals;
  vs_dave_process_message_fn dave_process_commit;
  vs_dave_process_welcome_fn dave_process_welcome;
  vs_dave_output_fn dave_encrypt_opus;
  vs_dave_decrypt_fn dave_decrypt;
  vs_dave_session_status_fn dave_session_status;
  vs_dave_get_verification_code_fn dave_get_verification_code;
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
      api.dave_max_protocol_version =
          (vs_dave_max_protocol_version_fn)discord_voice_library_symbol(
              library, "vs_dave_max_protocol_version");
      api.dave_session_create =
          (vs_dave_session_create_fn)discord_voice_library_symbol(
              library, "vs_dave_session_create");
      api.dave_session_destroy =
          (vs_dave_session_destroy_fn)discord_voice_library_symbol(
              library, "vs_dave_session_destroy");
      api.dave_session_reinit =
          (vs_dave_session_reinit_fn)discord_voice_library_symbol(
              library, "vs_dave_session_reinit");
      api.dave_set_external_sender =
          (vs_dave_set_external_sender_fn)discord_voice_library_symbol(
              library, "vs_dave_set_external_sender");
      api.dave_get_key_package =
          (vs_dave_get_key_package_fn)discord_voice_library_symbol(
              library, "vs_dave_get_key_package");
      api.dave_process_proposals =
          (vs_dave_process_proposals_fn)discord_voice_library_symbol(
              library, "vs_dave_process_proposals");
      api.dave_process_commit =
          (vs_dave_process_message_fn)discord_voice_library_symbol(
              library, "vs_dave_process_commit");
      api.dave_process_welcome =
          (vs_dave_process_welcome_fn)discord_voice_library_symbol(
              library, "vs_dave_process_welcome");
      api.dave_encrypt_opus =
          (vs_dave_output_fn)discord_voice_library_symbol(
              library, "vs_dave_encrypt_opus");
      api.dave_decrypt =
          (vs_dave_decrypt_fn)discord_voice_library_symbol(
              library, "vs_dave_decrypt");
      api.dave_session_status =
          (vs_dave_session_status_fn)discord_voice_library_symbol(
              library, "vs_dave_session_status");
      api.dave_get_verification_code =
          (vs_dave_get_verification_code_fn)discord_voice_library_symbol(
              library, "vs_dave_get_verification_code");
      if (api.abi_version == NULL || api.free_output == NULL ||
          api.last_error == NULL || api.seal == NULL || api.open == NULL ||
          api.dave_max_protocol_version == NULL ||
          api.dave_session_create == NULL ||
          api.dave_session_destroy == NULL ||
          api.dave_session_reinit == NULL ||
          api.dave_set_external_sender == NULL ||
          api.dave_get_key_package == NULL ||
          api.dave_process_proposals == NULL ||
          api.dave_process_commit == NULL ||
          api.dave_process_welcome == NULL ||
          api.dave_encrypt_opus == NULL || api.dave_decrypt == NULL ||
          api.dave_session_status == NULL ||
          api.dave_get_verification_code == NULL) {
        api.status = DISCORD_VOICE_SHIM_MISSING_SYMBOL;
        snprintf(api.reason, sizeof(api.reason),
                 "discord voice shim is missing one or more ABI v2 symbols");
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

typedef struct {
  void *session;
} DiscordDaveSession;

static void discord_voice_dave_session_finalize(void *pointer) {
  DiscordDaveSession *session = (DiscordDaveSession *)pointer;
  if (session->session != NULL) {
    discord_voice_shim_api()->dave_session_destroy(session->session);
    session->session = NULL;
  }
}

static int discord_voice_dave_ready(const DiscordVoiceShimApi *api) {
  discord_voice_last_status = api->status;
  return api->status == 0;
}

static void *discord_voice_dave_raw_session(DiscordDaveSession *session) {
  if (session == NULL || session->session == NULL) {
    discord_voice_last_status = -22;
    return NULL;
  }
  return session->session;
}

static moonbit_bytes_t discord_voice_dave_take_output(
    const DiscordVoiceShimApi *api, uint8_t *output, size_t output_len) {
  if (output_len > INT32_MAX) {
    if (output != NULL) {
      api->free_output(output, output_len);
    }
    discord_voice_last_status = -22;
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t result = moonbit_make_bytes((int32_t)output_len, 0);
  if (output != NULL && output_len > 0) {
    memcpy(result, output, output_len);
  }
  if (output != NULL) {
    api->free_output(output, output_len);
  }
  return result;
}

static moonbit_bytes_t discord_voice_dave_failed_output(
    const DiscordVoiceShimApi *api, uint8_t *output, size_t output_len) {
  if (output != NULL) {
    api->free_output(output, output_len);
  }
  return moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT
int32_t discord_voice_dave_max_protocol_version(void) {
  const DiscordVoiceShimApi *api = discord_voice_shim_api();
  if (!discord_voice_dave_ready(api)) {
    return 0;
  }
  discord_voice_last_status = 0;
  return (int32_t)api->dave_max_protocol_version();
}

MOONBIT_FFI_EXPORT
DiscordDaveSession *discord_voice_dave_session_create(
    int32_t protocol_version, moonbit_bytes_t user_id, uint64_t channel_id) {
  const DiscordVoiceShimApi *api = discord_voice_shim_api();
  DiscordDaveSession *result =
      (DiscordDaveSession *)moonbit_make_external_object(
          discord_voice_dave_session_finalize, sizeof(void *));
  result->session = NULL;
  if (!discord_voice_dave_ready(api)) {
    return result;
  }
  if (protocol_version <= 0 || protocol_version > UINT16_MAX ||
      user_id == NULL) {
    discord_voice_last_status = -1;
    return result;
  }
  result->session = api->dave_session_create(
      (uint16_t)protocol_version, (const char *)user_id, channel_id);
  if (result->session == NULL) {
    discord_voice_last_status = -22;
  } else {
    discord_voice_last_status = 0;
  }
  return result;
}

MOONBIT_FFI_EXPORT
int32_t discord_voice_dave_session_reinit(DiscordDaveSession *session,
                                           int32_t protocol_version) {
  const DiscordVoiceShimApi *api = discord_voice_shim_api();
  if (!discord_voice_dave_ready(api)) {
    return api->status;
  }
  void *raw = discord_voice_dave_raw_session(session);
  if (raw == NULL) {
    return discord_voice_last_status;
  }
  if (protocol_version <= 0 || protocol_version > UINT16_MAX) {
    discord_voice_last_status = -1;
    return -1;
  }
  discord_voice_last_status =
      api->dave_session_reinit(raw, (uint16_t)protocol_version);
  return discord_voice_last_status;
}

MOONBIT_FFI_EXPORT
int32_t discord_voice_dave_set_external_sender(DiscordDaveSession *session,
                                                moonbit_bytes_t data) {
  const DiscordVoiceShimApi *api = discord_voice_shim_api();
  if (!discord_voice_dave_ready(api)) {
    return api->status;
  }
  void *raw = discord_voice_dave_raw_session(session);
  if (raw == NULL || data == NULL) {
    if (raw != NULL) {
      discord_voice_last_status = -1;
    }
    return discord_voice_last_status;
  }
  discord_voice_last_status = api->dave_set_external_sender(
      raw, data, (size_t)Moonbit_array_length(data));
  return discord_voice_last_status;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t
discord_voice_dave_get_key_package(DiscordDaveSession *session) {
  const DiscordVoiceShimApi *api = discord_voice_shim_api();
  if (!discord_voice_dave_ready(api)) {
    return moonbit_make_bytes(0, 0);
  }
  void *raw = discord_voice_dave_raw_session(session);
  if (raw == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  uint8_t *output = NULL;
  size_t output_len = 0;
  discord_voice_last_status =
      api->dave_get_key_package(raw, &output, &output_len);
  if (discord_voice_last_status != 0) {
    return discord_voice_dave_failed_output(api, output, output_len);
  }
  return discord_voice_dave_take_output(api, output, output_len);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t *discord_voice_dave_process_proposals(
    DiscordDaveSession *session, int32_t op_type, moonbit_bytes_t data,
    moonbit_bytes_t *recognized_user_ids) {
  const DiscordVoiceShimApi *api = discord_voice_shim_api();
  moonbit_bytes_t *result =
      (moonbit_bytes_t *)moonbit_make_ref_array_raw(2);
  result[0] = moonbit_make_bytes(0, 0);
  result[1] = moonbit_make_bytes(0, 0);
  if (!discord_voice_dave_ready(api)) {
    return result;
  }
  void *raw = discord_voice_dave_raw_session(session);
  if (raw == NULL || data == NULL || recognized_user_ids == NULL) {
    if (raw != NULL) {
      discord_voice_last_status = -1;
    }
    return result;
  }
  uint8_t *commit = NULL;
  size_t commit_len = 0;
  uint8_t *welcome = NULL;
  size_t welcome_len = 0;
  discord_voice_last_status = api->dave_process_proposals(
      raw, op_type, data, (size_t)Moonbit_array_length(data),
      (const char *const *)recognized_user_ids,
      (size_t)Moonbit_array_length(recognized_user_ids), &commit, &commit_len,
      &welcome, &welcome_len);
  if (discord_voice_last_status != 0) {
    discord_voice_dave_failed_output(api, commit, commit_len);
    discord_voice_dave_failed_output(api, welcome, welcome_len);
    return result;
  }
  moonbit_decref(result[0]);
  result[0] = discord_voice_dave_take_output(api, commit, commit_len);
  moonbit_decref(result[1]);
  result[1] = discord_voice_dave_take_output(api, welcome, welcome_len);
  return result;
}

MOONBIT_FFI_EXPORT
int32_t discord_voice_dave_process_commit(DiscordDaveSession *session,
                                           moonbit_bytes_t data) {
  const DiscordVoiceShimApi *api = discord_voice_shim_api();
  if (!discord_voice_dave_ready(api)) {
    return api->status;
  }
  void *raw = discord_voice_dave_raw_session(session);
  if (raw == NULL || data == NULL) {
    if (raw != NULL) {
      discord_voice_last_status = -1;
    }
    return discord_voice_last_status;
  }
  discord_voice_last_status = api->dave_process_commit(
      raw, data, (size_t)Moonbit_array_length(data));
  return discord_voice_last_status;
}

MOONBIT_FFI_EXPORT
int32_t discord_voice_dave_process_welcome(DiscordDaveSession *session,
                                            moonbit_bytes_t data) {
  const DiscordVoiceShimApi *api = discord_voice_shim_api();
  if (!discord_voice_dave_ready(api)) {
    return api->status;
  }
  void *raw = discord_voice_dave_raw_session(session);
  if (raw == NULL || data == NULL) {
    if (raw != NULL) {
      discord_voice_last_status = -1;
    }
    return discord_voice_last_status;
  }
  discord_voice_last_status = api->dave_process_welcome(
      raw, data, (size_t)Moonbit_array_length(data), NULL, 0);
  return discord_voice_last_status;
}

static moonbit_bytes_t discord_voice_dave_output_call(
    vs_dave_output_fn operation, DiscordDaveSession *session,
    moonbit_bytes_t input) {
  const DiscordVoiceShimApi *api = discord_voice_shim_api();
  if (!discord_voice_dave_ready(api)) {
    return moonbit_make_bytes(0, 0);
  }
  void *raw = discord_voice_dave_raw_session(session);
  if (raw == NULL || input == NULL) {
    if (raw != NULL) {
      discord_voice_last_status = -1;
    }
    return moonbit_make_bytes(0, 0);
  }
  uint8_t *output = NULL;
  size_t output_len = 0;
  discord_voice_last_status = operation(
      raw, input, (size_t)Moonbit_array_length(input), &output, &output_len);
  if (discord_voice_last_status != 0) {
    return discord_voice_dave_failed_output(api, output, output_len);
  }
  return discord_voice_dave_take_output(api, output, output_len);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t discord_voice_dave_encrypt_opus(DiscordDaveSession *session,
                                                 moonbit_bytes_t frame) {
  return discord_voice_dave_output_call(
      discord_voice_shim_api()->dave_encrypt_opus, session, frame);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t discord_voice_dave_decrypt(DiscordDaveSession *session,
                                            moonbit_bytes_t user_id,
                                            moonbit_bytes_t frame) {
  const DiscordVoiceShimApi *api = discord_voice_shim_api();
  if (!discord_voice_dave_ready(api)) {
    return moonbit_make_bytes(0, 0);
  }
  void *raw = discord_voice_dave_raw_session(session);
  if (raw == NULL || user_id == NULL || frame == NULL) {
    if (raw != NULL) {
      discord_voice_last_status = -1;
    }
    return moonbit_make_bytes(0, 0);
  }
  uint8_t *output = NULL;
  size_t output_len = 0;
  discord_voice_last_status = api->dave_decrypt(
      raw, (const char *)user_id, frame,
      (size_t)Moonbit_array_length(frame), &output, &output_len);
  if (discord_voice_last_status != 0) {
    return discord_voice_dave_failed_output(api, output, output_len);
  }
  return discord_voice_dave_take_output(api, output, output_len);
}

MOONBIT_FFI_EXPORT
int32_t discord_voice_dave_session_status(DiscordDaveSession *session) {
  const DiscordVoiceShimApi *api = discord_voice_shim_api();
  if (!discord_voice_dave_ready(api)) {
    return api->status;
  }
  void *raw = discord_voice_dave_raw_session(session);
  if (raw == NULL) {
    return discord_voice_last_status;
  }
  discord_voice_last_status = api->dave_session_status(raw);
  return discord_voice_last_status;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t
discord_voice_dave_get_verification_code(DiscordDaveSession *session,
                                          moonbit_bytes_t user_id) {
  const DiscordVoiceShimApi *api = discord_voice_shim_api();
  if (!discord_voice_dave_ready(api)) {
    return moonbit_make_bytes(0, 0);
  }
  void *raw = discord_voice_dave_raw_session(session);
  if (raw == NULL || user_id == NULL) {
    if (raw != NULL) {
      discord_voice_last_status = -1;
    }
    return moonbit_make_bytes(0, 0);
  }
  uint8_t *output = NULL;
  size_t output_len = 0;
  discord_voice_last_status = api->dave_get_verification_code(
      raw, (const char *)user_id, &output, &output_len);
  if (discord_voice_last_status != 0) {
    return discord_voice_dave_failed_output(api, output, output_len);
  }
  return discord_voice_dave_take_output(api, output, output_len);
}
