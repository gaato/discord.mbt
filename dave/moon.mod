name = "gaato/dave"

version = "0.1.1"

readme = "README.mbt.md"

repository = "https://github.com/gaato/discord.mbt"

license = "Apache-2.0"

keywords = [ "dave", "libdave", "discord", "e2ee", "mls", "native", "ffi" ]

description = "Safe native MoonBit bindings for Discord's official libdave C API"

preferred_target = "native"

supported_targets = "js + native + wasm"

// Keep the existing derived-trait API while validating on the pinned 0.10.16.

warnings = "-implicit_impl_as_method"

source = "src"

options(
  "--moonbit-unstable-prebuild": "build.js",
)
