#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="${DOTS_DIR:-$HOME/dev/dots}"

# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

fail() {
    error "$1"
    log_json_event failure "$1" update
    exit 1
}

if ! acquire_lock; then
    warn "Another dots operation is running. Try again later."
    log_json_event skipped "lock held by another process" update
    exit 1
fi

# Never operate on a repo stuck mid-rebase (e.g. a previous run was killed).
if [[ -d "$DOTS_DIR/.git/rebase-merge" || -d "$DOTS_DIR/.git/rebase-apply" ]]; then
    warn "Repository is stuck mid-rebase; aborting the stale rebase."
    git -C "$DOTS_DIR" rebase --abort || true
    fail "repo was stuck mid-rebase; stale rebase aborted — rerun update"
fi

info "Pulling latest changes..."
if ! git -C "$DOTS_DIR" pull --rebase; then
    git -C "$DOTS_DIR" rebase --abort 2>/dev/null || true
    fail "git pull --rebase failed"
fi

info "Checking for template conflicts..."
check_template_conflicts || fail "template conflict: refusing to apply over local edits"

info "Applying chezmoi configs..."
chezmoi apply -v --force || fail "chezmoi apply failed"

log_json_event success "update ok" update
success "Update complete."
