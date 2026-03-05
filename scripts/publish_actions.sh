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

# -------------------
# Setup
# -------------------
OWNER="${OWNER:-mettleci}"
TAG="${TAG:?TAG must be set (e.g. v1.2.3)}"
CREATE_RELEASES="${CREATE_RELEASES:-true}"

# Derive major tag (v1 from v1.2.3)
MAJOR="v${TAG#v}"
MAJOR="${MAJOR%%.*}"

# Redundant for now. We set per-repo homepages, but this might be useful in the future.
HOMEPAGE="https://mcix.mettleci.com"    

actions=(
  'asset-analysis/test:mcix-asset-analysis-test:["github-actions","mcix","asset-analysis"]'
  'composite/deploy:mcix-composite-deploy:["github-actions","mcix","composite"]'
  'datastage/compile:mcix-datastage-compile:["github-actions","mcix","datastage","compile"]'
  'datastage/import:mcix-datastage-import:["github-actions","mcix","datastage","import"]'
  'overlay/apply:mcix-overlay-apply:["github-actions","mcix","overlay"]'
  'system/version:mcix-system-version:["github-actions","mcix","system"]'
  'unit-test/execute:mcix-unit-test-execute:["github-actions","mcix","unit-test"]'
)

: "${GH_TOKEN:?GH_TOKEN is not set. Did you forget secrets.PUSH_MARKETPLACE_REPO_PAT?}"

# -------------------
# Functions
# -------------------
die() { echo "ERROR: $*" >&2; exit 1; }

# Validate required files exist in subtree
validate_subtree_files() {
  echo "Validating required files in $1..."
  local path="$1"
  [[ -f "$path/action.yml" ]] || die "Missing $path/action.yml"
  [[ -f "$path/Dockerfile" ]] || die "Missing $path/Dockerfile"
  [[ -f "$path/README.md" ]]  || die "Missing $path/README.md"
}

# Fail fast if action.yml references non-root Dockerfile paths
# Rules:
# - If using: docker (which we are) then...
#   - allow: image: Dockerfile
#   - allow: image: ./Dockerfile
#   - allow: image: docker://<image>
#   - disallow: local image reference containing '/' (e.g. ./datastage/compile/Dockerfile)
validate_action_yml_docker_image_path() {
  echo "Validating Docker image path in $1..."
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
  echo "Ensuring repo exists: $1..."
  local full="$1"

  if gh repo view "$full" >/dev/null 2>&1; then
    echo "Repo exists: $full"
    return 0
  fi

  if gh repo create "$full" --public; then
    echo "Created repo: $full"
  else
    return 1
  fi
}

set_repo_about() {
  local full="$1"         # owner/repo
  local desc="$2"         # repo description
  local homepage="$3"     # website/homepage URL (can be empty)
  local topics_json="$4"  # JSON array string, e.g. ["github-actions","mcix"]

  echo "Setting About metadata for ${full}..."

  # Description + Website (homepage)
  gh api -X PATCH "repos/${full}" \
    -H "Accept: application/vnd.github+json" \
    -f description="$desc" \
    -f homepage="$homepage" >/dev/null

  # Topics (replaces the entire topic set)
  # NOTE: This endpoint expects {"names":[...]}.
  gh api -X PUT "repos/${full}/topics" \
    -H "Accept: application/vnd.github+json" \
  --input - <<EOF >/dev/null
{"names": $topics_json}
EOF
}

push_split_to_repo() {
  echo "Pushing subtree $1 to repo $2 (tags: $TAG, $MAJOR)..."
  local path="$1"
  local full="$2"
  local repo="$3"

  local split_branch="split/${repo}"
  git subtree split --prefix="$path" -b "$split_branch"

  local remote="https://x-access-token:${GH_TOKEN}@github.com/${full}.git"

  # DIAGNOSTIC START
  # Sanity check: confirm GH_TOKEN is set and can see the repo
  [[ -n "${GH_TOKEN:-}" ]] || die "GH_TOKEN is empty (secret not passed?)"

  echo "PAT identity:"
  gh api user --jq '.login'

  echo "Checking remote access to ${full}..."
  git ls-remote "https://x-access-token:${GH_TOKEN}@github.com/${full}.git" HEAD

  git -c "http.extraHeader=AUTHORIZATION: basic $(printf 'x-access-token:%s' "$GH_TOKEN" | base64 -w0)" \
    ls-remote "https://github.com/${full}.git" HEAD >/dev/null \
    || die "PAT cannot access ${full} (wrong scopes, SSO not authorized, or no repo access)"
  # DIAGNOSTIC END

  # Force main to match the split output (idempotent)
  git push "$remote" "$split_branch:main" --force

  # Push immutable tag TAG (delete then recreate to keep idempotent; you can remove deletes if you want immutability)
  git push "$remote" ":refs/tags/$TAG" >/dev/null 2>&1 || true
  git push "$remote" "$split_branch:refs/tags/$TAG"

  # Push moving major tag (force update)
  git push "$remote" ":refs/tags/$MAJOR" >/dev/null 2>&1 || true
  git push "$remote" "$split_branch:refs/tags/$MAJOR" --force

  gh_notice "Repository published" \
    "${full} updated from '${path}' (tag ${TAG})"

  git branch -D "$split_branch"
}

