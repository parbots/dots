#!/usr/bin/env bash
# lib.sh — shared foundation sourced by the dots scripts. Not executable on
# its own. Source it with:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DOTS_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dots"
DOTS_SYNC_LOG="$DOTS_STATE_DIR/sync.log"

# Whether a parent process (sync.sh) already held the dots lock when this
# script started. Children skip locking and per-script logging.
DOTS_PARENT_HOLDS_LOCK="${DOTS_LOCK_HELD:-0}"

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

# log_json <result> <details> <action> [duration_ms] — append one JSON entry
# to the sync log. Field set matches what the TUI parses
# (tui/internal/app/status.go); duration_ms is optional.
log_json() {
    local result=$1 details=$2 action=$3 duration_ms=${4:-}
    mkdir -p "$DOTS_STATE_DIR"
    local ts entry
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    entry="{\"timestamp\":\"$ts\",\"action\":\"$(json_escape "$action")\",\"result\":\"$(json_escape "$result")\""
    # A non-numeric duration would corrupt the JSON — omit it instead.
    if [[ -n "$duration_ms" && "$duration_ms" =~ ^[0-9]+$ ]]; then
        entry+=",\"duration_ms\":$duration_ms"
    fi
    entry+=",\"details\":\"$(json_escape "$details")\"}"
    echo "$entry" >> "$DOTS_SYNC_LOG"
}

# log_json_event — like log_json, but suppressed when a parent (sync.sh)
# holds the lock, so an orchestrated run logs once instead of three times.
log_json_event() {
    if [[ "$DOTS_PARENT_HOLDS_LOCK" == "1" ]]; then
        return 0
    fi
    log_json "$@"
}
