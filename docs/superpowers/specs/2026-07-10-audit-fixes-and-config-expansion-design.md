# Audit Fixes and Config Expansion — Design

**Date:** 2026-07-10
**Status:** Approved by user (sections reviewed and approved in brainstorming session)

## Problem

A three-part audit of the dots repo (bash scripts + CI, Go TUI, chezmoi source state) found ~40 verified issues, including four data-loss paths and one feature that never worked. Separately, the user wants to expand chezmoi coverage from the current set (zshrc, kitty, nvim, Brewfile) to most of the configs on this machine.

Key confirmed findings driving this design (verified empirically against chezmoi v2.71.0):

1. **Template clobber (critical):** `chezmoi re-add` silently skips `.tmpl` sources, then `update.sh` runs `chezmoi apply --force`, destroying direct edits to templated targets like `~/.zshrc`. Commit `8f0a4e8` documents this destroying a real edit.
2. **Silent staging failure (critical):** `push.sh` ends `git add <9 hardcoded paths> 2>/dev/null || true`. Any failure (e.g. `index.lock` from a concurrent run — there is no locking anywhere) stages nothing and sync.log records success.
3. **Stranded commits (critical):** `push.sh` only pushes immediately after committing. A rejected push (remote ahead) leaves the commit local forever — subsequent runs find "no changes" and never push it.
4. **Preflight auto-kill (critical):** TUI parses `ps -o lstart` as UTC instead of local time, so a healthy chezmoi looks hours old and is auto-SIGTERMed mid-apply.
5. **Always-broken diff:** the TUI's "d" key passes source paths to `chezmoi diff` (which needs target paths), swallows the error, and always shows "No differences found."
6. **Ineffective `.chezmoiignore`:** patterns use source names (`dot_config/kitty/`) but chezmoi matches target paths — kitty would deploy on Linux.
7. Plus mediums/lows: stuck-rebase handling, TUI races, broken fresh-machine bootstrap (oh-my-zsh and tools never installed), unused `.email`/`machine_type` prompts, hardcoded `/Users/parkerb` in the zshrc template, systemd PATH missing `~/.local/bin`, gofmt/CI gaps, dead code.

## Decisions (user-confirmed)

| Decision | Choice |
| --- | --- |
| Fix scope | **All ~40 findings**, including the low-severity tail |
| Template-edit data loss | **Minimize templating**: convert templates to plain files with runtime shell conditionals; keep a skip+surface safety net for any remaining templates |
| Configs to onboard | **All four groups**: core CLI set, extra TUI tools, editors/apps, shell environment (OMZ plugins) |
| "Data" scope | **Configs + regenerable manifests only** — no secrets, no encryption support needed |
| Staging strategy | **`git add -A` + `.gitignore`** (replaces the hardcoded-path Critical Rule in CLAUDE.md) |
| Structure | **One project, three ordered phases**; each phase leaves the repo working |

## Phase 1 — Scripts & data integrity

### New: `scripts/lib.sh` (shared foundation)

Sourced by install/update/push/sync/schedule. Provides:

- **Color helpers** (`info`/`success`/`error`/`warn`) gated on `[[ -t 1 ]]` — scheduled runs get plain text, fixing ANSI garbage in launchd logs.
- **`json_escape`** — escapes a string for embedding in sync.log JSON (backslash, quote, control chars). All `details` values pass through it.
- **`acquire_lock` / `release_lock`** — portable mkdir-based lock at `$XDG_STATE_HOME/dots/lock` (macOS has no `flock` binary). Lock dir contains the holder PID; a lock whose PID is dead is stale and reclaimed. `release_lock` runs from an EXIT trap. Interface: `acquire_lock` returns non-zero if another live holder exists; callers exit with a "another dots operation is running" message and (for sync.sh) a logged `skipped` result.

Locking rule: `sync.sh` takes the lock around its entire run; `push.sh` and `update.sh` take it when invoked directly (re-entrant via an env guard `DOTS_LOCK_HELD=1` so sync.sh's children don't deadlock).

### `push.sh` rework

Order of operations:

1. **Template-conflict preflight (safety net):** parse `chezmoi status`; if any modified target's source file is a `.tmpl`, print a prominent warning naming the file and *do not* let a later apply clobber it (exit failure with instructions to reconcile via `chezmoi merge` or the TUI). After Phase 3 no user-editable target is templated, so this should never fire — it exists to protect any future template.
2. `chezmoi re-add`.
3. `git add -A` — **no stderr suppression, no `|| true`**. Non-zero exit is fatal and logged.
4. Commit (same message format as today, generated from `git diff --cached --name-only`).
5. `git pull --rebase` then `git push` (fixes rejected-push stranding). On rebase conflict: abort the rebase, exit failure.
6. **Final invariant:** `git rev-list --count @{u}..HEAD` must be 0 (when an upstream exists) or the script exits failure. Success is never reported while commits are unpushed.

### `update.sh`

