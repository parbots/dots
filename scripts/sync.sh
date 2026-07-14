#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

MAX_LOG_ENTRIES=500
MAX_SCHEDULER_LOG_LINES=1000

# rotate_log_tail <file> <max_lines> — truncate a log file to its last N lines.
rotate_log_tail() {
    local file=$1 max=$2 lines
    [[ -f "$file" ]] || return 0
    lines=$(wc -l < "$file")
    if (( lines > max )); then
        tail -n "$max" "$file" > "$file.tmp"
        mv "$file.tmp" "$file"
    fi
}

if ! acquire_lock; then
    warn "Another dots operation is running; skipping this sync."
    log_json skipped "lock held by another process" sync
    exit 0
fi

START_TIME=$(date +%s)
RESULT="success"
DETAILS=""

info "Phase 1: Pushing local changes..."
if "$SCRIPT_DIR/push.sh" "dots: auto-sync $(date -u +%Y-%m-%dT%H:%M:%SZ)"; then
    DETAILS="push ok"
else
    DETAILS="push failed"
    RESULT="failure"
fi

if [[ "$RESULT" == "success" ]]; then
    info "Phase 2: Pulling remote changes..."
    if "$SCRIPT_DIR/update.sh"; then
        DETAILS="$DETAILS, pull ok"
    else
        DETAILS="$DETAILS, pull failed"
        RESULT="failure"
    fi
fi

END_TIME=$(date +%s)
DURATION_MS=$(( (END_TIME - START_TIME) * 1000 ))

log_json "$RESULT" "$DETAILS" sync "$DURATION_MS"

# Rotate while still holding the lock so a concurrent run cannot lose appends.
# Rotation is housekeeping — its failure must not change the run's outcome.
rotate_log_tail "$DOTS_SYNC_LOG" "$MAX_LOG_ENTRIES" || warn "sync.log rotation skipped"
rotate_log_tail "$DOTS_STATE_DIR/launchd-stdout.log" "$MAX_SCHEDULER_LOG_LINES" || warn "launchd-stdout.log rotation skipped"
rotate_log_tail "$DOTS_STATE_DIR/launchd-stderr.log" "$MAX_SCHEDULER_LOG_LINES" || warn "launchd-stderr.log rotation skipped"

if [[ "$RESULT" == "success" ]]; then
    success "Sync complete."
else
    error "Sync completed with errors. Check log: $DOTS_SYNC_LOG"
    exit 1
fi
