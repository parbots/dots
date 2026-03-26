# dots — Dotfile Management System Design Spec

## Overview

A complete dotfile management system built on **chezmoi** with a **Go TUI** (Bubble Tea) for interactive management. Supports macOS and Linux with multi-machine configuration, automated sync scripts, and optional scheduled sync.

## Goals

- Store and manage developer/user configuration for kitty, nvim, zsh, and homebrew
- Support multiple machines (personal Mac, work Mac, Linux servers)
- Provide automated scripts for updating, installing, and pushing changes
- Deliver a polished TUI for interactive management with system info and visual flair
- Document everything in CLAUDE.md and README.md

## Repository Structure

```
~/dev/dots/
├── CLAUDE.md
├── README.md
├── Makefile                        # Build the TUI binary
│
├── configs/                        # chezmoi source directory
│   ├── .chezmoi.toml.tmpl          # chezmoi config (prompts for machine type)
│   ├── .chezmoiignore              # OS-conditional file ignores
│   ├── dot_config/
│   │   ├── kitty/
│   │   │   ├── kitty.conf
│   │   │   └── catppuccin-mocha.conf
│   │   └── nvim/
│   │       ├── init.lua
│   │       └── lua/
│   │           ├── config/
│   │           │   ├── autocmds.lua
│   │           │   ├── keymaps.lua
│   │           │   ├── options.lua
│   │           │   └── lazy.lua
│   │           ├── .luarc.json
│   │           └── picklevim/
│   │               ├── init.lua
│   │               ├── util/
│   │               ├── config/
│   │               ├── plugins/
│   │               └── lsp/
│   ├── dot_zshrc.tmpl              # templated for OS differences
│   ├── Brewfile                    # homebrew packages
│   └── run_onchange_install-packages.sh.tmpl
│
├── scripts/
│   ├── install.sh                  # bootstrap a new machine
│   ├── update.sh                   # pull remote + chezmoi apply
│   ├── push.sh                     # re-add + commit + push
│   ├── sync.sh                     # full pull + apply + push cycle
│   └── schedule.sh                 # enable/disable scheduled sync
│
└── tui/
    ├── go.mod
    ├── go.sum
    ├── main.go
    ├── cmd/
    ├── internal/
    │   ├── app/
    │   ├── runner/
    │   └── scheduler/
    └── Makefile
```

chezmoi's `sourceDir` is configured to `~/dev/dots/configs` so the repo stays at its current location.

## chezmoi Configuration & Templating

### Machine Identity

`.chezmoi.toml.tmpl` prompts on first init:

```toml
[data]
    email = "{{ promptString "email" }}"
    machine_type = "{{ promptChoiceOnce "machine_type" "Machine type" (list "personal" "work" "server") }}"
    is_macos = {{ eq .chezmoi.os "darwin" }}
    is_linux = {{ eq .chezmoi.os "linux" }}
```

### OS-Conditional Ignores

`.chezmoiignore`:

```
{{- if ne .chezmoi.os "darwin" }}
dot_config/kitty/
Brewfile
run_onchange_install-packages.sh.tmpl
{{- end }}
```

### Templated Configs

`dot_zshrc.tmpl` handles OS differences:

```zsh
# shared config
export EDITOR=nvim

{{- if eq .chezmoi.os "darwin" }}
eval "$(/opt/homebrew/bin/brew shellenv)"
{{- end }}

{{- if eq .chezmoi.os "linux" }}
# linux-specific paths, package manager aliases, etc.
{{- end }}
```

### Non-Templated Configs

kitty and nvim configs are plain files (no `.tmpl`). Promoted to templates only when machine-specific differences arise.

### Brewfile Management

`run_onchange_install-packages.sh.tmpl`:

```bash
#!/bin/bash
# hash: {{ include "Brewfile" | sha256sum }}
{{- if eq .chezmoi.os "darwin" }}
brew bundle --file="{{ .chezmoi.sourceDir }}/Brewfile"
{{- end }}
```

Runs automatically on `chezmoi apply` whenever Brewfile content changes.

## Automation Scripts

All scripts in `scripts/` are standalone bash. They detect OS and gate platform-specific operations.

### install.sh — Bootstrap a New Machine

1. Install chezmoi (brew on macOS, curl on Linux)
2. Clone dots repo to `~/dev/dots` (skip if exists)
3. Configure chezmoi `sourceDir` to `~/dev/dots/configs`
4. Run `chezmoi init --apply` (prompts for machine type, applies all configs)
5. On macOS: run `brew bundle` for Homebrew packages
6. Optionally build the TUI binary
7. Idempotent — safe to run again, skips completed steps

### update.sh — Pull Latest and Apply

1. `git -C ~/dev/dots pull`
2. `chezmoi apply`
3. Print summary of what changed

### push.sh — Capture Local Changes and Push

1. `chezmoi re-add` (captures direct edits to target files)
2. `git -C ~/dev/dots add -A`
3. Prompt for commit message (or auto-generate from changed files)
4. `git -C ~/dev/dots commit && git push`

### sync.sh — Full Bidirectional Sync

1. Run `push.sh` (capture local changes)
2. Run `update.sh` (pull remote changes)
3. Log result to `~/.local/state/dots/sync.log`

Used by scheduled sync jobs.

### schedule.sh — Toggle Scheduled Sync

- `schedule.sh enable [interval]` — installs launchd plist (macOS) or systemd user timer (Linux), default 30 minutes
- `schedule.sh disable` — removes the scheduler
- `schedule.sh status` — shows if active + last run time

