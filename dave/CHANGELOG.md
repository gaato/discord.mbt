# Changelog

All notable changes to `gaato/dave` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Releases before this
file were made from [gaato/dave.mbt](https://github.com/gaato/dave.mbt).

## [Unreleased]

### Changed

- The module moved into the `dave/` directory of
  [gaato/discord.mbt](https://github.com/gaato/discord.mbt). Its CI is the
  `Dave` workflow there, and `repository` in `moon.mod` points to it.
- The prebuild hook recognises a Moon run by `MOON_BACKEND`, which Moon sets
  for prebuild scripts since toolchain 0.10.14, instead of by the JSON payload
  on stdin, which Moon is going to stop sending. Without that change a Moon
  release that drops stdin would have made the hook download libdave for every
  native build. Run directly (`node build.js`), the hook no longer waits for
  end of input.
