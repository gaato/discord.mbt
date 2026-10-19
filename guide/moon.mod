// The gaato/discord guide: each chapter's `mbt check` blocks compile and run
// under `moon test --target native`. Not published; the workspace builds it
// against the gaato/discord in this repository.
name = "local/discord_guide"

version = "0.0.0"

private = true

license = "Apache-2.0"

preferred_target = "native"

warnings = "-implicit_impl_as_method"

import {
  "gaato/discord@0.11.0",
  "gaato/discord_voice@0.3.0",
  "gaato/sdk-runtime@0.5.0",
  "moonbitlang/async@0.22.5",
}
