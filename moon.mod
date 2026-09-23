name = "gaato/discord"

version = "0.4.3"

readme = "README.md"

repository = "https://github.com/gaato/discord.mbt"

license = "Apache-2.0"

keywords = [ "discord", "bot", "gateway", "api", "voice", "interactions" ]

description = "An experimental Discord library for MoonBit: native/JS/Wasm REST, interactions, and gateway bots; native voice with DAVE E2EE."

source = "src"

preferred_target = "native"

// Trait methods are never promoted to regular methods implicitly; the
// dot-callable ones are declared with `pub extend` (scripts/gen_extends.py).

warnings = "-implicit_impl_as_method"

import {
  "gaato/http@0.1.0",
  "gaato/http-async@0.1.1",
  "moonbitlang/async@0.22.1",
  "hustcer/ed25519@0.6.0",
  "gaato/dave@0.1.1",
}

options(
  "--moonbit-unstable-prebuild": "build.js",
)
