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
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$MCIX_BIN_DIR"

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

    # Display the mcix system version header
    echo '```text'
    awk '
      /^[[:space:]]*$/ { exit }              # stop on first blank line
      { print }
    ' "$tmp_out"
    echo '```'

    # Display the contents of the mcix image's scan-metadata.txt file. (collapsed by default)
    echo '<details>'
    echo '<summary>Image compliance information</summary>'
    echo # A blank line after the <summary> tag is required by GitHub to format the content correctly
    echo "${MCIX_COMPLIANCE_DIR}/scan-metadata.txt"
    echo '```'
    cat "${MCIX_COMPLIANCE_DIR}/scan-metadata.txt"
    echo '```'
    echo '</details>'
    echo
    echo 'You can inspect the image OCI and other compliance labels with:'
    echo "\`docker inspect <image-ref>:<version-tag> --format '{{ json .Config.Labels }}'\`"
    
    # Display the environment variables provided by GitHub to the execution environment. (collapsed by default)
    echo '<details>'
    echo '<summary>GitHub execution environment</summary>'
    echo  # A blank line after the <summary> tag is required by GitHub to format the content correctly
    echo '```'
    env | sort
    echo '```'
    echo '</details>'

    # Display a tabulated form of the plugins reported by mcix system version output (collapsed by default)
    echo '<details>'
    echo '<summary>MCIX plugins loaded</summary>'
    echo  # A blank line after the <summary> tag is required by GitHub to format the content correctly
    echo '| Plugin | Version |'
    echo '| ------ | ------- |'

    awk '
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
    '  "$tmp_out"
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
trap 'write_return_code_and_summary; cleanup' EXIT

# -----------------
# Build and execute
# -----------------
# There are GOOD REASONS we don't use MCIX_CMD_NAME here, but the necessary lesson
# in shell variable expansion is too long to go into here.  Just trust me - JMcK.
set -- mcix system version

# Prepare a file to capture output so we can detect "It has been logged (ID ...)" failures.
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
