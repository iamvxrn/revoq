#!/bin/sh
# Backfill GitHub Releases for deft's historical versions (pre-monorepo), so the
# Releases page shows a continuous history before v0.7.0.
#
# These are SOURCE-ONLY releases: their tags point at pre-monorepo commits that
# have no cli/ crate to build, so there are no prebuilt binaries (GitHub still
# attaches auto-generated "Source code" archives). Prebuilt binaries begin at
# v0.7.0, produced by .github/workflows/release.yml.
#
# Prerequisites:
#   - `gh` authenticated with push access to the repo
#   - the historical tags pushed first:
#       git push origin v0.3.0 v0.4.0 v0.5.0 v0.6.0
#   - run from the monorepo root (this script reads cli/CHANGELOG.md)
#
# Usage:
#   sh scripts/backfill-releases.sh

set -eu

REPO="${DEFT_REPO:-xntas/deft}"
CHANGELOG="cli/CHANGELOG.md"
VERSIONS="0.3.0 0.4.0 0.5.0 0.6.0"

command -v gh >/dev/null 2>&1 || { echo "error: gh (GitHub CLI) is required" >&2; exit 1; }
[ -f "$CHANGELOG" ] || { echo "error: run me from the monorepo root ($CHANGELOG not found)" >&2; exit 1; }

for ver in $VERSIONS; do
  tag="v$ver"

  if gh release view "$tag" --repo "$REPO" >/dev/null 2>&1; then
    echo "skip: release $tag already exists"
    continue
  fi

  # Pull this version's section out of the changelog (same extraction the
  # release workflow uses), then prepend a historical banner.
  notes="$(mktemp)"
  {
    echo "> Historical release, backfilled after the monorepo move. Source-only —"
    echo "> prebuilt binaries begin at v0.7.0."
    echo
    awk -v v="$ver" '
      $0 ~ "^## \\[" v "\\]" {flag=1; next}
      flag && /^## \[/ {exit}
      flag {print}
    ' "$CHANGELOG" | sed '/./,$!d'
  } > "$notes"

  echo "creating release $tag ..."
  gh release create "$tag" \
    --repo "$REPO" \
    --title "deft $ver" \
    --notes-file "$notes" \
    --verify-tag
  rm -f "$notes"
done

echo "done. Now tag and push v0.7.0 to cut the first release with binaries:"
echo "  git tag -a v0.7.0 -m 'deft 0.7.0' && git push origin v0.7.0"
