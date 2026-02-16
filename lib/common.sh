# ███╗   ███╗███████╗████████╗████████╗██╗     ███████╗ ██████╗██╗
# ████╗ ████║██╔════╝╚══██╔══╝╚══██╔══╝██║     ██╔════╝██╔════╝██║
# ██╔████╔██║█████╗     ██║      ██║   ██║     █████╗  ██║     ██║
# ██║╚██╔╝██║██╔══╝     ██║      ██║   ██║     ██╔══╝  ██║     ██║
# ██║ ╚═╝ ██║███████╗   ██║      ██║   ███████╗███████╗╚██████╗██║
# ╚═╝     ╚═╝╚══════╝   ╚═╝      ╚═╝   ╚══════╝╚══════╝ ╚═════╝╚═╝
# MettleCI DevOps for DataStage       (C) 2025-2026 Data Migrators
#        _   _ _ _ _   _
#  _   _| |_(_) (_) |_(_) ___  ___
# | | | | __| | | | __| |/ _ \/ __|
# | |_| | |_| | | | |_| |  __/\__ \
#  \__,_|\__|_|_|_|\__|_|\___||___/
# 
# -----------------
# Utility functions
# -----------------

# Failure handling utility functions
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Validate mutually exclusive project/project-id arguments
# PROJECT* vars have already undergone null checking so we can safely 
# assume they're set (to empty string if not provided)
validate_project() {
  if [ -n "$PROJECT" ] && [ -n "$PROJECT_ID" ]; then
    die "Provide either 'project' or 'project-id', not both."
  fi
  if [ -z "$PROJECT" ] && [ -z "$PROJECT_ID" ]; then
    die "You must provide either 'project' or 'project-id'."
  fi
}

# Normalise "true/false", "1/0", etc.
normalise_bool() {
  case "$1" in
    1|true|TRUE|yes|YES|on|ON) echo 1 ;;
    0|false|FALSE|no|NO|off|OFF|"") echo 0 ;;
    *) die "Invalid boolean: $1" ;;
  esac
}

# Resolve a path to an absolute path under the workspace, unless already absolute.
# - "" stays ""
# - "datastage" -> /github/workspace/datastage
# - "./datastage" -> /github/workspace/datastage
# - "/tmp/x" -> /tmp/x
resolve_workspace_path() {
  p="${1:-}"
  [ -z "$p" ] && { echo ""; return; }

  case "$p" in
    /*) echo "$p" ;;
    *)  base="${GITHUB_WORKSPACE:-/github/workspace}"
        echo "${base}/${p#./}" ;;
  esac
}

# ----------------
# GitHub Utilities
# ----------------

# Emit GitHub workflow-command annotations (instead of writing to stderr).
# We escape %, CR, LF to keep workflow commands well-formed.
_gh_escape() {
  printf '%s' "$1" | sed \
    -e 's/%/%25/g' \
    -e 's/\r/%0D/g' \
    -e 's/\n/%0A/g'
}

# gh_notice "Title" "Message"
gh_notice() { 
  echo "::notice title=$(_gh_escape "$1")::$(_gh_escape "$2")"
}

# gh_warn "Title" "Message"
gh_warn() { 
  echo "::warning title=$(_gh_escape "$1")::$(_gh_escape "$2")"
}

# gh_error "Title" "Message"
gh_error() { 
  echo "::error title=$(_gh_escape "$1")::$(_gh_escape "$2")"
}

# Required arguments
require() {
  # $1 = var name, $2 = human label (for error)
  eval "v=\${$1-}"
  if [ -z "$v" ]; then
    die "Missing required input: $2"
  fi
}
