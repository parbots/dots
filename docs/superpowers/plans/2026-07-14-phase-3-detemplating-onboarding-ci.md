# Phase 3: De-templating, Onboarding, Bootstrap & CI Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the template-edit data-loss trigger (plain `dot_zshrc` with runtime guards), close the config-onboarding gaps (gitconfig, lazygit, htop, Claude settings, oh-my-zsh externals), and codify Phase 1's script guarantees as a CI smoke-test job.

**Architecture:** `dot_zshrc.tmpl` becomes plain `dot_zshrc` — every OS template conditional becomes a `$OSTYPE`/`command -v` runtime guard, so a machine missing a tool degrades gracefully instead of erroring on every shell. The unused chezmoi prompts disappear (git email ships in a plain `dot_gitconfig`). `.chezmoiignore` switches to target-path patterns. New configs arrive via `chezmoi add`; oh-my-zsh + custom plugins via `.chezmoiexternal.toml` git-repo externals. CI gains a gofmt gate, a pinned shellcheck action, `make build`, and a scratch-repo smoke job that would have caught audit findings 1–3.

**Tech Stack:** chezmoi v2.71.0, bash (shellcheck-clean), GitHub Actions. One Go-adjacent change (none to Go source).

**Spec:** `docs/superpowers/specs/2026-07-10-audit-fixes-and-config-expansion-design.md` (Phase 3 section).

---

## Context you must know before starting

- **Working directory:** repo root (`~/dev/dots` or the worktree) unless stated. chezmoi's source dir is ALWAYS the real `~/dev/dots/configs` — `chezmoi add`/`diff`/`apply` commands operate on the real machine and real source dir regardless of cwd. **Tasks that run `chezmoi add` must therefore run in the REAL repo, not a worktree** (the controller sequences this; individual tasks say where they run).
- **Live-machine facts (verified at plan time):**
  - Already managed: `.zshrc`, and under `.config/`: btop, ccstatusline, gh, gh-dash, git (ignore), helix, herdr, kitty, mise, nvim, qman, starship.toml, verse, zed.
  - Onboarding gaps that exist on disk: `~/.gitconfig`, `~/.config/lazygit/`, `~/.config/htop/`, `~/.claude/settings.json`.
  - OMZ custom plugins present: `autoupdate`, `fast-syntax-highlighting`, `zsh-autosuggestions` (plus the stock `example` — never manage it).
  - `~/.zshrc` matches its source exactly (`chezmoi status` clean for it). **The live `~/.zshrc` is therefore the rendered darwin output of the current template** — the de-templating diff below is expressed against it.
  - The spec's `PNPM_HOME` bullet is OUTDATED: pnpm is now managed by mise (commit 4452d38 replaced the PNPM block with comments) — there is no PNPM_HOME to convert. The template DOES contain `eval "$(starship init zsh)"` (line 155) and `export PATH="$HOME/.cargo/bin:$PATH"` (line 158) — both get guards per the spec (Task 1 Step 3).
