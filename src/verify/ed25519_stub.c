/* Native Ed25519 verification and test signing via runtime-loaded libcrypto.
 *
 * OpenSSL is resolved with dlopen / LoadLibrary so discord.mbt does not impose
 * a link-time libcrypto dependency on downstream native applications.
 */
#include <moonbit.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#define DISCORD_VERIFY_EVP_PKEY_ED25519 1087

typedef struct evp_pkey_st EVP_PKEY;
typedef struct evp_pkey_ctx_st EVP_PKEY_CTX;
typedef struct evp_md_ctx_st EVP_MD_CTX;
typedef struct evp_md_st EVP_MD;
typedef struct engine_st ENGINE;

typedef EVP_PKEY *(*discord_evp_pkey_new_raw_public_key_fn)(
    int, ENGINE *, const unsigned char *, size_t);
typedef EVP_PKEY *(*discord_evp_pkey_new_raw_private_key_fn)(
    int, ENGINE *, const unsigned char *, size_t);
typedef void (*discord_evp_pkey_free_fn)(EVP_PKEY *);
typedef EVP_MD_CTX *(*discord_evp_md_ctx_new_fn)(void);
typedef void (*discord_evp_md_ctx_free_fn)(EVP_MD_CTX *);
typedef int (*discord_evp_digest_verify_init_fn)(
    EVP_MD_CTX *, EVP_PKEY_CTX **, const EVP_MD *, ENGINE *, EVP_PKEY *);
typedef int (*discord_evp_digest_verify_fn)(EVP_MD_CTX *,
                                            const unsigned char *, size_t,
                                            const unsigned char *, size_t);
typedef int (*discord_evp_digest_sign_init_fn)(
    EVP_MD_CTX *, EVP_PKEY_CTX **, const EVP_MD *, ENGINE *, EVP_PKEY *);
typedef int (*discord_evp_digest_sign_fn)(EVP_MD_CTX *, unsigned char *,
                                          size_t *, const unsigned char *,
                                          size_t);

typedef struct {
  int loaded;
  discord_evp_pkey_new_raw_public_key_fn pkey_new_raw_public_key;
  discord_evp_pkey_new_raw_private_key_fn pkey_new_raw_private_key;
  discord_evp_pkey_free_fn pkey_free;
  discord_evp_md_ctx_new_fn md_ctx_new;
  discord_evp_md_ctx_free_fn md_ctx_free;
  discord_evp_digest_verify_init_fn digest_verify_init;
  discord_evp_digest_verify_fn digest_verify;
  discord_evp_digest_sign_init_fn digest_sign_init;
  discord_evp_digest_sign_fn digest_sign;
} DiscordCryptoApi;

#if defined(_WIN32)
#include <windows.h>

static void *discord_crypto_open(void) {
  static const char *const candidates[] = {
      "libcrypto-3-x64.dll",
      NULL,
  };
  for (int i = 0; candidates[i] != NULL; i++) {
    HMODULE lib = LoadLibraryA(candidates[i]);
    if (lib != NULL) {
      return (void *)lib;
    }
  }
  return NULL;
}

static void *discord_crypto_sym(void *lib, const char *name) {
  return (void *)GetProcAddress((HMODULE)lib, name);
}
#else
#include <dlfcn.h>

static void *discord_crypto_open(void) {
  static const char *const candidates[] = {
      "libcrypto.so.3",
      "libcrypto.so.1.1",
      "libcrypto.so",
#if defined(__APPLE__)
      "libcrypto.3.dylib",
      "libcrypto.dylib",
#endif
      NULL,
  };
  for (int i = 0; candidates[i] != NULL; i++) {
    void *lib = dlopen(candidates[i], RTLD_LAZY | RTLD_LOCAL);
    if (lib != NULL) {
      return lib;
    }
  }
  return NULL;
}

static void *discord_crypto_sym(void *lib, const char *name) {
  return dlsym(lib, name);
}
#endif

