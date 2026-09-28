# CDN documentation audit

From the repository root (fish syntax):

```fish
moon run scripts/docs_cdn_audit.mbtx ~/ghq/github.com/discord/discord-api-docs/developers/reference.mdx --self-test
```

The audit compares all CDN table names, normalized paths and supported formats
with a declared baseline, verifies each implemented builder exists, and rejects
missing/malformed tables and stale or unexplained exceptions. Actual URL
behavior is covered separately by the `src/util` tests. The three intentionally
unimplemented rows are documented in `docs_cdn_audit.allow`.

CI fetches Discord's documentation at the commit in `discord-docs-commit`, the
last docs commit whose changes the library was reviewed against. This keeps
pull-request checks reproducible. The daily `Discord docs watch` workflow
compares the latest docs with that baseline: it lists the docs commits since
it and runs this audit and `docs_shape_audit.py` against the latest docs, and
keeps one issue, "Review Discord docs changes", open while anything needs
review. After reviewing and following the listed changes, move
`discord-docs-commit` to the reviewed commit; the next run closes the issue.

# Public API surface audit

From the repository root, after `moon info`:

```fish
moon run scripts/api_surface_audit.mbtx --self-test
```

The audit reads the generated interfaces and enforces two rules. First, the
`gaato/discord` facade is closed: every type that a facade-exported type or
function mentions is exported by the facade too, so a bot that imports only
the facade and `@model` can name everything its golden path hands it. Second,
no public function takes two consecutive positional arguments of the same type
(resource ids aside), which callers could swap without a compile error.
Deliberate exceptions are listed in `api_surface_audit.allow`, one type
(`@pkg.Type`) or function (`positional @pkg.function`) per line with a reason,
so every new gap needs its own decision. Unknown or stale entries fail the
audit.

# Interaction message field audit

```fish
moon run scripts/docs_callback_audit.mbtx ~/ghq/github.com/discord/discord-api-docs --self-test
```

For each interaction message surface — the initial callback and updates
(Interaction Callback Data), followups (Execute Webhook), and edits (Edit
Webhook Message) — compares the documented parameters with the fields the
library sends, and checks that every claimed field still appears in the
functions that build that body. A field Discord adds or removes fails the
audit until the library follows it or `docs_callback_audit.allow` explains why
that surface does not send it. CI and the daily docs watch run it next to the
CDN audit.