- **Templates after this phase:** `run_onchange_install-packages.sh.tmpl` (needs the Brewfile hash; not a user-editable target) and `.chezmoiignore` (chezmoi-internal). `.chezmoi.toml.tmpl` stays as a minimal comment-only template. `check_template_conflicts` in lib.sh stays as the safety net.
- **Scripts:** every `scripts/*.sh` must stay shellcheck-clean (`make lint` and CI's action both scan the whole dir — the new smoke script included). Single-file checks need `shellcheck -x` from repo root.
- **CI constraint:** the shellcheck action step MUST keep `env: SHELLCHECK_OPTS: -x` (added post-Phase-1; removing it re-breaks CI with SC1091).
- **Commit discipline:** conventional prefix, single-line message exactly as given, no Co-Authored-By trailer.

### File map

| File | Action | Responsibility |
| --- | --- | --- |
| `configs/dot_zshrc.tmpl` → `configs/dot_zshrc` | Rename+edit | Plain zsh config with runtime guards |
| `configs/.chezmoi.toml.tmpl` | Gut | Comment-only minimal template |
| `configs/dot_gitconfig` | Create (chezmoi add) | Git identity + config (email now lives here) |
| `configs/.chezmoiignore` | Rewrite | Target-path patterns |
| `configs/run_onchange_install-packages.sh.tmpl` | Harden | env-bash shebang + strict mode |
| `configs/Brewfile` | Trim | Delete 16 dead `vscode` lines |
| `configs/dot_config/{lazygit,htop}/`, `configs/dot_claude/settings.json` | Create (chezmoi add) | New onboarded configs |
| `configs/.chezmoiexternal.toml` | Create | oh-my-zsh + 3 custom plugins as git externals |
| `README.md`, `CLAUDE.md` | Update | Do-not-add list, structure drift |
| `.github/workflows/ci.yml`, `Makefile` | Extend | gofmt gate, pinned action, make build, smoke job |
| `scripts/ci-smoke.sh` | Create | Scratch-repo smoke test of push/sync guarantees |

---

## Chunk 1: De-templating & source hygiene

### Task 1: `dot_zshrc.tmpl` → plain `dot_zshrc` with runtime guards

**Runs in: the worktree** (source-file edits only; verification uses read-only chezmoi commands plus `zsh -n`). The final apply happens in Task 9.

**Files:**
- Rename+modify: `configs/dot_zshrc.tmpl` → `configs/dot_zshrc`

- [ ] **Step 1: Rename preserving history**

```bash
git mv configs/dot_zshrc.tmpl configs/dot_zshrc
```

- [ ] **Step 2: Convert each template conditional to a runtime guard.** Six `{{ }}` regions exist (template line numbers cited from HEAD). Apply these exact replacements:

1. **Editor (lines 74-81).** Replace the whole block

```
# Editor configuration - use Neovim for everything
{{- if eq .chezmoi.os "darwin" }}
export EDITOR="/opt/homebrew/bin/nvim"
export VISUAL="/opt/homebrew/bin/nvim"
{{- else }}
export EDITOR="nvim"
export VISUAL="nvim"
{{- end }}
```

with:

```zsh
# Editor configuration - use Neovim for everything
if [[ "$OSTYPE" == darwin* ]]; then
    export EDITOR="/opt/homebrew/bin/nvim"
    export VISUAL="/opt/homebrew/bin/nvim"
else
    export EDITOR="nvim"
    export VISUAL="nvim"
fi
```

2. **Homebrew settings (lines 94-98).** Replace

```
{{- if eq .chezmoi.os "darwin" }}
# Homebrew settings
export HOMEBREW_AUTO_UPDATE_SECS=3600  # Check for updates hourly
export HOMEBREW_NO_ENV_HINTS=1         # Disable environment hints in output
{{- end }}
```

with:

```zsh
# Homebrew settings (macOS only)
if [[ "$OSTYPE" == darwin* ]]; then
    export HOMEBREW_AUTO_UPDATE_SECS=3600  # Check for updates hourly
    export HOMEBREW_NO_ENV_HINTS=1         # Disable environment hints in output
fi
```

3. **Homebrew aliases (lines 104-110).** Replace

```
{{- if eq .chezmoi.os "darwin" }}
# Homebrew - cleanup old versions (keep last 7 days) and remove unused dependencies
alias brcl="brew cleanup -s -v --prune=7 && brew autoremove"

# Homebrew - update, upgrade all packages, cleanup, and remove unused dependencies
alias brup="brew update && brew upgrade && brew cleanup -s && brew autoremove"
{{- end }}
```

with:

```zsh
if [[ "$OSTYPE" == darwin* ]]; then
    # Homebrew - cleanup old versions (keep last 7 days) and remove unused dependencies
    alias brcl="brew cleanup -s -v --prune=7 && brew autoremove"

    # Homebrew - update, upgrade all packages, cleanup, and remove unused dependencies
    alias brup="brew update && brew upgrade && brew cleanup -s && brew autoremove"
fi
```

4. **mise (lines 140-145).** Replace

```
# mise - Runtime version manager for node, pnpm, etc.
{{- if eq .chezmoi.os "darwin" }}
eval "$(/opt/homebrew/bin/mise activate zsh)"
{{- else }}
eval "$(mise activate zsh)"
{{- end }}
```

with:

```zsh
# mise - Runtime version manager for node, pnpm, etc.
if [[ "$OSTYPE" == darwin* && -x /opt/homebrew/bin/mise ]]; then
    eval "$(/opt/homebrew/bin/mise activate zsh)"
elif command -v mise >/dev/null; then
    eval "$(mise activate zsh)"
fi
```

5. **SDL (lines 166-170).** Replace

```
{{- if eq .chezmoi.os "darwin" }}
export SDL_CONFIG="/opt/homebrew/bin/sdl2-config"
{{- else }}
export SDL_CONFIG="/usr/bin/sdl2-config"
{{- end }}
```

with:

```zsh
if [[ "$OSTYPE" == darwin* ]]; then
    export SDL_CONFIG="/opt/homebrew/bin/sdl2-config"
else
    export SDL_CONFIG="/usr/bin/sdl2-config"
fi
```

6. **Linux placeholder (lines 172-174).** Delete the block entirely (it renders to a comment or nothing):

```
{{- if eq .chezmoi.os "linux" }}
# Linux-specific configuration placeholder
{{- end }}
```

- [ ] **Step 3: Graceful-degradation guards** (fixes broken fresh-machine/Linux shells):

1. **oh-my-zsh existence check** — replace line 65 `source "$ZSH/oh-my-zsh.sh"` with:

```zsh
if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
else
    echo "oh-my-zsh not found at $ZSH — run 'chezmoi apply' to fetch it" >&2
fi
```

2. **zoxide** — line 135 `eval "$(zoxide init zsh)"` becomes:

```zsh
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
```

3. **fzf** — line 138 `source <(fzf --zsh)` becomes:

```zsh
command -v fzf >/dev/null && source <(fzf --zsh)
```

4. **plugins array not exported** (OMZ convention) — line 44 `export plugins=(` becomes `plugins=(`.

5. **starship** — line 155 `eval "$(starship init zsh)"` becomes:

```zsh
command -v starship >/dev/null && eval "$(starship init zsh)"
```

6. **cargo PATH dedup guard** — line 158 `export PATH="$HOME/.cargo/bin:$PATH"` becomes:

```zsh
case ":$PATH:" in
  *":$HOME/.cargo/bin:"*) ;;  # Already in PATH
  *) export PATH="$HOME/.cargo/bin:$PATH" ;;
esac
```

7. **local-bin PATH dedup guard** — last line `export PATH="$HOME/.local/bin:$PATH"` becomes:

```zsh
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;  # Already in PATH
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
```

- [ ] **Step 4: Verify no template syntax remains and the file is valid zsh**

```bash
grep -c '{{' configs/dot_zshrc || echo template-free
zsh -n configs/dot_zshrc && echo syntax-ok
```
Expected: `template-free`, `syntax-ok`.

- [ ] **Step 5: Verify the conversion is faithful** — diff against the live rendered output. Every hunk must be one of the intended changes above (guards added, indentation inside new `if` blocks, deleted placeholder, plugins export, PATH dedup) and NOTHING else:

```bash
diff ~/.zshrc configs/dot_zshrc || true
```
Review each hunk against Steps 2-3 (allowed hunk classes: the new `if`/`fi` guard lines and re-indentation inside them, `command -v` prefixes, the deleted Linux placeholder, `plugins=(` un-export, the case-block PATH guards, plus blank-line shifts from `{{-` chomping and the "(macOS only)" comment-text change). Any unexplained hunk = fidelity bug; fix before committing. NOTE: the real machine's `chezmoi status` will NOT change yet — this rename lives in the worktree and chezmoi reads the real source dir; the real-machine apply happens in Task 9 after merge. DO NOT apply here.

- [ ] **Step 6: Commit**

```bash
git add configs/dot_zshrc
git commit -m "feat: de-template zshrc — runtime OS/tool guards replace chezmoi conditionals"
```

### Task 2: Gut `.chezmoi.toml.tmpl`, onboard `dot_gitconfig`

**Runs in: the REAL repo `~/dev/dots`** (uses `chezmoi add`).

**Files:**
- Rewrite: `configs/.chezmoi.toml.tmpl`
- Create: `configs/dot_gitconfig` (via `chezmoi add ~/.gitconfig`)

- [ ] **Step 1: Confirm nothing uses the prompts anymore**

```bash
grep -rn "\.email\|machine_type\|is_macos\|is_linux" configs/ --include='*.tmpl' --include='.chezmoiignore'
```
Expected: only `.chezmoi.toml.tmpl` itself matches (`.chezmoiignore` uses `.chezmoi.os`, which is builtin data; the zshrc template never used these — this holds regardless of Task 1's worktree state). If anything else matches, stop and report.

- [ ] **Step 2: Replace `.chezmoi.toml.tmpl` content entirely with:**

```toml
# Intentionally minimal: the .email/.machine_type prompts were removed as
# unused (git identity ships in dot_gitconfig). If a per-machine value is
# ever needed again, add promptStringOnce data here — see git history.
```

(A comment-only TOML is valid; `chezmoi init` regenerates `~/.config/chezmoi/chezmoi.toml` without prompting. Stale `[data]` in existing machines' generated configs is harmless.)

- [ ] **Step 3: Onboard the gitconfig** (inspect first, like every add):

```bash
cat ~/.gitconfig   # confirm: public email + oh-my-zsh cache line only, no tokens
chezmoi add ~/.gitconfig
ls configs/dot_gitconfig && chezmoi diff ~/.gitconfig && echo gitconfig-clean
```
Expected: `configs/dot_gitconfig` exists; diff empty → `gitconfig-clean`. Note: the file contains the git email (already public in commit history — spec-sanctioned) and an `[oh-my-zsh] git-commit-alias` cache line (accepted churn, same class as lazy-lock.json).

- [ ] **Step 4: Verify chezmoi still healthy**

```bash
chezmoi doctor 2>&1 | grep -i "error\|warning" || echo doctor-ok
chezmoi status
```
Expected: `doctor-ok` (or only pre-existing warnings — inspect); status does NOT list `.zshrc` (Task 1's rename is in the worktree, invisible to the real chezmoi until Task 9's merge) and shows nothing alarming.

- [ ] **Step 5: Commit**

```bash
git add configs/.chezmoi.toml.tmpl configs/dot_gitconfig
git commit -m "feat: drop unused chezmoi prompts, onboard gitconfig"
```

### Task 3: Target-path `.chezmoiignore`, hardened run_onchange, Brewfile trim

**Runs in: the worktree.**

**Files:**
- Rewrite: `configs/.chezmoiignore`
- Modify: `configs/run_onchange_install-packages.sh.tmpl`
- Modify: `configs/Brewfile`

- [ ] **Step 1: Rewrite `.chezmoiignore` with target-path patterns** (current patterns use SOURCE names like `dot_config/kitty/`, which chezmoi does not match — kitty would deploy on Linux):

```
Brewfile
{{- if ne .chezmoi.os "darwin" }}
.config/kitty
install-packages.sh
{{- end }}
```

- [ ] **Step 2: Harden the run_onchange script.** Replace its first line `#!/bin/bash` with:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

(keep the `# hash:` template comment and everything else as-is).

- [ ] **Step 3: Trim the Brewfile** — delete all 16 `vscode "..."` lines (VS Code is not installed; brew bundle skips them silently today):

```bash
grep -c '^vscode' configs/Brewfile   # expect 16 before
sed -i '' '/^vscode /d' configs/Brewfile
grep -c '^vscode' configs/Brewfile || echo vscode-gone
```

- [ ] **Step 4: Verify ignore semantics against the WORKTREE's rewritten file** (the real source dir still has the old file, and on darwin both render identically — point chezmoi at the worktree source explicitly):

```bash
chezmoi ignored --source "$PWD/configs" | head -20
```
Expected: exactly `Brewfile` (we're on darwin — the kitty/install-packages entries only materialize on Linux; the Linux branch is genuinely exercised by a Linux machine or CI, not here). This proves the rewritten file parses and the darwin behavior is unchanged. Note: the Brewfile edit changes the run_onchange hash → the first post-merge `chezmoi apply` (Task 9) will re-run `brew bundle` once (harmless; it no-ops on installed packages).

- [ ] **Step 5: Commit**

```bash
git add configs/.chezmoiignore configs/run_onchange_install-packages.sh.tmpl configs/Brewfile
git commit -m "fix: target-path chezmoiignore, strict-mode run_onchange, drop dead vscode Brewfile lines"
```

---

## Chunk 2: Onboarding & docs

### Task 4: Onboard lazygit, htop, Claude settings

**Runs in: the REAL repo `~/dev/dots`** (uses `chezmoi add`).

**Files:**
- Create: `configs/dot_config/lazygit/**`, `configs/dot_config/htop/**`, `configs/dot_claude/settings.json`

- [ ] **Step 1: Inspect before adding** (never add blind):

```bash
ls -la ~/.config/lazygit/ ~/.config/htop/
cat ~/.claude/settings.json
```
Confirm no secrets/tokens in any of them (lazygit config.yml and htoprc are plain settings; ~/.claude/settings.json should be feature flags/preferences — if you see anything credential-like, STOP and report NEEDS_CONTEXT).

- [ ] **Step 2: Add them**

```bash
chezmoi add ~/.config/lazygit ~/.config/htop ~/.claude/settings.json
git -C ~/dev/dots status --short
```
Expected: new files under `configs/dot_config/lazygit/`, `configs/dot_config/htop/`, and `configs/dot_claude/settings.json` (NOT the whole `dot_claude` directory — only settings.json; verify nothing else from `~/.claude` was added).

- [ ] **Step 3: Verify clean round-trip**

```bash
chezmoi diff ~/.config/lazygit ~/.config/htop ~/.claude/settings.json && echo add-clean
chezmoi managed --include=files | grep -c "lazygit\|htop\|claude"
```
Expected: `add-clean`; count ≥ 3. (htop rewrites htoprc on exit — periodic churn commits are an accepted trade-off per spec.)

- [ ] **Step 4: Commit**

```bash
git add configs/
git commit -m "feat: onboard lazygit, htop, and Claude settings configs"
```

### Task 5: oh-my-zsh + custom plugins via `.chezmoiexternal.toml`

**Runs in: the REAL repo `~/dev/dots`** (verification runs `chezmoi apply` for the externals).

**Files:**
- Create: `configs/.chezmoiexternal.toml`

- [ ] **Step 1: Record current plugin remotes** (the externals must point at the same upstreams):

```bash
for p in autoupdate fast-syntax-highlighting zsh-autosuggestions; do
  git -C ~/.oh-my-zsh/custom/plugins/$p remote get-url origin
done
git -C ~/.oh-my-zsh remote get-url origin
```
Use the URLs printed (expected: ohmyzsh/ohmyzsh, TamCore/autoupdate-oh-my-zsh-plugin (or similar), zdharma-continuum/fast-syntax-highlighting, zsh-users/zsh-autosuggestions — trust the machine's actual remotes over this list).

- [ ] **Step 2: Create `configs/.chezmoiexternal.toml`** with the recorded URLs:

```toml
# oh-my-zsh and custom plugins as git-repo externals: chezmoi clones them on
# a fresh machine and pulls at most weekly, fixing the broken fresh-machine
# bootstrap (they were never installed by anything before).
[".oh-my-zsh"]
    type = "git-repo"
    url = "<oh-my-zsh remote from Step 1>"
    refreshPeriod = "168h"

[".oh-my-zsh/custom/plugins/autoupdate"]
    type = "git-repo"
    url = "<autoupdate remote>"
    refreshPeriod = "168h"

[".oh-my-zsh/custom/plugins/fast-syntax-highlighting"]
    type = "git-repo"
    url = "<fast-syntax-highlighting remote>"
    refreshPeriod = "168h"

[".oh-my-zsh/custom/plugins/zsh-autosuggestions"]
    type = "git-repo"
    url = "<zsh-autosuggestions remote>"
    refreshPeriod = "168h"
```

- [ ] **Step 3: Verify chezmoi accepts it and behaves on an ALREADY-CLONED machine** (the risky case — these dirs exist):

```bash
chezmoi doctor 2>&1 | tail -3
chezmoi apply --dry-run --verbose ~/.oh-my-zsh 2>&1 | head -20
```
Expected: doctor happy; the dry-run output may be EMPTY or terse — chezmoi's git-repo externals are "clone and/or pull" only and are not manifested in diff/dump output, so silence is success here, NOT failure. The one thing that must not appear is a proposed removal/re-creation of the existing `~/.oh-my-zsh` checkout; if you see that, STOP and report (do not apply). (Related expected behavior: after this change the plugin dirs still appear in `chezmoi unmanaged` and never in `chezmoi diff` — that is documented external semantics, not a bug.)

- [ ] **Step 4: Real apply of just the externals + fresh-shell test**

```bash
chezmoi apply ~/.oh-my-zsh
zsh -ic 'echo shell-ok' 2>&1 | tail -3
```
Expected: apply succeeds (a git pull at most); `shell-ok` with no errors.

- [ ] **Step 5: Commit**

```bash
git add configs/.chezmoiexternal.toml
git commit -m "feat: manage oh-my-zsh and custom plugins as chezmoi git externals"
```

### Task 6: Document the do-not-add list and structure drift

**Runs in: the worktree.**

**Files:**
- Modify: `README.md`, `CLAUDE.md`

- [ ] **Step 1: CLAUDE.md.** In Critical Rules add:

```markdown
- **Never manage these** (secrets/state): `~/.config/gh/hosts.yml` (OAuth tokens), anything under `~/.claude` except `settings.json` (credentials/history), zed conversations/embeddings, shell history, zoxide DB
```

Update the Project Structure tree: `dot_zshrc.tmpl # zsh config (templated for macOS/Linux)` → `dot_zshrc # zsh config (plain; runtime OS/tool guards)`; add a `.chezmoiexternal.toml # oh-my-zsh + plugin git externals` line under configs/. Update the chezmoi section's "Template data" bullet (`.email`, `.machine_type`, `.is_macos`, `.is_linux`) to say the config template is intentionally minimal with no custom data.

- [ ] **Step 2: README.md.** Mirror the same: structure tree (dot_zshrc plain, .chezmoiexternal.toml), and add a short "What's deliberately not managed" list (same items as CLAUDE.md).

- [ ] **Step 3: Verify + commit**

```bash
grep -n "dot_zshrc.tmpl\|machine_type" README.md CLAUDE.md || echo docs-drift-gone
git add README.md CLAUDE.md
git commit -m "docs: record do-not-add exclusions and de-templated zshrc"
```

---

## Chunk 3: CI

### Task 7: CI upgrades — pinned action, gofmt gate, make build, Go cache path

**Runs in: the worktree.**

**Files:**
- Modify: `.github/workflows/ci.yml`, `Makefile`

- [ ] **Step 1: Pin the shellcheck action.** Resolve the current master SHA:

```bash
gh api repos/ludeeus/action-shellcheck/commits/master --jq .sha
```

Replace `uses: ludeeus/action-shellcheck@master` with `uses: ludeeus/action-shellcheck@<sha>  # master as of 2026-07-14`. **Keep the `env: SHELLCHECK_OPTS: -x` block and its comment exactly as they are.**

- [ ] **Step 2: gofmt gate.** In `ci.yml`'s `build-and-test` job, after "Set up Go", add:

```yaml
      - name: Check formatting
        run: cd tui && test -z "$(gofmt -l .)" || { gofmt -l .; exit 1; }
```

And in the `Makefile` lint target, add the same line after the go vet line:

```make
	cd tui && test -z "$$(gofmt -l .)" || { gofmt -l .; exit 1; }
```

(note the `$$` escaping in Make.)

- [ ] **Step 3: Build via make build** (exercises the ldflags version injection). Replace the CI Build step's `run: cd tui && go build -o dots .` with `run: make build`.

- [ ] **Step 4: Fix the Go cache warning.** In the "Set up Go" step add:

```yaml
        with:
          go-version: '1.24'
          cache-dependency-path: tui/go.sum
```

(also updating go-version from '1.22' to '1.24' to match go.mod).

- [ ] **Step 5: Verify locally what can be verified**

```bash
make lint && make build && ./tui/dots --version
```
Expected: lint (now incl. gofmt gate) clean; build ok.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/ci.yml Makefile
git commit -m "ci: pin shellcheck action, add gofmt gate, build via make, fix Go cache path"
```

### Task 8: The smoke-test job — codify Phase 1's guarantees

**Runs in: the worktree.**

**Files:**
- Create: `scripts/ci-smoke.sh`
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Write `scripts/ci-smoke.sh`.** Self-contained scratch harness asserting the Phase 1 invariants. Requirements: `set -euo pipefail`; shellcheck-clean (it will be linted by `make lint` and CI automatically); uses only git, bash, jq (present on both runner OSes); never touches the invoking user's real state (`XDG_STATE_HOME`, `DOTS_DIR`, and `PATH`-stubbed chezmoi all point into a mktemp dir); exits non-zero with a clear `FAIL:` message on any assertion. Content:

```bash
#!/usr/bin/env bash
# ci-smoke.sh — end-to-end smoke test of the dots sync scripts against a
# scratch git remote and a stubbed chezmoi. Codifies the Phase 1 guarantees:
# commits are never stranded, remote-ahead converges, template conflicts
# block, concurrent runs are excluded by the lock, and the JSON log is valid.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS=$(mktemp -d)
trap 'rm -rf "$HARNESS"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "ok: $1"; }

# --- harness -----------------------------------------------------------------
mkdir -p "$HARNESS/bin" "$HARNESS/state"

cat > "$HARNESS/bin/chezmoi" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    re-add) exit "${STUB_READD_EXIT:-0}" ;;
    status) printf '%b' "${STUB_STATUS_OUTPUT:-}"; exit 0 ;;
    source-path) echo "${STUB_SOURCE_PATH:-/stub/source}"; exit 0 ;;
    apply) exit "${STUB_APPLY_EXIT:-0}" ;;
    *) exit 0 ;;
