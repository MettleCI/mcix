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
#                _
#  ___ _   _ ___| |_ ___ _ __ ___
# / __| | | / __| __/ _ \ '_ ` _ \
# \__ \ |_| \__ \ ||  __/ | | | | |
# |___/\__, |___/\__\___|_| |_| |_|
#      |___/          _
# __   _____ _ __ ___(_) ___  _ __
# \ \ / / _ \ '__/ __| |/ _ \| '_ \
#  \ V /  __/ |  \__ \ | (_) | | | |
#   \_/ \___|_|  |___/_|\___/|_| |_|

set -euo pipefail

# Import MettleCI GitHub Actions utility functions
. "/usr/share/mcix/common.sh"

# -----
# Setup
# -----
export MCIX_CMD_NAME="mcix system version"
export MCIX_BIN_DIR="/usr/share/mcix/bin"
export MCIX_LOG_DIR="/usr/share/mcix"
export PATH="$PATH:$MCIX_BIN_DIR"

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"

# We'll store the real command status here so the trap can see it
MCIX_STATUS=0
# Populated if command output matches: "It has been logged (ID ...)"
MCIX_LOGGED_ERROR_ID=""

# ------------
# Step summary
# ------------
write_step_summary() {
  rc=$1

  {
    cat <<EOF
### MCIX System Version
EOF

    echo '```text'
    awk '
      /^[[:space:]]*$/ { exit }              # stop on first blank line
      { print }
    ' "$tmp_out"
    echo '```'
    echo '<details>'
    echo '<summary>Loaded plugins</summary>'
    echo  # A blank line after the <summary> tag is required by GitHub to format the content correctly
    echo '| Plugin | Version |'
    echo '| ------ | ------- |'

    printf '%s\n' "$CMD_OUTPUT" | awk '
      BEGIN { in_plugins = 0 }

      /^Loaded plugins:/ {
        in_plugins = 1
        next
      }

      # Optional: stop once we hit a blank line after the plugins list
      in_plugins && NF == 0 {
        exit
      }

      in_plugins && /^[[:space:]]*\*/ {
        line = $0

        # strip leading " * " (with any whitespace around)
        sub(/^[[:space:]]*\*[[:space:]]*/, "", line)

        plugin = line
        version = ""

        # If there is a (...) at the end, treat that as the version
        if (match(plugin, /\(([^()]*)\)[[:space:]]*$/)) {
          version = substr(plugin, RSTART + 1, RLENGTH - 2)
          plugin  = substr(plugin, 1, RSTART - 1)
          sub(/[[:space:]]*$/, "", plugin)  # trim trailing spaces
        }

        printf("| %s | %s |\n", plugin, version)
      }
    '
    echo '</details>'

    echo '<details>'
    echo '<summary>Execution environment</summary>'
    echo  # A blank line after the <summary> tag is required by GitHub to format the content correctly
    echo '```'
    env | sort
    echo '```'
    echo '</details>'
  } >>"$GITHUB_STEP_SUMMARY"
}

# ---------
# Exit trap
# ---------
write_return_code_and_summary() {
  # Prefer MCIX_STATUS if set; fall back to $?
  rc=${MCIX_STATUS:-$?}

  echo "return-code=$rc" >>"$GITHUB_OUTPUT"

  [ -z "${GITHUB_STEP_SUMMARY:-}" ] && return

  write_step_summary "$rc"
}
# Combine summary/output writing + temp cleanup in a single EXIT trap.
trap write_return_code_and_summary EXIT

# -----------------
# Build and execute
# -----------------
set -- "$MCIX_CMD_NAME"

# Capture output so we can detect "It has been logged (ID ...)" failures.
tmp_out="$(mktemp)"
cleanup() { rm -f "$tmp_out"; }

# Run the command, capture its output and status, but don't let `set -e` kill us.
set +e
"$@" 2>&1 | tee "$tmp_out"
MCIX_STATUS=$?
set -e

# If the known "logged error" signature occurred, stash details for the summary.
MCIX_LOGGED_ERROR_ID=""
if mcix_has_logged_error "$tmp_out"; then
  MCIX_LOGGED_ERROR_ID="$(mcix_extract_logged_error_id "$tmp_out")"
  # Treat logged errors as failures for the purpose of the step summary, even if the command itself didn't return a non-zero code.
  MCIX_STATUS=1
fi

# Let the trap handle outputs & summary using MCIX_STATUS
exit "$MCIX_STATUS"
