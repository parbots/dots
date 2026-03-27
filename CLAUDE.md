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

```
cd tui && go build -o dots .
make build
make install
```

## Test

```
cd tui && go test ./...
shellcheck scripts/*.sh
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
