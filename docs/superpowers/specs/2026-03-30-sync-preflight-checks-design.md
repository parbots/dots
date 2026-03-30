# Sync Pre-flight Checks and Hang Detection

## Overview

Add pre-flight checks before sync actions and runtime hang detection during execution. Auto-fix safe issues (stale chezmoi lock), warn about risky conditions (git conflicts, dirty tree, network), and detect hung processes with an inline kill option.

## Pre-flight Checks

Before starting any sync action, `initRun` dispatches a `tea.Cmd` that runs all checks asynchronously (to avoid blocking the TUI render loop) and returns a `PreflightResultMsg`. The model enters a brief "checking" state before the script starts.

### Check Table

| Check | Detection | Severity | Fix |
|-------|-----------|----------|-----|
| Chezmoi locked | `pgrep -x chezmoi` — only matches processes NOT owned by the current TUI (compare PIDs against `os.Getpid()` and its children) | `autofix` | Kill the matching process. Only auto-kill if the process has been running >60s (stale heuristic). Otherwise downgrade to `ask`: "Chezmoi is running (PID X, started Ns ago). Kill it?" |
| Git conflicts | `git ls-files --unmerged` in dots dir (detects unmerged index entries regardless of staging state) | `ask` | Press `x` to open `$EDITOR` on conflicted files |
| Dirty working tree | `git status --porcelain` in dots dir (update action only — pulling into a dirty tree risks merge conflicts; push and full sync call push.sh first which stages explicitly) | `warn` | Informational, no fix |
| Remote unreachable | `git ls-remote --exit-code origin HEAD` via `exec.CommandContext` with 5s timeout context (push/update/full only) | `warn` | Informational, no fix |

### Severity Levels

- **`autofix`**: Fix runs automatically before the script starts. On success, a toast appears (e.g., "Killed stale chezmoi (PID 3650)") and the action proceeds. On failure, the issue is downgraded to `warn` and displayed inline.
- **`ask`**: A warning line appears in the progress pane with a keybind hint. The action still proceeds — the warning is advisory. The user can press `x` to trigger the fix action.
- **`warn`**: A warning line appears in the progress pane. Informational only, no fix available. The action proceeds.

### Pre-flight Flow

1. User presses `enter` → `initRun` sets `m.checking = true` and returns a `tea.Cmd` that runs `runPreflightChecks(action)` asynchronously
2. While checking, the progress pane shows a spinner with "Running pre-flight checks..."
3. `PreflightResultMsg` arrives with the list of issues
4. `autofix` issues are resolved: the fix runs inline within the `PreflightResultMsg` handler (these are fast — just `kill` or similar). On success, a `ToastMsg` cmd is returned. On failure, the issue is downgraded to `warn`.
5. Remaining issues are stored on the model as `preflightIssues`
6. `m.checking = false`, the script starts via the existing streaming flow
7. `renderProgress` displays pre-flight warnings above the step indicators

This adds ~1-6s to the start of each action (dominated by the network check). The spinner provides feedback during this time.

### Pre-flight Warning Rendering

Warnings appear at the top of the progress pane, before step indicators:

```
  ⚠ Uncommitted changes may conflict with pull
  ⚠ Git conflicts detected — press x to open editor

  ✓ Pull    · Apply
  ──────────────────────────────
  Pulling latest changes...
```

Style: yellow `⚠` icon, `ColorYellow` for the warning text. `ask` severity items include a dimmed hint about the `x` key.

## Runtime Hang Detection

### Timer Mechanism

During streaming, track time since the last output line. If 10 seconds pass with no `StreamLineMsg`:

1. A `HangWarningMsg` fires (returned by a `tea.Cmd` wrapping `time.After(10s)`)
2. The model sets `hangWarning = true`
3. A warning line appears in the progress pane: `"⚠ No output for 10s — process may be hung. Press x to kill"`
4. The `x` key becomes active to kill the running process

### Timer Reset

Each `StreamLineMsg` must reset the timer. Implementation:

- `initRun` starts the first timer alongside the first `waitForLine`
- Each `StreamLineMsg` handler returns a `tea.Batch` of `waitForLine` (for the next line) and a fresh `hangTimer()` cmd
- The `HangWarningMsg` includes a sequence number; the model tracks the current sequence. If the received sequence doesn't match (timer was reset), the message is ignored.

```go
type HangWarningMsg struct {
    Seq int
}

func hangTimer(seq int) tea.Cmd {
    return tea.Tick(10*time.Second, func(time.Time) tea.Msg {
        return HangWarningMsg{Seq: seq}
    })
}
```

### Kill Action

When the user presses `x` during a hang (or when an `ask`-severity pre-flight issue is active):

1. If `hangWarning` is true: find and kill the child process. The goroutine's `RunStream` will return with a non-zero exit code, triggering the normal `RunCompleteMsg` flow.
2. If a pre-flight `ask` issue is active: execute the issue's fix function (e.g., open `$EDITOR` on conflicted files via `tea.ExecProcess`).

Process killing: the runner needs a way to kill a running command. Since `RunStream` uses `exec.Command` internally, we need to either:
- Store the `*exec.Cmd` on the runner and expose a `Kill()` method
- Or use `pgrep`/`pkill` to find the child process by script name

The cleaner approach is to extend the runner. Add a `RunStreamCtx` method that accepts a `context.Context`. The model stores a `cancel` func and calls it on `x` press.