esac
EOF
chmod +x "$HARNESS/bin/chezmoi"

git init -q --bare "$HARNESS/remote.git"
git -C "$HARNESS/remote.git" symbolic-ref HEAD refs/heads/main
git clone -q "$HARNESS/remote.git" "$HARNESS/work" 2>/dev/null
git -C "$HARNESS/work" symbolic-ref HEAD refs/heads/main
git -C "$HARNESS/work" config user.email ci-smoke@example.invalid
git -C "$HARNESS/work" config user.name "CI Smoke"
git -C "$HARNESS/work" commit -q --allow-empty -m "init"
git -C "$HARNESS/work" push -q -u origin main

run_push() { PATH="$HARNESS/bin:$PATH" DOTS_DIR="$HARNESS/work" XDG_STATE_HOME="$HARNESS/state" bash "$REPO_ROOT/scripts/push.sh"; }
run_sync() { PATH="$HARNESS/bin:$PATH" DOTS_DIR="$HARNESS/work" XDG_STATE_HOME="$HARNESS/state" bash "$REPO_ROOT/scripts/sync.sh"; }

remote_head_subject() { git -C "$HARNESS/remote.git" log -1 --format=%s; }

# --- 1: new file is committed and pushed --------------------------------------
echo smoke > "$HARNESS/work/smoke.txt"
run_push >/dev/null
[[ "$(remote_head_subject)" == "dots: update smoke.txt" ]] || fail "new file did not reach the remote"
pass "new file committed and pushed"

