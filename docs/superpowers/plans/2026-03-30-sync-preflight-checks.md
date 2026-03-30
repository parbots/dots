# Sync Pre-flight Checks and Hang Detection Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add pre-flight checks (chezmoi lock, git conflicts, dirty tree, network) and runtime hang detection with inline kill to the sync tab.

**Architecture:** Pre-flight checks run asynchronously via `tea.Cmd` before the script starts. A `checking` state shows a spinner. Hang detection uses a sequence-numbered timer that resets on each output line. Process killing uses `context.Context` cancellation via a new `RunStreamCtx` runner method. All new logic is in `sync_preflight.go` (checks) and modifications to `sync.go` (orchestration).

**Tech Stack:** Go, Bubble Tea, context.Context, os/exec, syscall

**Spec:** `docs/superpowers/specs/2026-03-30-sync-preflight-checks-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `tui/internal/runner/runner.go` | Modify | Add `RunStreamCtx` method |
| `tui/internal/runner/runner_test.go` | Modify | Add cancellation test |
| `tui/internal/app/sync_preflight.go` | Create | Pre-flight check types, functions, and `runPreflightChecks()` |
| `tui/internal/app/sync_preflight_test.go` | Create | Unit tests for check functions |
| `tui/internal/app/sync.go` | Modify | Checking state, hang timer, `x` key, dynamic help bar, warning rendering |
| `tui/internal/app/app.go` | Modify | Route `HangWarningMsg` and `PreflightResultMsg` |

---

## Chunk 1: RunStreamCtx

### Task 1: Add RunStreamCtx to the runner

**Files:**
- Modify: `tui/internal/runner/runner.go`
- Modify: `tui/internal/runner/runner_test.go`

- [ ] **Step 1: Write failing test for RunStreamCtx cancellation**

Add to `tui/internal/runner/runner_test.go`:

```go
func TestRunStreamCtxCancel(t *testing.T) {
	r := runner.New(t.TempDir())
	lines := make(chan string, 10)
	ctx, cancel := context.WithCancel(context.Background())

	done := make(chan runner.RunResult, 1)
	go func() {
		done <- r.RunStreamCtx(ctx, "sleep", lines, "30")
		close(lines)
	}()

	// Give the process a moment to start
	time.Sleep(100 * time.Millisecond)

	// Cancel the context
	cancel()

	// Should return quickly with non-zero exit code
	select {
	case result := <-done:
		if result.ExitCode == 0 {
			t.Error("expected non-zero exit code after cancel")
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timeout: RunStreamCtx did not return after cancel")
	}
}
```

Add `"context"` to the test imports.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd tui && go test ./internal/runner/ -run TestRunStreamCtxCancel -v`
Expected: FAIL — `RunStreamCtx` not defined.

- [ ] **Step 3: Implement RunStreamCtx**

Add to `tui/internal/runner/runner.go`:

```go
// RunStreamCtx is like RunStream but accepts a context for cancellation.
// Cancelling the context kills the process.
func (r *Runner) RunStreamCtx(ctx context.Context, name string, lines chan<- string, args ...string) RunResult {
	start := time.Now()

	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Dir = r.DotsDir

	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return RunResult{ExitCode: -1, Stderr: err.Error(), Duration: time.Since(start)}
	}

	if err := cmd.Start(); err != nil {
		return RunResult{ExitCode: -1, Stderr: err.Error(), Duration: time.Since(start)}
	}

	scanner := bufio.NewScanner(stdout)
	var allOutput bytes.Buffer
	for scanner.Scan() {
		line := scanner.Text()
		allOutput.WriteString(line + "\n")
		lines <- line
	}

	err = cmd.Wait()
	duration := time.Since(start)

	exitCode := 0
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		} else {
			exitCode = -1
		}
	}

	return RunResult{
		Stdout:   allOutput.String(),
		Stderr:   stderr.String(),
		ExitCode: exitCode,
		Duration: duration,
	}
}
```

Add `"context"` to the imports in `runner.go`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd tui && go test ./internal/runner/ -run TestRunStreamCtxCancel -v`
Expected: PASS

- [ ] **Step 5: Run all runner tests**

Run: `cd tui && go test ./internal/runner/ -v`
Expected: All 4 tests pass.

- [ ] **Step 6: Commit**

```bash
git add tui/internal/runner/runner.go tui/internal/runner/runner_test.go
git commit -m "feat(runner): add RunStreamCtx with context cancellation support"
```

---

## Chunk 2: Pre-flight Check Functions

### Task 2: Create pre-flight types and check functions

**Files:**
- Create: `tui/internal/app/sync_preflight.go`
- Create: `tui/internal/app/sync_preflight_test.go`

- [ ] **Step 1: Write failing tests for check functions**

Create `tui/internal/app/sync_preflight_test.go`:

```go
package app

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestCheckChezmoiLock_NoProcess(t *testing.T) {
	// With no chezmoi running, should return nil
	issue := checkChezmoiLock()
	if issue != nil {
		t.Errorf("expected no issue, got %q", issue.Message)
	}
}

func TestCheckGitConflicts_Clean(t *testing.T) {
	dir := t.TempDir()
	// Init a git repo with no conflicts
	run := func(args ...string) {
		cmd := exec.Command("git", args...)
		cmd.Dir = dir
		cmd.Run()
	}
	run("init")
	run("config", "user.email", "test@test.com")
	run("config", "user.name", "test")
	os.WriteFile(filepath.Join(dir, "f.txt"), []byte("hello"), 0644)
	run("add", ".")
	run("commit", "-m", "init")

	issue := checkGitConflicts(dir)
	if issue != nil {
		t.Errorf("expected no issue, got %q", issue.Message)
	}
}

func TestCheckDirtyTree_Clean(t *testing.T) {
	dir := t.TempDir()
	run := func(args ...string) {
		cmd := exec.Command("git", args...)
		cmd.Dir = dir
		cmd.Run()
	}
	run("init")
	run("config", "user.email", "test@test.com")
	run("config", "user.name", "test")
	os.WriteFile(filepath.Join(dir, "f.txt"), []byte("hello"), 0644)
	run("add", ".")
	run("commit", "-m", "init")

	issue := checkDirtyTree(dir)
	if issue != nil {
		t.Errorf("expected no issue, got %q", issue.Message)
	}
}

func TestCheckDirtyTree_Dirty(t *testing.T) {
	dir := t.TempDir()
	run := func(args ...string) {
		cmd := exec.Command("git", args...)
		cmd.Dir = dir
		cmd.Run()
	}
	run("init")
	run("config", "user.email", "test@test.com")
	run("config", "user.name", "test")
	os.WriteFile(filepath.Join(dir, "f.txt"), []byte("hello"), 0644)
	run("add", ".")
	run("commit", "-m", "init")

	// Make the tree dirty
	os.WriteFile(filepath.Join(dir, "f.txt"), []byte("modified"), 0644)

	issue := checkDirtyTree(dir)
	if issue == nil {
		t.Fatal("expected dirty tree issue")
	}
	if issue.Severity != severityWarn {
		t.Errorf("expected severityWarn, got %d", issue.Severity)
	}
}

func TestRunPreflightChecks_NoIssues(t *testing.T) {
	dir := t.TempDir()
	run := func(args ...string) {
		cmd := exec.Command("git", args...)
		cmd.Dir = dir
		cmd.Run()
	}
	run("init")
	run("config", "user.email", "test@test.com")
	run("config", "user.name", "test")
	os.WriteFile(filepath.Join(dir, "f.txt"), []byte("hello"), 0644)
	run("add", ".")
	run("commit", "-m", "init")

	// Push action on a clean repo with no remote — should get network warn only
	issues := runPreflightChecks(dir, syncActionPush)
	// We expect at most a network warning (no remote configured)
	for _, issue := range issues {
		if issue.Severity != severityWarn {
			t.Errorf("unexpected non-warn issue: %q (severity %d)", issue.Message, issue.Severity)
		}
	}
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd tui && go test ./internal/app/ -run "TestCheck|TestRunPreflight" -v`
Expected: FAIL — functions not defined.

- [ ] **Step 3: Implement pre-flight types and check functions**

Create `tui/internal/app/sync_preflight.go`:

```go
package app

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

type preflightSeverity int

const (
	severityAutofix preflightSeverity = iota
	severityAsk
	severityWarn
)

// PreflightIssue represents a problem detected before running a sync action.
type PreflightIssue struct {
	Message string
	Severity preflightSeverity
	FixCmd  func() tea.Cmd // for ask-severity: returns a cmd to execute the fix
	AutoFix func() error   // for autofix-severity: runs synchronously
}

// PreflightResultMsg carries the results of async pre-flight checks.
type PreflightResultMsg struct {
	Issues []PreflightIssue
	Action syncAction
}

// runPreflightChecks runs all pre-flight checks for the given action.
// This runs in a tea.Cmd (off the main thread).
func runPreflightChecks(dotsDir string, action syncAction) []PreflightIssue {
	var issues []PreflightIssue

	if issue := checkChezmoiLock(); issue != nil {
		issues = append(issues, *issue)
	}

	if issue := checkGitConflicts(dotsDir); issue != nil {
		issues = append(issues, *issue)
	}

	// Dirty tree check only for update (pulling into dirty tree risks conflicts)
	if action == syncActionUpdate {
		if issue := checkDirtyTree(dotsDir); issue != nil {
			issues = append(issues, *issue)
		}
	}

	// Network check for actions that talk to remote
	if issue := checkRemoteReachable(dotsDir); issue != nil {
		issues = append(issues, *issue)
	}

	return issues
}

// checkChezmoiLock checks if another chezmoi process is running.
func checkChezmoiLock() *PreflightIssue {
	out, err := exec.Command("pgrep", "-x", "chezmoi").Output()
	if err != nil {
		return nil // no chezmoi process found
	}

	myPid := os.Getpid()
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		pid, err := strconv.Atoi(strings.TrimSpace(line))
		if err != nil || pid == myPid {
			continue
		}

		// Check how long the process has been running via ps
		// Use lstart (launch time) which works on both macOS and Linux
		lstart, err := exec.Command("ps", "-o", "lstart=", "-p", strconv.Itoa(pid)).Output()
		if err != nil {
			continue
		}
		startTime, err := time.Parse("Mon Jan  2 15:04:05 2006", strings.TrimSpace(string(lstart)))
		if err != nil {
			continue
		}
		seconds := int(time.Since(startTime).Seconds())

		if seconds > 60 {
			// Stale — auto-fix
			return &PreflightIssue{
				Message:  fmt.Sprintf("Stale chezmoi process (PID %d, running %ds) — killing", pid, seconds),
				Severity: severityAutofix,
				AutoFix: func() error {
					return syscall.Kill(pid, syscall.SIGTERM)
				},
			}
		}

		// Recent — ask the user
		return &PreflightIssue{
			Message:  fmt.Sprintf("Chezmoi is running (PID %d, started %ds ago) — press x to kill", pid, seconds),
			Severity: severityAsk,
			FixCmd: func() tea.Cmd {
				return func() tea.Msg {
					syscall.Kill(pid, syscall.SIGTERM)
					time.Sleep(500 * time.Millisecond) // give it a moment
					return ToastMsg{Message: fmt.Sprintf("Killed chezmoi (PID %d)", pid), Level: ToastSuccess}
				}
			},
		}
	}

	return nil
}

// checkGitConflicts checks for unmerged files in the git index.
func checkGitConflicts(dotsDir string) *PreflightIssue {
	cmd := exec.Command("git", "ls-files", "--unmerged")
	cmd.Dir = dotsDir
	out, err := cmd.Output()
	if err != nil {
		return nil
	}
	if len(strings.TrimSpace(string(out))) == 0 {
		return nil
	}

	return &PreflightIssue{
		Message:  "Git conflicts detected — press x to open editor",
		Severity: severityAsk,
		FixCmd: func() tea.Cmd {
			// Collect conflicted file paths
			conflicted := exec.Command("git", "diff", "--name-only", "--diff-filter=U")
			conflicted.Dir = dotsDir
			filesOut, _ := conflicted.Output()
			files := strings.Fields(strings.TrimSpace(string(filesOut)))
			if len(files) == 0 {
				return nil
			}
			editor := os.Getenv("EDITOR")
			if editor == "" {
				editor = "vi"
			}
			args := append([]string{}, files...)
			c := exec.Command(editor, args...)
			c.Dir = dotsDir
			return tea.ExecProcess(c, func(err error) tea.Msg {
				if err != nil {
					return ToastMsg{Message: "Editor error: " + err.Error(), Level: ToastError}
				}
				return ToastMsg{Message: "Editor closed", Level: ToastSuccess}
			})
		},
	}
}

// checkDirtyTree checks for uncommitted changes.
func checkDirtyTree(dotsDir string) *PreflightIssue {
	cmd := exec.Command("git", "status", "--porcelain")
	cmd.Dir = dotsDir
	out, err := cmd.Output()
	if err != nil {
		return nil
	}
	if len(strings.TrimSpace(string(out))) == 0 {
		return nil
	}

	return &PreflightIssue{
		Message:  "Uncommitted changes may conflict with pull",
		Severity: severityWarn,
	}
}

// checkRemoteReachable checks if the git remote is reachable (5s timeout).
func checkRemoteReachable(dotsDir string) *PreflightIssue {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "git", "ls-remote", "--exit-code", "origin", "HEAD")
	cmd.Dir = dotsDir
	if err := cmd.Run(); err != nil {
		return &PreflightIssue{
			Message:  "Remote unreachable — push/pull may fail",
			Severity: severityWarn,
		}
	}

	return nil
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd tui && go test ./internal/app/ -run "TestCheck|TestRunPreflight" -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tui/internal/app/sync_preflight.go tui/internal/app/sync_preflight_test.go
git commit -m "feat(sync): add pre-flight check functions"
```

---

## Chunk 3: Message Routing and Hang Timer

### Task 3: Add message types and routing in app.go

**Files:**
- Modify: `tui/internal/app/sync.go` (add HangWarningMsg type)
- Modify: `tui/internal/app/app.go` (route new messages)

- [ ] **Step 1: Add HangWarningMsg type to sync.go**

Add near the top of `sync.go`, next to the other message types:

```go
// HangWarningMsg fires when no output is received for 10 seconds.
type HangWarningMsg struct {
	Seq int
}
```

- [ ] **Step 2: Route HangWarningMsg and PreflightResultMsg in app.go**

Add two cases alongside the existing `StreamLineMsg` and `RunCompleteMsg` routing (around line 170-183):

```go
	case HangWarningMsg:
		var cmd tea.Cmd
		m.syncTab, cmd = m.syncTab.Update(msg)
		return m, cmd

	case PreflightResultMsg:
		var cmd tea.Cmd
		m.syncTab, cmd = m.syncTab.Update(msg)
		return m, cmd
```

- [ ] **Step 3: Verify it compiles**

Run: `cd tui && go build ./...`
Expected: Compiles.

- [ ] **Step 4: Commit**

```bash
git add tui/internal/app/sync.go tui/internal/app/app.go
git commit -m "feat(sync): add HangWarningMsg/PreflightResultMsg types and routing"
```

---

## Chunk 4: Integrate into SyncModel

### Task 4: Update SyncModel with new fields, initRun flow, and Update handler

**Files:**
- Modify: `tui/internal/app/sync.go`

This is the largest task — it modifies the existing sync.go to add pre-flight orchestration, hang detection, and the `x` key handler. Read the current file first, then apply targeted edits.

- [ ] **Step 1: Add new fields to SyncModel**

Add to the `SyncModel` struct, after the existing `// History` section:

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

Add `"context"` and `"time"` to the imports.

- [ ] **Step 2: Add hangTimer function**

Add after the `waitForLine` function:

```go
func hangTimer(seq int) tea.Cmd {
	return tea.Tick(10*time.Second, func(time.Time) tea.Msg {
		return HangWarningMsg{Seq: seq}
	})
}
```

- [ ] **Step 3: Rewrite initRun to include pre-flight and context**

Replace the existing `initRun` method with:

```go
func (m *SyncModel) initRun(action syncAction) tea.Cmd {
	if m.running || m.checking {
		return nil
	}
	m.checking = true
	m.running = false
	m.logLines = nil
	m.scroll = 0
	m.steps = nil
	m.stepIdx = -1
	m.focus = focusActions
	m.preflightIssues = nil
	m.hangWarning = false
	// hangSeq is NOT reset — monotonically increasing to avoid stale timer collisions

	dotsDir := m.dotsDir
	return tea.Batch(m.spinner.Tick, func() tea.Msg {
		issues := runPreflightChecks(dotsDir, action)
		return PreflightResultMsg{Issues: issues, Action: action}
	})
}
```

- [ ] **Step 4: Add startScript helper (extracted from old initRun streaming logic)**

Add a new method that starts the actual script after pre-flight:

```go
func (m *SyncModel) startScript(action syncAction) tea.Cmd {
	m.checking = false
	m.running = true
	m.steps = stepsForAction(action)
	m.stepIdx = -1

	if len(m.steps) > 0 {
		m.steps[0].status = stepRunning
		m.stepIdx = 0
	}

	ctx, cancel := context.WithCancel(context.Background())
	m.cancelRun = cancel

	lineCh := make(chan string, 64)
	doneCh := make(chan RunCompleteMsg, 1)
	m.lineCh = lineCh
	m.doneCh = doneCh

	var script string
	switch action {
	case syncActionUpdate:
		script = filepath.Join(m.dotsDir, "scripts", "update.sh")
	case syncActionPush:
		script = filepath.Join(m.dotsDir, "scripts", "push.sh")
	case syncActionFull:
		script = filepath.Join(m.dotsDir, "scripts", "sync.sh")
	}

	go func() {
		result := m.runner.RunStreamCtx(ctx, "bash", lineCh, script)
		close(lineCh)
		errStr := ""
		if result.ExitCode != 0 {
			errStr = result.Stderr
		}
		doneCh <- RunCompleteMsg{
			Action:   action,
			ExitCode: result.ExitCode,
			Err:      errStr,
			Output:   result.Stdout,
		}
	}()

	m.hangSeq++
	return tea.Batch(m.spinner.Tick, waitForLine(lineCh, doneCh), hangTimer(m.hangSeq))
}
```

- [ ] **Step 5: Update TriggerAction to use new flow**

Replace:

```go
func (m *SyncModel) TriggerAction(action syncAction) tea.Cmd {
	m.selected = int(action)
	return m.initRun(action)
}
```

No change needed — `initRun` now returns the pre-flight cmd, which eventually triggers `startScript` via `PreflightResultMsg`. Keep as-is.

- [ ] **Step 6: Add PreflightResultMsg handler in Update**

Add a new case in the `Update` switch, after the `syncHistoryMsg` case:

```go
	case PreflightResultMsg:
		// Process auto-fix issues
		var toastCmds []tea.Cmd
		var remaining []PreflightIssue
		for _, issue := range msg.Issues {
			if issue.Severity == severityAutofix && issue.AutoFix != nil {
				if err := issue.AutoFix(); err != nil {
					// Downgrade to warn on failure
					issue.Severity = severityWarn
					issue.Message = issue.Message + " (fix failed: " + err.Error() + ")"
					remaining = append(remaining, issue)
				} else {
					toastMsg := issue.Message // capture before closure
					toastCmds = append(toastCmds, func() tea.Msg {
						return ToastMsg{Message: toastMsg, Level: ToastSuccess}
					})
				}
			} else {
				remaining = append(remaining, issue)
			}
		}
		m.preflightIssues = remaining
		// Start the script
		scriptCmd := m.startScript(msg.Action)
		return m, tea.Batch(append(toastCmds, scriptCmd)...)
```

- [ ] **Step 7: Update StreamLineMsg handler to reset hang timer**

Replace the existing `StreamLineMsg` case return with:

```go
	case StreamLineMsg:
		m.logLines = append(m.logLines, msg.Line)
		m.hangWarning = false
		m.hangSeq++
		newIdx, advanced := detectStep(msg.Line, m.steps, m.stepIdx)
		if advanced {
			if m.stepIdx >= 0 && m.stepIdx < len(m.steps) {
				m.steps[m.stepIdx].status = stepDone
			}
			if newIdx >= 0 && newIdx < len(m.steps) {
				m.steps[newIdx].status = stepRunning
				m.stepIdx = newIdx
			} else {
				for i := range m.steps {
					if m.steps[i].status != stepDone {
						m.steps[i].status = stepDone
					}
				}
				m.stepIdx = len(m.steps)
			}
		}
		return m, tea.Batch(waitForLine(m.lineCh, m.doneCh), hangTimer(m.hangSeq))
```

- [ ] **Step 8: Add HangWarningMsg handler**

Add a new case in the `Update` switch:

```go
	case HangWarningMsg:
		if m.running && msg.Seq == m.hangSeq {
			m.hangWarning = true
			m.logLines = append(m.logLines, StyleWarning.Render("⚠ No output for 10s — process may be hung. Press x to kill"))
		}
		return m, nil
```

- [ ] **Step 9: Add unified `x` key handler**

The `x` key must work in both running and non-running states. Add it as a unified handler BEFORE the `if m.running` block in the `tea.KeyMsg` handler (so it fires regardless of running state). Priority: hang kill > preflight ask fix.

```go
		case "x":
			// Priority 1: kill hung process
			if m.hangWarning && m.cancelRun != nil {
				m.cancelRun()
				m.logLines = append(m.logLines, StyleWarning.Render("Process killed by user"))
				m.hangWarning = false
				return m, nil
			}
			// Priority 2: fix preflight ask issue
			for i, issue := range m.preflightIssues {
				if issue.Severity == severityAsk && issue.FixCmd != nil {
					m.preflightIssues = append(m.preflightIssues[:i], m.preflightIssues[i+1:]...)
					return m, issue.FixCmd()
				}
			}
			return m, nil
```

This `case "x"` goes at the very top of the `tea.KeyMsg` switch, before the `if m.running` block, so it is reachable in all states.

- [ ] **Step 10: Add RunCompleteMsg cleanup for hang state**

In the existing `RunCompleteMsg` handler, add cleanup at the top:

```go
		m.hangWarning = false
		m.cancelRun = nil
```

- [ ] **Step 11: Update renderProgress to show pre-flight warnings and checking state**

Add at the top of `renderProgress`, before the step indicators:

```go
	// Checking state
	if m.checking {
		b.WriteString("  " + m.spinner.View() + " Running pre-flight checks...\n\n")
		return b.String()
	}

	// Pre-flight warnings
	if len(m.preflightIssues) > 0 {
		for _, issue := range m.preflightIssues {
			b.WriteString("  " + StyleWarning.Render("⚠ "+issue.Message) + "\n")
		}
		b.WriteString("\n")
	}
```

- [ ] **Step 12: Update View to use dynamic help bar**

Replace the static help bar bindings in `View()` with:

```go
func (m SyncModel) View() string {
	bindings := [][2]string{
		{"j/k", "select"},
		{"enter", "run/expand"},
		{"f", "focus"},
	}
	if m.hangWarning || m.hasFixableIssue() {
		bindings = append(bindings, [2]string{"x", "fix"})
	}
	bindings = append(bindings, [][2]string{
		{"ctrl+d/u", "scroll"},
		{"tab", "tabs"},
		{"y", "copy"},
		{"q", "quit"},
	}...)
	return renderScrollView(m.renderContent(), &m.scroll, m.width, m.height, bindings)
}

func (m SyncModel) hasFixableIssue() bool {
	for _, issue := range m.preflightIssues {
		if issue.Severity == severityAsk && issue.FixCmd != nil {
			return true
		}
	}
	return false
}
```

- [ ] **Step 13: Update spinner tick routing in app.go**

In `app.go`, the `spinner.TickMsg` handler checks `m.syncTab.running`. Now it also needs to check `m.syncTab.checking`. Update the condition:

```go
		if m.syncTab.running || m.syncTab.checking {
```

- [ ] **Step 14: Verify it compiles**

Run: `cd tui && go build ./...`
Expected: Compiles.

- [ ] **Step 15: Run all tests**

Run: `cd tui && go test ./... -v`
Expected: All tests pass.

- [ ] **Step 16: Commit**

```bash
git add tui/internal/app/sync.go tui/internal/app/app.go
git commit -m "feat(sync): integrate pre-flight checks, hang detection, and kill action"
```

---

## Chunk 5: Integration Testing and Polish

### Task 5: Manual testing and bug fixes

**Files:**
- Possibly modify: `tui/internal/app/sync.go`, `tui/internal/app/sync_preflight.go`

- [ ] **Step 1: Build and run the TUI**

Run: `cd /Users/parkerb/dev/dots && make build && tui/dots`

- [ ] **Step 2: Test pre-flight checks**

Navigate to the Sync tab. Select "Update" and press enter. Verify:
- Brief spinner with "Running pre-flight checks..." appears
- Any warnings appear above the step indicators
- Script starts and streams as before

- [ ] **Step 3: Test hang detection**

This is harder to test manually. One approach: temporarily modify `update.sh` to add a `sleep 15` before the first `info` call, build, and run an Update. Verify:
- After 10s of no output, the warning "No output for 10s" appears
- `x` key hint appears in the help bar
- Pressing `x` kills the process
- The run completes with a failure status

Revert the script change after testing.

- [ ] **Step 4: Test pre-flight auto-fix**

If you can create a scenario where a stale chezmoi process is running (e.g., `sleep 120 & echo $!` then rename to chezmoi — or just run `chezmoi apply` on a slow config in another terminal and wait >60s), verify:
- The stale process is killed automatically
- A toast appears confirming the kill

- [ ] **Step 5: Fix any issues found and commit**

```bash
git add tui/
git commit -m "fix(sync): polish pre-flight checks after manual testing"
```

---

### Task 6: Final test suite and cleanup

- [ ] **Step 1: Run full test suite**

Run: `cd tui && go test ./... -v`
Expected: All pass.

- [ ] **Step 2: Run linter**

Run: `make lint`
Expected: Clean.

- [ ] **Step 3: Final commit if any cleanup was needed**

```bash
git add tui/
git commit -m "chore(sync): final cleanup for pre-flight checks"
```
