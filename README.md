# dots

Personal dotfile management system powered by [chezmoi](https://chezmoi.io) with an interactive Go TUI.

## What's Managed

| Config | Description |
| --- | --- |
| **kitty** | Terminal emulator config + Catppuccin Mocha theme |
| **neovim** | Editor config (picklevim) |
| **zsh** | Shell config, aliases, and plugin setup |
| **Homebrew** | Package list via Brewfile (macOS only) |

## Quick Start

Bootstrap on a new machine:

```bash
git clone git@github.com:parbots/dots.git ~/dev/dots
bash ~/dev/dots/scripts/install.sh
```

The install script will:
1. Install chezmoi (via Homebrew on macOS, curl on Linux)
2. Initialize chezmoi with your email and machine type
3. Apply all configs
4. Install Homebrew packages (macOS)
5. Optionally build the TUI

## Usage

### Scripts

| Command | Description |
| --- | --- |
| `bash scripts/update.sh` | Pull latest from remote + apply configs |
| `bash scripts/push.sh` | Capture local edits, commit, and push |
| `bash scripts/sync.sh` | Full cycle: push then pull |
| `bash scripts/schedule.sh enable` | Enable automatic sync (every 30 min) |
| `bash scripts/schedule.sh disable` | Disable automatic sync |
| `bash scripts/schedule.sh status` | Check scheduler status |

Scheduled sync uses **launchd** on macOS and **systemd user timers** on Linux.

### TUI

Build and run the interactive terminal UI:

```bash
make build && ./tui/dots
```

Or install to PATH:

```bash
make install
dots
```

The TUI provides six tabs:

| Tab | Description |
| --- | --- |
| **Status** | Sync state, machine info, recent activity, quick actions |
| **Configs** | Browse managed configs, view diffs, open in editor |
| **Packages** | View/edit Brewfile, run brew bundle (macOS only) |
| **Sync** | Run update/push/sync with live output |
| **System** | Hardware, OS, shell, dev tools, dots health |
| **Settings** | Toggle scheduled sync, configure interval, chezmoi settings |

## Multi-Machine Support

Configs use [chezmoi templates](https://www.chezmoi.io/user-guide/templating/) to vary per machine. On first setup, `chezmoi init` prompts for:

| Variable | Description |
| --- | --- |
| `.email` | Git commit email |
| `.machine_type` | `"personal"`, `"work"`, or `"server"` |

OS detection is automatic:

| Variable | Value |
| --- | --- |
| `.is_macos` | `true` on macOS |
| `.is_linux` | `true` on Linux |

Template files live in `configs/` with a `.tmpl` extension and use Go `text/template` syntax.

## Repository Structure

```
dots/
├── configs/                          # chezmoi source directory
│   ├── .chezmoi.toml.tmpl            # machine identity config
│   ├── .chezmoiignore                # OS-conditional ignores
│   ├── dot_config/
│   │   ├── kitty/                    # kitty terminal config
│   │   └── nvim/                     # neovim config (picklevim)
│   ├── dot_zshrc.tmpl                # zsh config (templated)
│   ├── Brewfile                      # Homebrew packages
│   └── run_onchange_install-packages.sh.tmpl
├── scripts/                          # bash automation
│   ├── install.sh                    # bootstrap a new machine
│   ├── update.sh                     # pull + apply
│   ├── push.sh                       # capture + commit + push
│   ├── sync.sh                       # full sync cycle
│   └── schedule.sh                   # scheduled sync toggle
├── tui/                              # Go TUI (Bubble Tea)
│   ├── main.go
│   └── internal/
│       ├── app/                      # tab models, theme, toast
│       ├── runner/                   # command execution wrapper
│       └── scheduler/                # schedule.sh integration
├── Makefile                          # build, install, test, lint
└── .github/workflows/ci.yml          # CI: shellcheck + Go build/test
```

## Prerequisites

- [chezmoi](https://chezmoi.io) >= 2.40.0
- [Go](https://go.dev) >= 1.22 (for building the TUI)
- git with SSH authentication configured
