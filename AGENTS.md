# Agent notes

## Documentation

- A module README (`<module>/README.md`, a link to the root package's
  `src/overview.mbt.md`) is for people deciding whether and how to use the
  module, because mooncakes.io renders it as the module page. Keep it to what
  a user needs: what the module is, install, a compiled usage example, the
  limits and requirements they must know, links, and the license. Put design
  rationale, internal mechanics, test or release procedures, and version pins
  in `docs/`, the changelog, or the guides, and link them absolutely: a
  relative link on mooncakes resolves to a raw file or a 404.
- Run `moon run scripts/docs_audit.mbtx --self-test` after changing docs or
  public declarations. CI runs it, and it catches the rules a reviewer
  misses (missing doc comments, relative links, README layout).
- `scripts/docs_audit.mbtx` here is the original that the other gaato
  MoonBit repositories copy byte-for-byte, so every module page is held to
  the same rules. A change to it must be copied to those repositories in the
  same round; keep repository-specific settings in `scripts/docs_audit.json`
  and `scripts/docs_audit.allow` instead of editing the script.
