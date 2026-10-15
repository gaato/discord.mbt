/* Gateway zlib-stream transport compression.
 *
 * zlib is resolved at runtime (dlopen / LoadLibrary) instead of being linked
 * with -lz. Package-level cc-link-flags do not propagate to downstream link
 * targets in moon, so a link-time dependency would force every consumer of
 * this library to configure -lz themselves. Runtime loading follows the
 * moonbitlang/async TLS precedent (OpenSSL is loaded the same way) and keeps
 * compression a zero-configuration opt-in. When the zlib shared library is
 * missing, constructors report DISCORD_GATEWAY_ZLIB_UNAVAILABLE (-100) and
 * the MoonBit side raises before any connection is attempted.
 *
 * <zlib.h> is still included for the z_stream layout and constants; only
 * link-time symbol resolution is avoided.
 */
#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#define DISCORD_GATEWAY_ZLIB_UNAVAILABLE (-100)

typedef int (*discord_zlib_inflate_init2_fn)(z_streamp, int, const char *, int);
typedef int (*discord_zlib_inflate_fn)(z_streamp, int);
typedef int (*discord_zlib_inflate_end_fn)(z_streamp);
typedef int (*discord_zlib_deflate_init2_fn)(z_streamp, int, int, int, int, int,
                                             const char *, int);
typedef int (*discord_zlib_deflate_fn)(z_streamp, int);
typedef int (*discord_zlib_deflate_end_fn)(z_streamp);
typedef uLong (*discord_zlib_compress_bound_fn)(uLong);

typedef struct {
  int loaded;
  discord_zlib_inflate_init2_fn inflate_init2;
  discord_zlib_inflate_fn inflate;
  discord_zlib_inflate_end_fn inflate_end;
  discord_zlib_deflate_init2_fn deflate_init2;
  discord_zlib_deflate_fn deflate;
  discord_zlib_deflate_end_fn deflate_end;
  discord_zlib_compress_bound_fn compress_bound;
} DiscordZlibApi;

#if defined(_WIN32)
#include <windows.h>

static void *discord_zlib_open(void) {
  return (void *)LoadLibraryA("zlib1.dll");
}

static void *discord_zlib_sym(void *lib, const char *name) {
  return (void *)GetProcAddress((HMODULE)lib, name);
}
#else
#include <dlfcn.h>

