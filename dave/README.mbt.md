# gaato/dave

[![CI](https://github.com/gaato/discord.mbt/actions/workflows/dave.yml/badge.svg)](https://github.com/gaato/discord.mbt/actions/workflows/dave.yml)
[![mooncakes](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fmooncakes.io%2Fapi%2Fv0%2Fmodules%2Fgaato%2Fdave&query=%24.version&label=mooncakes&prefix=v)](https://mooncakes.io/docs/gaato/dave)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/gaato/discord.mbt)
[![License](https://img.shields.io/github/license/gaato/discord.mbt)](https://github.com/gaato/discord.mbt/blob/main/dave/LICENSE)

Safe native MoonBit bindings for Discord's official
[`libdave`](https://github.com/discord/libdave) C API.

`gaato/dave` owns the unsafe FFI boundary and exposes opaque MoonBit types for
MLS sessions, key ratchets, and media encryptors/decryptors. It is a protocol
and media-crypto library, not a Discord client: Gateway and voice WebSocket
opcodes, participant bookkeeping, transition timing, RTP/UDP transport, and
recovery policy stay in the application.

The module lives in the `dave/` directory of
[gaato/discord.mbt](https://github.com/gaato/discord.mbt), whose voice support
is its main consumer; it is published to mooncakes on its own.

Real DAVE operations target MoonBit's native backend and pin upstream
`libdave` `v1.2.0/cpp`. The package also type-checks on JavaScript and
linear-memory Wasm so it can remain in a multi-target dependency graph;
there `available()` is false and
native-handle constructors raise `DaveError::LibraryUnavailable`.

## Using the API

Add the released module to the consumer and import the root package from
`moon.pkg`:

```sh
moon add gaato/dave@0.1.0
```

```moonbit
import {
  "gaato/dave",
}
```

Create an MLS session and obtain the key package that the Discord DAVE
orchestration layer sends to the voice server:

```moonbit
///|
fn make_key_package() -> Bytes raise @dave.DaveError {
  let session = @dave.Session::new(
    protocol_version=1,
    group_id=42UL,
    self_user_id=100UL,
  )
  session.key_package()
}
```

The application sets the external sender before processing proposals, then
feeds proposal, commit, and Welcome messages into the session. The external
sender cannot be replaced while pending or established MLS group state exists;
call `reset`, replace it, and then `reinitialize` when a replacement is needed.
`reset` itself retains the configured external sender, matching libdave, so an
ordinary `reinitialize` recreates pending group state with that sender. Once an
epoch is established, obtain per-user `KeyRatchet` values and install them into
an `Encryptor` or `Decryptor`. Outbound SSRCs must be assigned a supported codec
before encrypted frames are processed.

Check `available()` before starting an optional DAVE path, or let constructors
raise `DaveError::LibraryUnavailable` when DAVE is required.

## Ownership and errors

- `Session`, `KeyRatchet`, `Encryptor`, and `Decryptor` own finalizable native
  handles. Copying one of these MoonBit values aliases the same mutable native
  state, so access to a single value must be serialized by the application.
- Byte strings returned from native code are copied into MoonBit-owned memory.
  Installing a `KeyRatchet` copies its native key state into the media object.
- `Session::new` always requests libdave's transient signing-key behavior in
  v0.1. Native authentication-session IDs and persisted-key lookup are not
  exposed by the safe API.
- Invalid use, unavailable native support, and wrapper/native failures raise
  `DaveError`. MLS commit and Welcome rejections remain protocol outcomes in
  `CommitResult::Failed` or `WelcomeResult::Failed`. Applied commit and Welcome
  results both carry roster deltas; `RosterChange::Remove` represents an empty
  signature returned by libdave.

## Verification boundary

The official libdave v1.2.0 prebuilt C ABI has `PERSISTENT_KEYS` disabled. Each
`Session` therefore has a different transient signing identity, even for the
same Discord user, and `Session::reinitialize` rotates that identity again.
Concurrent sessions must not be treated as sharing a persistent DAVE identity.

`Session::current_group_pairwise_fingerprint_blocking` compares signing keys in
the currently established MLS group only. It can produce the current group's
DAVE verification code, but it does not provide identity continuity, a durable
verified-contact state, or persistent verification across reconnects,
reinitialization, or a replacement `Session`. Applications must discard any
stored fingerprint, display code, or trust decision when that boundary changes.
The fingerprint-format version is fixed to the canonical protocol value zero;
callers cannot substitute another version. The method waits for libdave's
asynchronous fingerprint worker and must not be called on an event-loop thread.

Formatting the current-group result is an explicit second step:

```moonbit
let fingerprint = session.current_group_pairwise_fingerprint_blocking(
  user_id=peer_user_id,
)
let display_code = @dave.pairwise_verification_code(fingerprint)
```

## Native runtime

Opt in once from a native Moon build to download the matching official libdave
archive, verify its pinned size and SHA-256 digest, and store the complete
extraction in a user cache:

```sh
env MBT_DAVE_REQUIRE_NATIVE=1 moon build --target native --release --deny-warn
```

The shared library is loaded at runtime; it is not installed system-wide or
embedded in the Mooncake. Builds without `MBT_DAVE_REQUIRE_NATIVE=1`, including
JavaScript and Wasm builds, do not bootstrap a host library.

See [Native libdave runtime](https://github.com/gaato/discord.mbt/blob/main/dave/docs/native-runtime.md) for cache paths, offline
and preseeded builds, environment overrides, and loader order.

The upstream release provides these host assets:

| Host | Architecture | CI coverage |
| --- | --- | --- |
| Linux | x86-64 | native build and tests |
| Linux | ARM64 | native build and tests |
| macOS | ARM64 | native build and tests |
| macOS | x86-64 | asset bootstrap and digest smoke test |
| Windows | x86-64 | native build and tests |

The official MoonBit installer currently has no Darwin x86-64 toolchain, so
the macOS Intel job cannot compile or execute the binding. Windows ARM64 and
other hosts have no pinned upstream libdave asset. Host-selected bootstrap does
not support cross-compilation.

Upstream's Linux binaries require glibc 2.38 and GLIBCXX 3.4.32. Applications
on older distributions need a compatible self-built library supplied through
`MBT_DAVE_NATIVE_LIB` or a newer runtime environment.

## Verification

On a supported host, bootstrap the pinned runtime and verify the backends from
the `dave/` directory with:

```sh
moon fmt --check
node --test test/build.test.js
moon check --target all --deny-warn
env MBT_DAVE_REQUIRE_NATIVE=1 moon build --target native --release --deny-warn
env MBT_DAVE_REQUIRE_NATIVE=1 moon test --target native --release --deny-warn
moon test --target js --release --deny-warn
moon test --target wasm --release --deny-warn
moon info --target native
moon package --list
```

The offline Node downloader tests under `test/` are repository-only and are
excluded from the published Mooncake.

The pinned native bridge smoke exercises the safe MoonBit/C boundary through a
successful single-member commit, roster and authenticator decoding, key-ratchet
installation, and encrypted media round trip. It does not cover a
server-signed Add proposal, Welcome processing, or multi-party Discord DAVE
conformance. Those paths require libdave's upstream test-only ExternalSender
helper or messages produced by a live Discord voice session.

## Upstream and licensing

This project is an independent binding. It is not affiliated with or endorsed
by Discord. `libdave` and its bundled dependencies retain their upstream
licenses and notices; see [THIRD_PARTY.md](https://github.com/gaato/discord.mbt/blob/main/dave/THIRD_PARTY.md). The MoonBit binding
itself is licensed under Apache-2.0.
