# Phase 1: Scripts & Data Integrity Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make dots sync safe — locking, JSON-escaped logging, push convergence invariants, and a template-conflict preflight gating every apply path — so no direct edit or commit can be silently lost.

**Architecture:** A new `scripts/lib.sh` provides shared primitives (tty-gated colors, JSON logging, mkdir-based locking, template-conflict detection) sourced by all five scripts. `push.sh` gains a converge-with-remote step and a "success ⇒ nothing unpushed" invariant; `update.sh` gains stuck-rebase recovery and the apply preflight; `sync.sh` orchestrates both under a single lock.

**Tech Stack:** Bash (strict mode, shellcheck-clean), chezmoi v2.71.0, git. No Go changes in this phase.

**Spec:** `docs/superpowers/specs/2026-07-10-audit-fixes-and-config-expansion-design.md` (Phase 1 section)

---

## Context you must know before starting

- **Working directory for all commands:** `~/dev/dots` (repo root) unless a step says otherwise.
- **The re-add blind spot (finding 1):** `chezmoi re-add` silently skips `.tmpl` sources. `~/.zshrc` is still templated until Phase 3, so a direct edit to it must make push/update/sync fail loudly until reconciled — that is intended behavior, not a bug.
- **TUI compatibility constraints (verified against current Go code):**
  - `tui/internal/app/status.go:20-25` unmarshals sync.log lines into `{timestamp, action, result, duration_ms, details}`. `duration_ms` may be omitted (Go zero-values it). Never emit invalid JSON.
  - `tui/internal/scheduler/scheduler.go:72` detects scheduler state via `strings.Contains(clean, "ACTIVE") && !strings.Contains(clean, "INACTIVE")`. Any new `schedule.sh status` output line for a broken state **must not contain the substring `ACTIVE`** (use `BROKEN`).
- **Locking contract:** `sync.sh` takes the lock for its whole run and exports `DOTS_LOCK_HELD=1`; `push.sh`/`update.sh` see that env var, skip acquiring, and suppress their own sync.log entries (sync.sh logs once for the run). Invoked standalone (e.g. from the TUI), they take the lock and log themselves.
- **shellcheck:** `make lint` runs `shellcheck scripts/*.sh`, which automatically includes the new `lib.sh` and passes because lib.sh is itself an input. Checking a **single** script that sources lib.sh requires `-x` (e.g. `shellcheck -x scripts/push.sh`, run **from the repo root**) — without `-x`, SC1091 fires and exits 1 even with the `# shellcheck source=scripts/lib.sh` directive present. Every task must end shellcheck-clean; never "fix" a warning with a disable comment when the code can be restructured.
- **Scratch harness:** Tasks 6–8 verify against throwaway git repos plus a `chezmoi` stub on `PATH`, so no real machine state is touched until the final verification task.
- **macOS bash is 3.2** (`/bin/bash`); scripts use `#!/usr/bin/env bash`. Avoid bash-4-only features (associative arrays, `${var,,}`, `mapfile`).

### File map for this phase

| File | Action | Responsibility |
| --- | --- | --- |
| `scripts/lib.sh` | Create | Shared primitives: colors, `json_escape`, `log_json`/`log_json_event`, `acquire_lock`/`release_lock`, `check_template_conflicts` |
| `scripts/push.sh` | Rewrite | Preflight → re-add → `git add -A` → commit → converge → invariant |
| `scripts/update.sh` | Rewrite | Stuck-rebase recovery → pull → preflight → apply |
| `scripts/sync.sh` | Rewrite | Orchestrate push+update under one lock, JSON log, rotate logs |
| `scripts/schedule.sh` | Modify | Interval validation, XDG paths, systemd PATH, BROKEN status |
| `scripts/install.sh` | Modify | brew check, safe curl install, version-parse error, drop duplicate `brew bundle` |
| `.gitignore` | Modify | Audit for `git add -A` safety |
| `CLAUDE.md`, `README.md` | Modify | Replace hardcoded-staging rule; document lib.sh |

---

## Chunk 1: lib.sh foundation

### Task 1: Create `scripts/lib.sh` with tty-gated colors and `json_escape`

**Files:**
- Create: `scripts/lib.sh`

- [ ] **Step 1: Write `scripts/lib.sh`**

Note: the state-dir and lock variables are deliberately **not** defined yet — shellcheck flags variables that nothing in the file uses (SC2034), and each task must commit shellcheck-clean. Task 2 and Task 3 introduce them alongside the functions that use them.

```bash
#!/usr/bin/env bash
# lib.sh — shared foundation sourced by the dots scripts. Not executable on
# its own. Source it with:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Color helpers — plain text when stdout is not a terminal, so launchd/systemd
# logs don't fill with ANSI escapes.
if [[ -t 1 ]]; then
    NC='\033[0m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
else
    NC=''
    GREEN=''
    BLUE=''
    RED=''
    YELLOW=''
fi

info() { echo -e "${BLUE}$1${NC}"; }
success() { echo -e "${GREEN}$1${NC}"; }
error() { echo -e "${RED}$1${NC}" >&2; }
warn() { echo -e "${YELLOW}$1${NC}"; }

# json_escape <string> — print the string escaped for embedding in a JSON
# string value. JSON forbids unescaped control characters (0x00-0x1f).
json_escape() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\b'/\\b}
    s=${s//$'\f'/\\f}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    # Any remaining control characters are dropped rather than escaped.
    s=$(printf '%s' "$s" | tr -d '\000-\037')
    printf '%s' "$s"
}
```

- [ ] **Step 2: Verify `json_escape` behavior**

Run:
```bash
bash -c 'source scripts/lib.sh; json_escape $'"'"'he said "hi\\" and\tleft\n'"'"'; echo'
```
Expected output: `he said \"hi\\\" and\tleft\n` (literal backslash-escapes, no raw tab/newline).

Run:
```bash
bash -c 'source scripts/lib.sh; json_escape "plain text"; echo'
```
Expected output: `plain text`

- [ ] **Step 3: Verify tty gating**

Run:
```bash
bash -c 'source scripts/lib.sh; info colored' | cat -v
```
Expected: `colored` with **no** `^[[` escape sequences (stdout is a pipe, not a tty).

- [ ] **Step 4: shellcheck**

