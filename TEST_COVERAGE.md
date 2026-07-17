# Test coverage ledger

Line coverage of the library packages (`src/` minus `src/examples/`), measured
with `moon coverage analyze`. Companion to [COVERAGE.md](COVERAGE.md), which
tracks REST *endpoint* coverage; this file tracks *test* coverage and applies
the same closed-ledger rule:

> **Every uncovered line is either covered by a test or listed below with a
> reason.** `scripts/coverage_report.sh` enforces this: a file with uncovered
> lines must have a row here whose budget is at least the actual count, and
> the script fails otherwise. Rows for fully covered files are flagged as
> stale so budgets only ever shrink.

Run `scripts/coverage_report.sh` for the per-package table and the current
check result. On hosts where moon's bundled tcc cannot link (openSUSE), the
script already sets `MOON_CC=cc`.

## Policy

Must be covered by tests:

- pure logic: codecs, projections, query/body assembly, parsers, state
  machines behind trait seams (fakes exist for gateway and voice transports);
- every `raise` arm reachable through the public API;
- wire boundaries via `perform_override_` wbtests (exact method/path/body).

Accepted as uncovered (needs a ledger row):

- thin adapters over live sockets/websockets and extern/FFI glue — their
  behavior is exercised by the live probe sweeps recorded in COVERAGE.md and
  the live-probe run logs (run 11: 242 PASS / 0 FAIL, 2026-07-16);
- `abort(...)` arms that are unreachable by construction;
- example `main`s (excluded from the report entirely).

## Accepted uncovered

| File | Budget | Reason |
| --- | --- | --- |
| src/voice/transport.mbt | 41 | Thin adapter over a live websocket connection; verified live (voice join + soundboard, 2026-07-15). |

(The list grows/shrinks per batch; the report script is the source of truth
for what still needs a row.)
