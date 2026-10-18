// Examples of gaato/discord. Not published: the workspace builds them against
// the gaato/discord in this repository.
name = "local/discord_examples"

version = "0.0.0"

private = true

license = "Apache-2.0"

preferred_target = "native"

// Same promotion policy as gaato/discord: trait methods are called through
// explicit `pub extend` declarations only.

warnings = "-implicit_impl_as_method"

import {
  "gaato/sdk-runtime@0.5.0",
  "gaato/discord@0.10.0",
  "gaato/discord_voice@0.3.0",
  "moonbitlang/async@0.22.5",
}
