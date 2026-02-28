#!/usr/bin/sh
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

set -eu

# NOTES
# Composite actions don’t have a Docker 'entrypoint' the way other GitHub actions do. 
# Instead, the commands in the `runs` section of action.yml are executed directly 
# by the runner.  The `entrypoint.sh` in this context serves as an invocable utility 
# script which prepares and validates parameters and encapsulates any shared logic.
#
# This composite action has only one output:
# overlay_assets
#    A normalized version of the overlay_output - the path to the processed 
#    assets file created by the overlay/apply action.

# -----
# Setup
# -----
export MCIX_BIN_DIR="/usr/share/mcix/bin"
export MCIX_LOG_DIR="/usr/share/mcix"
# Make us immune to runner differences or potential base-image changes
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$MCIX_BIN_DIR"

# Verify and store GitHub environment values
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"
workspace="${GITHUB_WORKSPACE:-$PWD}"

# -------------------
# Functions
# -------------------

# Required arguments
# Usage: 
#   require PARAM_API_KEY "api-key"
require() {
    # $1 = var name, $2 = human label (for error)
    eval "v=\${$1-}"
    if [ -z "$v" ]; then
        die "Missing required input: $2"
    fi
}

# If a path is relative, anchor it under the workspace
anchor_path() {
  local p="${1:-}"
  if [[ -z "$p" ]]; then
    echo ""
  elif [[ "$p" = /* ]]; then
    echo "$p"
  else
    echo "${workspace}/${p#./}"
  fi
}

# Resolve a path to an absolute path under the workspace, unless already absolute.
# - "" stays ""
# - "datastage"   -> /github/workspace/datastage
# - "./datastage" -> /github/workspace/datastage
# - "/tmp/x"      -> /tmp/x
# Usage: 
#   resolve_workspace_path <path>
resolve_workspace_path() {
    p="${1:-}"
    [ -z "$p" ] && { echo ""; return; }
    
    case "$p" in
        /*) echo "$p" ;;
        *)  base="${GITHUB_WORKSPACE:-/github/workspace}"
        echo "${base}/${p#./}" ;;
    esac
}

# -------------------
# Validate parameters
# -------------------

# These are validated in the individual actions, but there's no harm in failing fast if
# they're not set at all, or if the mutually exclusive project/project-id are both set.
require PARAM_API_KEY "api-key"
require PARAM_URL "url"
require PARAM_USER "user"
require PARAM_ASSETS "assets"
require PARAM_OVERLAY "overlay"

# Add some special "if-null" processing for this one 
# require PARAM_REPORT "report"

# Ensure PARAM_REPORT will always be /github/workspace/...
report_abs="$(resolve_workspace_path "$PARAM_REPORT")"
mkdir -p "$(dirname "$report_abs")"

# Default overlay output if not provided
if [[ -z "$PARAM_OVERLAY" ]]; then
  overlay_output_abs="${workspace}/assets-overlay.zip"
fi


# -------------------
# Generate outputs
# -------------------
# Provide all inputs as outputs so that downstream steps can consume them as needed.
# This centralizes any validation and normalization logic required of the composite action's 
# downstream steps here in the entrypoint.
# Note that we still rely on the logic and validation in the downstream steps, but this gives 
# us a single source of truth for the composite action's parameters and any required normalization.
{
  # Shared (import + compile)
  echo "api_key=$PARAM_API_KEY"
  echo "url=$PARAM_URL"
  echo "user=$PARAM_USER"

  # Target project selection (import + compile)
  echo "project=$PARAM_PROJECT"
  echo "project_id=$PARAM_PROJECT_ID"

  # Assets + overlay
  echo "assets=$overlay_output_abs"
  echo "overlay=$PARAM_OVERLAY"
  echo "properties=$PARAM_PROPERTIES"

  # Where to write overlaid assets (passed to overlay apply; then imported)
  overlay-output:
  echo "overlay_output=$PARAM_OVERLAY_OUTPUT"
 
  # Compile report options
  echo "report=$report_abs"
  echo "compile_include_asset_in_test_name=$PARAM_INCLUDE_ASSET_IN_TEST_NAME"
} >>"$GITHUB_OUTPUT"