#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/release.sh            # bump patch
#   ./scripts/release.sh patch      # bump patch
#   ./scripts/release.sh minor      # bump minor
#   ./scripts/release.sh major      # bump major
#   ./scripts/release.sh v1.2.3     # tag exactly v1.2.3

BUMP="${1:-patch}"

REMOTE="${REMOTE:-origin}"

die() { echo "ERROR: $*" >&2; exit 1; }

# Ensure we're in a git repo
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not in a git repository"

# Ensure we have up-to-date tags
git fetch --tags "$REMOTE" >/dev/null 2>&1 || true

latest_tag="$(git tag -l 'v*.*.*' --sort=-v:refname | head -n 1 || true)"
latest_tag="${latest_tag:-v0.0.0}"

parse_ver() {
  local t="$1"
  t="${t#v}"
  IFS='.' read -r major minor patch <<<"$t"
  echo "${major:-0} ${minor:-0} ${patch:-0}"
}

make_ver() {
  local major="$1" minor="$2" patch="$3"
  echo "v${major}.${minor}.${patch}"
}

if [[ "$BUMP" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  new_tag="$BUMP"
else
  read -r major minor patch < <(parse_ver "$latest_tag")

  case "$BUMP" in
    patch) patch=$((patch + 1)) ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    major) major=$((major + 1)); minor=0; patch=0 ;;
    *)
      die "Unknown bump '$BUMP' (use major|minor|patch or an explicit vX.Y.Z)"
      ;;
  esac

  new_tag="$(make_ver "$major" "$minor" "$patch")"
fi

# Make sure tag doesn't already exist
if git rev-parse "$new_tag" >/dev/null 2>&1; then
  die "Tag already exists: $new_tag"
fi

# Create annotated tag and push it
git tag -a "$new_tag" -m "Release $new_tag"
git push "$REMOTE" "$new_tag"

# Print helpful links
repo="$(git config --get remote.${REMOTE}.url | sed -E 's#^git@github.com:([^/]+/[^.]+)\.git$#\1#; s#^https://github.com/([^/]+/[^.]+)(\.git)?$#\1#')"
if [[ "$repo" =~ ^[^/]+/[^/]+$ ]]; then
  echo ""
  echo "Triggered workflow for tag $new_tag"
  echo "Actions: https://github.com/${repo}/actions"
  echo "Tag:     https://github.com/${repo}/releases/tag/${new_tag}"
else
  echo ""
  echo "Pushed tag $new_tag (could not parse repo URL for links)"
fi
