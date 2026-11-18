# Changelog

All notable changes to `gaato/dave` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Minor releases
(0.x → 0.y) may contain breaking changes; patch releases do not. Releases up
to 0.1.1 were made from [gaato/dave.mbt](https://github.com/gaato/dave.mbt).

## [Unreleased]

### Changed

- **Native builds use libdave 1.3.0** (`v1.3.0/cpp`, released 2026-11-10) instead
  of 1.2.0. Among its fixes: it validates every proposal and commit against
  the users the application recognizes, guards the decryptor state with one
  lock, and hardens the VP8 and H.264/H.265 frame parsers. The prebuild hook
  downloads and verifies the new archives into a new cache directory
  (`gaato-dave/libdave/v1.3.0-cpp/`).
- **A session keeps its recognized users itself**, as libdave 1.3.0 does.
  `Session::add_recognized_user(user_id~)` and
  `Session::remove_recognized_user(user_id~)` replace the
  `recognized_user_ids~` argument of `process_proposals` and
  `process_welcome`. Recognized users persist across `reinitialize` and
  `reset`, the session's own user is always recognized, and libdave now
  refuses a commit, not only proposals and a Welcome, that adds a user who is
  not recognized.
  - Migration: call `add_recognized_user` for each user the voice gateway
    reports as connected (clients_connect, opcode 11) and
    `remove_recognized_user` on client_disconnect (opcode 13), and drop the
    `recognized_user_ids~` argument.
  - Until the next minor release, the argument is still accepted with a
    deprecation warning: each listed user is recognized before the payload
    is processed, and none is removed. Users who left therefore stay
    recognized until you call `remove_recognized_user`.
- **`Session::process_proposals` returns `Bytes?`.** libdave 1.3.0 commits
  only queued proposals, so a revoke that withdraws every queued proposal
  returns `None`: there is nothing to send. Migration: send the commit only
  when the result is `Some`.

### Fixed

- **A libdave without the pinned C API is refused when it loads.** A library
  named by `MBT_DAVE_NATIVE_LIB` or `MBT_DAVE_NATIVE_ROOT` that lacks a
  function of the libdave 1.3.0 C API, such as any release before 1.3.0, makes
  `available()` false with a reason naming the missing function. Before, a
  1.3.0 library loaded under 0.2.0 was called with the older argument lists.

## [0.2.0] - 2026-11-18

### Changed

- Built and tested with MoonBit 0.10.21. The generated `.mbti` interface
  files spell `Int` as `Int32` and `UInt` as `UInt32` (since 0.10.16), list
  derived traits as a `#derive(...)` attribute above each declaration; these
  are the same types, and no signature changed.
- **`EncryptFailure` and `DecryptFailure` are `#non_exhaustive`**, so a later
  release can name a libdave failure code that arrives as `Unknown(code~)`
  today without breaking matches in your code.
  - Migration: a `match` outside this module that lists every constructor of
    either enum needs a last arm `Type::..`, for example
    `@dave.DecryptFailure::.. => ...`. A `_` or binding arm after every
    constructor is reported as unused: replace it with `Type::..`. A `match`
    whose `_` or binding arm still covers some constructors needs no change.
- The module moved into the `dave/` directory of
  [gaato/discord.mbt](https://github.com/gaato/discord.mbt). Its CI is the
  `Dave` workflow there, and `repository` in `moon.mod` points to it.
- The prebuild hook recognises a Moon run by `MOON_BACKEND`, which Moon sets
  for prebuild scripts since toolchain 0.10.14, instead of by the JSON payload
  on stdin, which Moon is going to stop sending. Without that change a Moon
  release that drops stdin would have made the hook download libdave for every
  native build. Run directly (`node build.js`), the hook no longer waits for
  end of input.

### Fixed

- **The README has sections and compile-checked examples.** The README is
  now the compiled `src/overview.mbt.md` (Install, Usage, Verification codes,
  Native runtime, Links), so its examples are checked by `moon test` instead
  of a separate copy. The libdave verification boundary moved to
  [docs/verification-boundary.md](https://github.com/gaato/discord.mbt/blob/main/dave/docs/verification-boundary.md),
  and the README no longer names the pinned libdave release.