### Runner Changes

Add to `runner.go`:

```go
func (r *Runner) RunStreamCtx(ctx context.Context, name string, lines chan<- string, args ...string) RunResult {
    // Same as RunStream but uses exec.CommandContext(ctx, ...)
    // Context cancellation kills the process
}
```

`initRun` creates a context with cancel, stores cancel on the model, and passes context to `RunStreamCtx`.

## New Types

### PreflightIssue

```go
type preflightSeverity int

const (
    severityAutofix preflightSeverity = iota
    severityAsk
    severityWarn
)

type PreflightIssue struct {
    Message  string
    Severity preflightSeverity
    FixCmd   func() tea.Cmd // nil for warn-only issues; returns a tea.Cmd
    AutoFix  func() error   // nil unless severity is autofix; runs synchronously during PreflightResultMsg handling
}
```

`FixCmd` returns a `tea.Cmd` because some fixes (like opening `$EDITOR` via `tea.ExecProcess`) require Bubble Tea integration. `AutoFix` is a simple synchronous function for auto-fix severity issues (e.g., `syscall.Kill`).

### New Message Types

- `PreflightResultMsg{Issues []PreflightIssue}` — results of async pre-flight checks
- `HangWarningMsg{Seq int}` — 10s timer expired, sequence number for deduplication
- `ToastMsg` (existing) — used for auto-fix notifications

`HangWarningMsg` must be routed directly to the sync tab in `app.go` (same as `StreamLineMsg` and `RunCompleteMsg`) so it is not lost if the user switches tabs during a run.

## UI Changes

### Progress Pane

- Pre-flight warnings render above step indicators (yellow `⚠` styled lines)
- Hang warning renders inline in the log area
- Both can show `"press x to ..."` hints when fixable

### Help Bar

- When a fixable issue is active (`hangWarning == true` or an `ask` pre-flight issue exists), add `x fix` to the help bar
- When no fixable issue is active, `x` is absent from the help bar

Dynamic help bar: `View()` builds the bindings list conditionally.

### Toast

- Auto-fix results appear as toasts via the existing `ToastMsg` system

## Files Changed

| File | Action | Changes |
|------|--------|---------|
| `tui/internal/app/sync_preflight.go` | Create | `PreflightIssue`, severity types, `runPreflightChecks()`, individual check functions |
| `tui/internal/app/sync_preflight_test.go` | Create | Unit tests for check functions |
| `tui/internal/app/sync.go` | Modify | Pre-flight orchestration in `initRun`, `checking` state, hang timer, `HangWarningMsg` handling, `x` key handler, dynamic help bar, warning rendering in progress pane, state cleanup |
| `tui/internal/runner/runner.go` | Modify | Add `RunStreamCtx` method with `context.Context` support |
| `tui/internal/runner/runner_test.go` | Modify | Add test for `RunStreamCtx` cancellation (verify pipe cleanup after context cancel) |
| `tui/internal/app/app.go` | Modify | Route `HangWarningMsg` and `PreflightResultMsg` directly to sync tab |

## State Management

### New Fields on SyncModel

```go
// Pre-flight
checking        bool
preflightIssues []PreflightIssue

// Hang detection
hangWarning bool
hangSeq     int

// Process control
cancelRun context.CancelFunc
```

### State Cleanup in initRun

When a new sync action starts, `initRun` must reset all new fields:

- `checking = true` (enters checking state)
- `preflightIssues = nil`
- `hangWarning = false`
- `hangSeq = 0`
- `cancelRun` — if non-nil from a previous run, do NOT call it (previous run already completed)

### Post-Kill State

When the user presses `x` to kill a hung process:

1. `cancelRun()` is called, which cancels the context
2. `exec.CommandContext` sends SIGKILL to the process
3. The stdout pipe closes, `scanner.Scan()` returns false, `RunStream` returns
4. The goroutine sends `RunCompleteMsg` with a non-zero exit code
5. The model handles `RunCompleteMsg` normally — `running = false`, steps marked failed, etc.
6. The user can start a new action by pressing `enter` again

The user does NOT need to do anything special after killing — the normal completion flow handles cleanup.

## Edge Cases

- **Multiple pre-flight issues**: All are displayed. Currently only one `ask`-severity issue exists (git conflicts). If more are added, `x` fixes them in order of appearance.
- **Hang warning + pre-flight ask**: Both can be active. `x` priority: (1) kill hung process, (2) fix pre-flight issue. Hang is always more urgent because the process is stuck.
- **Script finishes during hang warning**: `RunCompleteMsg` arrives, `hangWarning` resets to false. The warning line stays in the log as historical context.
- **Auto-fix fails**: Issue is downgraded to `warn` severity and displayed inline. The script still starts.
- **No pre-flight issues**: `PreflightResultMsg` arrives with empty issues list, script starts immediately. The "checking" spinner is visible for <1s.
- **Pipe cleanup after context cancel**: When `exec.CommandContext` kills the process, the stdout pipe is closed by the OS. `scanner.Scan()` returns false, the scanner loop exits, and `RunStream` returns normally. A test must verify this works cleanly.
- **Chezmoi kill safety**: Only auto-kill chezmoi processes running >60s. For processes <60s, downgrade to `ask` so the user decides. This prevents killing a legitimate concurrent `chezmoi apply` that just started.