static const DiscordCryptoApi *discord_crypto_api(void) {
  static DiscordCryptoApi api;
  static int attempted = 0;
  if (!attempted) {
    attempted = 1;
    void *lib = discord_crypto_open();
    if (lib != NULL) {
      api.pkey_new_raw_public_key =
          (discord_evp_pkey_new_raw_public_key_fn)discord_crypto_sym(
              lib, "EVP_PKEY_new_raw_public_key");
      api.pkey_new_raw_private_key =
          (discord_evp_pkey_new_raw_private_key_fn)discord_crypto_sym(
              lib, "EVP_PKEY_new_raw_private_key");
      api.pkey_free = (discord_evp_pkey_free_fn)discord_crypto_sym(
          lib, "EVP_PKEY_free");
      api.md_ctx_new =
          (discord_evp_md_ctx_new_fn)discord_crypto_sym(lib, "EVP_MD_CTX_new");
      api.md_ctx_free = (discord_evp_md_ctx_free_fn)discord_crypto_sym(
          lib, "EVP_MD_CTX_free");
      api.digest_verify_init =
          (discord_evp_digest_verify_init_fn)discord_crypto_sym(
              lib, "EVP_DigestVerifyInit");
      api.digest_verify = (discord_evp_digest_verify_fn)discord_crypto_sym(
          lib, "EVP_DigestVerify");
      api.digest_sign_init =
          (discord_evp_digest_sign_init_fn)discord_crypto_sym(
              lib, "EVP_DigestSignInit");
      api.digest_sign = (discord_evp_digest_sign_fn)discord_crypto_sym(
          lib, "EVP_DigestSign");
      api.loaded = api.pkey_new_raw_public_key != NULL &&
                   api.pkey_new_raw_private_key != NULL &&
                   api.pkey_free != NULL && api.md_ctx_new != NULL &&
                   api.md_ctx_free != NULL &&
                   api.digest_verify_init != NULL &&
                   api.digest_verify != NULL &&
                   api.digest_sign_init != NULL && api.digest_sign != NULL;
    }
    if (!api.loaded) {
      fprintf(stderr,
              "discord/verify: libcrypto not found; signature verification "
              "disabled\n");
    }
  }
  return &api;
}

MOONBIT_FFI_EXPORT
int discord_verify_ed25519(moonbit_bytes_t public_key,
                           moonbit_bytes_t signature,
                           moonbit_bytes_t message) {
  if (public_key == NULL || signature == NULL || message == NULL) {
    return 0;
  }
  int32_t public_key_len = Moonbit_array_length(public_key);
  int32_t signature_len = Moonbit_array_length(signature);
  int32_t message_len = Moonbit_array_length(message);
  if (public_key_len != 32 || signature_len != 64 || message_len < 0) {
    return 0;
  }

  const DiscordCryptoApi *api = discord_crypto_api();
  if (!api->loaded) {
    return 0;
  }

  int result = 0;
  EVP_PKEY *pkey = api->pkey_new_raw_public_key(
      DISCORD_VERIFY_EVP_PKEY_ED25519, NULL, public_key, 32);
  EVP_MD_CTX *ctx = NULL;
  if (pkey == NULL) {
    goto cleanup;
  }
  ctx = api->md_ctx_new();
  if (ctx == NULL) {
    goto cleanup;
  }
  if (api->digest_verify_init(ctx, NULL, NULL, NULL, pkey) != 1) {
    goto cleanup;
  }
  result = api->digest_verify(ctx, signature, 64, message,
                              (size_t)message_len) == 1;

cleanup:
  if (ctx != NULL) {
    api->md_ctx_free(ctx);
  }
  if (pkey != NULL) {
    api->pkey_free(pkey);
  }
  return result;
}

MOONBIT_FFI_EXPORT
int discord_verify_ed25519_sign(moonbit_bytes_t private_key,
                                moonbit_bytes_t message,
                                moonbit_bytes_t out_signature) {
  if (private_key == NULL || message == NULL || out_signature == NULL) {
    return 0;
  }
  int32_t private_key_len = Moonbit_array_length(private_key);
  int32_t message_len = Moonbit_array_length(message);
  int32_t out_signature_len = Moonbit_array_length(out_signature);
  if (private_key_len != 32 || message_len < 0 || out_signature_len != 64) {
    return 0;
  }

  const DiscordCryptoApi *api = discord_crypto_api();
  if (!api->loaded) {
    return 0;
  }

  int result = 0;
  EVP_PKEY *pkey = api->pkey_new_raw_private_key(
      DISCORD_VERIFY_EVP_PKEY_ED25519, NULL, private_key, 32);
  EVP_MD_CTX *ctx = NULL;
  if (pkey == NULL) {
    goto cleanup;
  }
  ctx = api->md_ctx_new();
  if (ctx == NULL) {
    goto cleanup;
  }
  if (api->digest_sign_init(ctx, NULL, NULL, NULL, pkey) != 1) {
    goto cleanup;
  }
  size_t signature_len = 64;
  result = api->digest_sign(ctx, out_signature, &signature_len, message,
                            (size_t)message_len) == 1 &&
           signature_len == 64;

cleanup:
  if (ctx != NULL) {
    api->md_ctx_free(ctx);
  }
  if (pkey != NULL) {
    api->pkey_free(pkey);
  }
  return result;
}