Run: `shellcheck scripts/lib.sh`
Expected: no output, exit 0. (The color vars don't trip SC2034 because the helper functions in the same file use them.)

- [ ] **Step 5: Commit**

```bash
git add scripts/lib.sh
git commit -m "feat: add scripts/lib.sh with tty-gated colors and json_escape"
```

### Task 2: Add `log_json` / `log_json_event` to lib.sh

**Files:**
- Modify: `scripts/lib.sh`

- [ ] **Step 1: Add state-dir constants above the color block**

Insert immediately after the header comment (before the color helpers):

```bash
DOTS_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dots"
DOTS_SYNC_LOG="$DOTS_STATE_DIR/sync.log"

# Whether a parent process (sync.sh) already held the dots lock when this
# script started. Children skip locking and per-script logging.
DOTS_PARENT_HOLDS_LOCK="${DOTS_LOCK_HELD:-0}"
```

- [ ] **Step 2: Append logging functions after `json_escape`**

```bash
# log_json <result> <details> <action> [duration_ms] — append one JSON entry
# to the sync log. Field set matches what the TUI parses
# (tui/internal/app/status.go); duration_ms is optional.
log_json() {
    local result=$1 details=$2 action=$3 duration_ms=${4:-}
    mkdir -p "$DOTS_STATE_DIR"
    local ts entry
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    entry="{\"timestamp\":\"$ts\",\"action\":\"$(json_escape "$action")\",\"result\":\"$(json_escape "$result")\""
    # A non-numeric duration would corrupt the JSON — omit it instead.
    if [[ -n "$duration_ms" && "$duration_ms" =~ ^[0-9]+$ ]]; then
        entry+=",\"duration_ms\":$duration_ms"
    fi
    entry+=",\"details\":\"$(json_escape "$details")\"}"
    echo "$entry" >> "$DOTS_SYNC_LOG"
}

# log_json_event — like log_json, but suppressed when a parent (sync.sh)
# holds the lock, so an orchestrated run logs once instead of three times.
log_json_event() {
    if [[ "$DOTS_PARENT_HOLDS_LOCK" == "1" ]]; then
        return 0
    fi
    log_json "$@"
}
```

- [ ] **Step 3: Verify entries are valid JSON with correct fields**

Run (sandboxed state dir; requires `jq` — `brew install jq` if missing):
```bash
SANDBOX=$(mktemp -d)
XDG_STATE_HOME="$SANDBOX" bash -c '
    source scripts/lib.sh
    log_json failure $'"'"'weird "details"\twith\ttabs'"'"' push
    log_json success "push ok, pull ok" sync 4200
'
jq -c '.' "$SANDBOX/dots/sync.log"
jq -r '.duration_ms // "absent"' "$SANDBOX/dots/sync.log"
```
Expected: two JSON objects print without jq errors; second command prints `absent` then `4200`.

- [ ] **Step 4: Verify suppression under an orchestrating parent**

Run:
```bash
XDG_STATE_HOME="$SANDBOX" DOTS_LOCK_HELD=1 bash -c '
    source scripts/lib.sh
    log_json_event failure "should be suppressed" push
'
wc -l < "$SANDBOX/dots/sync.log"
```
Expected: still `2` (no third line was appended).

- [ ] **Step 5: shellcheck**

Run: `shellcheck scripts/lib.sh`
Expected: exit 0, no output.

- [ ] **Step 6: Commit**

```bash
git add scripts/lib.sh
git commit -m "feat: add escaped JSON sync-log helpers to lib.sh"
```

### Task 3: Add `acquire_lock` / `release_lock` to lib.sh

mkdir-based lock (macOS ships no `flock` binary). Lock dir holds the owner PID; a lock whose PID is dead is stale and reclaimed. Re-entrant across processes via the `DOTS_LOCK_HELD` env guard.

**Files:**
- Modify: `scripts/lib.sh` (append after logging functions)

- [ ] **Step 1: Add the lock-dir constant**

Insert below `DOTS_SYNC_LOG=` near the top of lib.sh:

```bash
DOTS_LOCK_DIR="$DOTS_STATE_DIR/lock"
```

- [ ] **Step 2: Append locking functions**

```bash
# acquire_lock — take the global dots lock. Returns non-zero if another live
# process holds it. Re-entrant: when a parent (sync.sh) already holds the
# lock, returns 0 without acquiring. The acquiring process installs an EXIT
# trap to release.
acquire_lock() {
    if [[ "$DOTS_PARENT_HOLDS_LOCK" == "1" ]]; then
        return 0
    fi
    mkdir -p "$DOTS_STATE_DIR"
    local holder_pid
    for _ in 1 2; do
        if mkdir "$DOTS_LOCK_DIR" 2>/dev/null; then
            echo "$$" > "$DOTS_LOCK_DIR/pid"
            export DOTS_LOCK_HELD=1
            trap release_lock EXIT
            return 0
        fi
        holder_pid=$(cat "$DOTS_LOCK_DIR/pid" 2>/dev/null || true)
        if [[ -z "$holder_pid" ]]; then
            # Holder may be between mkdir and writing its pid — give it a
            # moment before declaring the lock stale.
            sleep 1
            holder_pid=$(cat "$DOTS_LOCK_DIR/pid" 2>/dev/null || true)
        fi
        if [[ -n "$holder_pid" ]] && kill -0 "$holder_pid" 2>/dev/null; then
            return 1
        fi
        # Holder is dead. Reclaim by atomically renaming the stale lock dir
        # aside — only one contender can win the rename, and the winner then
        # exclusively owns that instance, so re-checking its pid is race-free.
        if mv "$DOTS_LOCK_DIR" "$DOTS_LOCK_DIR.stale.$$" 2>/dev/null; then
            # If the pid inside is alive, we captured a lock that was
            # recreated after our staleness check — put it back and report
            # contention. (If a third process re-locked in the interim, the
            # restore fails and we just discard our capture; the displaced
            # holder's next run self-heals.)
            holder_pid=$(cat "$DOTS_LOCK_DIR.stale.$$/pid" 2>/dev/null || true)
            if [[ -n "$holder_pid" ]] && kill -0 "$holder_pid" 2>/dev/null; then
                mv "$DOTS_LOCK_DIR.stale.$$" "$DOTS_LOCK_DIR" 2>/dev/null || rm -rf "$DOTS_LOCK_DIR.stale.$$"
                return 1
            fi
            rm -rf "$DOTS_LOCK_DIR.stale.$$"
        fi
    done
    return 1
}

# release_lock — remove the lock if this process acquired it (never a lock
# inherited from a parent). Runs from the EXIT trap set by acquire_lock.
release_lock() {
    if [[ "${DOTS_LOCK_HELD:-0}" == "1" && "$DOTS_PARENT_HOLDS_LOCK" != "1" ]]; then
        rm -rf "$DOTS_LOCK_DIR"
    fi
}
```

- [ ] **Step 3: Verify contention, release, and re-entrancy**

Run:
```bash
SANDBOX=$(mktemp -d)
# Holder acquires, then a second process must fail to acquire.
XDG_STATE_HOME="$SANDBOX" bash -c '
    source scripts/lib.sh
    acquire_lock || { echo "FIRST FAILED"; exit 1; }
    XDG_STATE_HOME="'"$SANDBOX"'" DOTS_LOCK_HELD= bash -c "
        source scripts/lib.sh
        if acquire_lock; then echo CONTENTION-BUG; else echo contention-ok; fi
    "
    # Re-entrant path: child that inherits DOTS_LOCK_HELD=1 succeeds.
    XDG_STATE_HOME="'"$SANDBOX"'" bash -c "
        source scripts/lib.sh
        if acquire_lock; then echo reentrant-ok; else echo REENTRANT-BUG; fi
    "
'
# EXIT trap released the lock when the holder exited:
[[ -d "$SANDBOX/dots/lock" ]] && echo RELEASE-BUG || echo release-ok
```
Expected output lines: `contention-ok`, `reentrant-ok`, `release-ok`.

Note the inner contention shell clears `DOTS_LOCK_HELD=` — it simulates an unrelated process, not a child of the lock holder.

- [ ] **Step 4: Verify stale-lock reclaim**

Run:
```bash
mkdir -p "$SANDBOX/dots/lock"
echo 99999999 > "$SANDBOX/dots/lock/pid"   # PID that cannot be alive
XDG_STATE_HOME="$SANDBOX" bash -c '
    source scripts/lib.sh
    if acquire_lock; then echo stale-reclaim-ok; else echo STALE-BUG; fi
'
```
Expected output: `stale-reclaim-ok`.

- [ ] **Step 5: shellcheck**

Run: `shellcheck scripts/lib.sh`
Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add scripts/lib.sh
git commit -m "feat: add cross-platform mkdir-based locking to lib.sh"
```

### Task 4: Add `check_template_conflicts` to lib.sh

The safety net for the re-add blind spot: if any locally-modified target's source file is a `.tmpl`, warn loudly and return non-zero so callers refuse to re-add/apply.

**Files:**
- Modify: `scripts/lib.sh` (append after locking functions)

- [ ] **Step 1: Append the function**

```bash
# check_template_conflicts — chezmoi re-add silently skips .tmpl sources, so
# a later 'apply --force' would destroy direct edits to templated targets.
# Returns non-zero (naming each file) if any locally-modified target's source
# is a template. Callers must exit failure without re-adding or applying.
check_template_conflicts() {
    local status_output
    if ! status_output=$(chezmoi status); then
        error "chezmoi status failed; cannot check for template conflicts."
        return 1
    fi

    local conflicts=() line target source_path
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        # chezmoi status lines: two status chars, a space, then the target
        # path relative to ~. A non-space first char means the file changed
        # on disk since the last apply (a local edit).
        [[ "${line:0:1}" == " " ]] && continue
        target="${line:3}"
        source_path=$(chezmoi source-path "$HOME/$target" 2>/dev/null) || continue
        if [[ "$source_path" == *.tmpl ]]; then
            conflicts+=("$target")
        fi
    done <<< "$status_output"

    if (( ${#conflicts[@]} > 0 )); then
        error "BLOCKED: direct edit(s) to templated target(s) detected:"
        local t
        for t in "${conflicts[@]}"; do
            error "  ~/$t"
        done
        error "'chezmoi re-add' cannot capture edits to .tmpl sources, and applying would destroy them."
        error "Reconcile first with: chezmoi merge ~/<file>   (or edit the source template, then 'chezmoi apply')."
        return 1
    fi
    return 0
}
```

- [ ] **Step 2: Verify the clean case against the real machine**

Precondition: `chezmoi status` shows no locally-modified templated targets. Run `chezmoi status` first — **as of plan-writing, `~/.zshrc` shows `MM` on this machine**, so expect to reconcile before continuing:

1. `chezmoi diff ~/.zshrc` — inspect what differs.
2. If the local edit should be **kept**: port it by hand into `configs/dot_zshrc.tmpl` (remember `chezmoi re-add` cannot do this for templates), then `chezmoi apply --force ~/.zshrc` and confirm the diff is empty.
3. If the local edit is **disposable**: just `chezmoi apply --force ~/.zshrc`.

Surface what you found and did to the user in your task report — a real local edit here is exactly the data this phase exists to protect.

Run:
```bash
bash -c 'set -euo pipefail; source scripts/lib.sh; check_template_conflicts && echo clean-ok'
```
Expected output: `clean-ok`.

- [ ] **Step 3: Verify the conflict case with a deliberate edit**

`~/.zshrc` is deployed from `configs/dot_zshrc.tmpl`, so a direct edit to it is exactly the conflict this function exists to catch.

Run:
```bash
echo "# template-conflict drill $(date +%s)" >> ~/.zshrc
bash -c 'source scripts/lib.sh; check_template_conflicts; echo "exit: $?"'
```
Expected: `BLOCKED: direct edit(s) to templated target(s) detected:` naming `~/.zshrc`, then `exit: 1`.

- [ ] **Step 4: Undo the drill edit**

Run:
```bash
chezmoi apply --force ~/.zshrc
chezmoi status
```
Expected: the drill line is gone from `~/.zshrc` (`grep "template-conflict drill" ~/.zshrc` prints nothing) and `chezmoi status` no longer lists `.zshrc`.

- [ ] **Step 5: shellcheck + commit**

Run: `shellcheck scripts/lib.sh` — expected exit 0.

```bash
git add scripts/lib.sh
git commit -m "feat: add template-conflict safety net to lib.sh"
```

---

## Chunk 2: push.sh, update.sh, sync.sh, docs

### Reusable scratch harness (used by Tasks 6–8)

Each of these tasks verifies against a throwaway harness: a bare "remote", a working clone, a sandboxed state dir, and a `chezmoi` stub on `PATH` so no real chezmoi state is touched. Create it fresh at the start of each task's verification (it is cheap):

```bash
HARNESS=$(mktemp -d)
mkdir -p "$HARNESS/bin" "$HARNESS/state"

cat > "$HARNESS/bin/chezmoi" <<'EOF'
#!/usr/bin/env bash
# chezmoi stub for scratch verification of the dots scripts.
case "${1:-}" in
    re-add) exit "${STUB_READD_EXIT:-0}" ;;
    status) printf '%b' "${STUB_STATUS_OUTPUT:-}"; exit 0 ;;
    source-path) echo "${STUB_SOURCE_PATH:-/stub/source}"; exit 0 ;;
    apply)
        if [[ -n "${STUB_APPLY_MARKER:-}" ]]; then touch "$STUB_APPLY_MARKER"; fi
        exit "${STUB_APPLY_EXIT:-0}"
        ;;
    *) exit 0 ;;
