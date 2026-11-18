// Native tests of gaato/dave against the real libdave with a stand-in voice
// server. Not published: the workspace builds it against the gaato/dave in
// this repository, so its test-only dependency on a P-256 signer never
// reaches gaato/dave's users.
name = "local/dave_interop"

version = "0.0.0"

private = true

license = "Apache-2.0"

preferred_target = "native"

supported_targets = "native"

warnings = "-implicit_impl_as_method"

source = "src"

import {
  "gaato/dave@0.2.0",
  "moonbitstack/mooncrypt@0.5.2",
}
