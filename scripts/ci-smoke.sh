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
