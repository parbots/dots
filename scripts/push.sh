#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="${DOTS_DIR:-$HOME/dev/dots}"

# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

fail() {
    error "$1"
    log_json_event failure "$1" push
    exit 1
}

if ! acquire_lock; then
    warn "Another dots operation is running. Try again later."
    log_json_event skipped "lock held by another process" push
    exit 1
fi

cd "$DOTS_DIR"

info "Checking for template conflicts..."
check_template_conflicts || fail "template conflict: local edits to templated target(s)"

info "Capturing local config changes..."
chezmoi re-add || fail "chezmoi re-add failed"

info "Staging changes..."
git add -A || fail "git add -A failed"

if git diff --cached --quiet; then
    info "No new changes to commit."
else
    info "Changes to commit:"
    git diff --cached --stat

    if [[ $# -gt 0 ]]; then
        COMMIT_MSG="$1"
    else
        CHANGED_FILES=$(git diff --cached --name-only | head -5 | tr '\n' ',' | sed 's/,$//')
        COMMIT_MSG="dots: update ${CHANGED_FILES}"
    fi

    info "Committing: $COMMIT_MSG"
    git commit -m "$COMMIT_MSG" || fail "git commit failed"
fi

# Convergence: push everything unpushed, including commits stranded by a
# previously failed push or an aborted run — runs whether or not this
# invocation created a commit.
if git rev-parse --abbrev-ref '@{u}' &>/dev/null; then
    if (( $(git rev-list --count '@{u}..HEAD') > 0 )); then
        info "Pushing unpushed commit(s)..."
        if ! git pull --rebase; then
            git rebase --abort 2>/dev/null || true
            fail "rebase onto remote failed; resolve manually and rerun"
        fi
        git push || fail "git push failed"
    fi
    # Invariant: success is never reported while commits remain unpushed.
    (( $(git rev-list --count '@{u}..HEAD') == 0 )) || fail "commits remain unpushed after convergence"
    success "Push complete. Branch is in sync with remote."
    log_json_event success "push ok" push
else
    warn "No upstream configured; commit kept local. Set an upstream to enable pushing."
    log_json_event success "push ok (no upstream; commit kept local)" push
fi