esac
EOF
chmod +x "$HARNESS/bin/chezmoi"

git init --bare "$HARNESS/remote.git"
git -C "$HARNESS/remote.git" symbolic-ref HEAD refs/heads/main   # don't depend on init.defaultBranch
git clone "$HARNESS/remote.git" "$HARNESS/work" 2>/dev/null
git -C "$HARNESS/work" symbolic-ref HEAD refs/heads/main
git -C "$HARNESS/work" commit --allow-empty -m "init"
git -C "$HARNESS/work" push -u origin main

run_push()   { PATH="$HARNESS/bin:$PATH" DOTS_DIR="$HARNESS/work" XDG_STATE_HOME="$HARNESS/state" bash scripts/push.sh "$@"; }
run_update() { PATH="$HARNESS/bin:$PATH" DOTS_DIR="$HARNESS/work" XDG_STATE_HOME="$HARNESS/state" bash scripts/update.sh "$@"; }
run_sync()   { PATH="$HARNESS/bin:$PATH" DOTS_DIR="$HARNESS/work" XDG_STATE_HOME="$HARNESS/state" bash scripts/sync.sh "$@"; }
```

The stub is env-driven: e.g. `STUB_STATUS_OUTPUT='MM .zshrc\n' STUB_SOURCE_PATH=/fake/dot_zshrc.tmpl run_push` simulates a template conflict (env prefixes on a shell-function call export through to the child `bash scripts/push.sh` process). `git -C "$HARNESS/work"` commits work because git falls back to the global `user.name`/`user.email` already configured on this machine.

**Shell-state warning for agentic executors:** the Bash tool starts a fresh shell per invocation, so `$HARNESS` and the `run_*` functions do not survive between tool calls. Run a task's entire harness setup **plus** its verification steps in one Bash invocation (a single multi-line command), or re-run the setup block in each invocation.

### Task 5: Audit `.gitignore` for `git add -A` safety

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Add local-settings entry**

`.claude/settings.local.json` exists in the repo tree today and is only kept out of git by the user's *global* ignore file — on any other machine `git add -A` would stage it. Append to `.gitignore`:

```gitignore

