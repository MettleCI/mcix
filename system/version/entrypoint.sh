#!/bin/sh
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

set -eu

# Import MettleCI GitHub Actions utility functions
. "/usr/share//mcix/common.sh"

# -----
# Setup
# -----
MCIX_BIN_DIR="/usr/share/mcix/bin"
MCIX_CMD="$MCIX_BIN_DIR/mcix"
PATH="$PATH:$MCIX_BIN_DIR"

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"

# We'll store the real command status here so the trap can see it
MCIX_STATUS=0
CMD_OUTPUT=""

# ------------
# Step summary
# ------------
write_step_summary() {
  rc=$1

  [ "$rc" -ne 0 ] && status_emoji="❌" && status_title="Failure"

  {
    cat <<EOF
### MCIX System Version
EOF

    if [ -n "${CMD_OUTPUT:-}" ]; then
      echo '```text'
      printf '%s\n' "$CMD_OUTPUT" | awk '
        /^[[:space:]]*$/ { exit }              # stop on first blank line
        { print }
      '
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
      env | sort
      echo '</details>'
    fi
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
trap write_return_code_and_summary EXIT

# ------------------------
# Build command to execute
# ------------------------
set -- "$MCIX_CMD" system version

# -------
# Execute
# -------
echo "Executing: $*"

# Run the command, capture its output and status, but don't let `set -e` kill us.
set +e
CMD_OUTPUT=$("$@" 2>&1)
MCIX_STATUS=$?
set -e

# write outputs / summary based on MCIX_STATUS 
echo "return-code=$MCIX_STATUS" >> "$GITHUB_OUTPUT"

# Let the trap handle outputs & summary using MCIX_STATUS
exit "$MCIX_STATUS"
