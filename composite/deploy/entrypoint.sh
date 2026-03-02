#!/usr/bin/env bash
# Don't use -l here; we want to preserve the PATH and other env vars 
# as set in the base image, and not have it overridden by a login shell

# ███╗   ███╗███████╗████████╗████████╗██╗     ███████╗ ██████╗██╗
# ████╗ ████║██╔════╝╚══██╔══╝╚══██╔══╝██║     ██╔════╝██╔════╝██║
# ██╔████╔██║█████╗     ██║      ██║   ██║     █████╗  ██║     ██║
# ██║╚██╔╝██║██╔══╝     ██║      ██║   ██║     ██╔══╝  ██║     ██║
# ██║ ╚═╝ ██║███████╗   ██║      ██║   ███████╗███████╗╚██████╗██║
# ╚═╝     ╚═╝╚══════╝   ╚═╝      ╚═╝   ╚══════╝╚══════╝ ╚═════╝╚═╝
# MettleCI DevOps for DataStage       (C) 2025-2026 Data Migrators
#                                      _ _
#   ___ ___  _ __ ___  _ __   ___  ___(_) |_ ___
#  / __/ _ \| '_ ` _ \| '_ \ / _ \/ __| | __/ _ \
# | (_| (_) | | | | | | |_) | (_) \__ \ | ||  __/
#  \___\___/|_| |_| |_| .__/ \___/|___/_|\__\___|
#      _            _ |_|
#   __| | ___ _ __ | | ___  _   _
#  / _` |/ _ \ '_ \| |/ _ \| | | |
# | (_| |  __/ |_) | | (_) | |_| |
#  \__,_|\___| .__/|_|\___/ \__, |
#            |_|            |___/

set -euo pipefail

# NOTES
# Composite actions don’t have a Docker 'entrypoint' the way other GitHub actions do. 
# Instead, the commands in the `runs` section of action.yml are executed directly 
# by the runner.  The `entrypoint.sh` in this context serves as an invocable utility 
# script which prepares and validates parameters and encapsulates any shared logic. 

# -----
# Setup
# -----
export MCIX_BIN_DIR="/usr/share/mcix/bin"
export MCIX_LOG_DIR="/usr/share/mcix"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$MCIX_BIN_DIR"

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"
workspace="${GITHUB_WORKSPACE:-$PWD}"

# -------------------
# Functions
# -------------------
die() { echo "ERROR: $*" >&2; exit 1; }

# Usage: require VAR_NAME "human label"
require() {
  local var_name="$1"
  local label="$2"
  local v="${!var_name-}"
  [[ -n "$v" ]] || die "Missing required input: ${label}"
}

# Resolve a path to an absolute path under the workspace, unless already absolute.
# - "" stays ""
# - "datastage"   -> /github/workspace/datastage
# - "./datastage" -> /github/workspace/datastage
# - "/tmp/x"      -> /tmp/x
# Usage: resolve_workspace_path PATH
resolve_workspace_path() {
  local p="${1:-}"
  [[ -n "$p" ]] || { echo ""; return; }
  case "$p" in
    /*) echo "$p" ;;
    *)  echo "${workspace}/${p#./}" ;;
  esac
}

# -------------------
# Validate parameters
# -------------------
require PARAM_API_KEY "api-key"
require PARAM_URL "url"
require PARAM_USER "user"
require PARAM_ASSETS "assets"
require PARAM_OVERLAYS "overlays"

# Project selection must be exactly one of these
PARAM_PROJECT="${PARAM_PROJECT-}"
PARAM_PROJECT_ID="${PARAM_PROJECT_ID-}"

if [[ -n "$PARAM_PROJECT" && -n "$PARAM_PROJECT_ID" ]]; then
  die "Inputs 'project' and 'project-id' are mutually exclusive; set only one."
fi
if [[ -z "$PARAM_PROJECT" && -z "$PARAM_PROJECT_ID" ]]; then
  die "One of 'project' or 'project-id' must be set."
fi

# Optional inputs
PARAM_PROPERTIES="${PARAM_PROPERTIES-}"
PARAM_OUTPUT="${PARAM_OUTPUT-}"
PARAM_REPORT="${PARAM_REPORT-}"
PARAM_INCLUDE_ASSET_IN_TEST_NAME="${PARAM_INCLUDE_ASSET_IN_TEST_NAME-}"


# -------------------
# Normalize paths
# -------------------
assets_abs="$(resolve_workspace_path "$PARAM_ASSETS")"
# We don't normalize $PARAM_OVERLAYS as it's a comma- or newline-separated list of paths, 
# and we want to preserve the original formatting for the overlay/apply action.

# If properties is intended to be a file path, normalize it too.
# If you allow inline properties content, keep it as-is instead.
properties_abs="$(resolve_workspace_path "$PARAM_PROPERTIES")"

if [[ -n "$PARAM_OUTPUT" ]]; then
  overlay_output_abs="$(resolve_workspace_path "$PARAM_OUTPUT")"
else
  overlay_output_abs="${workspace}/assets-overlay.zip"
fi

report_abs="$(resolve_workspace_path "$PARAM_REPORT")"
if [[ -n "$report_abs" ]]; then
  mkdir -p "$(dirname "$report_abs")"
fi

# -------------------
# Generate outputs
# -------------------
{
  # Shared (import + compile)
  printf 'api_key=%s\n' "$PARAM_API_KEY"
  printf 'url=%s\n' "$PARAM_URL"
  printf 'user=%s\n' "$PARAM_USER"

  # Target project selection (import + compile)
  printf 'project=%s\n' "$PARAM_PROJECT"
  printf 'project_id=%s\n' "$PARAM_PROJECT_ID"

  # Assets + overlay
  printf 'assets=%s\n' "$assets_abs"
  printf 'overlays=%s\n' "$PARAM_OVERLAYS"
  printf 'properties=%s\n' "$properties_abs"

  # Where to write overlaid assets (passed to overlay/apply; then imported)
  printf 'overlay_output=%s\n' "$overlay_output_abs"

  # Compile report options
  printf 'report=%s\n' "$report_abs"
  printf 'compile_include_asset_in_test_name=%s\n' "$PARAM_INCLUDE_ASSET_IN_TEST_NAME"
} >>"$GITHUB_OUTPUT"