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

CI fetches data only from Discord's documentation at commit
`9ce0143eaadae072e19fb13627714a4a65895ff0`. This makes pull-request checks
reproducible; it does **not** continuously monitor Discord's latest changes.
Before a release, run against an up-to-date local docs checkout, review any
differences, update builders/tests/baseline as appropriate, then update the
pinned commit in CI and this file together.
