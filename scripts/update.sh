#!/usr/bin/env bash
set -euo pipefail

DOTS_DIR="${DOTS_DIR:-$HOME/dev/dots}"

NC='\033[0m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'

info() { echo -e "${BLUE}$1${NC}"; }
success() { echo -e "${GREEN}$1${NC}"; }
error() { echo -e "${RED}$1${NC}" >&2; }

info "Pulling latest changes..."
if git -C "$DOTS_DIR" pull --rebase; then
    success "Git pull complete."
else
    error "Git pull failed. Resolve conflicts manually."
    exit 1
fi

info "Applying chezmoi configs..."
if chezmoi apply -v; then
    success "Configs applied successfully."
else
    error "chezmoi apply failed."
    exit 1
fi

success "Update complete."
