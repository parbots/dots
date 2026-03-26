# dots Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete dotfile management system with chezmoi, automation scripts, and a Go TUI.

**Architecture:** chezmoi manages config files via a source-state model with templates for multi-machine support. Standalone bash scripts handle sync/install/push automation. A Go TUI (Bubble Tea) provides an interactive dashboard that shells out to chezmoi/git/brew.

**Tech Stack:** chezmoi, bash, Go 1.22+, Bubble Tea, Lip Gloss, Bubbles

**Spec:** `docs/superpowers/specs/2026-03-26-dots-redesign-design.md`

---

## Chunk 1: Repository Foundation & chezmoi Configuration

### Task 1: Repository scaffolding

**Files:**
- Create: `.gitignore`
- Create: `configs/.chezmoi.toml.tmpl`
- Create: `configs/.chezmoiignore`

- [ ] **Step 1: Create .gitignore**

```gitignore
# TUI build artifacts
tui/dots
dots

# OS files
.DS_Store
Thumbs.db
```

- [ ] **Step 2: Create chezmoi config template**

Create `configs/.chezmoi.toml.tmpl`:

```toml
[data]
    email = "{{ promptString "email" }}"
    machine_type = "{{ promptChoice "machine_type" "Machine type" (list "personal" "work" "server") }}"
    is_macos = {{ eq .chezmoi.os "darwin" }}
    is_linux = {{ eq .chezmoi.os "linux" }}
```

- [ ] **Step 3: Create chezmoiignore**

Create `configs/.chezmoiignore`:

```
Brewfile
{{- if ne .chezmoi.os "darwin" }}
dot_config/kitty/
run_onchange_install-packages.sh.tmpl
{{- end }}
```

- [ ] **Step 4: Commit**

```bash
git add .gitignore configs/.chezmoi.toml.tmpl configs/.chezmoiignore
git commit -m "feat: add repo scaffolding and chezmoi config templates"
```

---

### Task 2: Migrate existing zsh config as chezmoi template

**Files:**
- Create: `configs/dot_zshrc.tmpl`

**Context:** The user's current `.zshrc` lives at `~/.zshrc`. We need to copy it into the chezmoi source dir and wrap OS-specific sections in Go template conditionals.

- [ ] **Step 1: Copy current zshrc and convert to template**

Read the user's current `~/.zshrc`. Create `configs/dot_zshrc.tmpl` with the full contents, wrapping the Homebrew shellenv line (and any other macOS-specific lines) in `{{ if eq .chezmoi.os "darwin" }}` blocks. Add a Linux block placeholder.

The template should look like:

```zsh
# --- Shared config ---
export EDITOR=nvim

# ... (rest of user's existing zshrc content) ...

{{- if eq .chezmoi.os "darwin" }}
# macOS-specific
eval "$(/opt/homebrew/bin/brew shellenv)"
{{- end }}

{{- if eq .chezmoi.os "linux" }}
# Linux-specific paths and aliases
{{- end }}
```

Note: Preserve the user's full existing zshrc content. The above is a structural guide, not the complete file.

- [ ] **Step 2: Verify template syntax**

Run: `chezmoi execute-template < configs/dot_zshrc.tmpl` (if chezmoi is installed) to verify no template syntax errors.

- [ ] **Step 3: Commit**

```bash
git add configs/dot_zshrc.tmpl
git commit -m "feat: add zsh config as chezmoi template"
```

---

### Task 3: Migrate kitty config

**Files:**
- Create: `configs/dot_config/kitty/kitty.conf`
- Create: `configs/dot_config/kitty/catppuccin-mocha.conf`

**Context:** Copy kitty configs from `~/.config/kitty/`. These are plain files (no templating needed).

- [ ] **Step 1: Copy kitty configs into chezmoi source dir**

```bash
mkdir -p configs/dot_config/kitty
cp ~/.config/kitty/kitty.conf configs/dot_config/kitty/
cp ~/.config/kitty/catppuccin-mocha.conf configs/dot_config/kitty/
```

- [ ] **Step 2: Commit**

```bash
git add configs/dot_config/kitty/
git commit -m "feat: add kitty config"
```

---

### Task 4: Migrate nvim config

**Files:**
- Create: `configs/dot_config/nvim/` (entire directory tree)

**Context:** Copy the full nvim/picklevim config from `~/.config/nvim/`. Plain files, no templating.

- [ ] **Step 1: Copy nvim config into chezmoi source dir**

```bash
mkdir -p configs/dot_config/nvim
cp -R ~/.config/nvim/* configs/dot_config/nvim/
```

- [ ] **Step 2: Clean up unwanted artifacts**

Review the copied files and remove any that should not be version-controlled:

```bash
# Remove common nvim artifacts (adjust as needed)
rm -rf configs/dot_config/nvim/plugin/
rm -f configs/dot_config/nvim/lazy-lock.json
# Keep .luarc.json if present (it's in the spec)
```

- [ ] **Step 3: Verify the directory structure matches expected layout**

```bash
find configs/dot_config/nvim -type f | head -20
```

Should show `init.lua`, `lua/config/*.lua`, `lua/picklevim/**/*.lua`, etc.

- [ ] **Step 4: Commit**

```bash
git add configs/dot_config/nvim/
git commit -m "feat: add nvim (picklevim) config"
```

---

### Task 5: Add Brewfile and run_onchange script

**Files:**
- Create: `configs/Brewfile`
- Create: `configs/run_onchange_install-packages.sh.tmpl`

- [ ] **Step 1: Dump current Brewfile**

```bash
brew bundle dump --describe --file=configs/Brewfile
```

- [ ] **Step 2: Create run_onchange script**

Create `configs/run_onchange_install-packages.sh.tmpl`:

```bash
#!/bin/bash
# hash: {{ include "Brewfile" | sha256sum }}
{{- if eq .chezmoi.os "darwin" }}
brew bundle --file="{{ .chezmoi.sourceDir }}/Brewfile"
{{- end }}
```

- [ ] **Step 3: Commit**

```bash
git add configs/Brewfile configs/run_onchange_install-packages.sh.tmpl
git commit -m "feat: add Brewfile and auto-install script"
```

---

### Task 6: Initialize chezmoi with custom sourceDir

**Context:** Point chezmoi at `~/dev/dots/configs` instead of the default `~/.local/share/chezmoi`.

- [ ] **Step 1: Initialize chezmoi**

```bash
chezmoi init --source ~/dev/dots/configs
```

This will prompt for email and machine_type per the `.chezmoi.toml.tmpl`. Answer the prompts.

- [ ] **Step 2: Verify chezmoi sees the configs**

```bash
chezmoi managed
```

Expected: Should list `~/.zshrc`, `~/.config/kitty/kitty.conf`, `~/.config/kitty/catppuccin-mocha.conf`, `~/.config/nvim/init.lua`, and the nvim tree.

- [ ] **Step 3: Dry-run apply to verify no destructive changes**

```bash
chezmoi diff
```

Review the diff. Since we copied existing configs, there should be minimal or no differences.

- [ ] **Step 4: Apply**

```bash
chezmoi apply -v
```

- [ ] **Step 5: Review and commit any chezmoi-generated changes**

```bash
git status
# Review what changed, then stage specific files
git add configs/
git commit -m "feat: initialize chezmoi with custom sourceDir"
```

---

### Task 7: Create CLAUDE.md

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: Write CLAUDE.md**

Create `CLAUDE.md` with project context for Claude Code:

