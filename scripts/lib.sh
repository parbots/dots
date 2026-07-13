#!/usr/bin/env bash
# lib.sh — shared foundation sourced by the dots scripts. Not executable on
# its own. Source it with:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Color helpers — plain text when stdout is not a terminal, so launchd/systemd
# logs don't fill with ANSI escapes.
if [[ -t 1 ]]; then
    NC='\033[0m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
else
    NC=''
    GREEN=''
    BLUE=''
    RED=''
    YELLOW=''
fi

info() { echo -e "${BLUE}$1${NC}"; }
success() { echo -e "${GREEN}$1${NC}"; }
error() { echo -e "${RED}$1${NC}" >&2; }
warn() { echo -e "${YELLOW}$1${NC}"; }

# json_escape <string> — print the string escaped for embedding in a JSON
# string value. JSON forbids unescaped control characters (0x00-0x1f).
json_escape() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\b'/\\b}
    s=${s//$'\f'/\\f}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    # Any remaining control characters are dropped rather than escaped.
    s=$(printf '%s' "$s" | tr -d '\000-\037')
    printf '%s' "$s"
}
