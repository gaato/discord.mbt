# discord.mbt voice transport shim

This crate builds the native transport AEAD shim used by
`gaato/discord/voice`. It implements AES-256-GCM and XChaCha20-Poly1305 behind
a small C ABI. DAVE MLS and media encryption are provided separately by the
`gaato/dave` MoonBit module and official libdave.

Native `gaato/discord` consumers can provision the pinned component together
with official libdave:

```fish
env DISCORD_VOICE_REQUIRE_SHIM=1 MBT_DAVE_REQUIRE_NATIVE=1 moon build --target native --release
```

The root prebuild hook downloads the matching `voice-shim-v0.1.0` archive,
checks its pinned size and SHA-256 digest, verifies the extracted library, and
caches it outside the Mooncake. It supports Linux x86-64/ARM64, macOS
x86-64/ARM64, and Windows x86-64. Node.js and either `tar` (Linux/macOS) or
PowerShell (Windows) are required.

For component development, build the shim with:

```fish
cargo build --release
```

The output is one of:

- Linux: `target/release/libdiscord_voice_shim.so`
- macOS: `target/release/libdiscord_voice_shim.dylib`
- Windows: `target/release/discord_voice_shim.dll`

Set `DISCORD_VOICE_SHIM_PATH` to the absolute path of that file when running
discord.mbt tests or applications. When the variable is set, the loader tries
only that path. Without it, the loader searches `DISCORD_VOICE_SHIM_ROOT`, the
deterministic component cache, and the platform library path for the native
filename: `.so` on Linux, `.dylib` on macOS, or `.dll` on Windows.

For offline provisioning, set `DISCORD_VOICE_SHIM_ROOT` to an extracted
release directory and `DISCORD_VOICE_SHIM_OFFLINE=1` to forbid downloads.
`DISCORD_VOICE_SHIM_CACHE_DIR` overrides the cache base; all path overrides
must be absolute.

## C ABI

Component release 0.1 uses transport-only ABI version 3. Release versions and
ABI generations are independent: this is the first binary component release,
while ABI versions 1 and 2 existed during source-only development. The loader
requires only:

- `vs_abi_version`
- `vs_free`
- `vs_last_error`
- `vs_aead_seal`
- `vs_aead_open`

ABI version 2 also exposed an in-shim DAVE session API and is intentionally
incompatible. The AEAD entry points catch unwinding panics before returning
across the C boundary. Output buffers remain Rust-owned until the caller passes
the exact pointer/length pair to `vs_free`; the MoonBit C adapter copies them
before releasing them.

The release workflow for the `voice-shim-v0.1.0` tag produces official
component archives. Each archive contains the platform library, the project license,
`THIRD_PARTY.md`, and the dependency license texts under
`THIRD_PARTY_LICENSES/`. `SHA256SUMS`, `RUNTIME_SHA256SUMS`, and `ASSET_SIZES`
are attached to the same release.

AEAD mode `0` is AES-256-GCM with a 32-byte key and 12-byte nonce. Mode `1` is
XChaCha20-Poly1305 with a 32-byte key and 24-byte nonce. Input buffers are
borrowed only for the synchronous call. Output slots are initialized to null
and zero before processing; opening an authenticated empty plaintext succeeds
with that empty representation.

Status codes are `0` for success, `-1` for an invalid argument, `-2` for an
unsupported mode, `-3` for authentication failure, `-4` for another
cryptographic failure, and `-5` for a caught Rust panic. Loader-only statuses
are `-100` (unavailable), `-101` (ABI mismatch), and `-102` (missing symbol).

Before changing the ABI, run the same checks as CI:

```fish
cargo fmt -- --check
cargo clippy --all-targets --locked -- -D warnings
cargo test --locked
cargo build --release --locked
```
