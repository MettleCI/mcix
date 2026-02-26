#!/usr/bin/env bash

# This is a tag-triggered, idempotent publisher workflow that:
# - creates the action repos if missing
# - validates each action subtree contains action.yml, Dockerfile, README.md
# - fails fast if action.yml’s Docker runs.image references a non-root path
# - splits & force-pushes each subtree to the action repo’s main
# - pushes tags (vX.Y.Z and moving v1)
# - optionally creates a GitHub Release per repo/tag (skips if it already exists)
# 
# It assumes:
# - The organisation for publishing customer-facing materials is 'mettleci'
# - Our monorepo workflow runs on vn.n.n tags (like v1.2.3)
# - We provide a PAT in secrets.PUSH_MARKETPLACE_REPO_PAT that can create repos in 
#   the org and push contents/tags, and create releases.

set -euo pipefail

OWNER="${OWNER:-mettleci}"
TAG="${TAG:?TAG must be set (e.g. v1.2.3)}"
CREATE_RELEASES="${CREATE_RELEASES:-true}"

# Derive major tag (v1 from v1.2.3)
MAJOR="v${TAG#v}"
MAJOR="v${MAJOR%%.*}"

actions=(
  "asset-analysis/test:mcix-asset-analysis-test"
  "composite/deploy:mcix-composite-deploy"
  "datastage/compile:mcix-datastage-compile"
  "datastage/import:mcix-datastage-import"
  "overlay/apply:mcix-overlay-apply"
  "system/version:mcix-system-version"
  "unit-test/execute:mcix-unit-test-execute"
)

die() { echo "ERROR: $*" >&2; exit 1; }

# Validate required files exist in subtree
validate_subtree_files() {
  local path="$1"
  [[ -f "$path/action.yml" ]] || die "Missing $path/action.yml"
  [[ -f "$path/Dockerfile" ]] || die "Missing $path/Dockerfile"
  [[ -f "$path/README.md" ]]  || die "Missing $path/README.md"
}

# Fail fast if action.yml references non-root Dockerfile paths
# Rules:
# - If using: docker
#   - allow: image: Dockerfile
#   - allow: image: ./Dockerfile
#   - allow: image: docker://<image>
#   - disallow: image value containing '/' (e.g. ./datastage/compile/Dockerfile)
validate_action_yml_docker_image_path() {
  local action_yml="$1"

  if ! grep -Eq '^[[:space:]]*using:[[:space:]]*docker[[:space:]]*$' "$action_yml"; then
    # Not a docker action (could be composite, node, etc.). Skip this check.
    return 0
  fi

  # Grab the first "image:" line under runs: (simple heuristic; works for typical action.yml)
  local image_line
  image_line="$(grep -E '^[[:space:]]*image:[[:space:]]*' "$action_yml" | head -n 1 || true)"
  [[ -n "$image_line" ]] || die "$action_yml: docker action but no runs.image found"

  # Extract value after "image:"
  local image_val
  image_val="$(echo "$image_line" | sed -E 's/^[[:space:]]*image:[[:space:]]*//')"
  # Trim quotes if present
  image_val="${image_val%\"}"; image_val="${image_val#\"}"
  image_val="${image_val%\'}"; image_val="${image_val#\'}"
  # Trim trailing comments
  image_val="$(echo "$image_val" | sed -E 's/[[:space:]]+#.*$//')"

  # Allow docker:// images
  if [[ "$image_val" =~ ^docker:// ]]; then
    return 0
  fi

  # Allow Dockerfile or ./Dockerfile (root)
  if [[ "$image_val" == "Dockerfile" || "$image_val" == "./Dockerfile" ]]; then
    return 0
  fi

  # Disallow path separators (non-root references)
  if [[ "$image_val" == *"/"* ]]; then
    die "$action_yml: runs.image references a non-root path: '$image_val' (expected 'Dockerfile' or 'docker://...')"
  fi

  # Anything else is suspicious; fail to be safe
  die "$action_yml: runs.image value '$image_val' is not allowed by policy (expected 'Dockerfile' or 'docker://...')"
}

create_repo_if_missing() {
  local full="$1"
  local desc="$2"

  if gh repo view "$full" >/dev/null 2>&1; then
    echo "Repo exists: $full"
  else
    gh repo create "$full" --public --description "$desc"
    echo "Created repo: $full"
  fi
}

push_split_to_repo() {
  local path="$1"
  local full="$2"
  local repo="$3"

  local split_branch="split/${repo}"
  git subtree split --prefix="$path" -b "$split_branch"

  local remote="https://x-access-token:${GH_TOKEN}@github.com/${full}.git"

  # Force main to match the split output (idempotent)
  git push "$remote" "$split_branch:main" --force

  # Push immutable tag TAG (delete then recreate to keep idempotent; you can remove deletes if you want immutability)
  git push "$remote" ":refs/tags/$TAG" >/dev/null 2>&1 || true
  git push "$remote" "$split_branch:refs/tags/$TAG"

  # Push moving major tag (force update)
  git push "$remote" ":refs/tags/$MAJOR" >/dev/null 2>&1 || true
  git push "$remote" "$split_branch:refs/tags/$MAJOR" --force

  git branch -D "$split_branch"
}

create_release_if_missing() {
  local full="$1"
  local repo="$2"

  # Idempotent: if release exists, skip
  if gh release view "$TAG" --repo "$full" >/dev/null 2>&1; then
    echo "Release exists: $full@$TAG (skipping)"
    return 0
  fi

  # Use generated notes to keep it hands-off
  gh release create "$TAG" \
    --repo "$full" \
    --title "${repo} ${TAG}" \
    --generate-notes

  echo "Created release: $full@$TAG"
}

main() {
  git config user.name  "github-actions[bot]"
  git config user.email "github-actions[bot]@users.noreply.github.com"

  for item in "${actions[@]}"; do
    local path="${item%%:*}"
    local repo="${item##*:}"
    local full="${OWNER}/${repo}"

    echo ""
    echo "==> Publishing ${full} from ${path}"

    validate_subtree_files "$path"
    validate_action_yml_docker_image_path "$path/action.yml"

    create_repo_if_missing "$full" "GitHub Action published from monorepo path: ${path}"
    push_split_to_repo "$path" "$full" "$repo"

    if [[ "$CREATE_RELEASES" == "true" ]]; then
      create_release_if_missing "$full" "$repo"
    else
      echo "CREATE_RELEASES=false; skipping release creation"
    fi
  done
}

main "$@"