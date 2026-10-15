# Changelog

All notable changes to `gaato/dave` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Releases before this
file were made from [gaato/dave.mbt](https://github.com/gaato/dave.mbt).

## [Unreleased]

### Changed

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