# --- 2: a stranded commit is healed on a no-change run ------------------------
git -C "$HARNESS/work" commit -q --allow-empty -m "stranded"
run_push >/dev/null
[[ "$(remote_head_subject)" == "stranded" ]] || fail "stranded commit was not converged"
pass "stranded commit healed"

# --- 3: remote-ahead run rebases and pushes -----------------------------------
git clone -q "$HARNESS/remote.git" "$HARNESS/work2"
git -C "$HARNESS/work2" config user.email ci-smoke@example.invalid
git -C "$HARNESS/work2" config user.name "CI Smoke"
git -C "$HARNESS/work2" commit -q --allow-empty -m "remote moved"
git -C "$HARNESS/work2" push -q
git -C "$HARNESS/work" commit -q --allow-empty -m "local behind"
run_push >/dev/null
# Plain grep (not -q): grep -q exits at first match, git takes SIGPIPE, and
# under pipefail the pipeline reports 141 — a guaranteed false failure.
git -C "$HARNESS/remote.git" log --format=%s | grep "remote moved" >/dev/null || fail "remote commit lost"
git -C "$HARNESS/remote.git" log --format=%s | grep "local behind" >/dev/null || fail "local commit not pushed after rebase"
pass "remote-ahead run converged"

# --- 4: template conflict blocks before any state change ----------------------
if STUB_STATUS_OUTPUT='MM .zshrc\n' STUB_SOURCE_PATH=/fake/dot_zshrc.tmpl run_push >/dev/null 2>&1; then
    fail "template conflict did not block push"
