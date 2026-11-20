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
- A module README is also read raw by coding agents in a user's
  `.mooncakes/`. They copy its examples, take every sentence literally, fill
  what it leaves out with guesses, and read the published text until the next
  release, while the modules it might mention change and get renamed.

## API changes

- When a published function's labelled parameter is renamed or removed, an
  optional one becomes required, or a positional one becomes labelled, keep
  existing calls compiling for one minor release with `#label_migration`
  (`alias=old`, `fill=false`, `fill=true` or `allow_positional=true`) and a
  `msg` naming the new form, and remove the attribute in the next minor
  release. Callers then get a warning instead of a build failure; the
  CHANGELOG still lists the change with its migration note. A renamed or
  removed function keeps a `#deprecated` alias for the same period.
