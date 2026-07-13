#!/usr/bin/env bash
# lib.sh — shared foundation sourced by the dots scripts. Not executable on
# its own. Source it with:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DOTS_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dots"
DOTS_SYNC_LOG="$DOTS_STATE_DIR/sync.log"
DOTS_LOCK_DIR="$DOTS_STATE_DIR/lock"

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

# acquire_lock — take the global dots lock. Returns non-zero if another live
# process holds it. Re-entrant: when a parent (sync.sh) already holds the
# lock, returns 0 without acquiring. The acquiring process installs an EXIT
# trap to release.
acquire_lock() {
    if [[ "$DOTS_PARENT_HOLDS_LOCK" == "1" ]]; then
        return 0
    fi
    mkdir -p "$DOTS_STATE_DIR"
    local holder_pid
    for _ in 1 2; do
        if mkdir "$DOTS_LOCK_DIR" 2>/dev/null; then
            echo "$$" > "$DOTS_LOCK_DIR/pid"
            export DOTS_LOCK_HELD=1
            trap release_lock EXIT
            return 0
        fi
        holder_pid=$(cat "$DOTS_LOCK_DIR/pid" 2>/dev/null || true)
        if [[ -z "$holder_pid" ]]; then
            # Holder may be between mkdir and writing its pid — give it a
            # moment before declaring the lock stale.
            sleep 1
            holder_pid=$(cat "$DOTS_LOCK_DIR/pid" 2>/dev/null || true)
        fi
        if [[ -n "$holder_pid" ]] && kill -0 "$holder_pid" 2>/dev/null; then
            return 1
        fi
        # Holder is dead. Reclaim by atomically renaming the stale lock dir
        # aside — only one contender can win the rename, and the winner then
        # exclusively owns that instance, so re-checking its pid is race-free.
        if mv "$DOTS_LOCK_DIR" "$DOTS_LOCK_DIR.stale.$$" 2>/dev/null; then
            # If the pid inside is alive, we captured a lock that was
            # recreated after our staleness check — put it back and report
            # contention. (If a third process re-locked in the interim, the
            # restore fails and we just discard our capture; the displaced
            # holder's next run self-heals.)
            holder_pid=$(cat "$DOTS_LOCK_DIR.stale.$$/pid" 2>/dev/null || true)
            if [[ -n "$holder_pid" ]] && kill -0 "$holder_pid" 2>/dev/null; then
                mv "$DOTS_LOCK_DIR.stale.$$" "$DOTS_LOCK_DIR" 2>/dev/null || rm -rf "$DOTS_LOCK_DIR.stale.$$"
                return 1
            fi
            rm -rf "$DOTS_LOCK_DIR.stale.$$"
        fi
    done
    return 1
}

# release_lock — remove the lock if this process acquired it (never a lock
# inherited from a parent). Runs from the EXIT trap set by acquire_lock.
release_lock() {
    if [[ "${DOTS_LOCK_HELD:-0}" == "1" && "$DOTS_PARENT_HOLDS_LOCK" != "1" ]]; then
        rm -rf "$DOTS_LOCK_DIR"
    fi
}

# check_template_conflicts — chezmoi re-add silently skips .tmpl sources, so
# a later 'apply --force' would destroy direct edits to templated targets.
# Returns non-zero (naming each file) if any locally-modified target's source
# is a template. Callers must exit failure without re-adding or applying.
check_template_conflicts() {
    local status_output
    if ! status_output=$(chezmoi status); then
        error "chezmoi status failed; cannot check for template conflicts."
        return 1
    fi

    local conflicts=() line target source_path
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        # chezmoi status lines: two status chars, a space, then the target
        # path relative to ~. A non-space first char means the file changed
        # on disk since the last apply (a local edit).
        [[ "${line:0:1}" == " " ]] && continue
        target="${line:3}"
        source_path=$(chezmoi source-path "$HOME/$target" 2>/dev/null) || continue
        if [[ "$source_path" == *.tmpl ]]; then
            conflicts+=("$target")
        fi
    done <<< "$status_output"

    if (( ${#conflicts[@]} > 0 )); then
        error "BLOCKED: direct edit(s) to templated target(s) detected:"
        local t
        for t in "${conflicts[@]}"; do
            error "  ~/$t"
        done
        error "'chezmoi re-add' cannot capture edits to .tmpl sources, and applying would destroy them."
        error "Reconcile first with: chezmoi merge ~/<file>   (or edit the source template, then 'chezmoi apply')."
        return 1
    fi
    return 0
}