fi
tail -1 "$HARNESS/state/dots/sync.log" | jq -e '.action == "push" and .result == "failure"' >/dev/null \
    || fail "template conflict was not logged as a failure"
pass "template conflict blocks and logs"

# --- 5: lock excludes concurrent runs -----------------------------------------
mkdir -p "$HARNESS/state/dots/lock"
echo $$ > "$HARNESS/state/dots/lock/pid"
if run_push >/dev/null 2>&1; then
    fail "push ran despite a held lock"
fi
tail -1 "$HARNESS/state/dots/sync.log" | jq -e '.result == "skipped"' >/dev/null \
    || fail "lock contention was not logged as skipped"
rm -rf "$HARNESS/state/dots/lock"
pass "lock excludes concurrent runs"

# --- 6: full sync produces exactly one valid JSON entry -----------------------
: > "$HARNESS/state/dots/sync.log"
echo more > "$HARNESS/work/more.txt"
run_sync >/dev/null
[[ "$(wc -l < "$HARNESS/state/dots/sync.log" | tr -d ' ')" == "1" ]] || fail "sync logged more than one entry"
jq -e '.action == "sync" and .result == "success" and (.duration_ms | type == "number")' \
    "$HARNESS/state/dots/sync.log" >/dev/null || fail "sync log entry invalid"
