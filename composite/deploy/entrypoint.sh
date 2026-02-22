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
# Instead, the commands in the `runs` section of `action.yml` are executed directly 
# by the runner.  The `entrypoint.sh` in this context serves as a placeholder to 
# encapsulate any required shared logic.
#
# This 'wrapper' action outputs junit-path by mapping from the compile step output
# (our compile action exposes junit-path)

set -euo pipefail

# Import MettleCI GitHub Actions utility functions
# Not needed in composite action since we're not running a real entrypoint.sh, 
# but leaving here in case we want to move some shared logic in the future
# . "/usr/share//mcix/common.sh"        

assets="${INPUT_ASSETS:-}"
overlay="${INPUT_OVERLAY:-}"
properties="${INPUT_PROPERTIES:-}"
overlay_output="${INPUT_OVERLAY_OUTPUT:-}"

: "${assets:?INPUT_ASSETS must be set}"
: "${overlay:?INPUT_OVERLAY must be set}"

workspace="${GITHUB_WORKSPACE:-$PWD}"

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