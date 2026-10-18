name = "gaato/discord"

version = "0.10.0"

readme = "README.md"

repository = "https://github.com/gaato/discord.mbt"

license = "Apache-2.0"

keywords = [ "discord", "bot", "gateway", "api", "interactions" ]

description = "An experimental Discord library for MoonBit: native/JS/Wasm REST, interactions, and gateway bots. Voice is in gaato/discord_voice."

source = "src"

preferred_target = "native"

// Trait methods are never promoted to regular methods implicitly; the
// dot-callable ones are declared with `pub extend` (scripts/gen_extends.py).

warnings = "-implicit_impl_as_method"

import {
  "gaato/http@0.3.1",
  "gaato/http-async@0.3.1",
  "gaato/sdk-runtime@0.5.0",
  "moonbitlang/async@0.22.5",
  "hustcer/ed25519@0.6.0",
  "moonbit-community/flate@0.9.0",
}