pass "sync logs exactly one valid entry"

# --- 7: whole log is valid JSON -----------------------------------------------
jq -es . "$HARNESS/state/dots/sync.log" >/dev/null || fail "sync.log contains invalid JSON"
pass "sync.log fully valid JSON"

echo "all smoke tests passed"
```

- [ ] **Step 2: Run it locally**

```bash
bash scripts/ci-smoke.sh
```
Expected: seven `ok:` lines then `all smoke tests passed`, exit 0. Also `shellcheck scripts/ci-smoke.sh` → clean.

- [ ] **Step 3: Add the CI job** to `.github/workflows/ci.yml`:

```yaml
  smoke-scripts:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Run sync-script smoke tests
        run: bash scripts/ci-smoke.sh
```

- [ ] **Step 4: Full local lint + commit**

```bash
make lint
git add scripts/ci-smoke.sh .github/workflows/ci.yml
git commit -m "ci: add scratch-repo smoke test for push/sync guarantees"
```

### Task 9: Final verification (controller-driven, real machine)

**Files:** none (verification, merge, push).

- [ ] **Step 1: Merge worktree branch into main** (with the real-repo Tasks 2/4/5 commits, controller sequences the rebase), then from `~/dev/dots`: `make lint && make test && make build`.
- [ ] **Step 2: Apply everything for real:** `chezmoi apply` (expect: the de-templated `.zshrc` applies — the guard-version replaces the rendered one; run_onchange re-runs brew bundle once due to Brewfile hash change). Then `chezmoi status` → clean; `chezmoi doctor` → healthy.
- [ ] **Step 3: Fresh shell:** `zsh -ic 'echo shell-ok'` → no errors. Spot-check aliases/env (`zsh -ic 'alias brup >/dev/null && echo alias-ok'`).
- [ ] **Step 4: Template-safety net still intact:** the ONLY user-editable templates are gone — `echo "# drill" >> ~/.zshrc && bash scripts/push.sh` must now SUCCEED (re-add captures it into `configs/dot_zshrc`, commit + push — this intentionally lands a real drill commit on origin, consistent with the auto-sync churn workflow). Clean up properly: remove the line from the SOURCE `configs/dot_zshrc`, commit (second real commit), `chezmoi apply --force ~/.zshrc` (--force avoids any interactive prompt), and confirm `grep drill ~/.zshrc` is empty and `chezmoi status` clean. Verify `check_template_conflicts` still exists in lib.sh and passes clean.
- [ ] **Step 5: Real push + CI:** `bash scripts/push.sh`; `gh run watch` the run (now 3 jobs incl. smoke on both OSes) to success.
- [ ] **Step 6: TUI check:** `./tui/dots --version`; note for the user: the Configs tab now shows lazygit/htop/home (with `.gitconfig`)/`.claude` automatically — Phase 2's discovery doing its job. Interactive walkthrough remains on the user's list.
