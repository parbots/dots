# Sync Pre-flight Checks and Hang Detection

## Overview

Add pre-flight checks before sync actions and runtime hang detection during execution. Auto-fix safe issues (stale chezmoi lock), warn about risky conditions (git conflicts, dirty tree, network), and detect hung processes with an inline kill option.

## Pre-flight Checks

Before starting any sync action, `initRun` runs a series of quick checks via `runPreflightChecks()`. Each check returns a `PreflightIssue` with a severity level and optional auto-fix function.

### Check Table

| Check | Detection | Severity | Fix |
|-------|-----------|----------|-----|
| Chezmoi locked | `pgrep -x chezmoi` | `autofix` | Kill the process |
| Git conflicts | `git diff --check` in dots dir | `ask` | Press `x` to open `$EDITOR` on conflicted files |
| Dirty working tree | `git status --porcelain` in dots dir (update action only) | `warn` | Informational, no fix |
| Remote unreachable | `git ls-remote --exit-code origin HEAD` with 5s timeout (push/update/full only) | `warn` | Informational, no fix |

### Severity Levels

- **`autofix`**: Fix runs automatically before the script starts. On success, a toast appears (e.g., "Killed stale chezmoi (PID 3650)") and the action proceeds. On failure, the issue is downgraded to `warn` and displayed inline.
- **`ask`**: A warning line appears in the progress pane with a keybind hint. The action still proceeds — the warning is advisory. The user can press `x` to trigger the fix action.
- **`warn`**: A warning line appears in the progress pane. Informational only, no fix available. The action proceeds.

### Pre-flight Flow

1. `initRun` calls `runPreflightChecks(action)` synchronously (all checks are fast — under 5s total)
2. `autofix` issues are resolved immediately; toast sent on success
3. Remaining issues are stored on the model as `preflightIssues`
4. `renderProgress` displays pre-flight warnings above the step indicators
5. The script starts regardless of warnings

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
    Fix      func() error // nil for warn-only issues
}
```

### New Message Types

- `HangWarningMsg{Seq int}` — 10s timer expired, sequence number for deduplication
- `ToastMsg` (existing) — used for auto-fix notifications

No new routed messages needed in `app.go` — `HangWarningMsg` is handled within the sync tab's own `Update`.

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
| `tui/internal/app/sync.go` | Modify | Pre-flight orchestration in `initRun`, hang timer, `HangWarningMsg` handling, `x` key handler, dynamic help bar, warning rendering in progress pane |
| `tui/internal/runner/runner.go` | Modify | Add `RunStreamCtx` method |
| `tui/internal/runner/runner_test.go` | Modify | Add test for `RunStreamCtx` cancellation |
| `tui/internal/app/app.go` | No change | `HangWarningMsg` is internal to sync tab, no routing needed |

## Edge Cases

- **Multiple pre-flight issues**: All are displayed, fixes are offered for all fixable ones. `x` fixes the most severe actionable issue first.
- **Hang warning + pre-flight ask**: Both can be active. `x` prioritizes killing the hung process (more urgent).
- **Script finishes during hang warning**: `RunCompleteMsg` arrives, `hangWarning` resets, warning becomes stale. The warning line stays in the log as historical context.
- **Auto-fix fails**: Issue is downgraded to `warn` severity and displayed inline. The script still starts.
- **No pre-flight issues**: Nothing extra renders, the sync starts immediately as before.
