# gaato/dave

Native MoonBit bindings for Discord's official
[`libdave`](https://github.com/discord/libdave), the library behind Discord's
DAVE end-to-end encryption for voice and video. Use it to establish the MLS
group and encrypt or decrypt media frames in your own voice implementation.

**Most bots do not need this module directly.** Bots built with
[`gaato/discord`](https://mooncakes.io/docs/gaato/discord) get DAVE, together
with the voice gateway and RTP transport, from
[`gaato/discord_voice`](https://mooncakes.io/docs/gaato/discord_voice).

`gaato/dave` owns the unsafe FFI boundary and exposes opaque types for MLS
sessions, key ratchets and media encryptors and decryptors. It is a protocol
and media-crypto library, not a Discord client. Gateway and voice WebSocket
opcodes, participant bookkeeping, transition timing, RTP/UDP transport and
recovery policy stay in your application.

## Install

```sh
moon add gaato/dave
```

Import `gaato/dave` in your package's `moon.pkg`. Then download the native
library once, from a native build:

```sh
env MBT_DAVE_REQUIRE_NATIVE=1 moon build --target native --release
```

The build hook fetches Discord's official prebuilt `libdave` for the host,
checks its size and SHA-256 digest, and caches it for loading at run time.
Nothing is installed system-wide. The hook runs with `node`, so Node.js must be
on `PATH` for native builds. Linux and macOS also need `unzip`. Builds without
`MBT_DAVE_REQUIRE_NATIVE=1` download nothing.

| Host | Architecture | Support |
| --- | --- | --- |
| Linux | x86-64, ARM64 | Supported |
| macOS | ARM64 | Supported |
| Windows | x86-64 | Supported |
| macOS | x86-64 | Upstream asset only. MoonBit has no Darwin x86-64 toolchain. |

Other hosts have no upstream asset. Upstream's Linux binaries need a recent
glibc. On older distributions, point `MBT_DAVE_NATIVE_LIB` at a compatible
self-built library.

On JavaScript and linear-memory Wasm the package still type-checks, so it can
stay in a multi-target dependency graph. There, `available()` is false and
native-handle constructors raise `DaveError::LibraryUnavailable`.

## Start a session

Create an MLS session and obtain the key package that your DAVE orchestration
sends to the voice server:

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

Then:

1. Set the external sender before processing proposals.
2. Feed proposal, commit and Welcome messages into the session.
3. Once an epoch is established, get each participant's `KeyRatchet` and
   install it into an `Encryptor` or `Decryptor`.
4. Assign a supported codec to each outbound SSRC before encrypting its
   frames.

The external sender cannot be replaced while pending or established group
state exists. Call `reset`, replace it, then `reinitialize`. `reset` keeps the
configured external sender, as libdave does.

Check `available()` before starting an optional DAVE path, or let
constructors raise `DaveError::LibraryUnavailable` when DAVE is required.

## Ownership and errors

- `Session`, `KeyRatchet`, `Encryptor` and `Decryptor` own native handles.
  Copying one of these values aliases the same mutable native state, so
  serialize access to each one.
- Bytes returned from native code are copied into MoonBit memory. Installing a
  `KeyRatchet` copies its key state into the media object.
- Invalid use, unavailable native support and native failures raise
  `DaveError`. A rejected commit or Welcome is a protocol outcome, returned as
  `CommitResult::Failed` or `WelcomeResult::Failed`, for your state machine to
  handle.
- `Session::new` always uses transient signing keys. Persisted keys are not
  exposed.

## Verification codes

`current_group_pairwise_fingerprint_blocking` returns the pairwise fingerprint
for a peer in the current group, and `pairwise_verification_code` formats it as
the code users compare:

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

A code is valid for the current group only. Because signing identities are
transient, discard any stored fingerprint, code or trust decision after a
reconnect, a `reinitialize` or a new `Session`. The call blocks until
libdave's worker answers, so do not make it on an event-loop thread.

## Upstream and licensing

This is an independent binding, not affiliated with or endorsed by Discord.
`libdave` and its bundled dependencies keep their upstream licenses. The
downloaded release and its digests are recorded in
[THIRD_PARTY.md](https://github.com/gaato/discord.mbt/blob/main/dave/THIRD_PARTY.md).

## Links

- [Native runtime notes](https://github.com/gaato/discord.mbt/blob/main/dave/docs/native-runtime.md):
  exact requirements, cache paths, offline builds and loader order
- [Verification boundary](https://github.com/gaato/discord.mbt/blob/main/dave/docs/verification-boundary.md)
- [Changelog](https://github.com/gaato/discord.mbt/blob/main/dave/CHANGELOG.md)
- [Repository](https://github.com/gaato/discord.mbt) (the module lives in `dave/`)
- [`libdave`](https://github.com/discord/libdave)

## License

Apache-2.0
