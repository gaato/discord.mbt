# Scripts

Audits and release tooling for this repository. Run every command from the
repository root. The audits take deliberate exceptions from a matching
`.allow` file, one entry per line with a `#` reason; an unknown, stale, or
unexplained entry fails the audit. `--self-test` also checks that the audit
still rejects what it should. CI runs each audit with `--self-test`.

## Public API surface audit

```sh
moon info --target native
moon run scripts/api_surface_audit.mbtx --self-test
```

Reads the generated interfaces and source, and enforces three rules:

- The `gaato/discord` facade is closed: every type that a facade-exported type
  or function mentions is exported by the facade too, so a bot that imports
  only the facade and `@model` can name everything its golden path hands it.
- No public function takes two consecutive positional arguments of the same
  type (resource ids aside), which callers could swap without a compile error.
- No `pub using` block that re-exports two or more types has a `///` doc
  comment, because moon doc would show it in place of each type's own docs.

Exceptions in `api_surface_audit.allow` name a type (`@pkg.Type`) or a
function (`positional @pkg.function`).

## Clock guard

```sh
moon run scripts/clock_guard.mbtx --self-test
```

Library code waits and reads time through an injected `gaato/http/clock`
`Clock`, so tests can drive it with `VirtualClock` from `gaato/http-async/mock`
instead of sleeping. The guard scans the library sources of every module
(tests excluded) for real-time entry points: `@async.sleep`,
`@async.with_timeout(_opt)`, `@async.now`, `@async.retry` and its delays,
`@async.Timer`, `@env.now`, the internal `@clock.now_ms`, and
`AsyncClock::new`. A real clock as a labelled argument's default
(`clock~ : &@hclock.Clock = @transport.AsyncClock::new()`) is the injection
point and passes. Any other use needs one `<file> <function> <entry point>`
line in `clock_guard.allow` per use; today these are deadlines on live
sockets and the coordinator's TCP client.

## Docs audit

```sh
moon run scripts/docs_audit.mbtx --self-test
```

Checks the documentation rules shared by every gaato MoonBit repository:

- No code block is fenced as `fish`; commands are written for `sh`.
- Files inside the published module directories link only to absolute URLs,
  because mooncakes.io serves them away from the repository. Every other
  relative link names an existing file.
- Each published module has `readme = "README.md"`, and that README is a
  link to the root package's `overview.mbt.md`, so its examples compile. It
  has a title, an `## Install` section and a `## License` section. The root
  package has no `README.mbt.md` of its own, because mooncakes.io would show
  it after the module README.
- Every top-level `pub` declaration in a published package has a `///` doc
  comment, except in generated files (first line `DO NOT EDIT`).

The published modules and generated paths are in `docs_audit.json`. What a
module leaves out of its package comes from its `.moonignore`. Exceptions in
`docs_audit.allow` are `<file> <key>` lines with a ` #` reason. The script is
the same in every repository; change it everywhere at once.

## Discord documentation audits

These compare the library with
[discord/discord-api-docs](https://github.com/discord/discord-api-docs). Pass
the path of a checkout:

```sh
moon run scripts/docs_cdn_audit.mbtx <docs>/developers/reference.mdx --self-test
moon run scripts/docs_callback_audit.mbtx <docs> --self-test
scripts/docs_shape_audit.py <docs>
```

- `docs_cdn_audit.mbtx` compares every CDN table's names, normalized paths,
  and supported formats with a declared baseline, and verifies each
  implemented builder exists. URL behavior is tested separately in
  `discord/src/util`.
- `docs_callback_audit.mbtx` compares the documented parameters of each
  interaction message surface (the initial callback and updates, followups,
  and edits) with the fields the library sends, and checks that every
  claimed field still appears in the functions that build that body.
- `docs_shape_audit.py` matches every `discord/src/model` struct to its docs
  field table and fails on a field the docs mark optional (`name?`) or
  nullable (`?type`) that the model does not.

CI fetches the docs at the commit in `discord-docs-commit`, the last docs
commit the library was reviewed against, so pull-request checks are
reproducible. The daily `Discord docs watch` workflow runs the audits against
the latest docs, lists the docs commits since the baseline, and keeps one
issue, "Review Discord docs changes", open while anything needs review. After
following the listed changes, move `discord-docs-commit` to the reviewed
commit; the next run closes the issue.

## Generated `ToJson` extends

```sh
moon info --target native
scripts/gen_extends.py           # write
scripts/gen_extends.py --check   # CI: fail when a file is out of date
```

Writes the `pub extend T with ToJson::{to_json}` declarations that replace
the implicit promotion of trait methods, which moonc deprecates. Rerun it
after adding or removing a type that implements `ToJson`.

## Coverage ledger

```sh
scripts/coverage_report.sh
scripts/coverage_report.sh --from-json coverage.json   # reuse a report
```

Measures line coverage of the library packages and checks every uncovered
line against [`docs/test-coverage.md`](../docs/test-coverage.md). Native voice
tests need the pinned runtimes, so it is not part of CI; run it before
tagging a release.

## Release

```sh
scripts/release.sh --dry-run discord
```

Publishes one module to mooncakes unless its `moon.mod` version is already in
the registry, building it outside the workspace so it resolves its
dependencies as a consumer does. The release workflow runs it for a pushed
release tag; `--dry-run` only packages and verifies.
