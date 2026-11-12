name = "gaato/discord_voice"

version = "0.6.0"

readme = "README.md"

repository = "https://github.com/gaato/discord.mbt"

license = "Apache-2.0"

keywords = [ "discord", "voice", "dave", "opus", "native" ]

description = "Experimental Discord voice for gaato/discord bots on MoonBit's native backend: voice gateway v8, Opus playback and receive, DAVE E2EE."

source = "src"

preferred_target = "native"

supported_targets = "native"

// Same promotion policy as gaato/discord: dot-callable trait methods are
// declared with `pub extend` (scripts/gen_extends.py).

warnings = "-implicit_impl_as_method"

import {
  "gaato/discord@0.17.0",
  "gaato/dave@0.1.1",
  "gaato/mttp_core@0.1.0",
  "gaato/mttp@0.3.0",
}

options(
  "--moonbit-unstable-prebuild": "build.js",
)
