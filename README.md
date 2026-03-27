# dots

Personal dotfile management system powered by chezmoi.

## What's Managed

| Config | Description |
|--------|-------------|
| **kitty** | Terminal emulator config |
| **neovim** | Editor config (picklevim) |
| **zsh** | Shell config and aliases |
| **Homebrew** | Package list via Brewfile |

## Quick Start

Bootstrap on a new machine:

```bash
# Clone the repo
git clone git@github.com:parbots/dots.git ~/dev/dots

# Run the install script
bash ~/dev/dots/scripts/install.sh
```

Or fetch and run directly:

```bash
curl -fsSL https://raw.githubusercontent.com/parbots/dots/main/scripts/install.sh | bash
```

## Usage

### Update

Pull latest configs from the repo and apply them to the home directory:

```bash
bash scripts/update.sh
```

### Push

Capture any direct edits to managed files, commit, and push to the remote:

```bash
bash scripts/push.sh
```

### Sync

Full cycle — pull, apply, capture, commit, and push:

```bash
bash scripts/sync.sh
```

### TUI

Run the interactive terminal UI:

```bash
# Build and run from the repo
make build
./tui/dots

# Or install to PATH and run from anywhere
make install
dots
```

## Scheduled Sync

Enable automatic background syncing via launchd (macOS) or cron (Linux):

```bash
bash scripts/schedule.sh enable    # enable scheduled sync
bash scripts/schedule.sh disable   # disable scheduled sync
bash scripts/schedule.sh status    # check current schedule status
```

## Multi-Machine Support

Configs use chezmoi templates to vary per machine. The template data includes:

| Variable | Description |
|----------|-------------|
| `.machine_type` | `"personal"` or `"work"` |
| `.is_macos` | `true` on macOS |
| `.is_linux` | `true` on Linux |
| `.email` | Git commit email |

Templates live in `configs/` with a `.tmpl` extension and use Go `text/template` syntax.

## Repository Structure

```
dots/
├── configs/                  # chezmoi source directory
│   ├── dot_config/           # maps to ~/.config/
│   │   ├── kitty/
│   │   └── nvim/
│   ├── dot_zshrc.tmpl        # maps to ~/.zshrc
│   ├── Brewfile              # Homebrew package list
│   └── .chezmoiignore
├── scripts/                  # bash automation scripts
│   ├── install.sh
│   ├── update.sh
│   ├── push.sh
│   ├── sync.sh
│   └── schedule.sh
├── tui/                      # Go TUI (Bubble Tea)
│   ├── main.go
│   └── internal/
│       ├── app/
│       ├── runner/
│       └── scheduler/
└── docs/superpowers/         # design specs and plans
```

## Prerequisites

- [chezmoi](https://chezmoi.io) >= 2.40.0
- [Go](https://go.dev) >= 1.22 (for the TUI)
- git with SSH authentication configured
