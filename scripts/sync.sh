#!/usr/bin/env bash
set -euo pipefail

DOTS_DIR="${DOTS_DIR:-$HOME/dev/dots}"
SCRIPTS_DIR="$DOTS_DIR/scripts"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dots"
LOG_FILE="$LOG_DIR/sync.log"
MAX_LOG_ENTRIES=500

mkdir -p "$LOG_DIR"

NC='\033[0m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'

info() { echo -e "${BLUE}$1${NC}"; }
success() { echo -e "${GREEN}$1${NC}"; }
error() { echo -e "${RED}$1${NC}" >&2; }

START_TIME=$(date +%s)
RESULT="success"
DETAILS=""

# Phase 1: Push local changes
info "Phase 1: Pushing local changes..."
if "$SCRIPTS_DIR/push.sh" "dots: auto-sync $(date -u +%Y-%m-%dT%H:%M:%SZ)"; then
    DETAILS="push ok"
else
    DETAILS="push failed"
    RESULT="failure"
fi

# Phase 2: Pull remote changes (only if push succeeded)
if [[ "$RESULT" == "success" ]]; then
    info "Phase 2: Pulling remote changes..."
    if "$SCRIPTS_DIR/update.sh"; then
        DETAILS="$DETAILS, pull ok"
    else
        DETAILS="$DETAILS, pull failed"
        RESULT="failure"
    fi
fi

END_TIME=$(date +%s)
DURATION_MS=$(( (END_TIME - START_TIME) * 1000 ))
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Log result as JSON line
echo "{\"timestamp\":\"$TIMESTAMP\",\"action\":\"sync\",\"result\":\"$RESULT\",\"duration_ms\":$DURATION_MS,\"details\":\"$DETAILS\"}" >> "$LOG_FILE"

# Rotate log: keep last N entries
if [[ -f "$LOG_FILE" ]]; then
    LINES=$(wc -l < "$LOG_FILE")
    if (( LINES > MAX_LOG_ENTRIES )); then
        tail -n "$MAX_LOG_ENTRIES" "$LOG_FILE" > "$LOG_FILE.tmp"
        mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
fi

if [[ "$RESULT" == "success" ]]; then
    success "Sync complete."
else
    error "Sync completed with errors. Check log: $LOG_FILE"
    exit 1
fi
