#!/usr/bin/env bash
# Publishes gaato/discord to mooncakes when moon.mod's version is not yet in
# the registry index. Idempotent, so it runs on every push to main and only a
# version bump releases anything. Pass --dry-run to only package and verify.
set -euo pipefail
cd "$(dirname "$0")/.."
name=$(sed -nE 's/^name = "(.*)"$/\1/p' moon.mod)
version=$(sed -nE 's/^version = "(.*)"$/\1/p' moon.mod)
moon update >/dev/null
index="${MOON_HOME:-$HOME/.moon}/registry/index/user/$name.index"
if [ -f "$index" ] && grep -Eq "\"version\"[[:space:]]*:[[:space:]]*\"$version\"" "$index"; then
  echo "skip    $name@$version (already published)"; exit 0
fi
if [ "${1:-}" = "--dry-run" ]; then
  # `moon publish --dry-run` exits non-zero even when the server accepts it.
  out=$(moon publish --dry-run 2>&1) || true
  echo "$out" | grep -q 'Dry run completed successfully' || { echo "$out"; exit 1; }
  echo "would   $name@$version"
else
  echo "publish $name@$version"
  moon publish
fi