create_release_if_missing() {
  echo "Ensuring release exists for $1@$TAG..."
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

gh_notice() {
  local title="$1"
  local message="$2"

  # Minimal escaping for workflow commands
  message="${message//'%'/'%25'}"
  message="${message//$'\r'/'%0D'}"
  message="${message//$'\n'/'%0A'}"

  echo "::notice title=${title}::${message}"
}

gh_error() {
  local title="$1" message="$2"
  message="${message//'%'/'%25'}"
  message="${message//$'\r'/'%0D'}"
  message="${message//$'\n'/'%0A'}"
  echo "::error title=${title}::${message}"
}
summary_append() {
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] || return 0
  printf '%s\n' "$*" >>"$GITHUB_STEP_SUMMARY"
}

summary_repo_line() {
  local full="$1" path="$2"
  local url="https://github.com/${full}"
  summary_append "- **${full}** ← \`${path}\`  (${url})"
}

# Extract a single-line top-level YAML scalar (e.g. name: ..., description: ...)
yaml_top_scalar() {
  local key="$1"
  local file="$2"

  # Match "key: value" at column 0 (allow spaces). Ignore commented lines.
  # Trim surrounding quotes (single or double) if present.
  local line val
  line="$(grep -E "^[[:space:]]*${key}:[[:space:]]*" "$file" \
        | grep -Ev '^[[:space:]]*#' \
        | head -n 1 || true)"
  [ -n "$line" ] || return 1

  val="${line#*:}"
  val="${val#"${val%%[![:space:]]*}"}"   # ltrim
  val="${val%"${val##*[![:space:]]}"}"   # rtrim

  # Strip one layer of matching quotes
  if [[ "$val" == \"*\" && "$val" == *\" ]]; then
    val="${val#\"}"; val="${val%\"}"
  elif [[ "$val" == \'*\' && "$val" == *\' ]]; then
    val="${val#\'}"; val="${val%\'}"
  fi

  [ -n "$val" ] || return 1
  printf '%s' "$val"
}

derive_about_desc() {
  local path="$1"
  local action_yml="${path}/action.yml"

  local name desc
  name="$(yaml_top_scalar name "$action_yml" 2>/dev/null || true)"
  desc="$(yaml_top_scalar description "$action_yml" 2>/dev/null || true)"

  if [ -n "$name" ] && [ -n "$desc" ]; then
    printf '%s — %s' "$name" "$desc"
  elif [ -n "$name" ]; then
    printf '%s' "$name"
  elif [ -n "$desc" ]; then
    printf '%s' "$desc"
  else
    printf 'GitHub Action published from monorepo path: %s' "$path"
  fi
}

repo_homepage() {
  local repo="$1"  # e.g. mcix-datastage-compile
  printf 'https://%s.mettleci.io' "$repo"
}

# -------------------
# Main
# -------------------
main() {
  echo "Starting action publishing process for tag $TAG (major: $MAJOR)..."
summary_append "## Published action repositories (${TAG})"
  summary_append ""

  git config user.name  "github-actions[bot]"
  git config user.email "github-actions[bot]@users.noreply.github.com"

  for item in "${actions[@]}"; do
    IFS=':' read -r path repo topics_json <<<"$item"

    full="${OWNER}/${repo}"

    echo ""
    echo "==> Publishing ${full} from ${path}"

    repo_url="https://github.com/${full}"

    gh_notice "Publishing GitHub Marketplace repo" \
      "${full}  ←  ${path}\n${repo_url}"
    summary_repo_line "$full" "$path"

    validate_subtree_files "$path"
    validate_action_yml_docker_image_path "$path/action.yml"

    about_desc="$(derive_about_desc "$path") (from ${path})"

    if ! create_repo_if_missing "$full" "$about_desc"; then
      gh_error "Failed ensuring repository exists" \
        "Failed to publish ${full} from monorepo path '${path}'.\nRepository: ${repo_url}\nWorkflow run: ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
      exit 1
    else
      echo "Repository ready: ${full}"
      gh_notice "Published action repository" \
      "${full} successfully updated from '${path}' (tag ${TAG})"
    fi

    homepage="$(repo_homepage "$repo")"
    set_repo_about "$full" "$about_desc" "$homepage" "$topics_json"

    if ! push_split_to_repo "$path" "$full" "$repo"; then
      gh_error "Failed publishing repository" \
      "Failed to publish ${full}. 
      Source path: ${path}
      Tag: ${TAG}
      Repository: ${repo_url}
      Run: ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
      exit 1
    fi

    if [[ "$CREATE_RELEASES" == "true" ]]; then
      create_release_if_missing "$full" "$repo"
    else
      echo "CREATE_RELEASES=false; skipping release creation"
    fi
  done
}

main "$@"