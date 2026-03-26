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
├── .gitignore                      # Ignore build artifacts (TUI binary, etc.)
├── Makefile                        # Builds TUI binary, installs to ~/bin
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
│   ├── Brewfile                    # homebrew packages (ignored via .chezmoiignore, not deployed to $HOME)
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
    └── internal/
        ├── app/
        ├── runner/
        └── scheduler/
```

chezmoi's `sourceDir` is configured to `~/dev/dots/configs` so the repo stays at its current location.

## chezmoi Configuration & Templating

### Machine Identity

`.chezmoi.toml.tmpl` prompts on first init:

```toml
[data]
    email = "{{ promptString "email" }}"
    machine_type = "{{ promptChoice "machine_type" "Machine type" (list "personal" "work" "server") }}"
    is_macos = {{ eq .chezmoi.os "darwin" }}
    is_linux = {{ eq .chezmoi.os "linux" }}
```

### OS-Conditional Ignores

`.chezmoiignore`:

```
Brewfile
{{- if ne .chezmoi.os "darwin" }}
dot_config/kitty/
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

### sync.sh — Push-Then-Pull Sync

1. Run `push.sh` (capture and push local changes)
2. Run `update.sh` (pull remote changes and apply)
3. If pull causes merge conflicts, log the conflict and exit non-zero (do not auto-resolve)
4. Log result to `~/.local/state/dots/sync.log` (JSON lines format, see below)

Used by scheduled sync jobs. Note: this is push-first, so local changes are preserved. Remote conflicts require manual resolution.

#### Sync Log Format

Each entry in `~/.local/state/dots/sync.log` is a JSON line:

```json
{"timestamp":"2026-03-26T12:04:00Z","action":"sync","result":"success","duration_ms":1200,"details":"pushed 2 commits, pulled 1 commit"}
```

The log directory (`~/.local/state/dots/`) is created by `install.sh` and by `sync.sh` on first run if missing. Log rotation: `sync.sh` truncates the file to the last 500 entries on each run.

### schedule.sh — Toggle Scheduled Sync

- `schedule.sh enable [interval]` — installs launchd plist (macOS) or systemd user timer (Linux), default 30 minutes
- `schedule.sh disable` — removes the scheduler
- `schedule.sh status` — shows if active + last run time

Scheduler details:
- **macOS**: Installs `com.dots.sync.plist` to `~/Library/LaunchAgents/`
- **Linux**: Installs `dots-sync.timer` and `dots-sync.service` to `~/.config/systemd/user/`
- The shell scripts are the single source of truth for scheduler artifacts. The TUI's `internal/scheduler/` package calls `scripts/schedule.sh` rather than generating files independently — this avoids dual-ownership of scheduler config.

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
- **Tab transitions**: Instant switch with active tab highlight (Bubble Tea redraws full view; smooth animation is not practical in terminal)

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

**Go module path**: `github.com/parbots/dots`

**`main.go`** — Entry point. Parses flags (`--version`, `--help`), initializes the root Bubble Tea program, and runs it.

**`internal/runner/`** — Thin exec wrapper for chezmoi, git, and brew commands. Captures stdout/stderr and streams output to the TUI via a channel. Uniform error handling. Each command execution returns a `RunResult{Stdout, Stderr, ExitCode, Duration}`.

**`internal/scheduler/`** — Calls `scripts/schedule.sh` for enable/disable/status operations. Parses the script output to present in the TUI. Does not generate scheduler files directly.

**`internal/app/`** — Bubble Tea model composition:

```go
// Root model composes all tab sub-models
type Model struct {
    activeTab   int
    tabs        []string
    statusTab   StatusModel
    configsTab  ConfigsModel
    packagesTab PackagesModel
    syncTab     SyncModel
    systemTab   SystemModel
    settingsTab SettingsModel
    toast       ToastModel      // overlay, renders on top of active tab
    width       int
    height      int
}
```

**Message flow for async operations:**

1. User triggers action (e.g., `u` for update) -> tab sends a `tea.Cmd` that starts the subprocess via `runner`
2. Runner streams stdout/stderr line-by-line over a channel
3. Each line arrives as a `OutputLineMsg` -> tab appends to its viewport
4. When the subprocess exits, a `RunCompleteMsg{Result, Error}` is sent
5. Tab updates its state (spinner stops, status updates, toast fires)

**Toast system:** A `ToastModel` holds a queue of messages with auto-dismiss timers via `tea.Tick`. Renders as an overlay in the root `View()`.

**Tab transitions:** Instant switch (no frame-by-frame animation — Bubble Tea redraws the full view on each tab change). Visual distinction comes from the active tab highlight and content change, not animation. Spinners and pulsing indicators use `tea.Tick` at 100ms intervals.

**Config categories** in the Configs tab are derived dynamically by scanning `configs/dot_config/` subdirectories plus `configs/dot_zshrc.tmpl`. Not hardcoded.

## Prerequisites & Versioning

- **chezmoi**: >= 2.40.0 (required for `promptChoice` and current template functions). Checked by `install.sh` and TUI on launch.
- **Go**: >= 1.22 for building the TUI
- **Git authentication**: Scripts that push (`push.sh`, `sync.sh`) require non-interactive git auth. `install.sh` checks for SSH key or credential helper and warns if neither is configured. Scheduled sync will skip push and log a warning if auth fails.
- **TUI versioning**: The TUI binary embeds version info via `go build -ldflags` from the latest git tag. `dots --version` prints it. No formal release process — the binary is built from source on each machine.

## Error Handling & Edge Cases

- **Missing dependencies**: TUI checks for chezmoi, git, brew (macOS) on launch. Shows install instructions if missing.
- **Merge conflicts**: Git conflicts pause with file list for manual resolution. chezmoi conflicts use configured merge tool (nvim -d, vimdiff, etc.).
- **Dirty state on push**: `push.sh` runs `chezmoi re-add` to capture direct edits to target files. Targets only chezmoi-managed files (not arbitrary home directory state).
- **Scheduled sync failures**: Logged to `~/.local/state/dots/sync.log` with timestamps. TUI Status tab surfaces last failure.
- **First-time setup**: `install.sh` is idempotent — skips completed steps on re-run.
- **Cross-OS safety**: Scripts gate platform-specific operations behind OS checks. No script fails on the wrong OS.

## Testing Strategy

### Shell Scripts

- **shellcheck** for static analysis/linting
- Integration tests in Docker (Linux) and locally (macOS) against a temp chezmoi source dir

### Go TUI

- **`internal/runner/`**: Unit tests with mock exec — verify correct commands built, exit codes handled
- **`internal/scheduler/`**: Unit tests verifying correct invocation of `schedule.sh` and parsing of its output
- **`internal/app/`**: Bubble Tea `teatest` integration tests — send keystrokes, assert view output

### CI — GitHub Actions

- `shellcheck` on all scripts
- `go test ./...` for TUI
- `go build` on macOS and Linux runners
- `chezmoi doctor` dry-run to validate source dir structure

Note: Docker-based Linux CI cannot test macOS-specific paths (launchd, brew). macOS-specific integration tests run on GitHub Actions macOS runners only.
