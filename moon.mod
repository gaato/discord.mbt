name = "gaato/discord"

version = "0.4.0"

readme = "README.mbt.md"

repository = "https://github.com/gaato/discord.mbt"

license = "Apache-2.0"

keywords = [ "discord", "bot", "gateway", "api", "voice", "interactions" ]

description = "An experimental Discord library for MoonBit: typed APIs, a native gateway with voice (DAVE E2EE), and JS/serverless HTTP interactions."

source = "src"

preferred_target = "native"

// Trait methods are never promoted to regular methods implicitly; the
// dot-callable ones are declared with `pub extend` (scripts/gen_extends.py).

warnings = "-implicit_impl_as_method"

import {
  "moonbitlang/async@0.22.1",
  "hustcer/ed25519@0.6.0",
  "gaato/dave@0.1.0",
}

options(
  "--moonbit-unstable-prebuild": "build.js",
)