## TUI Application

### Tech Stack

- **Go** — single binary, pairs with chezmoi
- **Bubble Tea** — TUI framework (github.com/charmbracelet/bubbletea)
- **Lip Gloss** — styling (github.com/charmbracelet/lipgloss)
- **Bubbles** — pre-built components (github.com/charmbracelet/bubbles)

### Visual Design

- **Color palette**: Catppuccin Mocha (matches kitty theme)
- **Gradient header**: Title uses Lip Gloss gradient (Mauve to Lavender)
- **Rounded borders**: All panels use `lipgloss.RoundedBorder()`
- **Dimmed secondary text**: Timestamps and metadata use `lipgloss.AdaptiveColor`
- **Spinner animations**: During all async operations with contextual messages
- **Progress bars**: Multi-step operations show step progress (1/5, 2/5, etc.)
- **Live streaming output**: Scrollable viewport with log output during operations
- **Toast notifications**: Slide-in from bottom, auto-dismiss for success/error feedback
- **Pulsing status indicators**: Green (up-to-date), amber (changes pending), red (error)
- **Tab transitions**: Smooth fade/slide between tabs

### Layout

```
╭─── dots ─────────────────────────────────────────────────────╮
│                                                               │
│    ·  ·  ·  ·                                                │
│   ╺━━━━━━━━━╸  d o t s                                      │
│    ·  ·  ·  ·                                                │
│                                                               │
│  ┃ Status ┃  Configs    Packages    Sync    System    Settings│
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  Main content area                                           │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│  q quit · tab next · u update · p push · ? help              │
╰───────────────────────────────────────────────────────────────╯
```

### Tabs

#### Status (default)

- Sync state with animated indicators (ahead/behind/clean)
- Last sync timestamp with relative time ("3 minutes ago")
- Machine identity (type, OS, arch)
- Uncommitted changes count, expandable file list via `enter`
- Recent activity feed (scrollable, last 20 operations from sync log)
- Quick actions: `u` update, `p` push, `s` full sync

#### Configs

- Category list with icons (kitty, nvim, zsh)
- Per-category: tracked file tree with last modified times
- Inline diff preview when selecting a changed file
- `e` open in `$EDITOR` via `chezmoi edit`
- `d` show full diff in scrollable viewport
- `a` add a new file to chezmoi tracking

#### Packages (macOS only, hidden on Linux)

- Brewfile contents grouped by type (taps, brews, casks) with styled headers
- Search/filter with `/`
- `a` add package (inline prompt)
- `r` remove package
- `b` run `brew bundle` with streaming output + progress

#### Sync

- Three action buttons: Update, Push, Full Sync
- Streaming output viewport during operations
- Sync history table: timestamp, action, result, duration
- Animated spinner while operations run

#### System

- **Hardware**: Machine model, chip, memory, disk usage
- **OS**: macOS/Linux version, kernel version
- **Shell**: Current shell + version, active plugins
- **Dev tools**: Installed versions (chezmoi, git, brew, nvim, node, go, etc.) with green checkmark or red X for missing
- **Network**: Hostname, local IP
- **dots health**: chezmoi doctor output, scheduled sync status, last sync result
- Info gathered on tab focus with spinner, cached for session

#### Settings

- Toggle scheduled sync on/off with animated switch
- Configure sync interval (15m, 30m, 1h, custom)
- View/edit chezmoi data (machine type, OS, email)
- Open chezmoi config in `$EDITOR`
- Reset/re-initialize chezmoi

### Internal Architecture

**`internal/runner/`** — Thin exec wrapper for chezmoi, git, and brew commands. Captures stdout/stderr and streams output to the TUI. Uniform error handling.

**`internal/scheduler/`** — Reads/writes launchd plists (macOS) and systemd timer units (Linux). Used by Settings tab and `scripts/schedule.sh`.

**`internal/app/`** — Bubble Tea model with per-tab sub-models. Each tab is its own Bubble Tea model composed into the root app model.

## Error Handling & Edge Cases

- **Missing dependencies**: TUI checks for chezmoi, git, brew (macOS) on launch. Shows install instructions if missing.
- **Merge conflicts**: Git conflicts pause with file list for manual resolution. chezmoi conflicts use configured merge tool (nvim -d, vimdiff, etc.).
- **Dirty state on push**: `push.sh` runs `chezmoi re-add` first to capture direct edits to target files.
- **Scheduled sync failures**: Logged to `~/.local/state/dots/sync.log` with timestamps. TUI Status tab surfaces last failure.
- **First-time setup**: `install.sh` is idempotent — skips completed steps on re-run.
- **Cross-OS safety**: Scripts gate platform-specific operations behind OS checks. No script fails on the wrong OS.

## Testing Strategy

### Shell Scripts

- **shellcheck** for static analysis/linting
- Integration tests in Docker (Linux) and locally (macOS) against a temp chezmoi source dir

### Go TUI

- **`internal/runner/`**: Unit tests with mock exec — verify correct commands built, exit codes handled
- **`internal/scheduler/`**: Unit tests verifying correct plist/systemd unit generation without installing
- **`internal/app/`**: Bubble Tea `teatest` integration tests — send keystrokes, assert view output

### CI — GitHub Actions

- `shellcheck` on all scripts
- `go test ./...` for TUI
- `go build` on macOS and Linux runners
- `chezmoi doctor` dry-run to validate source dir structure
