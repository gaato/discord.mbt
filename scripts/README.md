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
