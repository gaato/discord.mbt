name = "gaato/dave"

version = "0.1.1"

readme = "README.md"

repository = "https://github.com/gaato/discord.mbt"

license = "Apache-2.0"

keywords = [ "dave", "libdave", "discord", "e2ee", "mls", "native", "ffi" ]

description = "Safe native MoonBit bindings for Discord's official libdave C API"

preferred_target = "native"

supported_targets = "js + native + wasm"

// Keep the derived trait methods callable as methods: moonc 0.10.14 and
// later warn about that implicit promotion.

warnings = "-implicit_impl_as_method"

source = "src"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