static void *discord_zlib_open(void) {
  static const char *const candidates[] = {
#if defined(__APPLE__)
    "libz.1.dylib", "libz.dylib",
#else
    "libz.so.1", "libz.so",
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

static void *discord_zlib_sym(void *lib, const char *name) {
  return dlsym(lib, name);
}
#endif

static const DiscordZlibApi *discord_zlib_api(void) {
  static DiscordZlibApi api;
  static int attempted = 0;
  if (!attempted) {
    attempted = 1;
    void *lib = discord_zlib_open();
    if (lib != NULL) {
      api.inflate_init2 =
          (discord_zlib_inflate_init2_fn)discord_zlib_sym(lib, "inflateInit2_");
      api.inflate = (discord_zlib_inflate_fn)discord_zlib_sym(lib, "inflate");
      api.inflate_end =
          (discord_zlib_inflate_end_fn)discord_zlib_sym(lib, "inflateEnd");
      api.deflate_init2 =
          (discord_zlib_deflate_init2_fn)discord_zlib_sym(lib, "deflateInit2_");
      api.deflate = (discord_zlib_deflate_fn)discord_zlib_sym(lib, "deflate");
      api.deflate_end =
          (discord_zlib_deflate_end_fn)discord_zlib_sym(lib, "deflateEnd");
      api.compress_bound =
          (discord_zlib_compress_bound_fn)discord_zlib_sym(lib,
                                                           "compressBound");
      api.loaded = api.inflate_init2 != NULL && api.inflate != NULL &&
                   api.inflate_end != NULL && api.deflate_init2 != NULL &&
                   api.deflate != NULL && api.deflate_end != NULL &&
                   api.compress_bound != NULL;
    }
  }
  return &api;
}

typedef struct {
  z_stream stream;
  int32_t status;
  int initialized;
} DiscordGatewayZlib;

static void discord_gateway_zlib_finalize(void *object) {
  DiscordGatewayZlib *inflater = (DiscordGatewayZlib *)object;
  if (inflater->initialized) {
    discord_zlib_api()->inflate_end(&inflater->stream);
  }
}

MOONBIT_FFI_EXPORT
DiscordGatewayZlib *discord_gateway_zlib_new(void) {
  DiscordGatewayZlib *inflater = (DiscordGatewayZlib *)
      moonbit_make_external_object(discord_gateway_zlib_finalize,
                                   sizeof(DiscordGatewayZlib));
  memset(inflater, 0, sizeof(*inflater));
  const DiscordZlibApi *api = discord_zlib_api();
  if (!api->loaded) {
    inflater->status = DISCORD_GATEWAY_ZLIB_UNAVAILABLE;
    return inflater;
  }
  inflater->status =
      api->inflate_init2(&inflater->stream, 15, ZLIB_VERSION, sizeof(z_stream));
  inflater->initialized = inflater->status == Z_OK;
  return inflater;
}

MOONBIT_FFI_EXPORT
int32_t discord_gateway_zlib_status(DiscordGatewayZlib *inflater) {
  return inflater->status;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t discord_gateway_zlib_inflate(DiscordGatewayZlib *inflater,
                                              moonbit_bytes_t input) {
  const DiscordZlibApi *api = discord_zlib_api();
  size_t input_len = Moonbit_array_length(input);
  size_t capacity = input_len * 3 + 256;
  uint8_t *output = (uint8_t *)malloc(capacity);
  size_t used = 0;

  if (!inflater->initialized || output == NULL) {
    inflater->status = output == NULL ? Z_MEM_ERROR : Z_STREAM_ERROR;
    free(output);
    return moonbit_make_bytes(0, 0);
  }

  inflater->stream.next_in = input;
  inflater->stream.avail_in = (uInt)input_len;
  inflater->status = Z_OK;
  for (;;) {
    if (used == capacity) {
      size_t next_capacity = capacity * 2;
      uint8_t *grown = (uint8_t *)realloc(output, next_capacity);
      if (grown == NULL) {
        free(output);
        inflater->status = Z_MEM_ERROR;
        return moonbit_make_bytes(0, 0);
      }
      output = grown;
      capacity = next_capacity;
    }
    inflater->stream.next_out = output + used;
    inflater->stream.avail_out = (uInt)(capacity - used);
    uInt previous_input = inflater->stream.avail_in;
    size_t previous_used = used;
    int result = api->inflate(&inflater->stream, Z_SYNC_FLUSH);
    used = capacity - inflater->stream.avail_out;
    if (result != Z_OK && result != Z_STREAM_END && result != Z_BUF_ERROR) {
      free(output);
      inflater->status = result;
      return moonbit_make_bytes(0, 0);
    }
    if (result == Z_BUF_ERROR && inflater->stream.avail_in == previous_input &&
        used == previous_used) {
      free(output);
      inflater->status = Z_DATA_ERROR;
      return moonbit_make_bytes(0, 0);
    }
    if (inflater->stream.avail_in == 0 && inflater->stream.avail_out != 0) {
      break;
    }
  }

  moonbit_bytes_t result = moonbit_make_bytes((int32_t)used, 0);
  memcpy(result, output, used);
  free(output);
  inflater->status = Z_OK;
  return result;
}

/* Test-only deflater API used by compression_wbtest.mbt. */
typedef struct {
  z_stream stream;
  int32_t status;
  int initialized;
} DiscordGatewayDeflater;

static void discord_gateway_deflater_finalize(void *object) {
  DiscordGatewayDeflater *deflater = (DiscordGatewayDeflater *)object;
  if (deflater->initialized) {
    discord_zlib_api()->deflate_end(&deflater->stream);
  }
}

MOONBIT_FFI_EXPORT
DiscordGatewayDeflater *discord_gateway_test_deflater_new(void) {
  DiscordGatewayDeflater *deflater = (DiscordGatewayDeflater *)
      moonbit_make_external_object(discord_gateway_deflater_finalize,
                                   sizeof(DiscordGatewayDeflater));
  memset(deflater, 0, sizeof(*deflater));
  const DiscordZlibApi *api = discord_zlib_api();
  if (!api->loaded) {
    deflater->status = DISCORD_GATEWAY_ZLIB_UNAVAILABLE;
    return deflater;
  }
  deflater->status =
      api->deflate_init2(&deflater->stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED,
                         15, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION,
                         sizeof(z_stream));
  deflater->initialized = deflater->status == Z_OK;
  return deflater;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t discord_gateway_test_deflate(DiscordGatewayDeflater *deflater,
                                             moonbit_bytes_t input) {
  const DiscordZlibApi *api = discord_zlib_api();
  size_t input_len = Moonbit_array_length(input);
  if (!deflater->initialized) {
    deflater->status = Z_STREAM_ERROR;
    return moonbit_make_bytes(0, 0);
  }
  size_t capacity = api->compress_bound(input_len) + 16;
  uint8_t *output = (uint8_t *)malloc(capacity);
  if (output == NULL) {
    deflater->status = Z_MEM_ERROR;
    return moonbit_make_bytes(0, 0);
  }
  deflater->stream.next_in = input;
  deflater->stream.avail_in = (uInt)input_len;
  deflater->stream.next_out = output;
  deflater->stream.avail_out = (uInt)capacity;
  deflater->status = api->deflate(&deflater->stream, Z_SYNC_FLUSH);
  if (deflater->status != Z_OK || deflater->stream.avail_in != 0) {
    free(output);
    return moonbit_make_bytes(0, 0);
  }
  size_t used = capacity - deflater->stream.avail_out;
  moonbit_bytes_t result = moonbit_make_bytes((int32_t)used, 0);
  memcpy(result, output, used);
  free(output);
  return result;
}