- Before pulling: if `.git/rebase-merge` or `.git/rebase-apply` exists, run `git rebase --abort`, report failure for this run. Never operate on a repo stuck mid-rebase.
- Keep `chezmoi apply`; `--force` remains acceptable because after the push.sh preflight and Phase 3 de-templating there is no template-clobber path. Apply failures are fatal and logged.

### `sync.sh`

- All `details` strings pass through `json_escape`.
- Log rotation happens while holding the lock (no lost appends).
- Also rotates `launchd-stdout.log` / `launchd-stderr.log` (truncate to tail when > 1000 lines).
- A run skipped due to the lock logs `"result":"skipped"`.

### `schedule.sh`

- systemd unit PATH gains `%h/.local/bin` (where install.sh puts chezmoi on Linux).
- Log/state paths honor `XDG_STATE_HOME` (matching sync.sh) instead of hardcoding `~/.local/state`.
- Interval validation: minimum 60 seconds, integer seconds on both platforms; systemd uses `OnUnitActiveSec=<N>s` (no more truncating 90s to 1min).
- `status` also checks that the sync.sh path baked into the plist/unit still exists, and reports BROKEN if not.

### `install.sh`

- Linux chezmoi install: download the installer to a temp file and fail loudly if curl fails (no more `sh -c ""` silently succeeding).
- macOS: check `command -v brew` before using it, with a clear error pointing to brew.sh.
- Remove the duplicate `brew bundle` (chezmoi apply's run_onchange already runs it).
- Version-check grep failure produces a clear error message instead of a bare `set -e` death.

## Phase 2 — TUI correctness & discovery architecture

### Runner hardening (`internal/runner`)

One hardened exec path used by everything:

- `SysProcAttr{Setpgid: true}` and kill via negative PID so cancel/"x" kills the whole process group (`git push` waiting on ssh, chezmoi prompts).
- `cmd.WaitDelay` as a backstop so `Wait` cannot hang forever on inherited pipes.
- Scanner buffer raised to 1 MB; `scanner.Err()` checked and surfaced.
- Default timeout for non-streaming `Run` calls (context-based); streaming runs are cancellable and group-killed.
- Delete dead `RunStream` (keep `RunStreamCtx`); tests updated.

### Sync preflight (`internal/app/sync_preflight.go`)

- `time.ParseInLocation("Mon Jan  2 15:04:05 2006", s, time.Local)` for `lstart` (fixes the UTC-offset auto-kill).
- Long-running chezmoi processes are **always severityAsk** — the TUI never SIGTERMs a process without user confirmation.
- Conflict detection matches any locally-modified status (`MM` and friends), not just `DA`.
- Fix commands run **sequentially before** the pending script starts (chain on fix-complete messages) instead of racing it via `tea.Batch`.
- `initRun` resets `awaitingResolve` (closes the double-run hole).

### Configs tab (`internal/app/configs.go`)

- Discovery rebuilt on chezmoi as source of truth: file list from `chezmoi managed --include=files`, and a single mapping helper backed by `chezmoi source-path` / `chezmoi target-path` replaces the three divergent `strings.ReplaceAll("dot_", ".")` implementations. New onboarded files (e.g. `dot_gitconfig`, top-level entries) appear automatically; chezmoi attribute prefixes (`private_`, `executable_`, …) are handled by chezmoi itself.
- Categories derived from target paths (`.config/<name>` → category `<name>`; top-level dotfiles → "home" category) — presentation-only logic, no name un-mangling.
- Diff ("d") fixed: pass **target** paths to `chezmoi diff`, check exit code, surface stderr on failure.
- `categoriesLoadedMsg` clamps `m.cursor` as well as `fileCursor` (no panic when categories shrink after rescan).

### Root model & other tabs

- Quit ("q"/ctrl+c) while a sync script runs cancels the run (process-group kill) before exiting — no detached half-finished git operations.
- Homebrew tab: `running` guard on "b" (and Brewfile mutations blocked mid-bundle); `brewBundleCompleteMsg.exitCode` checked with error styling + toast on failure.
- Status tab: `chezmoi data` loads async via a `tea.Cmd` (no synchronous exec before the program starts); missing upstream shows a "no upstream" warning instead of a false "In sync"; rev-list errors surfaced.
- Settings/scheduler: exit codes of `chezmoi data` and `schedule.sh status` checked; failures render an error state, not empty/garbage.
- `$EDITOR` values with arguments (`code --wait`) split into argv before exec (both launch sites).
- `stripANSI` centralized in one package and fixed for non-SGR escape sequences.
- Dead code removed: `SettingsModel.syncInterval`, unused theme styles/colors.
- `go mod tidy` (clipboard dep is direct); CLAUDE.md drift fixed (tab name, Go version, staging rule, context table).

## Phase 3 — De-templating, onboarding, bootstrap, CI

### De-templating

- `dot_zshrc.tmpl` → plain `dot_zshrc`. Every current template conditional is an OS check; each becomes a runtime conditional:
  - `[[ "$OSTYPE" == darwin* ]]` guards for Homebrew settings/aliases, SDL/ncurses paths, PNPM_HOME location.
  - `command -v` guards for zoxide, fzf, mise, starship, and an existence check for oh-my-zsh — a machine missing a tool degrades gracefully instead of erroring on every new shell (fixes broken Linux/fresh-machine shells).
  - `PNPM_HOME` uses `$HOME/Library/pnpm` (removes the hardcoded `/Users/parkerb`).
  - PATH entries (`.cargo/bin`, `.local/bin`) get the same dedup guard pnpm already uses.
  - `plugins=(...)` not exported (OMZ convention).
- `.chezmoi.toml.tmpl`: delete the unused `.email` / `machine_type` prompts and `is_macos`/`is_linux` data. The git email ships in a plain `dot_gitconfig` (it is already public in commit history). If a per-machine value is ever needed again, prompts can return — YAGNI now.
- Remaining templates: only `run_onchange_install-packages.sh.tmpl` (needs the Brewfile hash; not a user-editable target, so the re-add blind spot cannot bite). It gets `#!/usr/bin/env bash` + `set -euo pipefail` per repo standards.
- `.chezmoiignore` rewritten with **target-path** patterns: `Brewfile` (unchanged), `.config/kitty` and `install-packages.sh` under the non-darwin conditional.

### Config onboarding (all plain files via `chezmoi add`)

| Group | Files |
| --- | --- |
| Core CLI | `~/.gitconfig`, `~/.config/starship.toml`, `~/.config/mise/` config, `~/.config/gh/config.yml`, `~/.config/lazygit/config.yml` |
| Extra TUI tools | `~/.config/helix/config.toml`, `~/.config/btop/btop.conf` + themes, `~/.config/gh-dash`, `~/.config/htop`, `~/.config/qman` |
| Editors/apps | `~/.config/zed/settings.json` + `keymap.json` (never conversations/embeddings), `~/.claude/settings.json`, `~/.config/ccstatusline` |
| Shell environment | oh-my-zsh core + custom plugins (autoupdate, fast-syntax-highlighting, zsh-autosuggestions) via `.chezmoiexternal.toml` (git-repo externals, `refreshPeriod: 168h`) |

Exclusions (never managed): `~/.config/gh/hosts.yml` (OAuth tokens), `~/.claude` beyond `settings.json` (credentials/history), zed conversations/embeddings. Each sensitive sibling is listed in README/CLAUDE.md as a do-not-add.

- Brewfile: delete the 16 `vscode "..."` extension lines (VS Code is not installed; `brew bundle` skips them silently today).
- `.gitignore` audited for `git add -A` safety (build artifacts, `.DS_Store`, `.claude/settings.local.json` if present).

### CI (`.github/workflows/ci.yml`)

- Add `gofmt -l` gate (and format the three currently-unformatted files); wire into `make lint` too.
- Build via `make build` so the ldflags version injection is exercised.
- Pin `ludeeus/action-shellcheck` to a commit SHA.
- New smoke test job (macOS + Linux): scratch git repo (bare remote + clone) + scratch chezmoi source; run `push.sh` and `sync.sh` against it; assert commits pushed, JSON log valid (`jq`), lock prevents a concurrent second run, and a template-source conflict is detected by the preflight. This test would have caught findings 1–4.

## Error handling principles

- Scripts: every failure path logs an escaped-JSON entry to sync.log; success requires end-state invariants (nothing unpushed, no rebase in progress, apply exited 0). No `|| true` on state-changing commands; no stderr suppression.
- TUI: every `RunResult.ExitCode` checked; failures render visibly (error styling/toast), never as empty/success states. No destructive action (kill, discard) without user confirmation.

## Testing

- **Go unit tests** (extending existing suites): runner process-group kill, timeout, >64 KB output lines, `scanner.Err` surfacing; preflight `lstart` parsing in non-UTC zones and `MM` status parsing; source↔target mapping helper (table-driven); cursor clamping on category shrink.
- **Scripts:** shellcheck (zero warnings, including lib.sh) + the CI smoke test above.
- **Manual verification on this machine:** `chezmoi doctor`; `chezmoi diff` clean after onboarding; fresh-shell startup with no errors; TUI walkthrough of every tab including diff view against a deliberately-dirtied file, kill of a deliberately-hung script, and scheduled sync round-trip.

## Out of scope

- Secrets management / chezmoi encryption (no sensitive data is being managed).
- App state/history sync (shell history, zoxide DB — poor fits for git).
- Linux package provisioning beyond graceful degradation (no apt/dnf Brewfile equivalent).
- New TUI features beyond fixing/generalizing what exists.

## Phase ordering rationale

Phase 1 makes sync safe (locking + invariants) so nothing added later can be silently lost. Phase 2 makes the TUI truthful and makes discovery generic so Phase 3's files appear without per-file TUI work. Phase 3 changes the managed set. Each phase ends with lint + tests green and the repo deployable.
