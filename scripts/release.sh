#!/usr/bin/env bash
# Publishes one module of this repository to mooncakes unless its moon.mod
# version is already in the registry index, so a rerun after a successful
# publish does nothing. The release workflow runs it for a pushed release tag.
#
# Usage: scripts/release.sh [--dry-run] MODULE_DIR
#   MODULE_DIR  the workspace member to publish, such as `discord` or `dave`
#   --dry-run   only package and verify
#
# The module is built outside the workspace (MOON_WORK=off), so it resolves
# every dependency from the registry as a consumer does.
set -euo pipefail
dry_run=false
if [ "${1:-}" = "--dry-run" ]; then
  dry_run=true
  shift
fi
module="${1:?usage: scripts/release.sh [--dry-run] MODULE_DIR}"
export MOON_WORK=off
cd "$(dirname "$0")/.."
cd "$module"
name=$(sed -nE 's/^name = "(.*)"$/\1/p' moon.mod)
version=$(sed -nE 's/^version = "(.*)"$/\1/p' moon.mod)
moon update >/dev/null
index="${MOON_HOME:-$HOME/.moon}/registry/index/user/$name.index"
if [ -f "$index" ] && grep -Eq "\"version\"[[:space:]]*:[[:space:]]*\"$version\"" "$index"; then
  echo "skip    $name@$version (already published)"; exit 0
fi
if $dry_run; then
  # `moon publish --dry-run` exits non-zero even when the server accepts it.
  out=$(moon publish --dry-run 2>&1) || true
  echo "$out" | grep -q 'Dry run completed successfully' || { echo "$out"; exit 1; }
  echo "would   $name@$version"
else
  echo "publish $name@$version"
  moon publish
fi