# Local agent settings (machine-specific, never shared)
.claude/settings.local.json
```

The existing entries (`tui/dots`, `dots`, `.DS_Store`, `Thumbs.db`) already cover build artifacts and OS files.

- [ ] **Step 2: Verify nothing unexpected would be staged**

Run:
```bash
git check-ignore -v .claude/settings.local.json
git status --porcelain --ignored=matching | grep '^!!' || true
git add -A --dry-run
```
Expected: `check-ignore` now matches against the **repo's** `.gitignore` line; the dry-run lists no unexpected files (only your in-progress plan/doc files, if any).

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: ignore .claude/settings.local.json for git add -A safety"
```

### Task 6: Rewrite `push.sh`

Order: lock → template preflight → re-add → `git add -A` (fatal on failure) → commit if staged → **convergence** (pull --rebase + push whenever ahead, even with no new commit) → final invariant (never report success with unpushed commits).

**Files:**
- Rewrite: `scripts/push.sh`

- [ ] **Step 1: Replace `scripts/push.sh` entirely**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="${DOTS_DIR:-$HOME/dev/dots}"

# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

fail() {
    error "$1"
    log_json_event failure "$1" push
    exit 1
}

if ! acquire_lock; then
    warn "Another dots operation is running. Try again later."
    log_json_event skipped "lock held by another process" push
    exit 1
fi

cd "$DOTS_DIR"

info "Checking for template conflicts..."
check_template_conflicts || fail "template conflict: local edits to templated target(s)"

info "Capturing local config changes..."
chezmoi re-add || fail "chezmoi re-add failed"

info "Staging changes..."
git add -A || fail "git add -A failed"

if git diff --cached --quiet; then
    info "No new changes to commit."
