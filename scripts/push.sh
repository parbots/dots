#!/usr/bin/env bash
set -euo pipefail

DOTS_DIR="${DOTS_DIR:-$HOME/dev/dots}"

NC='\033[0m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'

info() { echo -e "${BLUE}$1${NC}"; }
success() { echo -e "${GREEN}$1${NC}"; }
error() { echo -e "${RED}$1${NC}" >&2; }
warn() { echo -e "${YELLOW}$1${NC}"; }

info "Capturing local config changes..."
chezmoi re-add

cd "$DOTS_DIR"

info "Staging changes..."
git add configs/ scripts/ tui/ Makefile .gitignore CLAUDE.md README.md .github/ docs/ 2>/dev/null || true

if git diff --cached --quiet; then
    warn "No changes to push."
    exit 0
fi

info "Changes to commit:"
git diff --cached --stat

# Auto-generate commit message from changed files, or use provided arg
if [[ $# -gt 0 ]]; then
    COMMIT_MSG="$1"
else
    CHANGED_FILES=$(git diff --cached --name-only | head -5 | tr '\n' ', ' | sed 's/,$//')
    COMMIT_MSG="dots: update ${CHANGED_FILES}"
fi

info "Committing: $COMMIT_MSG"
git commit -m "$COMMIT_MSG"

info "Pushing to remote..."
if git push; then
    success "Push complete."
else
    error "Push failed. Check git authentication."
    exit 1
fi
