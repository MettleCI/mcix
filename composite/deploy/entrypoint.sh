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


set -eu

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

# -------------------
# Validate parameters
# -------------------

# These are validated in the individual actions, but there's no harm in failing fast if
# they're not set at all, or if the mutually exclusive project/project-id are both set.
require PARAM_API_KEY "api-key"
require PARAM_URL "url"
require PARAM_USER "user"
require PARAM_REPORT "report"
require PARAM_ASSETS "assets"
require PARAM_OVERLAY "overlay"

# Ensure PARAM_REPORT will always be /github/workspace/...
PARAM_REPORT="$(resolve_workspace_path "$PARAM_REPORT")"
mkdir -p "$(dirname "$PARAM_REPORT")"
report_display="${PARAM_REPORT#${GITHUB_WORKSPACE:-/github/workspace}/}"


# Default overlay output if not provided
if [[ -z "$overlay_output_abs" ]]; then
  overlay_output_abs="${workspace}/assets-overlay.zip"
fi

# Sanity checks (helpful)
if [[ ! -e "$assets_abs" ]]; then
  echo "ERROR: assets not found: $assets_abs" >&2
  exit 1
fi
if [[ ! -d "$overlay_abs" ]]; then
  echo "ERROR: overlay dir not found: $overlay_abs" >&2
  exit 1
fi
if [[ -n "$properties_abs" && ! -f "$properties_abs" ]]; then
  echo "ERROR: properties file not found: $properties_abs" >&2
  exit 1
fi

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"
{
  # Generate our output in a normalized form (absolute path) so that 
  # downstream steps can consume it reliably regardless of how the user 
  # provided it.
  echo "overlay_assets=$overlay_output_abs"
} >>"$GITHUB_OUTPUT"