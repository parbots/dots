# CLAUDE.md

## Table of Contents

- [Commands](#commands)
- [Architecture](#architecture)
- [Critical Rules](#critical-rules)
- [Code Philosophy](#code-philosophy)
- [Go Standards](#go-standards)
- [Shell Script Standards](#shell-script-standards)
- [Testing](#testing)
- [Git Workflow](#git-workflow)

## Commands

| Command | Description |
| --- | --- |
| `make build` | Build the TUI binary to `tui/dots` |
| `make install` | Build and install to `$(brew --prefix)/bin/dots` |
| `make test` | Run Go tests |
| `make lint` | Run shellcheck + go vet |
| `make clean` | Remove built binary |
| `chezmoi apply` | Apply configs from source to home directory |
| `chezmoi diff` | Preview changes before applying |
| `chezmoi re-add` | Capture direct edits to managed files back into source |
| `chezmoi managed` | List all managed files |

## Architecture

### Overview

Dotfile management system with three layers:

1. **chezmoi** manages config files via a source-state model with Go templates for multi-machine support
2. **Bash scripts** handle automation (install, update, push, sync, scheduled sync)
3. **Go TUI** (Bubble Tea) provides an interactive dashboard that shells out to chezmoi/git/brew

### Project Structure

```
dots/
├── configs/                          # chezmoi source directory (sourceDir: ~/dev/dots/configs)
│   ├── .chezmoi.toml.tmpl            # machine identity prompts (email, machine_type)
│   ├── .chezmoiignore                # OS-conditional file ignores
│   ├── dot_config/
│   │   ├── kitty/                    # terminal emulator config
│   │   └── nvim/                     # neovim config (picklevim)
│   ├── dot_zshrc.tmpl                # zsh config (templated for macOS/Linux)
│   ├── Brewfile                      # Homebrew packages (not deployed, used by run_onchange)
│   └── run_onchange_install-packages.sh.tmpl
├── scripts/                          # standalone bash automation
│   ├── lib.sh                        # shared helpers: colors, JSON log, locking, template-conflict check
│   ├── install.sh                    # bootstrap a new machine
│   ├── update.sh                     # rebase-safe pull + preflight + apply
│   ├── push.sh                       # re-add + git add -A + commit + converge
│   ├── sync.sh                       # push-then-pull under one lock, JSON log
│   └── schedule.sh                   # launchd (macOS) / systemd (Linux) toggle
├── tui/                              # Go TUI application
│   ├── main.go                       # entry point (--version, dep checks, alt screen)
│   └── internal/
│       ├── app/                      # Bubble Tea models (one per tab + root + theme + toast)
│       ├── runner/                   # exec wrapper for chezmoi/git/brew
│       └── scheduler/                # delegates to scripts/schedule.sh
├── .github/workflows/ci.yml          # shellcheck + Go build/test on macOS + Linux
├── Makefile                          # build, install, test, lint targets
└── docs/superpowers/                 # design specs and implementation plans
```

### chezmoi

- **Source dir:** `~/dev/dots/configs`
- **Config:** `~/.config/chezmoi/chezmoi.toml`
- **Template data:** `.email`, `.machine_type`, `.is_macos`, `.is_linux`
- **Brewfile** is in source dir but excluded from deployment via `.chezmoiignore`
- **OS-conditional configs:** kitty and Brewfile are macOS-only (ignored on Linux via `.chezmoiignore`)

### TUI Architecture

- **Module:** `github.com/parbots/dots`
- **Framework:** Bubble Tea + Lip Gloss + Bubbles
- **Color palette:** Catppuccin Mocha (defined in `theme.go`)
- **Tabs:** Status, Configs, Homebrew (macOS only), Sync, System, Settings
- **Message routing:** Tab-specific messages (e.g., `systemInfoMsg`, `gitStatusMsg`) route directly to owning tab. `spinner.TickMsg` routes to all loading tabs. Keys route to active tab.
- **Async pattern:** `tea.Cmd` returns a closure that runs `runner.Run()`, result arrives as a typed message (e.g., `RunCompleteMsg`)
- **Editor launching:** Uses `tea.ExecProcess` to suspend Bubble Tea while `$EDITOR` runs

### Scripts

All scripts use `set -euo pipefail` and gate platform-specific operations behind `uname -s` checks. All scripts source `scripts/lib.sh`; `sync.sh` holds a lock for its whole run and its children skip locking/logging via `DOTS_LOCK_HELD`.

| Script | Purpose |
| --- | --- |
| `lib.sh` | Shared foundation sourced by all scripts: tty-gated colors, `json_escape`/`log_json`, mkdir-based locking, `check_template_conflicts` |
| `install.sh` | Bootstrap: install chezmoi, clone repo, init, apply, brew bundle |
| `update.sh` | Stuck-rebase recovery + `git pull --rebase` + `check_template_conflicts` + `chezmoi apply` |
| `push.sh` | `check_template_conflicts` + `chezmoi re-add` + `git add -A` + commit + converge with remote (rebase, push; success requires nothing unpushed) |
| `sync.sh` | Push then pull under a single lock, one escaped-JSON log entry per run, log rotation |
| `schedule.sh` | Enable/disable launchd plist or systemd timer for periodic sync |

### Context Loading

| Working on... | Load first |
| --- | --- |
| TUI code | `tui/internal/app/app.go` (root model, message routing) |
| TUI tab | The specific tab file (e.g., `status.go`, `system.go`) |
| TUI styling | `tui/internal/app/theme.go` (colors and shared styles) |
| chezmoi configs | `configs/.chezmoi.toml.tmpl` and `configs/.chezmoiignore` |
| Scripts | The specific script in `scripts/` |
| Runner/exec behavior | `tui/internal/runner/runner.go` |
| Scheduler status parsing | `tui/internal/scheduler/scheduler.go` and `scripts/schedule.sh` |

## Critical Rules

- **Never edit managed configs directly** in `$HOME` without running `chezmoi re-add` afterward — direct edits are overwritten on the next `chezmoi apply`
- **chezmoi template syntax** uses `{{` `}}` delimiters — these must be written literally in `.tmpl` files, not interpreted
- **Brewfile lives in chezmoi source dir** but is excluded from deployment via `.chezmoiignore` — it is consumed by `run_onchange_install-packages.sh.tmpl`, not copied to `$HOME`
- **`push.sh` stages everything via `git add -A`** — keep `.gitignore` complete; anything untracked and unignored in the repo will be committed and pushed by the next sync

## Code Philosophy

### Keep It Simple (YAGNI)

Write the simplest code that solves the current problem.

- **No premature abstractions** — three similar lines of code is better than a utility function used once
- **No speculative generality** — don't add config options or extension points "in case we need them later"
- **Prefer deletion over deprecation** — if something is unused, remove it

### TUI Design

- **Thin wrapper** — the TUI shells out to chezmoi/git/brew rather than reimplementing their logic
- **One model per tab** — each tab is a self-contained Bubble Tea model composed by the root
- **Theme consistency** — all colors come from the Catppuccin Mocha palette in `theme.go`

## Go Standards

- **Go >= 1.24** required
- **Standard formatting** — `gofmt` / `go fmt`
- **Module path:** `github.com/parbots/dots`
- **Internal packages** — all TUI code lives under `tui/internal/` to prevent external imports
- **Error handling** — check `RunResult.ExitCode` after every command execution
- **No `any` type** — use concrete types or interfaces

## Shell Script Standards

- **Shebang:** `#!/usr/bin/env bash`
- **Strict mode:** `set -euo pipefail`
- **Color output helpers:** `info()`, `success()`, `error()`, `warn()` in `scripts/lib.sh`, tty-gated (no ANSI codes when output isn't a terminal)
- **OS detection:** `uname -s` to gate macOS/Linux operations
- **Lint with shellcheck** — all scripts must pass `shellcheck` with zero warnings
- **Locking and logging:** state-changing scripts acquire the dots lock and log failures via `scripts/lib.sh` — never suppress stderr or append `|| true` to state-changing commands

## Testing

### Current Coverage

- **`internal/ansi/`** — table-driven tests for escape stripping (SGR, CSI, OSC)
- **`internal/runner/`** — exec hardening tests (timeout, process-group kill, 1 MB scan buffer, scanner errors)
- **`internal/scheduler/`** — status parsing (ACTIVE/INACTIVE/BROKEN), script path construction
- **`internal/app/`** — pure-helper tests (sync steps, preflight parsing, editor argv, config categories) and direct `Update()` tests for fix sequencing and cursor clamping
- **Scripts** — validated via `shellcheck` static analysis

### Running Tests

```bash
make test          # Go tests
make lint          # shellcheck + go vet
```

## Git Workflow

### Commit Discipline

- **Conventional commits:** `feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `ci:`
- **Atomic commits** — each commit represents one logical change
- **Version embedding** — `make build` injects the git describe tag via `-ldflags`
