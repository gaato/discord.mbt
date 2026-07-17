#!/usr/bin/env bash
# Library test-coverage report for discord.mbt.
#
# Runs `moon coverage analyze -- -f summary`, restricts the result to library
# packages (src/ minus src/examples/), prints a per-package table, and checks
# every remaining uncovered file against the TEST_COVERAGE.md ledger: a file
# with uncovered lines must have a ledger row whose budget covers them.
#
# Usage: scripts/coverage_report.sh [--from-summary FILE]
#   --from-summary FILE  reuse an existing `-f summary` output instead of
#                        re-running the (slow) instrumented test suite.
#
# Exit status: 0 = every uncovered line is ledgered, 1 = unexplained coverage
# gaps or over-budget files, 2 = setup/run failure.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
ledger="$repo_root/TEST_COVERAGE.md"
summary_file=""

if [[ "${1:-}" == "--from-summary" ]]; then
  summary_file="${2:?--from-summary needs a file}"
else
  summary_file="$(mktemp)"
  trap 'rm -f "$summary_file"' EXIT
  # moon's bundled tcc cannot link on some hosts (openSUSE); use the system cc.
  (cd "$repo_root" && MOON_CC="${MOON_CC:-cc}" moon coverage analyze -- -f summary) \
    > "$summary_file" 2>/dev/null || {
      echo "error: moon coverage analyze failed" >&2
      exit 2
    }
fi

awk -v ledger="$ledger" '
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

  # ---- summary lines: "path: covered/total" ------------------------------
  /^src\// {
    split($0, halves, ": ")
    file = halves[1]
    if (file ~ /^src\/examples\//) next
    split(halves[2], nums, "/")
    cov = nums[1] + 0; tot = nums[2] + 0
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
' "$summary_file"
