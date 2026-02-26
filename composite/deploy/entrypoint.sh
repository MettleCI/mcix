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

# NOTES
# Composite actions don’t have a Docker “entrypoint” the way other GitHub actions do. 
# Instead, the commands in the `runs` section of action.yml are executed directly 
# by the runner.  The `entrypoint.sh` in this context serves as a placeholder to 
# encapsulate any required shared logic.
#
# This 'wrapper' action outputs junit-path by mapping from the compile step output
# (our compile action exposes junit-path)

set -euo pipefail

# Import MettleCI GitHub Actions utility functions
. "/usr/share/mcix/common.sh"


# -----
# Setup
# -----
export MCIX_BIN_DIR="/usr/share/mcix/bin"
export MCIX_LOG_DIR="/usr/share/mcix"
# Make us immune to runner differences or potential base-image changes
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$MCIX_BIN_DIR"

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"

# -------------------
# Validate parameters
# -------------------

# We don't validate parameters here since we're not actually running a command in this composite action.
# Checking we have values for mandatory  parameters using 'requires' function, validating the mutual 
# exclusivity of project and projectid, etc.

# Overlay Apply parameters
echo PARAM_ASSETS is ${PARAM_ASSETS}
echo PARAM_OVERLAY is ${PARAM_OVERLAY}
echo PARAM_PROPERTIES is ${PARAM_PROPERTIES}
echo PARAM_OVERLAY_OUTPUT is ${PARAM_OVERLAY_OUTPUT}
# DataStage Import parameters
echo PARAM_API_KEY is ${PARAM_API_KEY}
echo PARAM_URL is ${PARAM_URL}
echo PARAM_USER is ${PARAM_USER}
# PARAM_ASSETS: ${{ inputs.assets }} (overlaid assets path is determined by overlay apply output)
echo PARAM_PROJECT is ${PARAM_PROJECT}
echo PARAM_PROJECT_ID is ${PARAM_PROJECT_ID}
# DataStage Compile parameters
echo PARAM_REPORT is ${PARAM_REPORT}
echo PARAM_INCLUDE_ASSET_IN_TEST_NAME is ${PARAM_INCLUDE_ASSET_IN_TEST_NAME}

export assets="${PARAM_ASSETS:-}"
export overlay="${PARAM_OVERLAY:-}"
export properties="${PARAM_PROPERTIES:-}"
export overlay_output="${PARAM_OVERLAY_OUTPUT:-}"

: "${assets:?PARAM_ASSETS must be set}"
: "${overlay:?PARAM_OVERLAY must be set}"

workspace="${GITHUB_WORKSPACE:-$PWD}"

assets_abs="$(anchor_path "$assets")"
overlay_abs="$(anchor_path "$overlay")"
properties_abs="$(anchor_path "$properties")"
overlay_output_abs="$(anchor_path "$overlay_output")"

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
  echo "overlay_assets=$overlay_output_abs"
} >>"$GITHUB_OUTPUT"