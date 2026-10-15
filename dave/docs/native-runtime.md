# Native libdave runtime

`gaato/dave` performs DAVE operations on MoonBit's native backend. It loads
Discord's official `libdave` shared library at runtime instead of linking the
library into each application. Its JavaScript implementation is an unavailable
facade so a multi-target dependency graph can still be checked and tested.

## Normal installation

Native bootstrap requires Node.js 18 or newer. Linux and macOS hosts also need
`unzip`; Windows uses PowerShell's `Expand-Archive`. The first online build
needs HTTPS access to the pinned GitHub Release asset. Offline builds must
preseed a verified extraction as described below.

The module's experimental Moon prebuild hook provisions a host library only
when a Moon command sets `MBT_DAVE_REQUIRE_NATIVE=1`. It selects the asset
matching the build host, downloads the pinned `v1.2.0/cpp` archive, checks its
size and SHA-256 digest, extracts it into the user's cache, checks the shared
library's SHA-256 digest, and leaves it at a deterministic path shared with the
C loader. The Mooncake itself contains no platform binaries, and later builds
reuse the verified cache entry.

The downloader rejects a conflicting `Content-Length` before creating the
archive file and enforces the pinned archive size while streaming, including
for chunked responses. It never writes more than the recorded asset size; the
digest remains the final authenticity check.

Bootstrap and compile on a supported native host with:

```fish
env MBT_DAVE_REQUIRE_NATIVE=1 moon build --target native --release
```

Running `node build.js </dev/null` is an explicit bootstrap-only alternative.
When Moon invokes the hook without `MBT_DAVE_REQUIRE_NATIVE=1`, it returns an
empty configuration without selecting, validating, or downloading a host
asset. This keeps JavaScript and applications that do not use voice free from
an unnecessary native dependency.

Node.js executes the JavaScript-format `build.js` prebuild script. Extraction
uses `unzip` on Linux and macOS and Windows PowerShell's `Expand-Archive` on
Windows. The script writes only JSON to stdout, as required by Moon's prebuild
protocol.

Default cache locations are:

- Linux: `$XDG_CACHE_HOME/gaato-dave`, or `~/.cache/gaato-dave`
- macOS: `~/Library/Caches/gaato-dave`
- Windows: `%LOCALAPPDATA%\gaato-dave`

The cache retains the complete upstream extraction, including its `licenses/`
directory. It does not place a shared library into the system library path.

## Overrides and offline builds

The following environment variables are supported:

- `MBT_DAVE_REQUIRE_NATIVE`: set to `1` to opt a Moon build into the verified
  host-asset bootstrap. Native CI tests also use this value to fail rather than
  skip when libdave is unavailable.
- `MBT_DAVE_NATIVE_ROOT`: an absolute path to an extracted official archive.
  The hook selects `lib/libdave.so`, `lib/libdave.dylib`, or
  `bin/libdave.dll` beneath it and requires the pinned library SHA-256 digest.
  Keep this variable set when running the application because the loader uses
  the same root.
- `MBT_DAVE_NATIVE_CACHE_DIR`: an absolute base directory for the managed
  cache. Keep it set at runtime when using a non-default cache base.
- `MBT_DAVE_NATIVE_OFFLINE`: when `1`, `true`, `yes`, or `on`, prohibit a
  download and fail on a cache miss.
- `MBT_DAVE_NATIVE_LIB`: a runtime-only absolute path to an ABI-compatible
  library. This intentional override is not downloaded or hash-checked by the
  build hook. It is an explicit trust override and takes precedence over the
  pinned locations.

For example, an air-gapped build can pre-extract the matching official archive
and run:

```fish
set -gx MBT_DAVE_NATIVE_ROOT /opt/libdave/v1.2.0-cpp/linux-x64
set -gx MBT_DAVE_NATIVE_OFFLINE 1
env MBT_DAVE_REQUIRE_NATIVE=1 moon build --target native --release
```

The C loader searches in this order:

1. `MBT_DAVE_NATIVE_LIB` at runtime
2. the prebuild-verified `MBT_DAVE_NATIVE_ROOT` plus the current asset's
   library-relative path
3. `MBT_DAVE_NATIVE_CACHE_DIR`, or the platform default cache, plus
   `gaato-dave/libdave/v1.2.0-cpp/<asset-id>/<library-relative-path>`

The two explicit library locations are authoritative: if
`MBT_DAVE_NATIVE_LIB` or `MBT_DAVE_NATIVE_ROOT` is set but cannot be loaded,
the loader reports that path's error instead of falling through to the cache.

Every candidate path is absolute. The loader deliberately does not try a bare
`libdave.so`, `libdave.dylib`, or `libdave.dll`, the current directory, or
platform system-library paths. A missing bootstrap therefore fails closed
instead of silently selecting a different libdave build. The JavaScript
prebuild verifies the root or managed-cache library digest; the C loader then
checks the expected symbol set but does not calculate the digest again at each
process start. Keep `MBT_DAVE_NATIVE_ROOT` paired with a build that ran the
prebuild verification.

On Windows the loader reads path overrides through the Unicode environment API
and calls `LoadLibraryExW`. Dependencies are searched only beside the selected
library and in `System32`. There is no fallback to the ANSI loader or the
legacy current-directory search. Extremely long environment paths whose UTF-8
form exceeds the loader's 4096-byte path buffer are rejected with an actionable
unavailable reason. Windows systems that do not implement the
`LOAD_LIBRARY_SEARCH_*` flags also fail closed; the loader does not retry with
legacy search semantics.

The prebuild hook emits an empty JSON configuration object. It does not add a
native link configuration or bake a user-specific absolute path into compiled
objects.

## Official binary matrix

The pinned upstream release provides:

| Host | Architectures | Runtime file |
| --- | --- | --- |
| Linux | x86-64, ARM64 | `lib/libdave.so` |
| macOS | x86-64, ARM64 | `lib/libdave.dylib` |
| Windows | x86-64 | `bin/libdave.dll` |

Windows ARM64 and other hosts currently have no official asset and fail with an
actionable prebuild error when native bootstrap is required. Cross-compiling to
a different operating system or architecture is not supported by this
host-selected bootstrap.

The official Linux binaries require symbols as new as glibc 2.38 and
GLIBCXX 3.4.32. glibc has provided the dynamic-loader API directly from libc
since 2.34, so the supported binaries do not need a separate `-ldl` link flag.
On older distributions, provide a compatible self-built `libdave` with
`MBT_DAVE_NATIVE_LIB` and any application-specific linker flags it needs, or
build and run inside a newer runtime environment.

Moon currently marks module prebuild hooks as experimental. As with any module
that uses one, review `build.js` before adopting it in a high-trust build. This
hook has no package-manager dependencies and accepts only the release URLs and
digests recorded in `release/libdave-v1.2.0.js`.