```markdown
# dots

Dotfile management system using chezmoi with a Go TUI.

## Project Structure

- `configs/` — chezmoi source directory (sourceDir: `~/dev/dots/configs`)
- `scripts/` — standalone bash automation scripts
- `tui/` — Go TUI application (Bubble Tea)
- `docs/superpowers/` — design specs and implementation plans

## Key Commands

- `chezmoi apply` — apply configs from source to home directory
- `chezmoi diff` — preview changes before applying
- `chezmoi re-add` — capture direct edits to managed files back into source
- `chezmoi managed` — list all managed files

## Build

```bash
cd tui && go build -o dots .    # build TUI
make build                       # or via Makefile
make install                     # build + copy to ~/bin
```

## Test

```bash
cd tui && go test ./...          # Go tests
shellcheck scripts/*.sh          # lint shell scripts
```

## Conventions

- Shell scripts use bash with `set -euo pipefail`
- Go code follows standard Go formatting (`gofmt`)
- chezmoi templates use Go text/template syntax
- Catppuccin Mocha color palette in TUI
- Commits follow conventional commits format (feat:, fix:, docs:, etc.)

## chezmoi

- Source dir: `~/dev/dots/configs`
- Config: `~/.config/chezmoi/chezmoi.toml`
- Template data includes: `.email`, `.machine_type`, `.is_macos`, `.is_linux`
- Brewfile is in source dir but excluded from deployment via `.chezmoiignore`

## TUI Architecture

- Module: `github.com/parbots/dots`
- Entry: `tui/main.go`
- `internal/runner/` — exec wrapper for chezmoi/git/brew
- `internal/scheduler/` — delegates to `scripts/schedule.sh`
- `internal/app/` — Bubble Tea models, one per tab
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add CLAUDE.md for Claude Code context"
```

---

### Task 8: Create README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README.md**

Create a human-readable `README.md` covering:

- Project title and one-line description
- What configs are managed (kitty, nvim, zsh, homebrew)
- Quick start: how to bootstrap on a new machine (`install.sh`)
- Usage: how to use the scripts (update, push, sync)
- TUI: how to build and launch the TUI
- Multi-machine: how the templating works for different OSes/machine types
- Scheduled sync: how to enable/disable
- Repository structure overview
- Prerequisites (chezmoi >= 2.40.0, Go >= 1.22, git with SSH/credential helper)

Use clear headings, code blocks for commands, and keep it concise.

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README.md"
```

---

## Chunk 2: Automation Scripts

### Task 9: Create update.sh

**Files:**
- Create: `scripts/update.sh`
- Test: Manual run + shellcheck

- [ ] **Step 1: Write update.sh**

Create `scripts/update.sh`:

```bash
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
```

- [ ] **Step 2: Make executable and lint**

```bash
chmod +x scripts/update.sh
shellcheck scripts/update.sh
```

Expected: No shellcheck warnings.

- [ ] **Step 3: Commit**

```bash
git add scripts/update.sh
git commit -m "feat: add update.sh script"
```

---

### Task 10: Create push.sh

**Files:**
- Create: `scripts/push.sh`
- Test: shellcheck

- [ ] **Step 1: Write push.sh**

Create `scripts/push.sh`:

```bash
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

if git diff --quiet && git diff --cached --quiet; then
    warn "No changes to push."
    exit 0
fi

info "Staging changes..."
git add -A

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
```

- [ ] **Step 2: Make executable and lint**

```bash
chmod +x scripts/push.sh
shellcheck scripts/push.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/push.sh
git commit -m "feat: add push.sh script"
```

---

### Task 11: Create sync.sh

**Files:**
- Create: `scripts/sync.sh`
- Test: shellcheck

- [ ] **Step 1: Write sync.sh**

Create `scripts/sync.sh`:

```bash
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
    # push.sh exits 0 on "no changes" so a failure here is real
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
```

- [ ] **Step 2: Make executable and lint**

```bash
chmod +x scripts/sync.sh
shellcheck scripts/sync.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/sync.sh
git commit -m "feat: add sync.sh script with JSON logging"
```

---

### Task 12: Create schedule.sh

**Files:**
- Create: `scripts/schedule.sh`
- Test: shellcheck

- [ ] **Step 1: Write schedule.sh**

Create `scripts/schedule.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTS_DIR="${DOTS_DIR:-$HOME/dev/dots}"
SYNC_SCRIPT="$DOTS_DIR/scripts/sync.sh"

# Defaults
DEFAULT_INTERVAL=1800  # 30 minutes in seconds

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

# --- macOS (launchd) ---
PLIST_LABEL="com.dots.sync"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

generate_plist() {
    local interval="${1:-$DEFAULT_INTERVAL}"
    cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SYNC_SCRIPT</string>
    </array>
    <key>StartInterval</key>
    <integer>$interval</integer>
    <key>StandardOutPath</key>
    <string>$HOME/.local/state/dots/launchd-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.local/state/dots/launchd-stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
PLIST
}

# --- Linux (systemd) ---
SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="dots-sync"

generate_service() {
    cat <<SERVICE
[Unit]
Description=dots sync

[Service]
Type=oneshot
ExecStart=$SYNC_SCRIPT
Environment=PATH=/usr/local/bin:/usr/bin:/bin
SERVICE
}

generate_timer() {
    local interval="${1:-$DEFAULT_INTERVAL}"
    local minutes=$(( interval / 60 ))
    cat <<TIMER
[Unit]
Description=dots sync timer

[Timer]
OnBootSec=5min
OnUnitActiveSec=${minutes}min
Unit=$SERVICE_NAME.service

[Install]
WantedBy=timers.target
TIMER
}

# --- Commands ---

cmd_enable() {
    local interval="${1:-$DEFAULT_INTERVAL}"

    if [[ "$OS" == "Darwin" ]]; then
        mkdir -p "$(dirname "$PLIST_PATH")"
        mkdir -p "$HOME/.local/state/dots"
        generate_plist "$interval" > "$PLIST_PATH"
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        launchctl load "$PLIST_PATH"
        success "Scheduled sync enabled (launchd, every $((interval / 60))m)."

    elif [[ "$OS" == "Linux" ]]; then
        mkdir -p "$SYSTEMD_DIR"
        mkdir -p "$HOME/.local/state/dots"
        generate_service > "$SYSTEMD_DIR/$SERVICE_NAME.service"
        generate_timer "$interval" > "$SYSTEMD_DIR/$SERVICE_NAME.timer"
        systemctl --user daemon-reload
        systemctl --user enable --now "$SERVICE_NAME.timer"
        success "Scheduled sync enabled (systemd, every $((interval / 60))m)."

    else
        error "Unsupported OS: $OS"
        exit 1
    fi
}

cmd_disable() {
    if [[ "$OS" == "Darwin" ]]; then
        if [[ -f "$PLIST_PATH" ]]; then
            launchctl unload "$PLIST_PATH" 2>/dev/null || true
            rm -f "$PLIST_PATH"
            success "Scheduled sync disabled (launchd)."
        else
            warn "Scheduled sync is not enabled."
        fi

    elif [[ "$OS" == "Linux" ]]; then
        if systemctl --user is-enabled "$SERVICE_NAME.timer" &>/dev/null; then
            systemctl --user disable --now "$SERVICE_NAME.timer"
            rm -f "$SYSTEMD_DIR/$SERVICE_NAME.service" "$SYSTEMD_DIR/$SERVICE_NAME.timer"
            systemctl --user daemon-reload
            success "Scheduled sync disabled (systemd)."
        else
            warn "Scheduled sync is not enabled."
        fi

    else
        error "Unsupported OS: $OS"
        exit 1
    fi
}

cmd_status() {
    if [[ "$OS" == "Darwin" ]]; then
        if launchctl list "$PLIST_LABEL" &>/dev/null; then
            success "Scheduled sync: ACTIVE (launchd)"
            launchctl list "$PLIST_LABEL" 2>/dev/null | head -5
        else
            warn "Scheduled sync: INACTIVE"
        fi

    elif [[ "$OS" == "Linux" ]]; then
        if systemctl --user is-active "$SERVICE_NAME.timer" &>/dev/null; then
            success "Scheduled sync: ACTIVE (systemd)"
            systemctl --user status "$SERVICE_NAME.timer" --no-pager
        else
            warn "Scheduled sync: INACTIVE"
        fi
    fi

    # Show last sync from log
    local LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/dots/sync.log"
    if [[ -f "$LOG_FILE" ]]; then
        info "Last sync:"
        tail -1 "$LOG_FILE"
    fi
}

# --- Main ---

case "${1:-}" in
    enable)
        # Optional second arg: interval in seconds (or minutes with 'm' suffix)
        if [[ -n "${2:-}" ]]; then
            ARG="$2"
            if [[ "$ARG" == *m ]]; then
                INTERVAL=$(( ${ARG%m} * 60 ))
            else
                INTERVAL="$ARG"
            fi
            cmd_enable "$INTERVAL"
        else
            cmd_enable
        fi
        ;;
    disable)
        cmd_disable
        ;;
    status)
        cmd_status
        ;;
    *)
        echo "Usage: schedule.sh {enable [interval]|disable|status}"
        echo ""
        echo "  enable [interval]  Enable scheduled sync (default: 30m)"
        echo "                     interval: seconds, or Nm for minutes (e.g., 15m)"
        echo "  disable            Disable scheduled sync"
        echo "  status             Show scheduler status and last sync"
        exit 1
        ;;
esac
```

- [ ] **Step 2: Make executable and lint**

```bash
chmod +x scripts/schedule.sh
shellcheck scripts/schedule.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/schedule.sh
git commit -m "feat: add schedule.sh for launchd/systemd sync scheduling"
```

---

### Task 13: Create install.sh

**Files:**
- Create: `scripts/install.sh`
- Test: shellcheck

- [ ] **Step 1: Write install.sh**

Create `scripts/install.sh`:

```bash
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

# --- Step 1: Install chezmoi ---
version_gte() {
    # Returns 0 if $1 >= $2 (semantic version comparison)
    printf '%s\n%s' "$2" "$1" | sort -V -C
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

# --- Step 2: Clone repo ---
if [[ -d "$DOTS_DIR/.git" ]]; then
    info "dots repo already exists at $DOTS_DIR."
else
    info "Cloning dots repo..."
    mkdir -p "$(dirname "$DOTS_DIR")"
    git clone "$DOTS_REPO" "$DOTS_DIR"
    success "Cloned to $DOTS_DIR."
fi

# --- Step 3: Create state directory ---
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/dots"

# --- Step 4: Initialize chezmoi ---
info "Initializing chezmoi..."
chezmoi init --source "$DOTS_DIR/configs"
success "chezmoi initialized."

# --- Step 5: Apply configs ---
info "Applying configs..."
chezmoi apply -v
success "Configs applied."

# --- Step 6: Homebrew packages (macOS only) ---
if [[ "$OS" == "Darwin" ]]; then
    if [[ -f "$DOTS_DIR/configs/Brewfile" ]]; then
        info "Installing Homebrew packages..."
        brew bundle --file="$DOTS_DIR/configs/Brewfile"
        success "Homebrew packages installed."
    fi
fi

# --- Step 7: Check git auth ---
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    success "Git SSH authentication configured."
elif git config --global credential.helper &>/dev/null; then
    success "Git credential helper configured."
else
    warn "Warning: No SSH key or git credential helper detected."
    warn "Automated push/sync will not work without non-interactive git auth."
    warn "Set up SSH keys or a credential helper before using push.sh or sync.sh."
fi

# --- Step 8: Optionally build TUI ---
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
```

- [ ] **Step 2: Make executable and lint**

```bash
chmod +x scripts/install.sh
shellcheck scripts/install.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/install.sh
git commit -m "feat: add install.sh bootstrap script"
```

---

## Chunk 3: Go TUI Application

### Task 14: Initialize Go module and install dependencies

**Files:**
- Create: `tui/go.mod`
- Create: `tui/go.sum`
- Create: `Makefile`

- [ ] **Step 1: Initialize Go module**

```bash
mkdir -p tui
cd tui
go mod init github.com/parbots/dots
go get github.com/charmbracelet/bubbletea@latest
go get github.com/charmbracelet/lipgloss@latest
go get github.com/charmbracelet/bubbles@latest
```

- [ ] **Step 2: Create top-level Makefile**

Create `Makefile` at repo root:

```makefile
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
LDFLAGS := -ldflags "-X main.version=$(VERSION)"

.PHONY: build install clean test lint

build:
	cd tui && go build $(LDFLAGS) -o dots .

install: build
	mkdir -p $(HOME)/bin
	cp tui/dots $(HOME)/bin/dots

clean:
	rm -f tui/dots

test:
	cd tui && go test ./...

lint:
	shellcheck scripts/*.sh
	cd tui && go vet ./...
```

- [ ] **Step 3: Commit**

```bash
git add tui/go.mod tui/go.sum Makefile
git commit -m "feat: initialize Go module and Makefile"
```

---

### Task 15: Create runner package

**Files:**
- Create: `tui/internal/runner/runner.go`
- Create: `tui/internal/runner/runner_test.go`

- [ ] **Step 1: Write runner_test.go**

Create `tui/internal/runner/runner_test.go`:

```go
package runner_test

import (
	"testing"
	"time"

	"github.com/parbots/dots/internal/runner"
)

func TestRunSync(t *testing.T) {
	r := runner.New("/tmp/test-dots")
	result := r.Run("echo", "hello")

	if result.ExitCode != 0 {
		t.Errorf("expected exit code 0, got %d", result.ExitCode)
	}
	if result.Stdout != "hello\n" {
		t.Errorf("expected 'hello\\n', got %q", result.Stdout)
	}
	if result.Duration < 0 {
		t.Errorf("expected non-negative duration, got %v", result.Duration)
	}
}

func TestRunFailure(t *testing.T) {
	r := runner.New("/tmp/test-dots")
	result := r.Run("false")

	if result.ExitCode == 0 {
		t.Error("expected non-zero exit code")
	}
}

func TestRunStream(t *testing.T) {
	r := runner.New("/tmp/test-dots")
	lines := make(chan string, 10)

	go func() {
		r.RunStream("echo", lines, "line1")
		close(lines)
	}()

	var received []string
	timeout := time.After(5 * time.Second)
	for {
		select {
		case line, ok := <-lines:
			if !ok {
				goto done
			}
			received = append(received, line)
		case <-timeout:
			t.Fatal("timeout waiting for stream output")
		}
	}
done:

	if len(received) == 0 {
		t.Error("expected at least one line of output")
	}
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd tui && go test ./internal/runner/ -v
```

Expected: Compilation failure (runner package doesn't exist yet).

- [ ] **Step 3: Write runner.go**

Create `tui/internal/runner/runner.go`:

```go
package runner

import (
	"bufio"
	"bytes"
	"os/exec"
	"time"
)

// RunResult holds the output and metadata of a completed command.
type RunResult struct {
	Stdout   string
	Stderr   string
	ExitCode int
	Duration time.Duration
}

// Runner executes commands with a configured dots directory.
type Runner struct {
	DotsDir string
}

// New creates a Runner with the given dots directory.
func New(dotsDir string) *Runner {
	return &Runner{DotsDir: dotsDir}
}

// Run executes a command synchronously and returns the result.
func (r *Runner) Run(name string, args ...string) RunResult {
	start := time.Now()

	cmd := exec.Command(name, args...)
	cmd.Dir = r.DotsDir

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	duration := time.Since(start)

	exitCode := 0
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		} else {
			exitCode = -1
		}
	}

	return RunResult{
		Stdout:   stdout.String(),
		Stderr:   stderr.String(),
		ExitCode: exitCode,
		Duration: duration,
	}
}

// RunStream executes a command and sends stdout lines to the provided channel.
// The caller is responsible for closing the channel after RunStream returns.
func (r *Runner) RunStream(name string, lines chan<- string, args ...string) RunResult {
	start := time.Now()

	cmd := exec.Command(name, args...)
	cmd.Dir = r.DotsDir

	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return RunResult{ExitCode: -1, Stderr: err.Error(), Duration: time.Since(start)}
	}

	if err := cmd.Start(); err != nil {
		return RunResult{ExitCode: -1, Stderr: err.Error(), Duration: time.Since(start)}
	}

	scanner := bufio.NewScanner(stdout)
	var allOutput bytes.Buffer
	for scanner.Scan() {
		line := scanner.Text()
		allOutput.WriteString(line + "\n")
		lines <- line
	}

	err = cmd.Wait()
	duration := time.Since(start)

	exitCode := 0
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		} else {
			exitCode = -1
		}
	}

	return RunResult{
		Stdout:   allOutput.String(),
		Stderr:   stderr.String(),
		ExitCode: exitCode,
		Duration: duration,
	}
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd tui && go test ./internal/runner/ -v
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add tui/internal/runner/
git commit -m "feat: add runner package for command execution"
```

---

### Task 16: Create scheduler package

**Files:**
- Create: `tui/internal/scheduler/scheduler.go`
- Create: `tui/internal/scheduler/scheduler_test.go`

- [ ] **Step 1: Write scheduler_test.go**

Create `tui/internal/scheduler/scheduler_test.go`:

```go
package scheduler_test

import (
	"strings"
	"testing"

	"github.com/parbots/dots/internal/scheduler"
)

func TestParseStatusActive(t *testing.T) {
	output := "\033[0;32mScheduled sync: ACTIVE (launchd)\033[0m\n"
	status := scheduler.ParseStatus(output)

	if !status.Active {
		t.Error("expected Active to be true")
	}
}

func TestParseStatusInactive(t *testing.T) {
	output := "\033[0;33mScheduled sync: INACTIVE\033[0m\n"
	status := scheduler.ParseStatus(output)

	if status.Active {
		t.Error("expected Active to be false")
	}
}

func TestScheduleScriptPath(t *testing.T) {
	s := scheduler.New("/home/user/dev/dots")
	path := s.ScriptPath()

	if !strings.HasSuffix(path, "scripts/schedule.sh") {
		t.Errorf("expected path ending in scripts/schedule.sh, got %s", path)
	}
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd tui && go test ./internal/scheduler/ -v
```

Expected: Compilation failure.

- [ ] **Step 3: Write scheduler.go**

Create `tui/internal/scheduler/scheduler.go`:

```go
package scheduler

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/parbots/dots/internal/runner"
)

// Status represents the current state of the scheduled sync.
type Status struct {
	Active   bool
	Backend  string // "launchd", "systemd", or ""
	LastSync string // last line from sync log, if available
	Raw      string // full output from schedule.sh status
}

// Scheduler manages scheduled sync via scripts/schedule.sh.
type Scheduler struct {
	dotsDir string
	runner  *runner.Runner
}

// New creates a Scheduler for the given dots directory.
func New(dotsDir string) *Scheduler {
	return &Scheduler{
		dotsDir: dotsDir,
		runner:  runner.New(dotsDir),
	}
}

// ScriptPath returns the path to schedule.sh.
func (s *Scheduler) ScriptPath() string {
	return filepath.Join(s.dotsDir, "scripts", "schedule.sh")
}

// Enable enables scheduled sync with the given interval (e.g., "30m", "3600").
func (s *Scheduler) Enable(interval string) error {
	args := []string{s.ScriptPath(), "enable"}
	if interval != "" {
		args = append(args, interval)
	}
	result := s.runner.Run("bash", args...)
	if result.ExitCode != 0 {
		return fmt.Errorf("schedule enable failed: %s", result.Stderr)
	}
	return nil
}

// Disable disables scheduled sync.
func (s *Scheduler) Disable() error {
	result := s.runner.Run("bash", s.ScriptPath(), "disable")
	if result.ExitCode != 0 {
		return fmt.Errorf("schedule disable failed: %s", result.Stderr)
	}
	return nil
}

// GetStatus returns the current scheduler status.
func (s *Scheduler) GetStatus() Status {
	result := s.runner.Run("bash", s.ScriptPath(), "status")
	return ParseStatus(result.Stdout)
}

// ParseStatus parses the output of schedule.sh status into a Status struct.
func ParseStatus(output string) Status {
	status := Status{Raw: output}

	// Strip ANSI escape codes for parsing
	clean := stripANSI(output)

	if strings.Contains(clean, "ACTIVE") {
		status.Active = true
		if strings.Contains(clean, "launchd") {
			status.Backend = "launchd"
		} else if strings.Contains(clean, "systemd") {
			status.Backend = "systemd"
		}
	}

	// Extract last sync line
	lines := strings.Split(strings.TrimSpace(clean), "\n")
	for i := len(lines) - 1; i >= 0; i-- {
		if strings.HasPrefix(lines[i], "{") {
			status.LastSync = lines[i]
			break
		}
	}

	return status
}

// stripANSI removes ANSI escape codes from a string.
func stripANSI(s string) string {
	var result strings.Builder
	i := 0
	for i < len(s) {
		if s[i] == '\033' {
			// Skip until 'm'
			for i < len(s) && s[i] != 'm' {
				i++
			}
			i++ // skip the 'm'
		} else {
			result.WriteByte(s[i])
			i++
		}
	}
	return result.String()
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd tui && go test ./internal/scheduler/ -v
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add tui/internal/scheduler/
git commit -m "feat: add scheduler package wrapping schedule.sh"
```

---

### Task 17: Create TUI theme and shared styles

**Files:**
- Create: `tui/internal/app/theme.go`

- [ ] **Step 1: Write theme.go**

Create `tui/internal/app/theme.go` — Catppuccin Mocha color definitions and shared Lip Gloss styles:

```go
package app

import "github.com/charmbracelet/lipgloss"

// Catppuccin Mocha palette
var (
	ColorRosewater = lipgloss.Color("#f5e0dc")
	ColorFlamingo  = lipgloss.Color("#f2cdcd")
	ColorPink      = lipgloss.Color("#f5c2e7")
	ColorMauve     = lipgloss.Color("#cba6f7")
	ColorRed       = lipgloss.Color("#f38ba8")
	ColorMaroon    = lipgloss.Color("#eba0ac")
	ColorPeach     = lipgloss.Color("#fab387")
	ColorYellow    = lipgloss.Color("#f9e2af")
	ColorGreen     = lipgloss.Color("#a6e3a1")
	ColorTeal      = lipgloss.Color("#94e2d5")
	ColorSky       = lipgloss.Color("#89dceb")
	ColorSapphire  = lipgloss.Color("#74c7ec")
	ColorBlue      = lipgloss.Color("#89b4fa")
	ColorLavender  = lipgloss.Color("#b4befe")
	ColorText      = lipgloss.Color("#cdd6f4")
	ColorSubtext1  = lipgloss.Color("#bac2de")
	ColorSubtext0  = lipgloss.Color("#a6adc8")
	ColorOverlay2  = lipgloss.Color("#9399b2")
	ColorOverlay1  = lipgloss.Color("#7f849c")
	ColorOverlay0  = lipgloss.Color("#6c7086")
	ColorSurface2  = lipgloss.Color("#585b70")
	ColorSurface1  = lipgloss.Color("#45475a")
	ColorSurface0  = lipgloss.Color("#313244")
	ColorBase      = lipgloss.Color("#1e1e2e")
	ColorMantle    = lipgloss.Color("#181825")
	ColorCrust     = lipgloss.Color("#11111b")
)

// Shared styles
var (
	StyleTitle = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorMauve)

	StyleSubtitle = lipgloss.NewStyle().
			Foreground(ColorSubtext0)

	StyleSuccess = lipgloss.NewStyle().
			Foreground(ColorGreen)

	StyleWarning = lipgloss.NewStyle().
			Foreground(ColorYellow)

	StyleError = lipgloss.NewStyle().
			Foreground(ColorRed)

	StyleBorder = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(ColorSurface2)

	StyleActiveTab = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorMauve).
			Border(lipgloss.NormalBorder(), false, false, true, false).
			BorderForeground(ColorMauve)

	StyleInactiveTab = lipgloss.NewStyle().
			Foreground(ColorOverlay1).
			Border(lipgloss.NormalBorder(), false, false, true, false).
			BorderForeground(ColorSurface0)

	StyleStatusDot = lipgloss.NewStyle().
			Bold(true)

	StyleDimmed = lipgloss.NewStyle().
			Foreground(ColorOverlay0)

	StyleKey = lipgloss.NewStyle().
			Foreground(ColorLavender).
			Bold(true)

	StyleHelp = lipgloss.NewStyle().
			Foreground(ColorOverlay1)
)
```

- [ ] **Step 2: Commit**

```bash
git add tui/internal/app/theme.go
git commit -m "feat: add Catppuccin Mocha theme and shared styles"
```

---

### Task 18: Create toast model

**Files:**
- Create: `tui/internal/app/toast.go`

- [ ] **Step 1: Write toast.go**

Create `tui/internal/app/toast.go`:

```go
package app

import (
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// ToastLevel determines the toast's visual style.
type ToastLevel int

const (
	ToastSuccess ToastLevel = iota
	ToastWarning
	ToastError
	ToastInfo
)

const toastDuration = 3 * time.Second

// ToastMsg triggers a new toast notification.
type ToastMsg struct {
	Message string
	Level   ToastLevel
}

// toastExpiredMsg signals that the current toast should be dismissed.
type toastExpiredMsg struct{}

// ToastModel manages toast notification display and auto-dismiss.
type ToastModel struct {
	message string
	level   ToastLevel
	visible bool
	width   int
}

func NewToastModel() ToastModel {
	return ToastModel{}
}

func (m ToastModel) Update(msg tea.Msg) (ToastModel, tea.Cmd) {
	switch msg := msg.(type) {
	case ToastMsg:
		m.message = msg.Message
		m.level = msg.Level
		m.visible = true
		return m, tea.Tick(toastDuration, func(time.Time) tea.Msg {
			return toastExpiredMsg{}
		})
	case toastExpiredMsg:
		m.visible = false
		return m, nil
	}
	return m, nil
}

func (m ToastModel) View() string {
	if !m.visible {
		return ""
	}

	var style lipgloss.Style
	var icon string

	switch m.level {
	case ToastSuccess:
		style = StyleSuccess
		icon = "  "
	case ToastWarning:
		style = StyleWarning
		icon = "  "
	case ToastError:
		style = StyleError
		icon = "  "
	default:
		style = lipgloss.NewStyle().Foreground(ColorBlue)
		icon = "  "
	}

	content := style.Render(icon + m.message)

	return lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(style.GetForeground()).
		Padding(0, 1).
		Width(m.width - 4).
		Render(content)
}

func (m *ToastModel) SetWidth(w int) {
	m.width = w
}
```

- [ ] **Step 2: Commit**

```bash
git add tui/internal/app/toast.go
git commit -m "feat: add toast notification model"
```

---

### Task 19: Create status tab

**Files:**
- Create: `tui/internal/app/status.go`

- [ ] **Step 1: Write status.go**

Create `tui/internal/app/status.go` — the default tab showing sync state, machine identity, recent activity:

```go
package app

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/parbots/dots/internal/runner"
)

// SyncLogEntry represents a single line from the sync log.
type SyncLogEntry struct {
	Timestamp  string `json:"timestamp"`
	Action     string `json:"action"`
	Result     string `json:"result"`
	DurationMs int    `json:"duration_ms"`
	Details    string `json:"details"`
}

// GitStatus holds ahead/behind counts and dirty state.
type GitStatus struct {
	Ahead      int
	Behind     int
	Dirty      int
	DirtyFiles []string
}

type gitStatusMsg GitStatus
type syncLogMsg []SyncLogEntry

// StatusModel is the Bubble Tea model for the Status tab.
type StatusModel struct {
	dotsDir     string
	gitStatus   GitStatus
	logEntries  []SyncLogEntry
	machineType string
	osName      string
	arch        string
	spinner     spinner.Model
	loading     bool
	expanded    bool // expand dirty file list
	width       int
	height      int
}

func NewStatusModel(dotsDir string) StatusModel {
	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(ColorMauve)

	return StatusModel{
		dotsDir: dotsDir,
		spinner: s,
		loading: true,
	}
}

func (m StatusModel) Init() tea.Cmd {
	return tea.Batch(m.spinner.Tick, m.fetchGitStatus(), m.fetchSyncLog())
}

func (m StatusModel) Update(msg tea.Msg) (StatusModel, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		cmds = append(cmds, cmd)

	case gitStatusMsg:
		m.gitStatus = GitStatus(msg)
		m.loading = false

	case syncLogMsg:
		m.logEntries = []SyncLogEntry(msg)

	case tea.KeyMsg:
		if msg.String() == "enter" {
			m.expanded = !m.expanded
		}
	}

	return m, tea.Batch(cmds...)
}

func (m StatusModel) View() string {
	var b strings.Builder

	// Sync status
	statusDot := StyleStatusDot.Foreground(ColorGreen).Render("●")
	statusText := "Up to date"
	if m.loading {
		statusDot = m.spinner.View()
		statusText = "Checking..."
	} else if m.gitStatus.Ahead > 0 || m.gitStatus.Behind > 0 || m.gitStatus.Dirty > 0 {
		statusDot = StyleStatusDot.Foreground(ColorYellow).Render("●")
		parts := []string{}
		if m.gitStatus.Ahead > 0 {
			parts = append(parts, fmt.Sprintf("▲ %d ahead", m.gitStatus.Ahead))
		}
		if m.gitStatus.Behind > 0 {
			parts = append(parts, fmt.Sprintf("▼ %d behind", m.gitStatus.Behind))
		}
		if m.gitStatus.Dirty > 0 {
			parts = append(parts, fmt.Sprintf("%d changed", m.gitStatus.Dirty))
		}
		statusText = strings.Join(parts, "  ")
	}

	b.WriteString(fmt.Sprintf("  %s Sync Status          %s\n", statusDot, statusText))

	// Last sync
	lastSync := StyleDimmed.Render("never")
	if len(m.logEntries) > 0 {
		last := m.logEntries[len(m.logEntries)-1]
		if t, err := time.Parse(time.RFC3339, last.Timestamp); err == nil {
			lastSync = relativeTime(t)
		}
	}
	b.WriteString(fmt.Sprintf("  ● Last Sync            %s\n", lastSync))

	// Machine identity
	b.WriteString(fmt.Sprintf("  ● Machine              %s · %s · %s\n", m.machineType, m.osName, m.arch))

	// Dirty files
	if m.gitStatus.Dirty > 0 {
		expandHint := StyleDimmed.Render(" (enter to expand)")
		b.WriteString(fmt.Sprintf("  ● Uncommitted          %d files%s\n", m.gitStatus.Dirty, expandHint))
		if m.expanded {
			for _, f := range m.gitStatus.DirtyFiles {
				b.WriteString(fmt.Sprintf("      %s\n", StyleDimmed.Render(f)))
			}
		}
	}

	b.WriteString("\n")

	// Recent activity
	if len(m.logEntries) > 0 {
		activityBox := lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(ColorSurface2).
			Padding(0, 1).
			Width(m.width - 6)

		var activity strings.Builder
		activity.WriteString(StyleSubtitle.Render("Recent Activity") + "\n")

		start := 0
		if len(m.logEntries) > 20 {
			start = len(m.logEntries) - 20
		}
		for i := len(m.logEntries) - 1; i >= start; i-- {
			entry := m.logEntries[i]
			icon := StyleSuccess.Render("✓")
			if entry.Result != "success" {
				icon = StyleError.Render("✗")
			}
			ts := ""
			if t, err := time.Parse(time.RFC3339, entry.Timestamp); err == nil {
				ts = t.Local().Format("15:04")
			}
			activity.WriteString(fmt.Sprintf("  %s %s  %s\n", icon, StyleDimmed.Render(ts), entry.Details))
		}

		b.WriteString(activityBox.Render(activity.String()))
	}

	return b.String()
}

func (m StatusModel) fetchGitStatus() tea.Cmd {
	return func() tea.Msg {
		r := runner.New(m.dotsDir)
		status := GitStatus{}

		// Get ahead/behind
		result := r.Run("git", "rev-list", "--left-right", "--count", "HEAD...@{upstream}")
		if result.ExitCode == 0 {
			parts := strings.Fields(strings.TrimSpace(result.Stdout))
			if len(parts) == 2 {
				fmt.Sscanf(parts[0], "%d", &status.Ahead)
				fmt.Sscanf(parts[1], "%d", &status.Behind)
			}
		}

		// Get dirty files
		result = r.Run("git", "status", "--porcelain")
		if result.ExitCode == 0 {
			for _, line := range strings.Split(strings.TrimSpace(result.Stdout), "\n") {
				if line != "" {
					status.Dirty++
					if len(line) > 3 {
						status.DirtyFiles = append(status.DirtyFiles, strings.TrimSpace(line[3:]))
					}
				}
			}
		}

		return gitStatusMsg(status)
	}
}

func (m StatusModel) fetchSyncLog() tea.Cmd {
	return func() tea.Msg {
		logPath := filepath.Join(os.Getenv("HOME"), ".local", "state", "dots", "sync.log")
		data, err := os.ReadFile(logPath)
		if err != nil {
			return syncLogMsg(nil)
		}

		var entries []SyncLogEntry
		for _, line := range strings.Split(strings.TrimSpace(string(data)), "\n") {
			if line == "" {
				continue
			}
			var entry SyncLogEntry
			if err := json.Unmarshal([]byte(line), &entry); err == nil {
				entries = append(entries, entry)
			}
		}

		return syncLogMsg(entries)
	}
}

func (m *StatusModel) SetSize(w, h int) {
	m.width = w
	m.height = h
}

func (m *StatusModel) SetMachineInfo(machineType, osName, arch string) {
	m.machineType = machineType
	m.osName = osName
	m.arch = arch
}

func relativeTime(t time.Time) string {
	d := time.Since(t)
	switch {
	case d < time.Minute:
		return "just now"
	case d < time.Hour:
		m := int(d.Minutes())
		if m == 1 {
			return "1 minute ago"
		}
		return fmt.Sprintf("%d minutes ago", m)
	case d < 24*time.Hour:
		h := int(d.Hours())
		if h == 1 {
			return "1 hour ago"
		}
		return fmt.Sprintf("%d hours ago", h)
	default:
		days := int(d.Hours() / 24)
		if days == 1 {
			return "1 day ago"
		}
		return fmt.Sprintf("%d days ago", days)
	}
}
```

- [ ] **Step 2: Commit**

```bash
git add tui/internal/app/status.go
git commit -m "feat: add status tab model"
```

---

### Task 20: Create configs tab

**Files:**
- Create: `tui/internal/app/configs.go`

- [ ] **Step 1: Write configs.go**

Create `tui/internal/app/configs.go` — browsable config categories derived from the chezmoi source dir, with diff preview and edit actions:

```go
package app

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/parbots/dots/internal/runner"
)

type configCategory struct {
	Name  string
	Icon  string
	Files []string
}

type diffResultMsg struct {
	Content string
}

// ConfigsModel is the Bubble Tea model for the Configs tab.
type ConfigsModel struct {
	dotsDir    string
	runner     *runner.Runner
	categories []configCategory
	cursor     int
	fileCursor int
	inFiles    bool // true when browsing files within a category
	diffView   viewport.Model
	showDiff   bool
	width      int
	height     int
}

func NewConfigsModel(dotsDir string) ConfigsModel {
	return ConfigsModel{
		dotsDir:  dotsDir,
		runner:   runner.New(dotsDir),
		diffView: viewport.New(0, 0),
	}
}

func (m ConfigsModel) Init() tea.Cmd {
	return m.scanCategories()
}

func (m ConfigsModel) Update(msg tea.Msg) (ConfigsModel, tea.Cmd) {
	switch msg := msg.(type) {
	case []configCategory:
		m.categories = msg

	case diffResultMsg:
		m.diffView.SetContent(msg.Content)
		m.showDiff = true

	case tea.KeyMsg:
		if m.showDiff {
			switch msg.String() {
			case "esc", "q":
				m.showDiff = false
				return m, nil
			default:
				var cmd tea.Cmd
				m.diffView, cmd = m.diffView.Update(msg)
				return m, cmd
			}
		}

		switch msg.String() {
		case "j", "down":
			if m.inFiles {
				if m.fileCursor < len(m.categories[m.cursor].Files)-1 {
					m.fileCursor++
				}
			} else if m.cursor < len(m.categories)-1 {
				m.cursor++
			}
		case "k", "up":
			if m.inFiles {
				if m.fileCursor > 0 {
					m.fileCursor--
				}
			} else if m.cursor > 0 {
				m.cursor--
			}
		case "enter", "l", "right":
			if !m.inFiles && len(m.categories) > 0 {
				m.inFiles = true
				m.fileCursor = 0
			}
		case "esc", "h", "left":
			if m.inFiles {
				m.inFiles = false
			}
		case "d":
			if m.inFiles && len(m.categories) > 0 {
				return m, m.fetchDiff()
			}
		case "e":
			if m.inFiles && len(m.categories) > 0 {
				file := m.categories[m.cursor].Files[m.fileCursor]
				return m, m.openEditor(file)
			}
		}
	}

	return m, nil
}

func (m ConfigsModel) View() string {
	if m.showDiff {
		return m.diffView.View()
	}

	var b strings.Builder

	if len(m.categories) == 0 {
		b.WriteString(StyleDimmed.Render("  No configs found."))
		return b.String()
	}

	for i, cat := range m.categories {
		cursor := "  "
		style := lipgloss.NewStyle().Foreground(ColorText)
		if i == m.cursor && !m.inFiles {
			cursor = StyleKey.Render("> ")
			style = style.Bold(true).Foreground(ColorMauve)
		}
		b.WriteString(fmt.Sprintf("%s%s %s (%d files)\n",
			cursor, cat.Icon, style.Render(cat.Name), len(cat.Files)))

		// Show files if this category is selected and we're in file view
		if i == m.cursor && m.inFiles {
			for j, file := range cat.Files {
				fileCursor := "    "
				fileStyle := StyleDimmed
				if j == m.fileCursor {
					fileCursor = "  " + StyleKey.Render("> ")
					fileStyle = lipgloss.NewStyle().Foreground(ColorText)
				}
				b.WriteString(fmt.Sprintf("%s%s\n", fileCursor, fileStyle.Render(file)))
			}
		}
	}

	b.WriteString("\n")
	if m.inFiles {
		b.WriteString(StyleHelp.Render("  e: edit · d: diff · esc: back"))
	} else {
		b.WriteString(StyleHelp.Render("  enter: browse files · e: edit · d: diff"))
	}

	return b.String()
}

func (m ConfigsModel) scanCategories() tea.Cmd {
	return func() tea.Msg {
		var categories []configCategory
		configDir := filepath.Join(m.dotsDir, "configs", "dot_config")

		entries, err := os.ReadDir(configDir)
		if err != nil {
			return []configCategory{}
		}

		iconMap := map[string]string{
			"kitty": " ",
			"nvim":  " ",
		}

		for _, entry := range entries {
			if !entry.IsDir() {
				continue
			}
			icon := iconMap[entry.Name()]
			if icon == "" {
				icon = " "
			}

			var files []string
			filepath.Walk(filepath.Join(configDir, entry.Name()), func(path string, info os.FileInfo, err error) error {
				if err != nil || info.IsDir() {
					return nil
				}
				rel, _ := filepath.Rel(configDir, path)
				files = append(files, rel)
				return nil
			})

			categories = append(categories, configCategory{
				Name:  entry.Name(),
				Icon:  icon,
				Files: files,
			})
		}

		// Check for dot_zshrc.tmpl
		zshrcPath := filepath.Join(m.dotsDir, "configs", "dot_zshrc.tmpl")
		if _, err := os.Stat(zshrcPath); err == nil {
			categories = append(categories, configCategory{
				Name:  "zsh",
				Icon:  " ",
				Files: []string{"dot_zshrc.tmpl"},
			})
		}

		return categories
	}
}

func (m ConfigsModel) fetchDiff() tea.Cmd {
	return func() tea.Msg {
		result := m.runner.Run("chezmoi", "diff")
		return diffResultMsg{Content: result.Stdout}
	}
}

func (m ConfigsModel) openEditor(file string) tea.Cmd {
	return func() tea.Msg {
		m.runner.Run("chezmoi", "edit", file)
		return nil
	}
}

func (m *ConfigsModel) SetSize(w, h int) {
	m.width = w
	m.height = h
	m.diffView.Width = w - 4
	m.diffView.Height = h - 4
}
```

- [ ] **Step 2: Commit**

```bash
git add tui/internal/app/configs.go
git commit -m "feat: add configs tab model"
```

---

### Task 21: Create packages tab

**Files:**
- Create: `tui/internal/app/packages.go`

- [ ] **Step 1: Write packages.go**

Create `tui/internal/app/packages.go` — Brewfile viewer/editor with grouped display, search, add/remove:

```go
package app

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/parbots/dots/internal/runner"
)

type packageEntry struct {
	Type    string // "tap", "brew", "cask"
	Name    string
	Comment string
}

type brewfileLoadedMsg []packageEntry
type brewBundleCompleteMsg struct{ err error }

// PackagesModel is the Bubble Tea model for the Packages tab.
type PackagesModel struct {
	dotsDir   string
	runner    *runner.Runner
	packages  []packageEntry
	filtered  []packageEntry
	cursor    int
	search    textinput.Model
	searching bool
	adding    bool
	addInput  textinput.Model
	running   bool
	spinner   spinner.Model
	output    string
	width     int
	height    int
}

func NewPackagesModel(dotsDir string) PackagesModel {
	search := textinput.New()
	search.Placeholder = "Filter packages..."
	search.PromptStyle = lipgloss.NewStyle().Foreground(ColorMauve)

	addInput := textinput.New()
	addInput.Placeholder = "package-name"
	addInput.PromptStyle = lipgloss.NewStyle().Foreground(ColorGreen)

	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(ColorMauve)

	return PackagesModel{
		dotsDir:  dotsDir,
		runner:   runner.New(dotsDir),
		search:   search,
		addInput: addInput,
		spinner:  s,
	}
}

func (m PackagesModel) Init() tea.Cmd {
	if runtime.GOOS != "darwin" {
		return nil
	}
	return m.loadBrewfile()
}

func (m PackagesModel) Update(msg tea.Msg) (PackagesModel, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case brewfileLoadedMsg:
		m.packages = []packageEntry(msg)
		m.applyFilter()

	case brewBundleCompleteMsg:
		m.running = false
		if msg.err != nil {
			m.output = StyleError.Render("brew bundle failed: " + msg.err.Error())
		} else {
			m.output = StyleSuccess.Render("brew bundle complete")
		}

	case spinner.TickMsg:
		if m.running {
			var cmd tea.Cmd
			m.spinner, cmd = m.spinner.Update(msg)
			cmds = append(cmds, cmd)
		}

	case tea.KeyMsg:
		if m.searching {
			switch msg.String() {
			case "esc":
				m.searching = false
				m.search.Blur()
				m.search.SetValue("")
				m.applyFilter()
			case "enter":
				m.searching = false
				m.search.Blur()
			default:
				var cmd tea.Cmd
				m.search, cmd = m.search.Update(msg)
				m.applyFilter()
				cmds = append(cmds, cmd)
			}
			return m, tea.Batch(cmds...)
		}

		if m.adding {
			switch msg.String() {
			case "esc":
				m.adding = false
				m.addInput.Blur()
			case "enter":
				name := strings.TrimSpace(m.addInput.Value())
				if name != "" {
					m.addPackage(name)
				}
				m.adding = false
				m.addInput.Blur()
				m.addInput.SetValue("")
				return m, m.loadBrewfile()
			default:
				var cmd tea.Cmd
				m.addInput, cmd = m.addInput.Update(msg)
				cmds = append(cmds, cmd)
			}
			return m, tea.Batch(cmds...)
		}

		switch msg.String() {
		case "j", "down":
			if m.cursor < len(m.filtered)-1 {
				m.cursor++
			}
		case "k", "up":
			if m.cursor > 0 {
				m.cursor--
			}
		case "/":
			m.searching = true
			m.search.Focus()
			cmds = append(cmds, m.search.Cursor.BlinkCmd())
		case "a":
			m.adding = true
			m.addInput.Focus()
			cmds = append(cmds, m.addInput.Cursor.BlinkCmd())
		case "r":
			if len(m.filtered) > 0 {
				m.removePackage(m.filtered[m.cursor].Name)
				return m, m.loadBrewfile()
			}
		case "b":
			m.running = true
			m.output = ""
			cmds = append(cmds, m.spinner.Tick, m.runBrewBundle())
		}
	}

	return m, tea.Batch(cmds...)
}

func (m PackagesModel) View() string {
	if runtime.GOOS != "darwin" {
		return StyleDimmed.Render("  Packages tab is only available on macOS.")
	}

	var b strings.Builder

	if m.searching {
		b.WriteString("  " + m.search.View() + "\n\n")
	}

	if m.adding {
		b.WriteString("  Add brew package: " + m.addInput.View() + "\n\n")
	}

	// Group by type
	groups := map[string][]packageEntry{"tap": {}, "brew": {}, "cask": {}}
	for _, p := range m.filtered {
		groups[p.Type] = append(groups[p.Type], p)
	}

	globalIdx := 0
	for _, typ := range []string{"tap", "brew", "cask"} {
		pkgs := groups[typ]
		if len(pkgs) == 0 {
			continue
		}

		header := lipgloss.NewStyle().Bold(true).Foreground(ColorLavender)
		b.WriteString("  " + header.Render(strings.ToUpper(typ)) + "\n")

		for _, pkg := range pkgs {
			cursor := "    "
			style := StyleDimmed
			if globalIdx == m.cursor {
				cursor = "  " + StyleKey.Render("> ")
				style = lipgloss.NewStyle().Foreground(ColorText)
			}
			line := style.Render(pkg.Name)
			if pkg.Comment != "" {
				line += " " + StyleDimmed.Render(pkg.Comment)
			}
			b.WriteString(cursor + line + "\n")
			globalIdx++
		}
		b.WriteString("\n")
	}

	if m.running {
		b.WriteString("  " + m.spinner.View() + " Running brew bundle...\n")
	}
	if m.output != "" {
		b.WriteString("  " + m.output + "\n")
	}

	b.WriteString("\n")
	b.WriteString(StyleHelp.Render("  /: search · a: add · r: remove · b: brew bundle"))

	return b.String()
}

func (m PackagesModel) loadBrewfile() tea.Cmd {
	return func() tea.Msg {
		brewfilePath := filepath.Join(m.dotsDir, "configs", "Brewfile")
		data, err := os.ReadFile(brewfilePath)
		if err != nil {
			return brewfileLoadedMsg(nil)
		}

		var packages []packageEntry
		for _, line := range strings.Split(string(data), "\n") {
			line = strings.TrimSpace(line)
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}

			var entry packageEntry
			parts := strings.SplitN(line, " ", 2)
			if len(parts) < 2 {
				continue
			}
			entry.Type = parts[0]

			// Parse name (strip quotes)
			rest := parts[1]
			if commaIdx := strings.Index(rest, ","); commaIdx != -1 {
				entry.Comment = strings.TrimSpace(rest[commaIdx+1:])
				rest = rest[:commaIdx]
			}
			entry.Name = strings.Trim(strings.TrimSpace(rest), "\"")

			packages = append(packages, entry)
		}

		return brewfileLoadedMsg(packages)
	}
}

func (m *PackagesModel) applyFilter() {
	query := strings.ToLower(m.search.Value())
	if query == "" {
		m.filtered = m.packages
	} else {
		m.filtered = nil
		for _, p := range m.packages {
			if strings.Contains(strings.ToLower(p.Name), query) {
				m.filtered = append(m.filtered, p)
			}
		}
	}
	if m.cursor >= len(m.filtered) {
		m.cursor = max(0, len(m.filtered)-1)
	}
}

func (m PackagesModel) addPackage(name string) {
	brewfilePath := filepath.Join(m.dotsDir, "configs", "Brewfile")
	f, err := os.OpenFile(brewfilePath, os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	defer f.Close()
	fmt.Fprintf(f, "brew \"%s\"\n", name)
}

func (m PackagesModel) removePackage(name string) {
	brewfilePath := filepath.Join(m.dotsDir, "configs", "Brewfile")
	data, err := os.ReadFile(brewfilePath)
	if err != nil {
		return
	}

	var lines []string
	for _, line := range strings.Split(string(data), "\n") {
		if strings.Contains(line, "\""+name+"\"") {
			continue
		}
		lines = append(lines, line)
	}

	os.WriteFile(brewfilePath, []byte(strings.Join(lines, "\n")), 0644)
}

func (m PackagesModel) runBrewBundle() tea.Cmd {
	return func() tea.Msg {
		brewfilePath := filepath.Join(m.dotsDir, "configs", "Brewfile")
		result := m.runner.Run("brew", "bundle", "--file="+brewfilePath)
		if result.ExitCode != 0 {
			return brewBundleCompleteMsg{err: fmt.Errorf("%s", result.Stderr)}
		}
		return brewBundleCompleteMsg{err: nil}
	}
}

func (m *PackagesModel) SetSize(w, h int) {
	m.width = w
	m.height = h
}
```

- [ ] **Step 2: Commit**

```bash
git add tui/internal/app/packages.go
git commit -m "feat: add packages tab model"
```

---

### Task 22: Create sync tab

**Files:**
- Create: `tui/internal/app/sync.go`

- [ ] **Step 1: Write sync.go**

Create `tui/internal/app/sync.go` — sync operations with streaming output, history, and spinners:

```go
package app

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/parbots/dots/internal/runner"
)

type syncAction int

const (
	syncActionUpdate syncAction = iota
	syncActionPush
	syncActionFull
)

// OutputLineMsg carries a line of streaming output from a running command.
type OutputLineMsg struct {
	Line string
}

// RunCompleteMsg signals that a sync operation has finished.
type RunCompleteMsg struct {
	Action   syncAction
	ExitCode int
	Err      string
	Output   string
}

type syncHistoryMsg []SyncLogEntry

// SyncModel is the Bubble Tea model for the Sync tab.
type SyncModel struct {
	dotsDir  string
	runner   *runner.Runner
	selected int // 0=Update, 1=Push, 2=Full Sync
	running  bool
	spinner  spinner.Model
	output   viewport.Model
	lines    []string
	history  []SyncLogEntry
	width    int
	height   int
}

func NewSyncModel(dotsDir string) SyncModel {
	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(ColorMauve)

	return SyncModel{
		dotsDir:  dotsDir,
		runner:   runner.New(dotsDir),
		spinner:  s,
		output:   viewport.New(0, 0),
	}
}

func (m SyncModel) Init() tea.Cmd {
	return m.loadHistory()
}

func (m SyncModel) Update(msg tea.Msg) (SyncModel, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case spinner.TickMsg:
		if m.running {
			var cmd tea.Cmd
			m.spinner, cmd = m.spinner.Update(msg)
			cmds = append(cmds, cmd)
		}

	case OutputLineMsg:
		m.lines = append(m.lines, msg.Line)
		m.output.SetContent(strings.Join(m.lines, "\n"))
		m.output.GotoBottom()

	case RunCompleteMsg:
		m.running = false
		// Add command output lines
		for _, line := range strings.Split(msg.Output, "\n") {
			if line != "" {
				m.lines = append(m.lines, line)
			}
		}
		status := StyleSuccess.Render("Done")
		if msg.ExitCode != 0 {
			status = StyleError.Render("Failed: " + msg.Err)
		}
		m.lines = append(m.lines, "", status)
		m.output.SetContent(strings.Join(m.lines, "\n"))
		m.output.GotoBottom()
		cmds = append(cmds, m.loadHistory())

	case syncHistoryMsg:
		m.history = []SyncLogEntry(msg)

	case tea.KeyMsg:
		if m.running {
			// Allow scrolling output while running
			var cmd tea.Cmd
			m.output, cmd = m.output.Update(msg)
			cmds = append(cmds, cmd)
			return m, tea.Batch(cmds...)
		}

		switch msg.String() {
		case "h", "left":
			if m.selected > 0 {
				m.selected--
			}
		case "l", "right":
			if m.selected < 2 {
				m.selected++
			}
		case "enter":
			m.running = true
			m.lines = nil
			m.output.SetContent("")
			var action syncAction
			var script string
			switch m.selected {
			case 0:
				action = syncActionUpdate
				script = "update.sh"
			case 1:
				action = syncActionPush
				script = "push.sh"
			case 2:
				action = syncActionFull
				script = "sync.sh"
			}
			cmds = append(cmds, m.spinner.Tick, m.runScript(action, script))
		}
	}

	return m, tea.Batch(cmds...)
}

func (m SyncModel) View() string {
	var b strings.Builder

	// Action buttons
	actions := []string{"Update", "Push", "Full Sync"}
	var buttons []string
	for i, a := range actions {
		if i == m.selected {
			btn := lipgloss.NewStyle().
				Bold(true).
				Foreground(ColorBase).
				Background(ColorMauve).
				Padding(0, 2).
				Render(a)
			buttons = append(buttons, btn)
		} else {
			btn := lipgloss.NewStyle().
				Foreground(ColorText).
				Border(lipgloss.RoundedBorder()).
				BorderForeground(ColorSurface2).
				Padding(0, 2).
				Render(a)
			buttons = append(buttons, btn)
		}
	}
	b.WriteString("  " + lipgloss.JoinHorizontal(lipgloss.Top, buttons...) + "\n\n")

	// Running indicator
	if m.running {
		b.WriteString("  " + m.spinner.View() + " Running...\n\n")
	}

	// Output viewport
	if len(m.lines) > 0 {
		outputBox := lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(ColorSurface2).
			Width(m.width - 6).
			Height(min(len(m.lines)+2, m.height/3))

		b.WriteString("  " + outputBox.Render(m.output.View()) + "\n\n")
	}

	// History
	if len(m.history) > 0 {
		b.WriteString("  " + StyleSubtitle.Render("History") + "\n")
		start := max(0, len(m.history)-10)
		for i := len(m.history) - 1; i >= start; i-- {
			entry := m.history[i]
			icon := StyleSuccess.Render("✓")
			if entry.Result != "success" {
				icon = StyleError.Render("✗")
			}
			dur := fmt.Sprintf("%dms", entry.DurationMs)
			b.WriteString(fmt.Sprintf("    %s  %s  %s  %s\n",
				icon,
				StyleDimmed.Render(entry.Timestamp),
				entry.Action,
				StyleDimmed.Render(dur),
			))
		}
	}

	b.WriteString("\n")
	b.WriteString(StyleHelp.Render("  ←/→: select · enter: run"))

	return b.String()
}

func (m SyncModel) runScript(action syncAction, script string) tea.Cmd {
	return func() tea.Msg {
		scriptPath := filepath.Join(m.dotsDir, "scripts", script)

		// Run synchronously, collecting all output.
		// Lines are sent as OutputLineMsg via a goroutine + sub.
		result := m.runner.Run("bash", scriptPath)

		// Send all output lines at once (each becomes a viewport line)
		// In a future iteration, this can use tea.Sub for real-time streaming.
		// For now, the output appears when the command completes.
		errMsg := ""
		if result.ExitCode != 0 {
			errMsg = result.Stderr
		}

		return RunCompleteMsg{
			Action:   action,
			ExitCode: result.ExitCode,
			Err:      errMsg,
			Output:   result.Stdout,
		}
	}
}

func (m SyncModel) loadHistory() tea.Cmd {
	return func() tea.Msg {
		logPath := filepath.Join(os.Getenv("HOME"), ".local", "state", "dots", "sync.log")
		data, err := os.ReadFile(logPath)
		if err != nil {
			return syncHistoryMsg(nil)
		}

		var entries []SyncLogEntry
		for _, line := range strings.Split(strings.TrimSpace(string(data)), "\n") {
			if line == "" {
				continue
			}
			var entry SyncLogEntry
			if err := json.Unmarshal([]byte(line), &entry); err == nil {
				entries = append(entries, entry)
			}
		}

		return syncHistoryMsg(entries)
	}
}

func (m *SyncModel) SetSize(w, h int) {
	m.width = w
	m.height = h
	m.output.Width = w - 8
	m.output.Height = h / 3
}
```

- [ ] **Step 2: Commit**

```bash
git add tui/internal/app/sync.go
git commit -m "feat: add sync tab model"
```

---

### Task 23: Create system tab

**Files:**
- Create: `tui/internal/app/system.go`

- [ ] **Step 1: Write system.go**

Create `tui/internal/app/system.go` — system info display (hardware, OS, dev tools, network, dots health):

```go
package app

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/parbots/dots/internal/runner"
	"github.com/parbots/dots/internal/scheduler"
)

type systemInfo struct {
	// Hardware
	Model  string
	Chip   string
	Memory string
	Disk   string

	// OS
	OSVersion     string
	KernelVersion string

	// Shell
	Shell        string
	ShellVersion string

	// Network
	Hostname string
	LocalIP  string

	// Dev tools (name -> version or "not found")
	Tools map[string]string

	// dots health
	ChezmoiDoctor string
	ScheduleStatus string
}

type systemInfoMsg systemInfo

// SystemModel is the Bubble Tea model for the System tab.
type SystemModel struct {
	dotsDir   string
	runner    *runner.Runner
	scheduler *scheduler.Scheduler
	info      systemInfo
	spinner   spinner.Model
	loading   bool
	cached    bool
	width     int
	height    int
}

func NewSystemModel(dotsDir string) SystemModel {
	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(ColorMauve)

	return SystemModel{
		dotsDir:   dotsDir,
		runner:    runner.New(dotsDir),
		scheduler: scheduler.New(dotsDir),
		spinner:   s,
	}
}

func (m SystemModel) Init() tea.Cmd {
	return nil // load on first focus
}

// Refresh gathers system info. Call when tab is focused.
func (m SystemModel) Refresh() tea.Cmd {
	if m.cached {
		return nil
	}
	return m.gatherInfo()
}

func (m SystemModel) Update(msg tea.Msg) (SystemModel, tea.Cmd) {
	switch msg := msg.(type) {
	case spinner.TickMsg:
		if m.loading {
			var cmd tea.Cmd
			m.spinner, cmd = m.spinner.Update(msg)
			return m, cmd
		}

	case systemInfoMsg:
		m.info = systemInfo(msg)
		m.loading = false
		m.cached = true
	}

	return m, nil
}

func (m SystemModel) View() string {
	if m.loading {
		return "  " + m.spinner.View() + " Gathering system information..."
	}

	var b strings.Builder
	sectionHeader := lipgloss.NewStyle().Bold(true).Foreground(ColorLavender)

	// Hardware
	b.WriteString("  " + sectionHeader.Render("Hardware") + "\n")
	b.WriteString(fmt.Sprintf("    Model     %s\n", m.info.Model))
	b.WriteString(fmt.Sprintf("    Chip      %s\n", m.info.Chip))
	b.WriteString(fmt.Sprintf("    Memory    %s\n", m.info.Memory))
	b.WriteString(fmt.Sprintf("    Disk      %s\n", m.info.Disk))
	b.WriteString("\n")

	// OS
	b.WriteString("  " + sectionHeader.Render("OS") + "\n")
	b.WriteString(fmt.Sprintf("    Version   %s\n", m.info.OSVersion))
	b.WriteString(fmt.Sprintf("    Kernel    %s\n", m.info.KernelVersion))
	b.WriteString("\n")

	// Shell
	b.WriteString("  " + sectionHeader.Render("Shell") + "\n")
	b.WriteString(fmt.Sprintf("    Shell     %s %s\n", m.info.Shell, m.info.ShellVersion))
	b.WriteString("\n")

	// Network
	b.WriteString("  " + sectionHeader.Render("Network") + "\n")
	b.WriteString(fmt.Sprintf("    Hostname  %s\n", m.info.Hostname))
	b.WriteString(fmt.Sprintf("    Local IP  %s\n", m.info.LocalIP))
	b.WriteString("\n")

	// Dev tools
	b.WriteString("  " + sectionHeader.Render("Dev Tools") + "\n")
	tools := []string{"chezmoi", "git", "brew", "nvim", "node", "go", "python3"}
	for _, tool := range tools {
		version, ok := m.info.Tools[tool]
		if ok && version != "" {
			b.WriteString(fmt.Sprintf("    %s %s %s\n",
				StyleSuccess.Render("✓"),
				lipgloss.NewStyle().Width(12).Render(tool),
				StyleDimmed.Render(version),
			))
		} else {
			b.WriteString(fmt.Sprintf("    %s %s %s\n",
				StyleError.Render("✗"),
				lipgloss.NewStyle().Width(12).Render(tool),
				StyleDimmed.Render("not found"),
			))
		}
	}
	b.WriteString("\n")

	// dots health
	b.WriteString("  " + sectionHeader.Render("dots Health") + "\n")
	b.WriteString(fmt.Sprintf("    Schedule  %s\n", m.info.ScheduleStatus))
	if m.info.ChezmoiDoctor != "" {
		b.WriteString(fmt.Sprintf("    Doctor    %s\n", m.info.ChezmoiDoctor))
	}

	return b.String()
}

func (m SystemModel) gatherInfo() tea.Cmd {
	return func() tea.Msg {
		info := systemInfo{
			Tools: make(map[string]string),
		}

		if runtime.GOOS == "darwin" {
			// macOS hardware info
			if out, err := exec.Command("sysctl", "-n", "hw.model").Output(); err == nil {
				info.Model = strings.TrimSpace(string(out))
			}
			if out, err := exec.Command("sysctl", "-n", "machdep.cpu.brand_string").Output(); err == nil {
				info.Chip = strings.TrimSpace(string(out))
			}
			if out, err := exec.Command("sysctl", "-n", "hw.memsize").Output(); err == nil {
				info.Memory = strings.TrimSpace(string(out))
			}
			if out, err := exec.Command("sw_vers", "-productVersion").Output(); err == nil {
				info.OSVersion = "macOS " + strings.TrimSpace(string(out))
			}
		} else {
			// Linux
			if data, err := os.ReadFile("/etc/os-release"); err == nil {
				for _, line := range strings.Split(string(data), "\n") {
					if strings.HasPrefix(line, "PRETTY_NAME=") {
						info.OSVersion = strings.Trim(strings.TrimPrefix(line, "PRETTY_NAME="), "\"")
					}
				}
			}
			if out, err := exec.Command("free", "-h", "--si").Output(); err == nil {
				lines := strings.Split(string(out), "\n")
				if len(lines) > 1 {
					fields := strings.Fields(lines[1])
					if len(fields) > 1 {
						info.Memory = fields[1]
					}
				}
			}
		}

		// Kernel
		if out, err := exec.Command("uname", "-r").Output(); err == nil {
			info.KernelVersion = strings.TrimSpace(string(out))
		}

		// Disk
		if out, err := exec.Command("df", "-h", "/").Output(); err == nil {
			lines := strings.Split(string(out), "\n")
			if len(lines) > 1 {
				fields := strings.Fields(lines[1])
				if len(fields) > 4 {
					info.Disk = fmt.Sprintf("%s used / %s total (%s)", fields[2], fields[1], fields[4])
				}
			}
		}

		// Shell
		info.Shell = os.Getenv("SHELL")
		if out, err := exec.Command(info.Shell, "--version").Output(); err == nil {
			info.ShellVersion = strings.Split(strings.TrimSpace(string(out)), "\n")[0]
		}

		// Network
		if hostname, err := os.Hostname(); err == nil {
			info.Hostname = hostname
		}

		// Dev tools
		tools := []string{"chezmoi", "git", "brew", "nvim", "node", "go", "python3"}
		for _, tool := range tools {
			if out, err := exec.Command(tool, "--version").Output(); err == nil {
				version := strings.TrimSpace(string(out))
				// Take first line only
				if idx := strings.Index(version, "\n"); idx != -1 {
					version = version[:idx]
				}
				info.Tools[tool] = version
			}
		}

		// dots health
		schedStatus := m.scheduler.GetStatus()
		if schedStatus.Active {
			info.ScheduleStatus = StyleSuccess.Render("active") + " (" + schedStatus.Backend + ")"
		} else {
			info.ScheduleStatus = StyleDimmed.Render("inactive")
		}

		if out, err := exec.Command("chezmoi", "doctor").Output(); err == nil {
			// Summarize: count ok vs warnings
			okCount := strings.Count(string(out), "ok")
			info.ChezmoiDoctor = fmt.Sprintf("%d checks passed", okCount)
		}

		return systemInfoMsg(info)
	}
}

func (m *SystemModel) SetSize(w, h int) {
	m.width = w
	m.height = h
}
```

- [ ] **Step 2: Commit**

```bash
git add tui/internal/app/system.go
git commit -m "feat: add system tab model"
```

---

### Task 24: Create settings tab

**Files:**
- Create: `tui/internal/app/settings.go`

- [ ] **Step 1: Write settings.go**

Create `tui/internal/app/settings.go` — sync toggle, interval config, chezmoi data view:

```go
package app

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/parbots/dots/internal/runner"
	"github.com/parbots/dots/internal/scheduler"
)

type settingsItem int

const (
	settingSyncToggle settingsItem = iota
	settingSyncInterval
	settingViewData
	settingEditConfig
	settingReinit
)

type scheduleActionDoneMsg struct {
	err error
}

// SettingsModel is the Bubble Tea model for the Settings tab.
type SettingsModel struct {
	dotsDir      string
	runner       *runner.Runner
	scheduler    *scheduler.Scheduler
	syncActive   bool
	syncBackend  string
	syncInterval string
	cursor       int
	spinner      spinner.Model
	processing   bool
	message      string
	intervals    []string
	intervalIdx  int
	width        int
	height       int
}

func NewSettingsModel(dotsDir string) SettingsModel {
	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(ColorMauve)

	return SettingsModel{
		dotsDir:      dotsDir,
		runner:       runner.New(dotsDir),
		scheduler:    scheduler.New(dotsDir),
		spinner:      s,
		syncInterval: "30m",
		intervals:    []string{"15m", "30m", "1h", "2h"},
		intervalIdx:  1, // default 30m
	}
}

func (m SettingsModel) Init() tea.Cmd {
	return m.refreshStatus()
}

func (m SettingsModel) Update(msg tea.Msg) (SettingsModel, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case spinner.TickMsg:
		if m.processing {
			var cmd tea.Cmd
			m.spinner, cmd = m.spinner.Update(msg)
			cmds = append(cmds, cmd)
		}

	case scheduler.Status:
		m.syncActive = msg.Active
		m.syncBackend = msg.Backend

	case scheduleActionDoneMsg:
		m.processing = false
		if msg.err != nil {
			m.message = StyleError.Render(msg.err.Error())
		} else {
			m.message = StyleSuccess.Render("Done")
		}
		cmds = append(cmds, m.refreshStatus())

	case tea.KeyMsg:
		if m.processing {
			return m, tea.Batch(cmds...)
		}

		switch msg.String() {
		case "j", "down":
			if m.cursor < 4 {
				m.cursor++
			}
		case "k", "up":
			if m.cursor > 0 {
				m.cursor--
			}
		case "enter":
			switch settingsItem(m.cursor) {
			case settingSyncToggle:
				m.processing = true
				m.message = ""
				if m.syncActive {
					cmds = append(cmds, m.spinner.Tick, m.disableSync())
				} else {
					cmds = append(cmds, m.spinner.Tick, m.enableSync())
				}
			case settingSyncInterval:
				m.intervalIdx = (m.intervalIdx + 1) % len(m.intervals)
				m.syncInterval = m.intervals[m.intervalIdx]
			case settingViewData:
				cmds = append(cmds, m.viewData())
			case settingEditConfig:
				cmds = append(cmds, m.editConfig())
			case settingReinit:
				m.processing = true
				cmds = append(cmds, m.spinner.Tick, m.reinit())
			}
		}
	}

	return m, tea.Batch(cmds...)
}

func (m SettingsModel) View() string {
	var b strings.Builder

	items := []struct {
		label string
		value string
	}{
		{
			"Scheduled Sync",
			func() string {
				if m.syncActive {
					return StyleSuccess.Render("ON") + " " + StyleDimmed.Render("("+m.syncBackend+")")
				}
				return StyleDimmed.Render("OFF")
			}(),
		},
		{"Sync Interval", StyleKey.Render(m.syncInterval) + StyleDimmed.Render("  (enter to cycle)")},
		{"View chezmoi data", StyleDimmed.Render("show template variables")},
		{"Edit chezmoi config", StyleDimmed.Render("open in $EDITOR")},
		{"Re-initialize chezmoi", StyleDimmed.Render("run chezmoi init")},
	}

	for i, item := range items {
		cursor := "  "
		style := lipgloss.NewStyle().Foreground(ColorText)
		if i == m.cursor {
			cursor = StyleKey.Render("> ")
			style = style.Bold(true).Foreground(ColorMauve)
		}
		b.WriteString(fmt.Sprintf("  %s%s    %s\n", cursor, style.Render(item.label), item.value))
	}

	if m.processing {
		b.WriteString("\n  " + m.spinner.View() + " Working...")
	}
	if m.message != "" {
		b.WriteString("\n  " + m.message)
	}

	b.WriteString("\n\n")
	b.WriteString(StyleHelp.Render("  ↑/↓: navigate · enter: select/toggle"))

	return b.String()
}

func (m SettingsModel) refreshStatus() tea.Cmd {
	return func() tea.Msg {
		return m.scheduler.GetStatus()
	}
}

func (m SettingsModel) enableSync() tea.Cmd {
	return func() tea.Msg {
		err := m.scheduler.Enable(m.syncInterval)
		return scheduleActionDoneMsg{err: err}
	}
}

func (m SettingsModel) disableSync() tea.Cmd {
	return func() tea.Msg {
		err := m.scheduler.Disable()
		return scheduleActionDoneMsg{err: err}
	}
}

func (m SettingsModel) viewData() tea.Cmd {
	return func() tea.Msg {
		result := m.runner.Run("chezmoi", "data")
		return ToastMsg{Message: "chezmoi data:\n" + result.Stdout, Level: ToastInfo}
	}
}

func (m SettingsModel) editConfig() tea.Cmd {
	return func() tea.Msg {
		m.runner.Run("chezmoi", "edit-config")
		return nil
	}
}

func (m SettingsModel) reinit() tea.Cmd {
	return func() tea.Msg {
		result := m.runner.Run("chezmoi", "init", "--source", m.dotsDir+"/configs")
		if result.ExitCode != 0 {
			return scheduleActionDoneMsg{err: fmt.Errorf("%s", result.Stderr)}
		}
		return scheduleActionDoneMsg{err: nil}
	}
}

func (m *SettingsModel) SetSize(w, h int) {
	m.width = w
	m.height = h
}
```

- [ ] **Step 2: Commit**

```bash
git add tui/internal/app/settings.go
git commit -m "feat: add settings tab model"
```

---

### Task 25: Create root app model and main.go

**Files:**
- Create: `tui/internal/app/app.go`
- Create: `tui/main.go`

- [ ] **Step 1: Write app.go — root model composing all tabs**

Create `tui/internal/app/app.go`:

```go
package app

import (
	"fmt"
	"runtime"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var tabNames = []string{"Status", "Configs", "Packages", "Sync", "System", "Settings"}

// Model is the root Bubble Tea application model.
type Model struct {
	activeTab int
	tabs      []string

	statusTab   StatusModel
	configsTab  ConfigsModel
	packagesTab PackagesModel
	syncTab     SyncModel
	systemTab   SystemModel
	settingsTab SettingsModel
	toast       ToastModel

	width  int
	height int
}

// New creates the root application model.
func New(dotsDir string) Model {
	tabs := tabNames
	// Hide Packages tab on non-macOS
	if runtime.GOOS != "darwin" {
		filtered := []string{}
		for _, t := range tabs {
			if t != "Packages" {
				filtered = append(filtered, t)
			}
		}
		tabs = filtered
	}

	return Model{
		tabs:        tabs,
		statusTab:   NewStatusModel(dotsDir),
		configsTab:  NewConfigsModel(dotsDir),
		packagesTab: NewPackagesModel(dotsDir),
		syncTab:     NewSyncModel(dotsDir),
		systemTab:   NewSystemModel(dotsDir),
		settingsTab: NewSettingsModel(dotsDir),
		toast:       NewToastModel(),
	}
}

func (m Model) Init() tea.Cmd {
	return tea.Batch(
		m.statusTab.Init(),
		m.configsTab.Init(),
		m.packagesTab.Init(),
		m.syncTab.Init(),
		m.settingsTab.Init(),
	)
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		contentHeight := msg.Height - 10 // header + tabs + footer
		m.statusTab.SetSize(msg.Width, contentHeight)
		m.configsTab.SetSize(msg.Width, contentHeight)
		m.packagesTab.SetSize(msg.Width, contentHeight)
		m.syncTab.SetSize(msg.Width, contentHeight)
		m.systemTab.SetSize(msg.Width, contentHeight)
		m.settingsTab.SetSize(msg.Width, contentHeight)
		m.toast.SetWidth(msg.Width)

	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			return m, tea.Quit
		case "tab":
			m.activeTab = (m.activeTab + 1) % len(m.tabs)
			// Refresh system tab on focus
			if m.tabs[m.activeTab] == "System" {
				cmds = append(cmds, m.systemTab.Refresh())
				m.systemTab.loading = true
				cmds = append(cmds, m.systemTab.spinner.Tick)
			}
		case "shift+tab":
			m.activeTab = (m.activeTab - 1 + len(m.tabs)) % len(m.tabs)
			if m.tabs[m.activeTab] == "System" {
				cmds = append(cmds, m.systemTab.Refresh())
				m.systemTab.loading = true
				cmds = append(cmds, m.systemTab.spinner.Tick)
			}
		}

	case ToastMsg:
		var cmd tea.Cmd
		m.toast, cmd = m.toast.Update(msg)
		cmds = append(cmds, cmd)

	case toastExpiredMsg:
		var cmd tea.Cmd
		m.toast, cmd = m.toast.Update(msg)
		cmds = append(cmds, cmd)
	}

	// Route to active tab
	switch m.tabs[m.activeTab] {
	case "Status":
		var cmd tea.Cmd
		m.statusTab, cmd = m.statusTab.Update(msg)
		cmds = append(cmds, cmd)
	case "Configs":
		var cmd tea.Cmd
		m.configsTab, cmd = m.configsTab.Update(msg)
		cmds = append(cmds, cmd)
	case "Packages":
		var cmd tea.Cmd
		m.packagesTab, cmd = m.packagesTab.Update(msg)
		cmds = append(cmds, cmd)
	case "Sync":
		var cmd tea.Cmd
		m.syncTab, cmd = m.syncTab.Update(msg)
		cmds = append(cmds, cmd)
	case "System":
		var cmd tea.Cmd
		m.systemTab, cmd = m.systemTab.Update(msg)
		cmds = append(cmds, cmd)
	case "Settings":
		var cmd tea.Cmd
		m.settingsTab, cmd = m.settingsTab.Update(msg)
		cmds = append(cmds, cmd)
	}

	return m, tea.Batch(cmds...)
}

func (m Model) View() string {
	var b strings.Builder

	// Header with dot art and gradient
	dotArt := lipgloss.NewStyle().Foreground(ColorOverlay1).Render("    ·  ·  ·  ·")
	bar := lipgloss.NewStyle().Foreground(ColorMauve).Bold(true).Render("   ╺━━━━━━━━━╸")
	// Gradient title: characters transition from Mauve to Lavender
	titleChars := []struct{ ch string; color lipgloss.Color }{
		{"d", ColorMauve}, {" ", ColorMauve},
		{"o", lipgloss.Color("#c9adf5")}, {" ", ColorMauve},
		{"t", lipgloss.Color("#c1b4f3")}, {" ", ColorMauve},
		{"s", ColorLavender},
	}
	var titleStr string
	for _, tc := range titleChars {
		titleStr += lipgloss.NewStyle().Bold(true).Foreground(tc.color).Render(tc.ch)
	}

	header := "\n" + dotArt + "\n" + bar + "  " + titleStr + "\n" + dotArt + "\n"
	b.WriteString(header + "\n")

	// Tab bar
	var tabs []string
	for i, name := range m.tabs {
		if i == m.activeTab {
			tabs = append(tabs, StyleActiveTab.Padding(0, 2).Render(name))
		} else {
			tabs = append(tabs, StyleInactiveTab.Padding(0, 2).Render(name))
		}
	}
	tabBar := lipgloss.JoinHorizontal(lipgloss.Top, tabs...)
	b.WriteString("  " + tabBar + "\n")
	b.WriteString(lipgloss.NewStyle().Foreground(ColorSurface2).Render(strings.Repeat("─", m.width)) + "\n")

	// Content
	var content string
	switch m.tabs[m.activeTab] {
	case "Status":
		content = m.statusTab.View()
	case "Configs":
		content = m.configsTab.View()
	case "Packages":
		content = m.packagesTab.View()
	case "Sync":
		content = m.syncTab.View()
	case "System":
		content = m.systemTab.View()
	case "Settings":
		content = m.settingsTab.View()
	}
	b.WriteString(content + "\n")

	// Toast overlay
	if toast := m.toast.View(); toast != "" {
		b.WriteString("\n" + toast + "\n")
	}

	// Footer
	footer := fmt.Sprintf("  %s quit · %s next tab · %s prev tab · %s update · %s push · %s help",
		StyleKey.Render("q"),
		StyleKey.Render("tab"),
		StyleKey.Render("shift+tab"),
		StyleKey.Render("u"),
		StyleKey.Render("p"),
		StyleKey.Render("?"),
	)
	b.WriteString("\n" + StyleHelp.Render(footer))

	return b.String()
}
```

- [ ] **Step 2: Write main.go**

Create `tui/main.go`:

```go
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/parbots/dots/internal/app"
)

var version = "dev"

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--version" {
		fmt.Printf("dots %s\n", version)
		os.Exit(0)
	}

	dotsDir := os.Getenv("DOTS_DIR")
	if dotsDir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			os.Exit(1)
		}
		dotsDir = filepath.Join(home, "dev", "dots")
	}

	// Verify dots dir exists
	if _, err := os.Stat(dotsDir); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "dots directory not found: %s\n", dotsDir)
		fmt.Fprintf(os.Stderr, "Set DOTS_DIR or run install.sh first.\n")
		os.Exit(1)
	}

	// Check dependencies
	deps := map[string]string{
		"chezmoi": "Install: brew install chezmoi (macOS) or https://www.chezmoi.io/install/",
		"git":     "Install: brew install git (macOS) or apt install git (Linux)",
	}
	if runtime.GOOS == "darwin" {
		deps["brew"] = "Install: https://brew.sh"
	}
	for dep, installHint := range deps {
		if _, err := exec.LookPath(dep); err != nil {
			fmt.Fprintf(os.Stderr, "required dependency not found: %s\n", dep)
			fmt.Fprintf(os.Stderr, "%s\n", installHint)
			os.Exit(1)
		}
	}

	model := app.New(dotsDir)
	p := tea.NewProgram(model, tea.WithAltScreen())

	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}
```

- [ ] **Step 3: Verify compilation**

```bash
cd tui && go mod tidy && go build -o dots .
```

Expected: Compiles successfully. Fix any import errors.

- [ ] **Step 4: Run the TUI briefly to verify it launches**

```bash
cd tui && ./dots
```

Press `q` to quit. Verify: header renders, tabs show, no crash.

- [ ] **Step 5: Commit**

```bash
git add tui/main.go tui/internal/app/app.go tui/go.mod tui/go.sum
git commit -m "feat: add root app model and main entry point"
```

---

### Task 26: Build, test, and final verification

- [ ] **Step 1: Run all Go tests**

```bash
cd tui && go test ./... -v
```

Expected: All tests pass.

- [ ] **Step 2: Lint all shell scripts**

```bash
shellcheck scripts/*.sh
```

Expected: No errors.

- [ ] **Step 3: Build via Makefile**

```bash
make build
```

Expected: `tui/dots` binary is produced.

- [ ] **Step 4: Run go vet**

```bash
cd tui && go vet ./...
```

Expected: No issues.

- [ ] **Step 5: Verify chezmoi state**

```bash
chezmoi managed
chezmoi diff
```

Expected: All configs listed, diff is clean or minimal.

- [ ] **Step 6: Commit any remaining changes**

```bash
git add -A
git commit -m "chore: final verification and cleanup"
```

---

### Task 27: Create GitHub Actions CI

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write CI workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint-scripts:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run shellcheck
        uses: ludeeus/action-shellcheck@master
        with:
          scandir: scripts

  build-and-test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.22'

      - name: Build
        run: cd tui && go build -o dots .

      - name: Test
        run: cd tui && go test ./... -v

      - name: Vet
        run: cd tui && go vet ./...

      - name: Install chezmoi
        run: |
          if [ "$RUNNER_OS" = "macOS" ]; then
            brew install chezmoi
          else
            sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
          fi

      - name: Validate chezmoi source dir
        run: chezmoi doctor --source configs/ || true
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add GitHub Actions workflow"
```