else
    info "Changes to commit:"
    git diff --cached --stat

    if [[ $# -gt 0 ]]; then
        COMMIT_MSG="$1"
    else
        CHANGED_FILES=$(git diff --cached --name-only | head -5 | tr '\n' ',' | sed 's/,$//')
        COMMIT_MSG="dots: update ${CHANGED_FILES}"
    fi

    info "Committing: $COMMIT_MSG"
    git commit -m "$COMMIT_MSG" || fail "git commit failed"
fi

# Convergence: push everything unpushed, including commits stranded by a
# previously failed push or an aborted run — runs whether or not this
# invocation created a commit.
if git rev-parse --abbrev-ref '@{u}' &>/dev/null; then
    if (( $(git rev-list --count '@{u}..HEAD') > 0 )); then
        info "Pushing unpushed commit(s)..."
        if ! git pull --rebase; then
            git rebase --abort 2>/dev/null || true
            fail "rebase onto remote failed; resolve manually and rerun"
        fi
        git push || fail "git push failed"
    fi
    # Invariant: success is never reported while commits remain unpushed.
    (( $(git rev-list --count '@{u}..HEAD') == 0 )) || fail "commits remain unpushed after convergence"
    success "Push complete. Branch is in sync with remote."
    log_json_event success "push ok" push
else
    warn "No upstream configured; commit kept local. Set an upstream to enable pushing."
    log_json_event success "push ok (no upstream; commit kept local)" push
fi
```

- [ ] **Step 2: shellcheck + syntax**

Run (from the repo root — `-x` lets shellcheck follow the sourced lib.sh): `shellcheck -x scripts/push.sh && bash -n scripts/push.sh`
Expected: exit 0, no output.

- [ ] **Step 3: Set up the scratch harness**

Run the harness block from the top of this chunk. Verify setup: `git -C "$HARNESS/work" log --oneline` shows the `init` commit.

- [ ] **Step 4: Verify — no changes is not an early exit, and clean runs succeed**

```bash
run_push; echo "exit: $?"
```
Expected: `No new changes to commit.` then `Push complete. Branch is in sync with remote.`, `exit: 0`.

- [ ] **Step 5: Verify — new file is committed and pushed**

```bash
echo hello > "$HARNESS/work/newfile.txt"
run_push
git -C "$HARNESS/remote.git" log --oneline -1
```
Expected: push output shows a commit `dots: update newfile.txt`; the remote log's newest commit is that same commit (it reached the remote).

- [ ] **Step 6: Verify — a stranded commit is healed on the next run**

```bash
git -C "$HARNESS/work" commit --allow-empty -m "stranded by a failed push"
run_push; echo "exit: $?"
git -C "$HARNESS/remote.git" log --oneline -1
```
Expected: even though nothing new was staged, convergence pushes; exit 0; remote's newest commit is `stranded by a failed push`. (Before this rework, this scenario left the commit local forever — spec finding 3.)

- [ ] **Step 7: Verify — remote-ahead run rebases and pushes instead of failing**

```bash
git clone "$HARNESS/remote.git" "$HARNESS/work2" 2>/dev/null
git -C "$HARNESS/work2" commit --allow-empty -m "remote moved ahead"
git -C "$HARNESS/work2" push
git -C "$HARNESS/work" commit --allow-empty -m "local commit behind remote"
run_push; echo "exit: $?"
git -C "$HARNESS/remote.git" log --oneline -3
```
Expected: exit 0; remote log contains **both** `remote moved ahead` and `local commit behind remote` (local was rebased onto remote, then pushed).

- [ ] **Step 8: Verify — template conflict blocks everything and is logged**

```bash
STUB_STATUS_OUTPUT='MM .zshrc\n' STUB_SOURCE_PATH=/fake/dot_zshrc.tmpl run_push; echo "exit: $?"
tail -1 "$HARNESS/state/dots/sync.log"
```
Expected: `BLOCKED` warning naming `~/.zshrc`; `exit: 1`; last log line is valid JSON with `"action":"push"` and `"result":"failure"`.

- [ ] **Step 9: Verify — lock contention skips with a logged entry**

```bash
mkdir -p "$HARNESS/state/dots/lock"
echo $$ > "$HARNESS/state/dots/lock/pid"     # this shell's live PID
run_push; echo "exit: $?"
tail -1 "$HARNESS/state/dots/sync.log"
rm -rf "$HARNESS/state/dots/lock"
```
Expected: `Another dots operation is running.`; `exit: 1`; last log line has `"result":"skipped"`.

- [ ] **Step 10: Commit**

```bash
git add scripts/push.sh
git commit -m "fix: rework push.sh with preflight, git add -A, and push convergence"
```

### Task 7: Rewrite `update.sh`

Adds: lock, stuck-rebase recovery before pulling, rebase abort on pull failure, template preflight before applying (update.sh is invoked standalone by the TUI Sync tab, so it cannot rely on push.sh having run first).

**Files:**
- Rewrite: `scripts/update.sh`

- [ ] **Step 1: Replace `scripts/update.sh` entirely**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="${DOTS_DIR:-$HOME/dev/dots}"

# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

fail() {
    error "$1"
    log_json_event failure "$1" update
    exit 1
}

if ! acquire_lock; then
    warn "Another dots operation is running. Try again later."
    log_json_event skipped "lock held by another process" update
    exit 1
fi

# Never operate on a repo stuck mid-rebase (e.g. a previous run was killed).
if [[ -d "$DOTS_DIR/.git/rebase-merge" || -d "$DOTS_DIR/.git/rebase-apply" ]]; then
    warn "Repository is stuck mid-rebase; aborting the stale rebase."
    git -C "$DOTS_DIR" rebase --abort || true
    fail "repo was stuck mid-rebase; stale rebase aborted — rerun update"
fi

info "Pulling latest changes..."
if ! git -C "$DOTS_DIR" pull --rebase; then
    git -C "$DOTS_DIR" rebase --abort 2>/dev/null || true
    fail "git pull --rebase failed"
fi

info "Checking for template conflicts..."
check_template_conflicts || fail "template conflict: refusing to apply over local edits"

info "Applying chezmoi configs..."
chezmoi apply -v --force || fail "chezmoi apply failed"

log_json_event success "update ok" update
success "Update complete."
```

- [ ] **Step 2: shellcheck + syntax**

Run (from the repo root): `shellcheck -x scripts/update.sh && bash -n scripts/update.sh`
Expected: exit 0.

- [ ] **Step 3: Set up a fresh scratch harness** (same block as the chunk intro)

- [ ] **Step 4: Verify — clean pull + apply succeeds and logs**

```bash
run_update; echo "exit: $?"
tail -1 "$HARNESS/state/dots/sync.log"
```
Expected: `Update complete.`, `exit: 0`; log line has `"action":"update"`, `"result":"success"`.

- [ ] **Step 5: Verify — genuinely stuck rebase is aborted and reported**

Create a real conflicted mid-rebase state, then confirm update.sh refuses to run, cleans it, and the next run proceeds:

```bash
# Diverge: local and remote both change c.txt differently.
echo local > "$HARNESS/work/c.txt"
git -C "$HARNESS/work" add c.txt && git -C "$HARNESS/work" commit -m "local change"
git clone "$HARNESS/remote.git" "$HARNESS/work2" 2>/dev/null
echo remote > "$HARNESS/work2/c.txt"
git -C "$HARNESS/work2" add c.txt && git -C "$HARNESS/work2" commit -m "remote change" && git -C "$HARNESS/work2" push
# Strand the repo mid-rebase, as a killed run would:
git -C "$HARNESS/work" pull --rebase || true
ls -d "$HARNESS/work/.git/rebase-merge" 2>/dev/null || ls -d "$HARNESS/work/.git/rebase-apply"

run_update; echo "exit: $?"
[[ -d "$HARNESS/work/.git/rebase-merge" || -d "$HARNESS/work/.git/rebase-apply" ]] && echo STILL-STUCK || echo cleaned-ok
```
Expected: the `ls` confirms a mid-rebase dir exists before the run; `run_update` prints the stuck-rebase warning and exits 1; `cleaned-ok` (the stale rebase was aborted).

- [ ] **Step 6: Verify — pull conflict fails cleanly without leaving rebase state**

The divergence from Step 5 still exists, so this run's own `pull --rebase` conflicts:

```bash
run_update; echo "exit: $?"
[[ -d "$HARNESS/work/.git/rebase-merge" || -d "$HARNESS/work/.git/rebase-apply" ]] && echo LEFT-STUCK || echo aborted-ok
git -C "$HARNESS/work" reset --hard origin/main   # clear the divergence for later steps
```
Expected: `git pull --rebase failed`, `exit: 1`, `aborted-ok`.

- [ ] **Step 7: Verify — template conflict blocks apply**

```bash
STUB_STATUS_OUTPUT='MM .zshrc\n' STUB_SOURCE_PATH=/fake/dot_zshrc.tmpl STUB_APPLY_MARKER="$HARNESS/apply-ran" run_update; echo "exit: $?"
[[ -f "$HARNESS/apply-ran" ]] && echo APPLY-RAN-BUG || echo apply-blocked-ok
```
Expected: `BLOCKED` warning, `exit: 1`, `apply-blocked-ok` (the stub's apply marker was never created).

- [ ] **Step 8: Commit**

```bash
git add scripts/update.sh
git commit -m "fix: harden update.sh with stuck-rebase recovery and apply preflight"
```

### Task 8: Rewrite `sync.sh`

Adds: whole-run lock (skipped runs are logged), escaped JSON via `log_json`, rotation of sync.log **and** the launchd stdout/stderr logs while still holding the lock.

**Files:**
- Rewrite: `scripts/sync.sh`

- [ ] **Step 1: Replace `scripts/sync.sh` entirely**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

MAX_LOG_ENTRIES=500
MAX_SCHEDULER_LOG_LINES=1000

# rotate_log_tail <file> <max_lines> — truncate a log file to its last N lines.
rotate_log_tail() {
    local file=$1 max=$2 lines
    [[ -f "$file" ]] || return 0
    lines=$(wc -l < "$file")
    if (( lines > max )); then
        tail -n "$max" "$file" > "$file.tmp"
        mv "$file.tmp" "$file"
    fi
}

if ! acquire_lock; then
    warn "Another dots operation is running; skipping this sync."
    log_json skipped "lock held by another process" sync
    exit 0
fi

START_TIME=$(date +%s)
RESULT="success"
DETAILS=""

info "Phase 1: Pushing local changes..."
if "$SCRIPT_DIR/push.sh" "dots: auto-sync $(date -u +%Y-%m-%dT%H:%M:%SZ)"; then
    DETAILS="push ok"
else
    DETAILS="push failed"
    RESULT="failure"
fi

if [[ "$RESULT" == "success" ]]; then
    info "Phase 2: Pulling remote changes..."
    if "$SCRIPT_DIR/update.sh"; then
        DETAILS="$DETAILS, pull ok"
    else
        DETAILS="$DETAILS, pull failed"
        RESULT="failure"
    fi
fi

END_TIME=$(date +%s)
DURATION_MS=$(( (END_TIME - START_TIME) * 1000 ))

log_json "$RESULT" "$DETAILS" sync "$DURATION_MS"

# Rotate while still holding the lock so a concurrent run cannot lose appends.
rotate_log_tail "$DOTS_SYNC_LOG" "$MAX_LOG_ENTRIES"
rotate_log_tail "$DOTS_STATE_DIR/launchd-stdout.log" "$MAX_SCHEDULER_LOG_LINES"
rotate_log_tail "$DOTS_STATE_DIR/launchd-stderr.log" "$MAX_SCHEDULER_LOG_LINES"

if [[ "$RESULT" == "success" ]]; then
    success "Sync complete."
else
    error "Sync completed with errors. Check log: $DOTS_SYNC_LOG"
    exit 1
fi
```

Note: `DOTS_DIR` is intentionally not referenced here — push.sh and update.sh derive their own default, and an exported `DOTS_DIR` passes through to them.

- [ ] **Step 2: shellcheck + syntax**

Run (from the repo root): `shellcheck -x scripts/sync.sh && bash -n scripts/sync.sh`
Expected: exit 0.

- [ ] **Step 3: Set up a fresh scratch harness** (same block as the chunk intro)

- [ ] **Step 4: Verify — full run logs exactly one entry**

```bash
echo data > "$HARNESS/work/file.txt"
run_sync; echo "exit: $?"
cat "$HARNESS/state/dots/sync.log"
jq -c '.' "$HARNESS/state/dots/sync.log" > /dev/null && echo json-ok
```
Expected: `Sync complete.`, exit 0; sync.log holds **exactly one** line (push.sh/update.sh suppressed theirs) with `"action":"sync"`, `"result":"success"`, `"details":"push ok, pull ok"`, a numeric `duration_ms`; `json-ok`.

- [ ] **Step 5: Verify — child failure produces one failure entry and exit 1**

```bash
STUB_READD_EXIT=1 run_sync; echo "exit: $?"
tail -1 "$HARNESS/state/dots/sync.log"
```
Expected: `exit: 1`; the new last line has `"result":"failure"`, `"details":"push failed"`.

- [ ] **Step 6: Verify — lock contention logs a skipped run and exits 0**

```bash
mkdir -p "$HARNESS/state/dots/lock"
echo $$ > "$HARNESS/state/dots/lock/pid"
run_sync; echo "exit: $?"
tail -1 "$HARNESS/state/dots/sync.log"
rm -rf "$HARNESS/state/dots/lock"
```
Expected: `exit: 0`; last line has `"result":"skipped"`.

- [ ] **Step 7: Verify — rotation trims sync.log and launchd logs**

```bash
for i in $(seq 1 600); do echo "{\"n\":$i}" >> "$HARNESS/state/dots/sync.log"; done
seq 1 1200 > "$HARNESS/state/dots/launchd-stdout.log"
run_sync
wc -l "$HARNESS/state/dots/sync.log" "$HARNESS/state/dots/launchd-stdout.log"
```
Expected: sync.log has exactly 500 lines, launchd-stdout.log exactly 1000.

- [ ] **Step 8: Commit**

```bash
git add scripts/sync.sh
git commit -m "fix: sync.sh locking, JSON escaping, and log rotation"
```

### Task 9: Update CLAUDE.md and README for the new staging rule and lib.sh

The spec requires the CLAUDE.md Critical Rule about hardcoded staging paths to change **in the same phase** as the behavior change.

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`

- [ ] **Step 1: CLAUDE.md — Critical Rules**

Replace the bullet:

```markdown
- **Scripts stage explicit paths** — `push.sh` stages `configs/ scripts/ tui/ Makefile .gitignore CLAUDE.md README.md .github/` rather than `git add -A`
```

with:

```markdown
- **`push.sh` stages everything via `git add -A`** — keep `.gitignore` complete; anything untracked and unignored in the repo will be committed and pushed by the next sync
```

- [ ] **Step 2: CLAUDE.md — Architecture script tables and project structure**

In the **Project Structure** tree, add under `scripts/`:

```
│   ├── lib.sh                        # shared helpers: colors, JSON log, locking, template-conflict check
```

In the **Scripts** table, update the descriptions:

| Script | New description |
| --- | --- |
| `lib.sh` (new row) | Shared foundation sourced by all scripts: tty-gated colors, `json_escape`/`log_json`, mkdir-based locking, `check_template_conflicts` |
| `push.sh` | `check_template_conflicts` + `chezmoi re-add` + `git add -A` + commit + converge with remote (rebase, push; success requires nothing unpushed) |
| `update.sh` | Stuck-rebase recovery + `git pull --rebase` + `check_template_conflicts` + `chezmoi apply` |
| `sync.sh` | Push then pull under a single lock, one escaped-JSON log entry per run, log rotation |

Also update the sentence above the table ("All scripts use `set -euo pipefail`...") to add: "All scripts source `scripts/lib.sh`; `sync.sh` holds a lock for its whole run and its children skip locking/logging via `DOTS_LOCK_HELD`."

- [ ] **Step 3: CLAUDE.md — Shell Script Standards**

Change the bullet `**Color output helpers:** ...` to note the helpers live in `scripts/lib.sh` and are tty-gated. Then add this new bullet to the list:

```markdown
- **Locking and logging:** state-changing scripts acquire the dots lock and log failures via `scripts/lib.sh` — never suppress stderr or append `|| true` to state-changing commands
```

- [ ] **Step 4: README.md — script descriptions**

Update the `scripts/` section of the README's project-structure block to add a `lib.sh` line and update `push.sh`'s description — it must mention `git add -A` explicitly (e.g. `capture + git add -A + commit + converge`), since Step 5's verification greps for that phrase.

- [ ] **Step 5: Verify docs match reality**

Run:
```bash
grep -n "git add -A" CLAUDE.md README.md scripts/push.sh
grep -rn "stage explicit paths\|configs/ scripts/ tui/" CLAUDE.md README.md || echo stale-refs-gone
```
Expected: the first grep hits all three files; the second prints `stale-refs-gone`.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md README.md
git commit -m "docs: replace hardcoded staging rule with git add -A + gitignore"
```

---

## Chunk 3: schedule.sh, install.sh, final verification

### Task 10: Fix `schedule.sh` (validation, XDG paths, systemd PATH, BROKEN status)

**Files:**
- Modify: `scripts/schedule.sh`

- [ ] **Step 1: Source lib.sh and drop inline color helpers**

Replace lines 8–17 (the `NC=`/`GREEN=`/... block and the four helper functions) with:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"
```

Keep `DOTS_DIR`, `SYNC_SCRIPT`, `DEFAULT_INTERVAL` as they are.

- [ ] **Step 2: Use XDG state paths everywhere**

- In `generate_plist`, change `StandardOutPath`/`StandardErrorPath` values to `$DOTS_STATE_DIR/launchd-stdout.log` and `$DOTS_STATE_DIR/launchd-stderr.log`.
- In `cmd_enable`, replace both `mkdir -p "$HOME/.local/state/dots"` occurrences with `mkdir -p "$DOTS_STATE_DIR"`.
- In `cmd_status`, replace `local LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/dots/sync.log"` with `local LOG_FILE="$DOTS_SYNC_LOG"`.

- [ ] **Step 3: Fix the systemd unit PATH and timer precision**

In `generate_service`, change the `Environment=` line to:

```
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
```

(`%h` is systemd's specifier for the user's home; install.sh puts chezmoi in `~/.local/bin` on Linux.)

In `generate_timer`, delete the `local minutes=$(( interval / 60 ))` line and change the timer line to:

```
OnUnitActiveSec=${interval}s
```

- [ ] **Step 4: Add interval validation**

Add above `cmd_enable`:

```bash
# parse_interval <arg> — accept seconds, Nm, or Nh; print seconds.
# Rejects non-numeric input and anything under 60 seconds.
parse_interval() {
    local arg=$1 seconds
    if [[ "$arg" =~ ^([0-9]+)h$ ]]; then
        seconds=$(( BASH_REMATCH[1] * 3600 ))
    elif [[ "$arg" =~ ^([0-9]+)m$ ]]; then
        seconds=$(( BASH_REMATCH[1] * 60 ))
    elif [[ "$arg" =~ ^[0-9]+$ ]]; then
        seconds=$arg
    else
        error "Invalid interval '$arg'. Use seconds, Nm, or Nh (e.g. 900, 15m, 1h)."
        return 1
    fi
    if (( seconds < 60 )); then
        error "Interval must be at least 60 seconds (got ${seconds}s)."
        return 1
    fi
    echo "$seconds"
}
```

Replace the `enable)` case branch's inline `*h`/`*m` arithmetic with:

```bash
    enable)
        INTERVAL="$DEFAULT_INTERVAL"
        if [[ -n "${2:-}" ]]; then
            INTERVAL="$(parse_interval "$2")" || exit 1
        fi
        cmd_enable "$INTERVAL"
        ;;
```

In both `cmd_enable` success messages, replace `every $((interval / 60))m` with `every ${interval}s` (no more lying about sub-minute truncation).

- [ ] **Step 5: `status` verifies the baked-in script path**

In `cmd_status`, extend both platform branches. Darwin branch becomes:

```bash
    if [[ "$OS" == "Darwin" ]]; then
        if launchctl list "$PLIST_LABEL" &>/dev/null; then
            local baked
            # '|| true': sed exits 2 if the file is missing, and under pipefail
            # that would kill the script before the BROKEN branch can report it.
            baked=$(sed -n 's|.*<string>\(.*sync\.sh\)</string>.*|\1|p' "$PLIST_PATH" 2>/dev/null | head -1 || true)
            if [[ -z "$baked" || ! -f "$baked" ]]; then
                error "Scheduled sync: BROKEN — script path in $PLIST_PATH is missing (${baked:-unparseable})"
            else
                success "Scheduled sync: ACTIVE (launchd)"
                launchctl list "$PLIST_LABEL" 2>/dev/null | head -5
            fi
        else
            warn "Scheduled sync: INACTIVE"
        fi
```

Linux branch becomes:

```bash
    elif [[ "$OS" == "Linux" ]]; then
        if systemctl --user is-active "$SERVICE_NAME.timer" &>/dev/null; then
            local baked
            # '|| true': see the Darwin branch — a missing unit file must reach
            # the BROKEN report, not kill the script via pipefail.
            baked=$(sed -n 's/^ExecStart=//p' "$SYSTEMD_DIR/$SERVICE_NAME.service" 2>/dev/null | head -1 || true)
            if [[ -z "$baked" || ! -f "$baked" ]]; then
                error "Scheduled sync: BROKEN — script path in $SYSTEMD_DIR/$SERVICE_NAME.service is missing (${baked:-unparseable})"
            else
                success "Scheduled sync: ACTIVE (systemd)"
                systemctl --user status "$SERVICE_NAME.timer" --no-pager
            fi
        else
            warn "Scheduled sync: INACTIVE"
        fi
```

**Constraint:** the BROKEN line must not contain the substring `ACTIVE` — the TUI's `ParseStatus` (`tui/internal/scheduler/scheduler.go:72`) does a substring match, and BROKEN must read as not-active until Phase 2 teaches the TUI about it.

- [ ] **Step 6: shellcheck + safe functional checks**

Run:
```bash
shellcheck -x scripts/schedule.sh && bash -n scripts/schedule.sh   # from the repo root
bash scripts/schedule.sh 2>&1 | head -2            # usage text, exit 1
bash scripts/schedule.sh enable 30; echo "exit: $?"    # rejected before touching launchd
bash scripts/schedule.sh enable abc; echo "exit: $?"
bash scripts/schedule.sh status
```
Expected: shellcheck clean; usage prints; `enable 30` → "Interval must be at least 60 seconds", exit 1; `enable abc` → "Invalid interval", exit 1; `status` reports the machine's real current state (ACTIVE with the plist's script path present, or INACTIVE) without errors.

- [ ] **Step 7: Verify TUI status parsing still works**

Run: `cd tui && go test ./internal/scheduler/ && cd ..`
Expected: PASS (the existing ParseStatus tests cover ACTIVE/INACTIVE strings, which are unchanged).

- [ ] **Step 8: Commit**

```bash
git add scripts/schedule.sh
git commit -m "fix: schedule.sh interval validation, XDG paths, systemd PATH, broken-path status"
```

### Task 11: Fix `install.sh` error handling

install.sh runs from a clone (`git clone ... && bash scripts/install.sh` per README), so it can source lib.sh like the others.

**Files:**
- Modify: `scripts/install.sh`

- [ ] **Step 1: Source lib.sh, drop inline colors**

Replace lines 8–17 (color vars + helper functions) with:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"
```

- [ ] **Step 2: Check for Homebrew up front on macOS**

Insert after the `OS="$(uname -s)"` line:

```bash
if [[ "$OS" == "Darwin" ]] && ! command -v brew &>/dev/null; then
    error "Homebrew is required on macOS but was not found."
    error "Install it from https://brew.sh, then re-run this script."
    exit 1
fi
```

- [ ] **Step 3: Fail loudly when the version can't be parsed**

Replace:

```bash
    CHEZMOI_VERSION=$(chezmoi --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
```

with:

```bash
    CHEZMOI_VERSION=$(chezmoi --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) || true
    if [[ -z "$CHEZMOI_VERSION" ]]; then
        error "Could not parse a version from 'chezmoi --version' output:"
        chezmoi --version >&2 || true
        exit 1
    fi
```

(Under `pipefail`, a non-matching grep previously killed the script with no message.)

- [ ] **Step 4: Make the Linux chezmoi install fail loudly**

Replace:

```bash
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
```

with:

```bash
        INSTALLER=$(mktemp)
        if ! curl -fsLS -o "$INSTALLER" get.chezmoi.io; then
            rm -f "$INSTALLER"
            error "Failed to download the chezmoi installer from get.chezmoi.io. Check your network."
            exit 1
        fi
        if ! sh "$INSTALLER" -b "$HOME/.local/bin"; then
            rm -f "$INSTALLER"
            error "The chezmoi installer failed."
            exit 1
        fi
        rm -f "$INSTALLER"
```

(The old form ran `sh -c ""` when curl failed — a silent no-op success.)

- [ ] **Step 5: Remove the duplicate `brew bundle`**

Delete the whole block:

```bash
if [[ "$OS" == "Darwin" ]]; then
    if [[ -f "$DOTS_DIR/configs/Brewfile" ]]; then
        info "Installing Homebrew packages..."
        brew bundle --file="$DOTS_DIR/configs/Brewfile"
        success "Homebrew packages installed."
    fi
fi
```

`chezmoi apply` already triggers `run_onchange_install-packages.sh.tmpl`, which runs `brew bundle`; running it twice was redundant.

- [ ] **Step 6: shellcheck + syntax**

Run (from the repo root): `shellcheck -x scripts/install.sh && bash -n scripts/install.sh`
Expected: exit 0. (Do **not** execute install.sh on this machine — `chezmoi init` would re-prompt and regenerate the local chezmoi config. Bootstrap is exercised for real by the Phase 3 CI smoke job.)

- [ ] **Step 7: Commit**

```bash
git add scripts/install.sh
git commit -m "fix: install.sh brew check, safe curl install, version-parse error"
```

### Task 12: Final verification on the real machine

This task runs the reworked scripts against the **real** repo and remote. It intentionally pushes all Phase 1 commits (plus the two spec commits already ahead of origin) to `origin/main` — that is the normal dots workflow and doubles as the convergence check.

**Files:** none (verification only)

- [ ] **Step 1: Full lint and test suite**

Run: `make lint && make test`
Expected: shellcheck clean over all six scripts, `go vet` clean, all Go tests PASS.

- [ ] **Step 2: Template-conflict drill end-to-end**

```bash
echo "# final drill $(date +%s)" >> ~/.zshrc
bash scripts/push.sh; echo "exit: $?"
tail -1 ~/.local/state/dots/sync.log
chezmoi apply --force ~/.zshrc   # undo the drill
```
Expected: push.sh exits 1 **before re-adding or staging anything**, with the BLOCKED warning naming `~/.zshrc`; sync.log gains a `"result":"failure"` push entry; the drill line is gone after the apply.

- [ ] **Step 3: Real push — convergence publishes everything**

```bash
git status --short          # expect: clean (all tasks committed)
git rev-list --count origin/main..HEAD    # expect: > 0 (spec + Phase 1 commits)
bash scripts/push.sh
git rev-list --count origin/main..HEAD    # expect: 0
```
Expected: push.sh reports `Push complete. Branch is in sync with remote.` and the ahead-count drops to 0.

- [ ] **Step 4: Real sync round-trip with lock drill**

```bash
bash scripts/sync.sh &
bash scripts/push.sh; echo "second: $?"
wait
tail -3 ~/.local/state/dots/sync.log
```
Expected: whichever process loses the race reports "Another dots operation is running" (the concurrent push exits 1 with a `skipped` entry, or — if sync lost — sync exits 0 with `skipped`); the winning run completes normally; all log lines are valid JSON (`tail -3 ~/.local/state/dots/sync.log | jq -c .`). If **neither** process reports contention (the background sync hadn't taken the lock yet, or finished first), the drill proved nothing — re-run the step until one side reports it.

- [ ] **Step 5: Scheduler smoke (restore prior state)**

```bash
bash scripts/schedule.sh status                # note current state before touching it
# If ACTIVE, capture the current interval BEFORE enable overwrites the plist:
grep -A1 StartInterval ~/Library/LaunchAgents/com.dots.sync.plist 2>/dev/null || echo "was inactive"

bash scripts/schedule.sh enable 90
bash scripts/schedule.sh status                # expect ACTIVE, plist path exists
bash scripts/schedule.sh disable
# Restore: if the scheduler was ACTIVE before, re-enable with the captured
# interval (seconds), e.g.:  bash scripts/schedule.sh enable 1800
```
Expected: enable accepts 90s (was previously truncated to 1min on systemd; launchd takes it directly), status shows ACTIVE then INACTIVE after disable. Note: while the 90s schedule is live, a real scheduled sync may fire mid-drill — harmless under the new locking, it just adds log entries. **Restore whatever state (and interval) the scheduler was in before this step.**

- [ ] **Step 6: TUI smoke**

Run `make build`, then launch `./tui/dots` and check the Status and Sync tabs render sync history (the new log entries parse), then quit.
Expected: history table populated, no blank/garbled rows.

- [ ] **Step 7: Final commit (if verification produced changes)**

```bash
git status --short
```
Expected: clean. If the drill or sync created auto-commits, that is normal (they are already pushed). Nothing further to commit.
