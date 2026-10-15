#!/usr/bin/env bash
# Publishes one module of this repository to mooncakes when its moon.mod
# version is not yet in the registry index. Idempotent, so it runs on every
# push to main and only a version bump releases anything.
#
# Usage: scripts/release.sh [--dry-run] MODULE_DIR
#   MODULE_DIR  the workspace member to publish, such as `discord` or `dave`
#   --dry-run   only package and verify
#
# The module is built outside the workspace (MOON_WORK=off), so it resolves
# every dependency from the registry as a consumer does.
#
# With GITHUB_TOKEN, GITHUB_REPOSITORY and RELEASE_SHA set (the release
# workflow sets them), a publish first tags RELEASE_SHA as
# `<MODULE_DIR>-v<version>`, or checks that an existing tag of that name
# already points there, so a retried release keeps its tag and a version is
# never tagged at two commits. Versions published before stay untagged.
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
  tag="$(basename "$module")-v$version"
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required for tagging}"
    : "${RELEASE_SHA:?RELEASE_SHA is required for tagging}"
    api="https://api.github.com/repos/$GITHUB_REPOSITORY/git"
    auth="Authorization: Bearer $GITHUB_TOKEN"
    # The first "sha" of a ref is the object it points to.
    existing=$(curl -fsS -H "$auth" "$api/ref/tags/$tag" 2>/dev/null |
      sed -nE 's/.*"sha"[[:space:]]*:[[:space:]]*"([0-9a-f]+)".*/\1/p' | head -n 1) || true
    if [ -z "$existing" ]; then
      curl -fsS -X POST -H "$auth" "$api/refs" \
        -d "{\"ref\":\"refs/tags/$tag\",\"sha\":\"$RELEASE_SHA\"}" >/dev/null
      echo "tag     $tag -> $RELEASE_SHA"
    elif [ "$existing" != "$RELEASE_SHA" ]; then
      echo "error: $tag already points to $existing, not $RELEASE_SHA" >&2
      exit 1
    fi
  else
    echo "note    not tagging $tag (no GITHUB_TOKEN)"
  fi
  echo "publish $name@$version"
  moon publish
fi
