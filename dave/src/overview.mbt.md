# gaato/dave

[![CI](https://github.com/gaato/discord.mbt/actions/workflows/dave.yml/badge.svg)](https://github.com/gaato/discord.mbt/actions/workflows/dave.yml)
[![License](https://img.shields.io/github/license/gaato/discord.mbt)](https://github.com/gaato/discord.mbt/blob/main/dave/LICENSE)

Safe native MoonBit bindings for Discord's official
[`libdave`](https://github.com/discord/libdave) C API, for applications that
implement Discord's DAVE end-to-end encryption themselves.

`gaato/dave` owns the unsafe FFI boundary and exposes opaque MoonBit types for
MLS sessions, key ratchets, and media encryptors/decryptors. It is a protocol
and media-crypto library, not a Discord client: Gateway and voice WebSocket
opcodes, participant bookkeeping, transition timing, RTP/UDP transport, and
recovery policy stay in the application. Bots built with `gaato/discord` get
all of this from
[`gaato/discord_voice`](https://mooncakes.io/docs/gaato/discord_voice).

Real DAVE operations run on MoonBit's native backend. The package also
type-checks on JavaScript and linear-memory Wasm so it can remain in a
multi-target dependency graph; there `available()` is false and native-handle
constructors raise `DaveError::LibraryUnavailable`.

## Install

```sh
moon add gaato/dave
```

Then import the root package in your package's `moon.pkg`:

```mbt nocheck
///|
import {
  "gaato/dave",
}
```

## Usage

Create an MLS session and obtain the key package that the Discord DAVE
orchestration layer sends to the voice server:

```mbt check
///|
test "create a session and its key package" {
  guard @dave.available() else { return }
  let session = @dave.Session::new(
    protocol_version=1,
    group_id=42UL,
    self_user_id=100UL,
  )
  let key_package = session.key_package()
  assert_true(key_package.length() > 0)
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
- `Session::new` always requests libdave's transient signing-key behavior.
  Native authentication-session IDs and persisted-key lookup are not
  exposed by the safe API.
- Invalid use, unavailable native support, and wrapper/native failures raise
  `DaveError`. MLS commit and Welcome rejections remain protocol outcomes in
  `CommitResult::Failed` or `WelcomeResult::Failed`. Applied commit and Welcome
  results both carry roster deltas; `RosterChange::Remove` represents an empty
  signature returned by libdave.

## Verification codes

`Session::current_group_pairwise_fingerprint_blocking` returns the pairwise
fingerprint for a peer in the currently established MLS group, and
`pairwise_verification_code` formats it as the DAVE verification code:

```mbt check
///|
fn current_group_verification_code(
  session : @dave.Session,
  peer_user_id : UInt64,
) -> String raise @dave.DaveError {
  let fingerprint = session.current_group_pairwise_fingerprint_blocking(
    user_id=peer_user_id,
  )
  @dave.pairwise_verification_code(fingerprint)
}

///|
test "the verification example compiles" {
  ignore(current_group_verification_code)
}
```

A code is valid for the current group only. Signing identities are transient,
so discard any stored fingerprint, code, or trust decision after a reconnect,
`reinitialize`, or a replacement `Session`. The method blocks until libdave's
fingerprint worker answers; do not call it on an event-loop thread.

## Native runtime

Opt in once from a native Moon build to download Discord's official prebuilt
libdave archive for the host, verify its size and SHA-256 digest, and store
the extraction in a user cache:

```sh
env MBT_DAVE_REQUIRE_NATIVE=1 moon build --target native --release
```

The module's prebuild hook runs with `node`, so Node.js must be on `PATH` for
native builds; Linux and macOS also need `unzip`. The shared library is loaded
at run time; it is not installed system-wide or embedded in the package.
Builds without `MBT_DAVE_REQUIRE_NATIVE=1`, including JavaScript and Wasm
builds, download nothing.

Native DAVE runs on these hosts:

| Host | Architecture | Support |
| --- | --- | --- |
| Linux | x86-64, ARM64 | Supported |
| macOS | ARM64 | Supported |
| Windows | x86-64 | Supported |
| macOS | x86-64 | Upstream asset only; MoonBit has no Darwin x86-64 toolchain |

Other hosts have no upstream asset, and the bootstrap does not cross-compile.
Upstream's Linux binaries need a recent glibc; on older distributions, supply a
compatible self-built library through `MBT_DAVE_NATIVE_LIB`. The
[native runtime notes](https://github.com/gaato/discord.mbt/blob/main/dave/docs/native-runtime.md)
cover the exact requirements, cache paths, offline builds, environment
overrides, and loader order.

## Upstream and licensing

This project is an independent binding. It is not affiliated with or endorsed
by Discord. `libdave` and its bundled dependencies keep their upstream
licenses and notices; the downloaded release and its digests are recorded in
[THIRD_PARTY.md](https://github.com/gaato/discord.mbt/blob/main/dave/THIRD_PARTY.md).

## Links

- [Changelog](https://github.com/gaato/discord.mbt/blob/main/dave/CHANGELOG.md)
- [Repository](https://github.com/gaato/discord.mbt) (the module lives in
  `dave/`)
- [Native runtime notes](https://github.com/gaato/discord.mbt/blob/main/dave/docs/native-runtime.md)
- [Verification boundary](https://github.com/gaato/discord.mbt/blob/main/dave/docs/verification-boundary.md)
- [`libdave`](https://github.com/discord/libdave)

## License

Apache-2.0
