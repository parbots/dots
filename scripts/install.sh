#!/usr/bin/env bash
set -euo pipefail

DOTS_REPO="https://github.com/parbots/dots.git"
DOTS_DIR="${DOTS_DIR:-$HOME/dev/dots}"
CHEZMOI_MIN_VERSION="2.40.0"

NC='\033[0m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'

info() { echo -e "${BLUE}$1${NC}"; }
success() { echo -e "${GREEN}$1${NC}"; }
error() { echo -e "${RED}$1${NC}" >&2; }
warn() { echo -e "${YELLOW}$1${NC}"; }

OS="$(uname -s)"

version_gte() {
    local IFS=.
    local i
    read -ra v1 <<< "$1"
    read -ra v2 <<< "$2"
    for ((i=0; i<${#v2[@]}; i++)); do
        if ((${v1[i]:-0} < ${v2[i]:-0})); then
            return 1
        elif ((${v1[i]:-0} > ${v2[i]:-0})); then
            return 0
        fi
    done
    return 0
}

if command -v chezmoi &>/dev/null; then
    CHEZMOI_VERSION=$(chezmoi --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if ! version_gte "$CHEZMOI_VERSION" "$CHEZMOI_MIN_VERSION"; then
        error "chezmoi $CHEZMOI_VERSION is too old. Minimum required: $CHEZMOI_MIN_VERSION"
        error "Run: brew upgrade chezmoi (macOS) or reinstall (Linux)"
        exit 1
    fi
    info "chezmoi $CHEZMOI_VERSION already installed."
else
    info "Installing chezmoi..."
    if [[ "$OS" == "Darwin" ]]; then
        brew install chezmoi
    else
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
        export PATH="$HOME/.local/bin:$PATH"
    fi
    success "chezmoi installed."
fi

if [[ -d "$DOTS_DIR/.git" ]]; then
    info "dots repo already exists at $DOTS_DIR."
else
    info "Cloning dots repo..."
    mkdir -p "$(dirname "$DOTS_DIR")"
    git clone "$DOTS_REPO" "$DOTS_DIR"
    success "Cloned to $DOTS_DIR."
fi

mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/dots"

info "Initializing chezmoi..."
chezmoi init --source "$DOTS_DIR/configs"
success "chezmoi initialized."

info "Applying configs..."
chezmoi apply -v
success "Configs applied."

if [[ "$OS" == "Darwin" ]]; then
    if [[ -f "$DOTS_DIR/configs/Brewfile" ]]; then
        info "Installing Homebrew packages..."
        brew bundle --file="$DOTS_DIR/configs/Brewfile"
        success "Homebrew packages installed."
    fi
fi

if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    success "Git SSH authentication configured."
elif git config --global credential.helper &>/dev/null; then
    success "Git credential helper configured."
else
    warn "Warning: No SSH key or git credential helper detected."
    warn "Automated push/sync will not work without non-interactive git auth."
    warn "Set up SSH keys or a credential helper before using push.sh or sync.sh."
fi

if command -v go &>/dev/null; then
    read -rp "Build dots TUI? [y/N] " BUILD_TUI
    if [[ "$BUILD_TUI" =~ ^[Yy]$ ]]; then
        info "Building TUI..."
        cd "$DOTS_DIR"
        make build
        success "TUI built. Run 'dots' to launch."
    fi
else
    info "Go not installed. Skipping TUI build."
fi

success "Installation complete!"
