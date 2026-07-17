#!/usr/bin/env bash
# Library test-coverage report for discord.mbt.
#
# Runs `moon coverage analyze` in Coveralls-JSON mode (the `summary` format
# silently omits fully covered files, which skews package totals), restricts
# the result to library packages (src/ minus src/examples/), prints a
# per-package table, and checks every remaining uncovered file against the
# TEST_COVERAGE.md ledger: a file with uncovered lines must have a ledger row
# whose budget covers them.
#
# Usage: scripts/coverage_report.sh [--from-json FILE]
#   --from-json FILE  reuse an existing Coveralls JSON report instead of
#                     re-running the (slow) instrumented test suite.
#
# Exit status: 0 = every uncovered line is ledgered, 1 = unexplained coverage
# gaps or over-budget files, 2 = setup/run failure.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
ledger="$repo_root/TEST_COVERAGE.md"
json_file=""

if [[ "${1:-}" == "--from-json" ]]; then
  json_file="${2:?--from-json needs a file}"
else
  json_file="$repo_root/_build/coverage_report.json"
  # The DAVE/AEAD tests skip themselves when the voice shim is not loadable,
  # which silently under-reports src/voice coverage. Point the loader at the
  # in-tree build when present.
  shim="$repo_root/voice-shim/target/release/libdiscord_voice_shim.so"
  if [[ -z "${DISCORD_VOICE_SHIM_PATH:-}" && -f "$shim" ]]; then
    export DISCORD_VOICE_SHIM_PATH="$shim"
  fi
  # moon_cove_report merges every counter/trace file it finds under the
  # working directory, so counters left by earlier runs and trace maps from
  # the release profile silently corrupt the numbers (the analyze run itself
  # builds the debug profile). Do not delete debug .trace.source files — the
  # incremental build will not regenerate them.
  find "$repo_root/_build" -name 'moonbit_coverage_*' -delete 2>/dev/null || true
  find "$repo_root/_build/native/release" "$repo_root/_build/js" \
    -name '*.trace.source' -delete 2>/dev/null || true
  # moon's bundled tcc cannot link on some hosts (openSUSE); use the system cc.
  (cd "$repo_root" &&
    MOON_CC="${MOON_CC:-cc}" moon coverage analyze -- -f coveralls -o "$json_file") \
    >/dev/null 2>&1 || {
      echo "error: moon coverage analyze failed" >&2
      exit 2
    }
fi

# One "file<TAB>covered<TAB>total" line per library source file.
jq -r '
  .source_files[]
  | select(.name | startswith("src/"))
  | select(.name | startswith("src/examples/") | not)
  | [ .name,
      ([.coverage[] | select(. != null and . > 0)] | length),
      ([.coverage[] | select(. != null)] | length) ]
  | @tsv
' "$json_file" | awk -F '\t' -v ledger="$ledger" '
  # ---- ledger: rows like "| src/foo/bar.mbt | 12 | reason |" -------------
  BEGIN {
    while ((getline line < ledger) > 0) {
      if (line !~ /^\| *src\//) continue
      split(line, cell, /\|/)
      file = cell[2]; gsub(/^ +| +$/, "", file)
      budget_str = cell[3]; gsub(/^ +| +$/, "", budget_str)
      if (budget_str + 0 == budget_str) budget[file] = budget_str + 0
    }
    close(ledger)
  }

  {
    file = $1; cov = $2 + 0; tot = $3 + 0
    if (tot == 0) next   # declaration-only files have no executable points
    pkg = file; sub(/\/[^\/]*$/, "", pkg)
    pcov[pkg] += cov; ptot[pkg] += tot
    lcov += cov; ltot += tot
    unc = tot - cov
    if (unc > 0) uncovered[file] = unc
    seen[file] = 1
  }

  END {
    printf "%-28s %10s %8s\n", "package", "covered", "%"
    n = asorti(pcov, keys)
    for (i = 1; i <= n; i++) {
      p = keys[i]
      printf "%-28s %5d/%-5d %7.1f%%\n", p, pcov[p], ptot[p], 100 * pcov[p] / ptot[p]
    }
    printf "%-28s %5d/%-5d %7.1f%%\n", "TOTAL (library)", lcov, ltot, 100 * lcov / ltot
    print ""

    bad = 0
    for (f in uncovered) {
      if (!(f in budget))
        { printf "UNEXPLAINED  %-44s %4d uncovered (no ledger row)\n", f, uncovered[f]; bad = 1 }
      else if (uncovered[f] > budget[f])
        { printf "OVER BUDGET  %-44s %4d uncovered > budget %d\n", f, uncovered[f], budget[f]; bad = 1 }
    }
    for (f in budget) {
      if (!(f in seen))
        printf "STALE LEDGER %-44s file not in coverage output\n", f
      else if (!(f in uncovered))
        printf "STALE LEDGER %-44s fully covered; drop the row\n", f
      else if (uncovered[f] < budget[f])
        printf "note: budget slack %-33s %4d uncovered < budget %d\n", f, uncovered[f], budget[f]
    }
    if (bad) { print "\nledger check: FAIL"; exit 1 }
    print "ledger check: OK — every uncovered line is ledgered"
  }
'
