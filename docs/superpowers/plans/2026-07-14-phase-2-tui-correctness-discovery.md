# Phase 2: TUI Correctness & Discovery Architecture Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the TUI truthful (every exit code checked, failures visible, no false "In sync"/"No differences"), safe (no auto-SIGTERM, no orphaned child processes, quit cancels runs), and generic (config discovery driven by chezmoi so Phase 3's onboarded files appear without per-file TUI work).

**Architecture:** A new `internal/ansi` leaf package centralizes escape-stripping for both `app` and `scheduler`. `internal/runner` gains process-group kill, a wait backstop, a large scan buffer, and a default timeout. The sync preflight stops auto-killing and stops racing fixes against script starts (new `FixCompleteMsg` chain). The Configs tab discovers files via `chezmoi managed` and target paths instead of walking the source tree with `strings.ReplaceAll("dot_", ".")`.

**Tech Stack:** Go 1.24 (Bubble Tea + Lip Gloss + Bubbles), chezmoi v2.71.0. One bash-adjacent change (none to scripts themselves).

**Spec:** `docs/superpowers/specs/2026-07-10-audit-fixes-and-config-expansion-design.md` (Phase 2 section) plus three carry-forwards from Phase 1 reviews: TUI-visible BROKEN scheduler state, `XDG_STATE_HOME` in `parseSyncLog`, and (noted, deliberately unchanged) sync.sh's exit-0-on-skip.

---

## Context you must know before starting

- **Working directory:** all Go commands run from `~/dev/dots/tui` (or the worktree's `tui/`); all paths below are relative to the repo root unless absolute.
- **Verify constantly:** `cd tui && go build ./... && go test ./... && go vet ./...` after every task; `gofmt -l .` must print nothing. `make lint` and `make test` run from the repo root.
- **Bubble Tea testing convention:** models are plain structs — call `m.Update(msg)` directly in tests; no teatest harness exists or is wanted. Pure helpers get table-driven tests (the `sync_steps_test.go` pattern).
- **Message routing:** new `tea.Msg` types handled by a tab must be added to the root routing table in `internal/app/app.go` (the big type-switch), or they will silently never reach the tab when it isn't active.
- **`tea.ExecProcess` cmds must NOT be wrapped** in another closure — the Bubble Tea runtime special-cases them. To change what an ExecProcess produces, change its callback's return value.
- **chezmoi status line format** (verified against v2.71.0): two status chars + space + target path relative to `~`. First char ≠ space ⇒ the file changed on disk since the last apply (a local edit). `MM .zshrc` = locally edited; ` M .config/gh` = apply would change it but no local edit.
- **Line numbers cited are from current HEAD (`26e78c4`)** — verify against what you read; nearby edits from earlier tasks in this plan can shift them.
- **Commit messages:** single line, conventional prefix, no Co-Authored-By trailer, exactly as given in each task.

### File map for this phase

| File | Action | Responsibility |
| --- | --- | --- |
| `tui/internal/ansi/ansi.go` (+test) | Create | Single ANSI-stripping implementation (CSI, OSC, two-char ESC) |
| `tui/internal/runner/runner.go` (+test) | Rewrite | Hardened exec: group kill, WaitDelay, 1 MB scanner, default timeout, drop `RunStream` |
| `tui/internal/app/sync_preflight.go` (+test) | Modify | lstart local-time parse, always-ask chezmoi, first-char conflict detection, `FixCompleteMsg` |
| `tui/internal/app/sync.go` (+new test) | Modify | Sequential fix chain, `initRun` reset, `CancelRun` |
| `tui/internal/app/app.go` | Modify | Quit-cancels-run, `FixCompleteMsg` + `machineTypeMsg` routing |
| `tui/internal/app/configs.go` (+new test) | Rewrite (discovery) | chezmoi-driven file list, target-path categories, fixed diff, cursor clamp |
| `tui/internal/app/editor.go` | Create | `$EDITOR` argv-splitting helper (used by configs + preflight) |
| `tui/internal/app/status.go` | Modify | Async `chezmoi data`, no-upstream warning, XDG sync.log path |
| `tui/internal/scheduler/scheduler.go` (+test) | Modify | BROKEN state parsed from stdout+stderr |
| `tui/internal/app/settings.go` | Modify | chezmoi-data exit check, BROKEN display, dead field removal |
| `tui/internal/app/homebrew.go` | Modify | Running guard, bundle exit-code surfacing |
| `tui/internal/app/theme.go`, `system.go`, `go.mod`, `CLAUDE.md` | Modify | Dead code removal, tidy, doc drift |

---

## Chunk 1: Foundations — ansi package and runner hardening

### Task 1: Create `internal/ansi` and delete both duplicate strippers

The two existing `stripANSI` copies (`internal/app/theme.go:210-226`, `internal/scheduler/scheduler.go:92-107`) only strip SGR (`ESC...m`) and mangle any other escape family. `scheduler` cannot import `app` (import cycle), so the shared home is a new leaf package.

**Files:**
- Create: `tui/internal/ansi/ansi.go`
- Create: `tui/internal/ansi/ansi_test.go`
- Modify: `tui/internal/app/theme.go` (delete stripANSI), `tui/internal/app/app.go:112`, `tui/internal/app/sync_steps.go:65`, `tui/internal/scheduler/scheduler.go` (delete stripANSI, use ansi.Strip)

- [ ] **Step 1: Write the failing test** — `tui/internal/ansi/ansi_test.go`:

```go
package ansi_test

import (
	"testing"

	"github.com/parbots/dots/internal/ansi"
)

func TestStrip(t *testing.T) {
	cases := []struct {
		name string
		in   string
		want string
	}{
		{"plain", "hello", "hello"},
		{"empty", "", ""},
		{"sgr color", "\033[0;32mgreen\033[0m", "green"},
		{"sgr bold multi", "\033[1m\033[35mbold\033[0m plain", "bold plain"},
		{"cursor up (non-SGR CSI)", "\033[2Aline", "line"},
		{"erase line", "before\033[Kafter", "beforeafter"},
		{"csi with params", "\033[1;31;40mx\033[0m", "x"},
		{"osc title BEL", "\033]0;window title\aname", "name"},
		{"osc title ST", "\033]0;window title\033\\name", "name"},
		{"bare two-char escape", "\033(Btext", "text"},
		{"truncated escape at end", "text\033[", "text"},
		{"mixed", "\033[0;34mPhase 1:\033[0m Pushing", "Phase 1: Pushing"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := ansi.Strip(tc.in); got != tc.want {
				t.Errorf("Strip(%q) = %q, want %q", tc.in, got, tc.want)
			}
		})
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd tui && go test ./internal/ansi/`
Expected: FAIL (package does not exist / `ansi.Strip` undefined).

- [ ] **Step 3: Implement** — `tui/internal/ansi/ansi.go`:

```go
// Package ansi provides ANSI escape-sequence stripping shared by the app
// and scheduler packages (which must not import each other).
package ansi

import "strings"

// Strip removes ANSI escape sequences from s: CSI sequences (ESC [ ... final
// byte in @-~), OSC sequences (ESC ] ... terminated by BEL or ESC \), and
// other two-character ESC sequences. Unterminated sequences at end of input
// are dropped.
func Strip(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	i := 0
	for i < len(s) {
		if s[i] != '\033' {
			b.WriteByte(s[i])
			i++
			continue
		}
		i++ // consume ESC
		if i >= len(s) {
			break
		}
		switch s[i] {
		case '[': // CSI: parameter/intermediate bytes 0x20-0x3F, final byte 0x40-0x7E
			i++
			for i < len(s) && (s[i] < 0x40 || s[i] > 0x7e) {
				i++
			}
			if i < len(s) {
				i++ // consume final byte
			}
		case ']': // OSC: terminated by BEL or ST (ESC \)
			i++
			for i < len(s) {
				if s[i] == '\a' {
					i++
					break
				}
				if s[i] == '\033' && i+1 < len(s) && s[i+1] == '\\' {
					i += 2
					break
				}
				i++
			}
		default: // two-character escape (e.g. ESC ( B)
			i++
			if i < len(s) {
				i++
			}
		}
	}
	return b.String()
}
```

Note on the `default` branch: sequences like `ESC ( B` are ESC + intermediate + final (3 bytes). Consuming two bytes after ESC handles them; the test's "bare two-char escape" case pins this.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd tui && go test ./internal/ansi/ -v`
Expected: PASS, all subtests.

- [ ] **Step 5: Migrate callers, delete both copies**

1. `tui/internal/app/theme.go`: delete the whole `stripANSI` function (lines 210-226) and its doc comment.
2. `tui/internal/app/app.go`: add import `"github.com/parbots/dots/internal/ansi"`; line 112 `content := stripANSI(m.activeTabView())` → `content := ansi.Strip(m.activeTabView())`.
3. `tui/internal/app/sync_steps.go`: add the same import; line 65 `clean := stripANSI(line)` → `clean := ansi.Strip(line)`.
4. `tui/internal/scheduler/scheduler.go`: delete its `stripANSI` (lines 92-107); add the import; line 70 `clean := stripANSI(output)` → `clean := ansi.Strip(output)`.

- [ ] **Step 6: Verify the module builds and all tests pass**

Run: `cd tui && gofmt -l . && go build ./... && go test ./... && go vet ./...`
Expected: gofmt prints nothing; build/tests/vet clean. `grep -rn "func stripANSI" internal/` prints nothing.

- [ ] **Step 7: Commit**

```bash
git add tui/internal/ansi/ tui/internal/app/theme.go tui/internal/app/app.go tui/internal/app/sync_steps.go tui/internal/scheduler/scheduler.go
git commit -m "refactor: centralize ANSI stripping in internal/ansi, handle non-SGR escapes"
```

### Task 2: Harden `internal/runner`

One hardened exec path: process-group kill (a cancelled `git push` must not orphan its ssh child), `WaitDelay` backstop, 1 MB scanner with surfaced errors, default timeout on `Run`, and `RunStream` (dead API — zero callers outside its own test) deleted.

**Files:**
- Rewrite: `tui/internal/runner/runner.go`
- Rewrite: `tui/internal/runner/runner_test.go`
- Modify: `tui/internal/app/homebrew.go:408`, `tui/internal/app/settings.go:329` (long-running call sites use explicit long timeouts)

- [ ] **Step 1: Write the failing tests** — replace `tui/internal/runner/runner_test.go` entirely:

```go
package runner_test

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"testing"
	"time"

	"github.com/parbots/dots/internal/runner"
)

func TestRunSync(t *testing.T) {
	r := runner.New(t.TempDir())
	result := r.Run("echo", "hello")

	if result.ExitCode != 0 {
		t.Errorf("expected exit code 0, got %d", result.ExitCode)
	}
	if result.Stdout != "hello\n" {
		t.Errorf("expected 'hello\\n', got %q", result.Stdout)
	}
}

func TestRunFailure(t *testing.T) {
	r := runner.New(t.TempDir())
	result := r.Run("false")

	if result.ExitCode == 0 {
		t.Error("expected non-zero exit code")
	}
}

func TestRunTimeout(t *testing.T) {
	r := runner.New(t.TempDir())
	start := time.Now()
	result := r.RunTimeout(300*time.Millisecond, "sleep", "10")

	if elapsed := time.Since(start); elapsed > 5*time.Second {
		t.Fatalf("RunTimeout did not enforce the timeout (took %v)", elapsed)
	}
	if result.ExitCode == 0 {
		t.Error("expected non-zero exit code after timeout")
	}
	if !strings.Contains(result.Stderr, "timed out") {
		t.Errorf("expected timeout note in stderr, got %q", result.Stderr)
	}
}

func TestRunNoTimeoutWhenZero(t *testing.T) {
	r := runner.New(t.TempDir())
	result := r.RunTimeout(0, "echo", "ok")
	if result.ExitCode != 0 {
		t.Errorf("expected exit 0 with zero (no) timeout, got %d", result.ExitCode)
	}
}

func TestRunStreamCtxLongLine(t *testing.T) {
	r := runner.New(t.TempDir())
	lines := make(chan string, 4)
	go func() {
		for range lines {
		}
	}()
	// One 200KB line — over bufio's 64KB default, under our 1MB max.
	result := r.RunStreamCtx(context.Background(), "bash", lines,
		"-c", `printf 'a%.0s' {1..200000}; echo`)
	close(lines)

	if result.ExitCode != 0 {
		t.Errorf("expected exit 0 for long line, got %d (stderr: %s)", result.ExitCode, result.Stderr)
	}
	if len(result.Stdout) < 200000 {
		t.Errorf("long line truncated: got %d bytes", len(result.Stdout))
	}
}

func TestRunStreamCtxScannerErrSurfaced(t *testing.T) {
	r := runner.New(t.TempDir())
	lines := make(chan string, 4)
	go func() {
		for range lines {
		}
	}()
	// One 2MB line — over the 1MB scanner max: scanner.Err() must surface.
	result := r.RunStreamCtx(context.Background(), "bash", lines,
		"-c", `printf 'a%.0s' {1..2000000}; echo`)
	close(lines)

	if result.ExitCode == 0 {
		t.Error("expected non-zero exit code when the scanner fails")
	}
	if !strings.Contains(result.Stderr, "stream error") {
		t.Errorf("expected stream error note in stderr, got %q", result.Stderr)
	}
}

func TestRunStreamCtxCancelKillsProcessGroup(t *testing.T) {
	r := runner.New(t.TempDir())
	lines := make(chan string, 16)
	ctx, cancel := context.WithCancel(context.Background())

	// Unique fractional duration so pgrep/pkill can never match an
	// unrelated process (fractional sleep works on macOS and GNU).
	dur := fmt.Sprintf("300.%d", os.Getpid())
	done := make(chan runner.RunResult, 1)
	go func() {
		// bash forks a grandchild sleep; without Setpgid+group kill,
		// cancelling only kills bash and orphans the sleep.
		done <- r.RunStreamCtx(ctx, "bash", lines,
			"-c", fmt.Sprintf("sleep %s & echo started; wait", dur))
	}()

	select {
	case line := <-lines:
		if line != "started" {
			t.Fatalf("unexpected first line %q", line)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timeout waiting for process to start")
	}

	cancel()

	select {
	case result := <-done:
		if result.ExitCode == 0 {
			t.Error("expected non-zero exit code after cancel")
		}
	case <-time.After(10 * time.Second):
		t.Fatal("RunStreamCtx did not return after cancel — WaitDelay backstop failed")
	}
	close(lines)

	// The grandchild sleep must be dead. Poll briefly to absorb signal latency.
	deadline := time.Now().Add(3 * time.Second)
	for {
		out, _ := exec.Command("pgrep", "-f", "sleep "+dur).Output()
		if strings.TrimSpace(string(out)) == "" {
			return // group killed — success
		}
		if time.Now().After(deadline) {
			exec.Command("pkill", "-f", "sleep "+dur).Run() // cleanup
			t.Fatal("grandchild sleep survived cancellation — process group was not killed")
		}
		time.Sleep(100 * time.Millisecond)
	}
}
```

Note: `TestRunStream` is gone — `RunStream` is deleted in this task.

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `cd tui && go test ./internal/runner/ -v`
Expected: compile failure (`RunTimeout` undefined) — that counts as the failing state.

- [ ] **Step 3: Rewrite `tui/internal/runner/runner.go`**

```go
package runner

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"syscall"
	"time"
)

// DefaultTimeout bounds Run so no fire-and-forget command can hang the UI
// forever. Long-running call sites (brew bundle, chezmoi init --apply) must
// use RunTimeout with an explicit generous timeout instead.
const DefaultTimeout = 60 * time.Second

// waitDelay is the backstop between context cancellation and forcibly
// abandoning Wait, so inherited pipes can never hang us forever.
const waitDelay = 5 * time.Second

// maxScanTokenSize allows streamed lines up to 1MB (bufio's default is 64KB,
// which chezmoi diffs and brew output can exceed).
const maxScanTokenSize = 1024 * 1024

// RunResult holds the output and metadata of a completed command.
type RunResult struct {
	Stdout   string
	Stderr   string
	ExitCode int
	Duration time.Duration
}

// Runner executes commands with a configured dots directory.
type Runner struct {
	DotsDir string
}

// New creates a Runner with the given dots directory.
func New(dotsDir string) *Runner {
	return &Runner{DotsDir: dotsDir}
}

// harden puts the child in its own process group and configures cancellation
// to kill the whole group, so cancelling a script also kills anything it
// forked (git's ssh, chezmoi's editors, ...). WaitDelay bounds Wait after
// cancellation even if a grandchild holds the output pipes open.
func harden(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error {
		return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
	}
	cmd.WaitDelay = waitDelay
}

func exitCodeOf(err error) int {
	if err == nil {
		return 0
	}
	if exitErr, ok := err.(*exec.ExitError); ok {
		return exitErr.ExitCode()
	}
	return -1
}

// Run executes a command synchronously with DefaultTimeout.
func (r *Runner) Run(name string, args ...string) RunResult {
	return r.RunTimeout(DefaultTimeout, name, args...)
}

// RunTimeout executes a command synchronously, killing its process group if
// it runs longer than timeout. A timeout of 0 means no timeout.
func (r *Runner) RunTimeout(timeout time.Duration, name string, args ...string) RunResult {
	start := time.Now()

	ctx := context.Background()
	if timeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, timeout)
		defer cancel()
	}

	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Dir = r.DotsDir
	harden(cmd)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()

	stderrStr := stderr.String()
	exitCode := exitCodeOf(err)
	if ctx.Err() == context.DeadlineExceeded {
		if exitCode == 0 {
			exitCode = -1
		}
		stderrStr = appendNote(stderrStr, fmt.Sprintf("command timed out after %s", timeout))
	}

	return RunResult{
		Stdout:   stdout.String(),
		Stderr:   stderrStr,
		ExitCode: exitCode,
		Duration: time.Since(start),
	}
}

// RunStreamCtx executes a command, sending stdout lines to the provided
// channel. Cancelling the context kills the whole process group. The caller
// is responsible for closing the channel after RunStreamCtx returns.
func (r *Runner) RunStreamCtx(ctx context.Context, name string, lines chan<- string, args ...string) RunResult {
	start := time.Now()

	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Dir = r.DotsDir
	harden(cmd)

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
	scanner.Buffer(make([]byte, 64*1024), maxScanTokenSize)
	var allOutput bytes.Buffer
	for scanner.Scan() {
		line := scanner.Text()
		allOutput.WriteString(line + "\n")
		lines <- line
	}
	scanErr := scanner.Err()
	if scanErr != nil {
		// The child may be blocked writing into the now-unread pipe, and
		// with an undone context WaitDelay never arms — Wait would hang
		// forever. Kill the group so Wait can return.
		_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
	}

	err = cmd.Wait()

	stderrStr := stderr.String()
	exitCode := exitCodeOf(err)
	if scanErr != nil {
		if exitCode == 0 {
			exitCode = -1
		}
		stderrStr = appendNote(stderrStr, "stream error: "+scanErr.Error())
	}

	return RunResult{
		Stdout:   allOutput.String(),
		Stderr:   stderrStr,
		ExitCode: exitCode,
		Duration: time.Since(start),
	}
}

func appendNote(stderr, note string) string {
	if stderr == "" {
		return note
	}
	return stderr + "\n" + note
}
```

Key details:
- `cmd.Cancel` (Go 1.20+) replaces the default kill-the-child-only behavior with a group kill; `Setpgid` makes the child a group leader so `-pid` addresses the whole tree.
- **The explicit group kill on scanner error is load-bearing.** When the scanner dies (token too long), the child may be blocked writing into the full pipe. `WaitDelay`'s timer only arms when the context is done or the child has exited — with `context.Background()` neither happens, so without the kill `cmd.Wait` hangs forever (empirically confirmed during plan review). `TestRunStreamCtxScannerErrSurfaced` exercises exactly this; if it hangs, the kill is missing.
- `WaitDelay` still matters for the cancellation path: after a context cancel, it bounds `Wait` even if a grandchild holds the output pipes open.
- `RunStream` is deleted; grep confirms its only caller was its own test.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd tui && go test ./internal/runner/ -v`
Expected: PASS all 7 tests. `TestRunStreamCtxCancelKillsProcessGroup` is the load-bearing one — if it fails at the pgrep check, the group kill isn't working; do not weaken the test.

- [ ] **Step 5: Give the two long-running call sites explicit timeouts**

1. `tui/internal/app/homebrew.go` `runBrewBundle` (line ~408): `m.runner.Run("brew", "bundle", ...)` → `m.runner.RunTimeout(30*time.Minute, "brew", "bundle", ...)`.
2. `tui/internal/app/settings.go` `reinitChezmoi` (line ~329): `m.runner.Run("chezmoi", "init", "--apply")` → `m.runner.RunTimeout(30*time.Minute, "chezmoi", "init", "--apply")` (init --apply can trigger the run_onchange brew bundle).

All other `Run` call sites (chezmoi data/status/diff/managed, git rev-list/status, schedule.sh) are local, fast operations — the 60s default is a pure backstop for them.

- [ ] **Step 6: Full verify**

Run: `cd tui && gofmt -l . && go build ./... && go test ./... && go vet ./...`
Expected: all clean. `grep -rn "RunStream(" internal/ | grep -v RunStreamCtx` prints nothing.

- [ ] **Step 7: Commit**

```bash
git add tui/internal/runner/ tui/internal/app/homebrew.go tui/internal/app/settings.go
git commit -m "fix: harden runner with process-group kill, WaitDelay, 1MB scanner, default timeout"
```

---

## Chunk 2: Sync preflight & flow correctness

### Task 3: Preflight truthfulness — lstart, always-ask, first-char conflict detection

Three bugs in `tui/internal/app/sync_preflight.go`: (1) `time.Parse` reads `ps -o lstart` as UTC so a healthy chezmoi looks hours old and gets auto-SIGTERMed; (2) the >60s branch auto-kills without confirmation; (3) conflict detection matches only the literal status `"DA"`, missing `MM` and friends.

**Files:**
- Modify: `tui/internal/app/sync_preflight.go`
- Modify: `tui/internal/app/sync_preflight_test.go` (add table tests)

- [ ] **Step 1: Write the failing tests** — append to `tui/internal/app/sync_preflight_test.go`:

```go
func TestParseProcessStart_LocalTime(t *testing.T) {
	// Fix a non-UTC zone so the test fails under the old UTC time.Parse
	// regardless of the machine's own zone.
	loc := time.FixedZone("UTC-7", -7*3600)
	now := time.Date(2026, 7, 14, 12, 0, 0, 0, loc)
	lstart := now.Add(-30 * time.Second).Format("Mon Jan  2 15:04:05 2006")

	start, err := parseProcessStart(lstart, loc)
	if err != nil {
		t.Fatalf("parseProcessStart: %v", err)
	}
	age := now.Sub(start)
	if age < 25*time.Second || age > 35*time.Second {
		t.Errorf("age = %v, want ~30s (UTC parsing would be off by 7h)", age)
	}
}

func TestIsLocallyModifiedStatus(t *testing.T) {
	cases := []struct {
		line string
		want bool
	}{
		{"MM .zshrc", true},
		{"DA .config/nvim/lua/plugins/snacks/picker.lua", true},
		{"AM .config/foo/bar", true},
		{" M .config/gh", false},        // apply-side change only, no local edit
		{" A .config/new/file", false},  // apply would add; nothing local
		{"", false},
		{"X", false}, // too short
	}
	for _, tc := range cases {
		if got := isLocallyModifiedStatus(tc.line); got != tc.want {
			t.Errorf("isLocallyModifiedStatus(%q) = %v, want %v", tc.line, got, tc.want)
		}
	}
}
```

Add `"time"` to the test file's imports if not present.

- [ ] **Step 2: Run to verify failure**

Run: `cd tui && go test ./internal/app/ -run 'TestParseProcessStart|TestIsLocallyModified'`
Expected: compile failure (helpers undefined).

- [ ] **Step 3: Implement the two pure helpers** in `sync_preflight.go`:

```go
// parseProcessStart parses `ps -o lstart=` output, which is printed in the
// machine's local timezone — parsing it as UTC (time.Parse) skews process
// age by the UTC offset and once caused healthy chezmoi runs to be killed.
func parseProcessStart(lstart string, loc *time.Location) (time.Time, error) {
	return time.ParseInLocation("Mon Jan  2 15:04:05 2006", strings.TrimSpace(lstart), loc)
}

// isLocallyModifiedStatus reports whether a chezmoi status line describes a
// target that changed on disk since chezmoi last wrote it (first status
// column non-space) — the cases where re-add/apply need user attention.
func isLocallyModifiedStatus(line string) bool {
	if len(line) < 3 {
		return false
	}
	return line[0] != ' '
}
```

- [ ] **Step 4: Use them, and remove the auto-kill branch**

In `checkChezmoiLock` (lines ~130-163):
1. Replace the `time.Parse(...)` call (line 136) with `parseProcessStart(string(lstart), time.Local)`.
2. **Delete the whole `if seconds > 60 { ... severityAutofix ... }` block** (lines 142-150). A running chezmoi is ALWAYS `severityAsk` — the TUI never SIGTERMs a process without user confirmation. Keep the `seconds` computation for the message text only.

In `checkChezmoiConflicts` (lines ~79-90): replace the parsing block

```go
		status := line[:2]
		path := strings.TrimSpace(line[2:])
		if status != "DA" {
			continue
		}
```

with:

```go
		if !isLocallyModifiedStatus(line) {
			continue
		}
		path := strings.TrimSpace(line[2:])
```

and update the stale format comment above it to: `// chezmoi status: two status chars + space + target path relative to ~. // A non-space first char means the file changed on disk since last apply.`

Note: `severityAutofix` and the `AutoFix` field become unused by any check after this. **Leave the severity/field in place for this task** — the `PreflightResultMsg` handler in sync.go still references them and Task 4 touches that code; removing the whole autofix machinery is evaluated there (Step 5 of Task 4).

- [ ] **Step 5: Run tests + full verify**

Run: `cd tui && go test ./internal/app/ -v -run 'TestParseProcessStart|TestIsLocallyModified|TestRunPreflight|TestCheckChezmoi'` then `go build ./... && go vet ./... && gofmt -l .`
Expected: PASS / clean.

- [ ] **Step 6: Commit**

```bash
git add tui/internal/app/sync_preflight.go tui/internal/app/sync_preflight_test.go
git commit -m "fix: preflight parses lstart in local time, never auto-kills, detects all local edits"
```

### Task 4: Fix commands run sequentially before the pending script

Today `x`/`X` strip ask-issues from the slice and `tea.Batch` the fixes together with `maybeStartAfterResolve()` — the script starts in parallel with (or before) the fixes actually running. The fix: fixes emit a `FixCompleteMsg`, and the model chains queue → next fix → start.

**Files:**
- Modify: `tui/internal/app/sync_preflight.go` (FixCmd producers return `FixCompleteMsg`)
- Modify: `tui/internal/app/sync.go` (queue, x/X handling, FixCompleteMsg case, initRun reset)
- Modify: `tui/internal/app/app.go` (route `FixCompleteMsg` to the sync tab)
- Create: `tui/internal/app/sync_test.go`

- [ ] **Step 1: Write the failing tests** — `tui/internal/app/sync_test.go`:

```go
package app

import (
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

// fakeFix returns a PreflightIssue whose fix appends its name to order.
func fakeFix(name string, order *[]string) PreflightIssue {
	return PreflightIssue{
		Message:  name,
		Severity: severityAsk,
		FixCmd: func() tea.Cmd {
			return func() tea.Msg {
				*order = append(*order, name)
				return FixCompleteMsg{Toast: ToastMsg{Message: name, Level: ToastSuccess}}
			}
		},
	}
}

func drain(cmd tea.Cmd) []tea.Msg {
	if cmd == nil {
		return nil
	}
	msg := cmd()
	if batch, ok := msg.(tea.BatchMsg); ok {
		var msgs []tea.Msg
		for _, c := range batch {
			msgs = append(msgs, drain(c)...)
		}
		return msgs
	}
	return []tea.Msg{msg}
}

func TestInitRunResetsAwaitingResolve(t *testing.T) {
	m := NewSyncModel(t.TempDir())
	m.awaitingResolve = true
	m.pendingAction = syncActionPush
	m.fixQueue = []tea.Cmd{func() tea.Msg { return nil }}

	m.initRun(syncActionUpdate)

	if m.awaitingResolve {
		t.Error("initRun must reset awaitingResolve")
	}
	if m.fixQueue != nil {
		t.Error("initRun must clear fixQueue")
	}
}

func TestFixAllRunsSequentiallyThenStarts(t *testing.T) {
	var order []string
	m := NewSyncModel(t.TempDir())
	m.awaitingResolve = true
	m.pendingAction = syncActionPush
	m.preflightIssues = []PreflightIssue{
		fakeFix("fix1", &order),
		fakeFix("fix2", &order),
	}

	// Press X: only the FIRST fix may be dispatched; the second waits.
	m2, cmd := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'X'}})
	m = m2
	if m.running {
		t.Fatal("script must not start while fixes are pending")
	}
	msgs := drain(cmd)
	if len(order) != 1 || order[0] != "fix1" {
		t.Fatalf("after X, exactly fix1 must have run; order=%v", order)
	}

	// Feed fix1's completion back: fix2 must run next, still no script.
	var fc FixCompleteMsg
	found := false
	for _, msg := range msgs {
		if f, ok := msg.(FixCompleteMsg); ok {
			fc, found = f, true
		}
	}
	if !found {
		t.Fatal("expected a FixCompleteMsg from the first fix")
	}
	m2, cmd = m.Update(fc)
	m = m2
	if m.running {
		t.Fatal("script must not start before the last fix completes")
	}
	msgs = drain(cmd)
	if len(order) != 2 || order[1] != "fix2" {
		t.Fatalf("fix2 must run after fix1 completes; order=%v", order)
	}

	// Feed fix2's completion: now the script may start.
	found = false
	for _, msg := range msgs {
		if f, ok := msg.(FixCompleteMsg); ok {
			fc, found = f, true
		}
	}
	if !found {
		t.Fatal("expected a FixCompleteMsg from the second fix")
	}
	m2, _ = m.Update(fc)
	m = m2
	if !m.running {
		t.Error("script must start once all fixes completed")
	}
	if m.awaitingResolve {
		t.Error("awaitingResolve must be false after start")
	}
	if m.cancelRun != nil {
		m.cancelRun() // clean up the goroutine startScript spawned
	}
}
```

(`startScript` will exec `bash <tempdir>/scripts/push.sh`, which fails instantly and harmlessly delivers a `RunCompleteMsg` nobody reads — acceptable in a unit test; the final `cancelRun()` cleans up.)

- [ ] **Step 2: Run to verify failure**

Run: `cd tui && go test ./internal/app/ -run 'TestInitRun|TestFixAll'`
Expected: compile failure (`FixCompleteMsg`, `fixQueue` undefined).

- [ ] **Step 3: Introduce `FixCompleteMsg` and convert the fix producers** in `sync_preflight.go`:

Add near `PreflightResultMsg`:

```go
// FixCompleteMsg reports that one preflight fix finished. The sync model
// chains on it: next queued fix, or start the pending script.
type FixCompleteMsg struct {
	Toast ToastMsg
}
```

Convert every `FixCmd` to return `FixCompleteMsg{Toast: ...}` instead of a bare `ToastMsg`:
1. `checkChezmoiConflicts` re-add fix: both returns wrap their ToastMsg: `return FixCompleteMsg{Toast: ToastMsg{...}}`.
2. `checkChezmoiLock` kill fix: `return FixCompleteMsg{Toast: ToastMsg{Message: fmt.Sprintf("Killed chezmoi (PID %d)", pid), Level: ToastSuccess}}`.
3. `checkGitConflicts` editor fix — this one returns `tea.ExecProcess(c, callback)`. Do NOT wrap the cmd; change the **callback returns** to `FixCompleteMsg{Toast: ToastMsg{Message: "Editor error: " + err.Error(), Level: ToastError}}` / `FixCompleteMsg{Toast: ToastMsg{Message: "Editor closed", Level: ToastSuccess}}`.

- [ ] **Step 4: Rework the sync model** in `sync.go`:

1. Add field to `SyncModel` (Process control section): `fixQueue []tea.Cmd`.
2. In `initRun` (after line 138 `m.hangWarning = false`): add

```go
	m.awaitingResolve = false
	m.pendingAction = 0
	m.fixQueue = nil
```

3. Replace the `"x"` case's fix branch (lines 236-241):

```go
			// Priority 2: fix first preflight ask issue
			for i, issue := range m.preflightIssues {
				if issue.Severity == severityAsk && issue.FixCmd != nil {
					fix := issue.FixCmd()
					m.preflightIssues = append(m.preflightIssues[:i], m.preflightIssues[i+1:]...)
					if fix == nil {
						// Nothing left to fix (e.g. conflicts resolved
						// out of band) — don't stall the chain.
						return m, m.maybeStartAfterResolve()
					}
					return m, fix
				}
			}
			return m, nil
```

4. Replace the `"X"` case (lines 242-256):

```go
		case "X":
			// Queue ALL preflight ask fixes; run them one at a time.
			var fixes []tea.Cmd
			var remaining []PreflightIssue
			for _, issue := range m.preflightIssues {
				if issue.Severity == severityAsk && issue.FixCmd != nil {
					// Skip nil cmds (a fix that decided there's nothing
					// to do) — a nil in the chain would stall it.
					if fix := issue.FixCmd(); fix != nil {
						fixes = append(fixes, fix)
					}
				} else {
					remaining = append(remaining, issue)
				}
			}
			m.preflightIssues = remaining
			if len(fixes) == 0 {
				return m, m.maybeStartAfterResolve()
			}
			m.fixQueue = fixes[1:]
			return m, fixes[0]
```

5. In the `"s"` (skip) key case of sync.go's `Update`, add `m.fixQueue = nil` alongside its existing issue-clearing logic — a skip pressed while a fix is in flight must not leave queued fixes to race the script when that fix's `FixCompleteMsg` later arrives.

6. Add a `FixCompleteMsg` case to `Update` (next to `PreflightResultMsg`):

```go
	case FixCompleteMsg:
		toast := func() tea.Msg { return msg.Toast }
		if len(m.fixQueue) > 0 {
			next := m.fixQueue[0]
			m.fixQueue = m.fixQueue[1:]
			return m, tea.Batch(toast, next)
		}
		return m, tea.Batch(toast, m.maybeStartAfterResolve())
```

- [ ] **Step 5: Evaluate the autofix machinery**

After Task 3, no check produces `severityAutofix`. Replace the **entire** `case PreflightResultMsg:` body in sync.go (lines 327-365 — everything from the case label through the final `return m, tea.Batch(append(toastCmds, scriptCmd)...)`) with:

```go
	case PreflightResultMsg:
		m.preflightIssues = msg.Issues
		m.checking = false

		hasAsk := false
		for _, issue := range msg.Issues {
			if issue.Severity == severityAsk {
				hasAsk = true
				break
			}
		}
		if hasAsk {
			m.pendingAction = msg.Action
			m.awaitingResolve = true
			return m, nil
		}
		return m, m.startScript(msg.Action)
```

Then delete `severityAutofix` from the const block and the `AutoFix` field from `PreflightIssue` in sync_preflight.go (prefer deletion over deprecation). Grep to confirm no other references: `grep -rn "severityAutofix\|AutoFix" tui/` must print nothing after this.

- [ ] **Step 6: Route the new message** in `app.go`: in the tab-specific routing type-switch (near the `PreflightResultMsg` case), add:

```go
	case FixCompleteMsg:
		var cmd tea.Cmd
		m.syncTab, cmd = m.syncTab.Update(msg)
		return m, cmd
```

(Mirror the exact style of the adjacent `PreflightResultMsg` routing case.)

- [ ] **Step 7: Run tests + full verify**

Run: `cd tui && go test ./internal/app/ -v -run 'TestInitRun|TestFixAll'` then `go build ./... && go test ./... && go vet ./... && gofmt -l .`
Expected: PASS / clean.

- [ ] **Step 8: Commit**

```bash
git add tui/internal/app/sync.go tui/internal/app/sync_preflight.go tui/internal/app/sync_test.go tui/internal/app/app.go
git commit -m "fix: preflight fixes run sequentially before the script, initRun resets resolve state"
```

### Task 5: Quit cancels a running sync

`q`/`ctrl+c` currently `tea.Quit` unconditionally, leaving a detached half-finished git/chezmoi pipeline. With Task 2's group kill, cancelling the context now reliably kills the whole tree.

**Files:**
- Modify: `tui/internal/app/sync.go` (exported `CancelRun`)
- Modify: `tui/internal/app/app.go` (quit path)

- [ ] **Step 1: Add `CancelRun` to `SyncModel`** (near `TriggerAction`):

```go
// CancelRun kills the running script's process group, if any. Used by the
// root model so quitting never leaves a detached half-finished sync.
func (m *SyncModel) CancelRun() {
	if m.cancelRun != nil {
		m.cancelRun()
		m.cancelRun = nil
	}
}
```

- [ ] **Step 2: Wire it into both quit paths in `app.go`** (lines 86-98). Replace:

```go
		case "ctrl+c":
			return m, tea.Quit
```

with:

```go
		case "ctrl+c":
			m.syncTab.CancelRun()
			return m, tea.Quit
```

and in the `"q"` case, immediately before `return m, tea.Quit`, add `m.syncTab.CancelRun()` (leave the two overlay fall-through checks above it untouched).

- [ ] **Step 3: Verify behavior manually-ish via test**

Append to `sync_test.go`:

```go
func TestCancelRunNilSafe(t *testing.T) {
	m := NewSyncModel(t.TempDir())
	m.CancelRun() // must not panic with no run in flight
	if m.cancelRun != nil {
		t.Error("cancelRun should stay nil")
	}
}
```

Run: `cd tui && go test ./internal/app/ -run TestCancelRun && go build ./... && gofmt -l .`
Expected: PASS / clean. (The kill-the-group behavior itself is covered by Task 2's runner test; this wires it to quit.)

- [ ] **Step 4: Commit**

```bash
git add tui/internal/app/sync.go tui/internal/app/app.go
git commit -m "fix: quitting the TUI cancels a running sync via process-group kill"
```

---

## Chunk 3: Configs tab — chezmoi-driven discovery

### Task 6: `$EDITOR` argv-splitting helper

`EDITOR="code --wait"` currently fails at both launch sites because the whole value is passed as argv[0].

**Files:**
- Create: `tui/internal/app/editor.go`
- Create: `tui/internal/app/editor_test.go`
- Modify: `tui/internal/app/sync_preflight.go` (git-conflict editor site)

- [ ] **Step 1: Write the failing test** — `tui/internal/app/editor_test.go`:

```go
package app

import "testing"

func TestEditorCommand(t *testing.T) {
	cases := []struct {
		name     string
		editor   string
		files    []string
		wantPath string
		wantArgs []string
	}{
		{"plain", "vi", []string{"f.txt"}, "vi", []string{"vi", "f.txt"}},
		{"with flag", "code --wait", []string{"f.txt"}, "code", []string{"code", "--wait", "f.txt"}},
		{"multiple flags", "nvim -u NONE", []string{"a", "b"}, "nvim", []string{"nvim", "-u", "NONE", "a", "b"}},
		{"empty falls back to vi", "", []string{"f"}, "vi", []string{"vi", "f"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv("EDITOR", tc.editor)
			cmd := editorCommand(tc.files...)
			if cmd.Path != tc.wantPath && cmd.Args[0] != tc.wantPath {
				t.Errorf("argv0 = %q/%q, want %q", cmd.Path, cmd.Args[0], tc.wantPath)
			}
			if len(cmd.Args) != len(tc.wantArgs) {
				t.Fatalf("args = %v, want %v", cmd.Args, tc.wantArgs)
			}
			for i := range tc.wantArgs {
				if cmd.Args[i] != tc.wantArgs[i] {
					t.Errorf("args[%d] = %q, want %q", i, cmd.Args[i], tc.wantArgs[i])
				}
			}
		})
	}
}
```

(Note `cmd.Path` may be resolved to an absolute path by exec.Command when the binary exists; the `cmd.Args[0]` fallback keeps the test robust — `vi` exists on macOS, `code`/`nvim` may not, and exec.Command tolerates unresolvable names until Start.)

- [ ] **Step 2: Run to verify failure** — `cd tui && go test ./internal/app/ -run TestEditorCommand` → compile failure.

- [ ] **Step 3: Implement** — `tui/internal/app/editor.go`:

```go
package app

import (
	"os"
	"os/exec"
	"strings"
)

// editorCommand builds an exec.Cmd for $EDITOR with the given file
// arguments. $EDITOR values with flags ("code --wait") are split into argv
// on whitespace; quoting is not supported (YAGNI). Falls back to vi.
func editorCommand(files ...string) *exec.Cmd {
	editor := strings.TrimSpace(os.Getenv("EDITOR"))
	if editor == "" {
		editor = "vi"
	}
	parts := strings.Fields(editor)
	args := append(parts[1:], files...)
	return exec.Command(parts[0], args...)
}
```

- [ ] **Step 4: Use it at the preflight site** — in `sync_preflight.go` `checkGitConflicts` (lines ~190-195), replace:

```go
			editor := os.Getenv("EDITOR")
			if editor == "" {
				editor = "vi"
			}
			c := exec.Command(editor, files...)
			c.Dir = dotsDir
```

with:

```go
			c := editorCommand(files...)
			c.Dir = dotsDir
```

(The configs.go site is converted as part of Task 7's rewrite.)

- [ ] **Step 5: Verify + commit**

Run: `cd tui && go test ./internal/app/ -run TestEditorCommand -v && go build ./... && go vet ./... && gofmt -l .`
Expected: PASS / clean.

```bash
git add tui/internal/app/editor.go tui/internal/app/editor_test.go tui/internal/app/sync_preflight.go
git commit -m "fix: split \$EDITOR values with arguments into argv"
```

### Task 7: Rebuild Configs discovery on chezmoi as source of truth

Replace the filesystem walk + three divergent `strings.ReplaceAll("dot_", ".")` mappings with: file list from `chezmoi managed --include=files`, source paths from one `chezmoi source-path` call, categories derived from **target** paths, diff on **target** paths with exit-code checking, and cursor clamping for both cursors.

**Files:**
- Modify: `tui/internal/app/configs.go` (types, scanCategories, buildTree, fetchDiff, key handlers, categoriesLoadedMsg)
- Create: `tui/internal/app/configs_test.go`

- [ ] **Step 1: Write the failing tests** — `tui/internal/app/configs_test.go`:

```go
package app

import (
	"testing"
	"time"
)

func TestCategoryForTarget(t *testing.T) {
	cases := []struct {
		target string
		want   string
	}{
		{".config/kitty/kitty.conf", "kitty"},
		{".config/nvim/lua/config/init.lua", "nvim"},
		{".config/starship.toml", "starship.toml"},
		{".zshrc", "home"},
		{".gitconfig", "home"},
		{".oh-my-zsh/custom/plugins/foo/foo.zsh", "home"},
	}
	for _, tc := range cases {
		if got := categoryForTarget(tc.target); got != tc.want {
			t.Errorf("categoryForTarget(%q) = %q, want %q", tc.target, got, tc.want)
		}
	}
}

func TestCategoriesLoadedClampsBothCursors(t *testing.T) {
	m := NewConfigsModel(t.TempDir())
	m.cursor = 5
	m.fileCursor = 9
	m.inFiles = true

	small := []configCategory{
		{Name: "kitty", Files: []configFile{{TargetRel: ".config/kitty/kitty.conf"}}},
		{Name: "home", Files: []configFile{{TargetRel: ".zshrc"}}},
	}
	m2, _ := m.Update(categoriesLoadedMsg{categories: small})

	if m2.cursor > len(small)-1 {
		t.Errorf("category cursor not clamped: %d", m2.cursor)
	}
	if m2.fileCursor > len(m2.tree)-1 {
		t.Errorf("file cursor not clamped: %d (tree %d)", m2.fileCursor, len(m2.tree))
	}
}

func TestScanErrorSurfaced(t *testing.T) {
	m := NewConfigsModel(t.TempDir())
	m2, cmd := m.Update(categoriesLoadedMsg{err: "chezmoi exploded"})
	if cmd == nil {
		t.Fatal("expected a toast command for the error")
	}
	if msg, ok := cmd().(ToastMsg); !ok || msg.Level != ToastError {
		t.Errorf("expected an error toast, got %#v", cmd())
	}
	_ = m2
}

func TestBuildTreeHomeCategoryTerminates(t *testing.T) {
	// Regression: the old common-prefix walk infinite-looped on two
	// top-level dotfiles (basePath stuck at "." with a "/" guard).
	m := NewConfigsModel(t.TempDir())
	cat := configCategory{Name: "home", Files: []configFile{
		{TargetRel: ".gitconfig"},
		{TargetRel: ".zshrc"},
		{TargetRel: ".oh-my-zsh/custom/plugins/foo/foo.zsh"},
	}}

	done := make(chan []treeEntry, 1)
	go func() { done <- m.buildTree(cat) }()

	select {
	case entries := <-done:
		var fileNames []string
		for _, e := range entries {
			if !e.IsDir {
				fileNames = append(fileNames, e.Name)
			}
		}
		if len(fileNames) != 3 {
			t.Errorf("expected 3 files in tree, got %v", fileNames)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("buildTree did not terminate — common-prefix walk is looping")
	}
}
```

- [ ] **Step 2: Run to verify failure** — `cd tui && go test ./internal/app/ -run 'TestCategoryForTarget|TestCategoriesLoaded|TestScanError|TestBuildTree'` → compile failure (`configFile`, `categoryForTarget`, `err` field undefined).

- [ ] **Step 3: Replace the data types** in `configs.go`:

```go
// configFile is one chezmoi-managed file, known by its target path.
type configFile struct {
	TargetRel  string // path relative to ~, as printed by `chezmoi managed`
	SourcePath string // absolute path in the chezmoi source dir ("" if unresolved)
	IsTemplate bool   // source is a .tmpl — chezmoi re-add cannot capture edits
	Dirty      bool   // chezmoi status lists a pending difference for this target
}

type configCategory struct {
	Name       string
	Icon       string
	Files      []configFile
	DirtyCount int
}
```

Update `treeEntry`: change the `Path` doc comment to `// target path relative to ~ (empty for directories)` and add `SourcePath string` after it. Update `categoriesLoadedMsg`:

```go
type categoriesLoadedMsg struct {
	categories []configCategory
	err        string // non-empty when discovery failed
}
```

Also DELETE the `dirtyFiles map[string]bool` field from `ConfigsModel` (line 59) and its initializer in `NewConfigsModel` (line 71) — dirtiness now travels on each `configFile`, so the model-level map would be write-only dead state.

- [ ] **Step 4: Add the pure category helper** (near buildTree):

```go
// categoryForTarget derives a presentation category from a target path:
// .config/<name>/... (or a file directly under .config) groups under <name>;
// everything else is a top-level dotfile in the "home" category.
func categoryForTarget(target string) string {
	rest, ok := strings.CutPrefix(target, ".config/")
	if !ok {
		return "home"
	}
	if i := strings.IndexByte(rest, '/'); i >= 0 {
		return rest[:i]
	}
	return rest
}
```

- [ ] **Step 5: Rewrite `scanCategories`** (replaces lines 453-532 wholesale):

```go
func (m ConfigsModel) scanCategories() tea.Cmd {
	return func() tea.Msg {
		r := runner.New(m.dotsDir)

		managed := r.Run("chezmoi", "managed", "--include=files")
		if managed.ExitCode != 0 {
			return categoriesLoadedMsg{err: "chezmoi managed failed: " + strings.TrimSpace(managed.Stderr)}
		}
		var targets []string
		for _, line := range strings.Split(strings.TrimSpace(managed.Stdout), "\n") {
			if line = strings.TrimSpace(line); line != "" {
				targets = append(targets, line)
			}
		}
		sort.Strings(targets)

		// Targets with pending differences per chezmoi status — either a
		// local edit or an unapplied source change (both matter to a user
		// browsing configs, matching the tab's existing behavior).
		dirtyFiles := make(map[string]bool)
		if st := r.Run("chezmoi", "status"); st.ExitCode == 0 {
			for _, line := range strings.Split(strings.TrimSpace(st.Stdout), "\n") {
				if len(line) > 3 {
					dirtyFiles[strings.TrimSpace(line[2:])] = true
				}
			}
		}

		// Resolve all source paths in one call. chezmoi prints results
		// sorted by TARGET PATH, not argument order — the sort.Strings on
		// targets above is load-bearing: it makes arg order match output
		// order (chezmoi's sort matches Go's byte-wise string sort).
		sourceFor := make(map[string]string, len(targets))
		home, homeErr := os.UserHomeDir()
		if homeErr == nil && len(targets) > 0 {
			args := make([]string, 0, len(targets)+1)
			args = append(args, "source-path")
			for _, t := range targets {
				args = append(args, filepath.Join(home, t))
			}
			if sp := r.Run("chezmoi", args...); sp.ExitCode == 0 {
				lines := strings.Split(strings.TrimSpace(sp.Stdout), "\n")
				if len(lines) == len(targets) {
					for i, t := range targets {
						sourceFor[t] = strings.TrimSpace(lines[i])
					}
				}
			}
			// A source-path failure degrades gracefully: files still list,
			// editing falls back to an error toast for unresolved entries.
		}

		iconMap := map[string]string{
			"kitty": " ",
			"nvim":  " ",
			"home":  " ",
		}
		defaultIcon := " "

		grouped := make(map[string][]configFile)
		var order []string
		for _, t := range targets {
			cat := categoryForTarget(t)
			if _, seen := grouped[cat]; !seen {
				order = append(order, cat)
			}
			src := sourceFor[t]
			grouped[cat] = append(grouped[cat], configFile{
				TargetRel:  t,
				SourcePath: src,
				IsTemplate: strings.HasSuffix(src, ".tmpl"),
				Dirty:      dirtyFiles[t],
			})
		}
		sort.Strings(order)

		var cats []configCategory
		for _, name := range order {
			files := grouped[name]
			dirtyCount := 0
			for _, f := range files {
				if f.Dirty {
					dirtyCount++
				}
			}
			icon := defaultIcon
			if ic, ok := iconMap[name]; ok {
				icon = ic
			}
			cats = append(cats, configCategory{Name: name, Icon: icon, Files: files, DirtyCount: dirtyCount})
		}

		return categoriesLoadedMsg{categories: cats}
	}
}
```

Delete `isFileDirty` entirely (lines 429-443) — dirtiness now travels on `configFile`. Update `hasTemplateFiles` to check `f.IsTemplate` instead of `strings.HasSuffix(f, ".tmpl")`.

- [ ] **Step 6: Adapt `buildTree`** — same tree algorithm, fed by target-relative paths, but the common-prefix walk MUST be rewritten, not just re-pointed. The current loop's termination guard is `basePath != "/"`, written for absolute paths; with relative targets `filepath.Dir` bottoms out at `"."` (never `"/"`), and plan review **confirmed by execution** that feeding it two home-category files (`.zshrc`, `.gitconfig`) infinite-loops and freezes the TUI. Replace the whole common-prefix block (lines 344-353) with:

```go
	// Common prefix of all target-relative paths in the category.
	// filepath.Dir on relative paths bottoms out at "." — that (not "/")
	// is the loop's floor, and it is the correct base for top-level
	// dotfiles: filepath.Rel(".", ".zshrc") == ".zshrc".
	basePath := ""
	if len(cat.Files) > 0 {
		basePath = filepath.Dir(cat.Files[0].TargetRel)
		for _, f := range cat.Files[1:] {
			for basePath != "." && !strings.HasPrefix(f.TargetRel, basePath+"/") {
				basePath = filepath.Dir(basePath)
			}
		}
	}
```

In the `fileInfo` build (lines 355-366), replace with:

```go
	type fileInfo struct {
		RelPath string
		File    configFile
	}
	var files []fileInfo
	for _, f := range cat.Files {
		rel, err := filepath.Rel(basePath, f.TargetRel)
		if err != nil || strings.HasPrefix(rel, "..") {
			rel = f.TargetRel
		}
		files = append(files, fileInfo{RelPath: rel, File: f})
	}
```

The file-entry append (lines 392-398) becomes:

```go
		entries = append(entries, treeEntry{
			Name:       parts[len(parts)-1],
			Path:       f.File.TargetRel,
			SourcePath: f.File.SourcePath,
			Depth:      len(parts) - 1,
			IsDir:      false,
			Dirty:      f.File.Dirty,
		})
```

(`Dirty: f.Dirty` and `AbsPath` references go away.)

- [ ] **Step 7: Fix the "d" and "e" key handlers and the message case**

`"d"` (lines 160-166): unchanged shape — still `return m, m.fetchDiff(entry.Path)`, but `entry.Path` is now the target-relative path. Replace `fetchDiff` (lines 534-543):

```go
func (m ConfigsModel) fetchDiff(targetRel string) tea.Cmd {
	return func() tea.Msg {
		home, err := os.UserHomeDir()
		if err != nil {
			return diffResultMsg{Content: StyleError.Render("Error: " + err.Error())}
		}
		result := m.runner.Run("chezmoi", "diff", filepath.Join(home, targetRel))
		if result.ExitCode != 0 {
			return diffResultMsg{Content: StyleError.Render("chezmoi diff failed:") + "\n" + strings.TrimSpace(result.Stderr)}
		}
		content := result.Stdout
		if strings.TrimSpace(content) == "" {
			content = "No differences found."
		}
		return diffResultMsg{Content: content}
	}
}
```

`"e"` (lines 167-180): edit the **source** file (the dots workflow — direct target edits are the re-add trap). Replace the body:

```go
		case "e":
			if m.inFiles && m.fileCursor < len(m.tree) {
				entry := m.tree[m.fileCursor]
				if !entry.IsDir {
					if entry.SourcePath == "" {
						return m, func() tea.Msg {
							return ToastMsg{Message: "No source path for " + entry.Path, Level: ToastError}
						}
					}
					c := editorCommand(entry.SourcePath)
					return m, tea.ExecProcess(c, func(err error) tea.Msg {
						return editorFinishedMsg{err: err}
					})
				}
			}
```

`categoriesLoadedMsg` case (lines 183-193): replace with:

```go
	case categoriesLoadedMsg:
		if msg.err != "" {
			return m, func() tea.Msg {
				return ToastMsg{Message: msg.err, Level: ToastError}
			}
		}
		m.categories = msg.categories
		if m.cursor >= len(m.categories) {
			m.cursor = max(0, len(m.categories)-1)
		}
		if m.inFiles && m.cursor < len(m.categories) {
			m.tree = m.buildTree(m.categories[m.cursor])
			if m.fileCursor >= len(m.tree) {
				m.fileCursor = max(0, len(m.tree)-1)
			}
		}
		return m, nil
```

Also remove the now-unused `"os/exec"` import from configs.go (the editor helper owns it), and keep `"os"` (UserHomeDir).

- [ ] **Step 8: Run tests + full verify**

Run: `cd tui && go test ./internal/app/ -v -run 'TestCategoryForTarget|TestCategoriesLoaded|TestScanError|TestBuildTree'` then `go build ./... && go test ./... && go vet ./... && gofmt -l .`
Expected: PASS / clean.

- [ ] **Step 9: Manual smoke on this machine**

Run: `cd tui && go run . 2>/dev/null || true` — actually launch `make build && ./tui/dots` from the repo root in an interactive terminal if available; otherwise verify the plumbing headlessly:

```bash
cd ~/dev/dots && chezmoi managed --include=files | head -5 && chezmoi source-path ~/.zshrc
```
Expected: managed prints target-relative paths (including Phase-3-onboarded files like `.config/starship.toml` and `.gitconfig` when they exist); source-path resolves. The Task 14 walkthrough covers the visual check.

- [ ] **Step 10: Commit**

```bash
git add tui/internal/app/configs.go tui/internal/app/configs_test.go
git commit -m "feat: configs tab discovers files via chezmoi managed, diffs target paths, clamps cursors"
```

---

## Chunk 4: Status, scheduler, settings, homebrew truthfulness

### Task 8: Status tab — async chezmoi data, no-upstream warning, XDG log path

**Files:**
- Modify: `tui/internal/app/status.go`
- Modify: `tui/internal/app/app.go` (route `machineTypeMsg`)

- [ ] **Step 1: Make `chezmoi data` async.** In `status.go`:

1. Add message type near `syncLogMsg`:

```go
type machineTypeMsg struct {
	machineType string
}
```

2. In `NewStatusModel` (lines 77-88): delete the whole synchronous block (`machineType := "unknown"` through the closing brace of the JSON parse) and the `machineType: machineType` field init — the struct field zero-value `""` is the "not loaded" state. Remove the now-unused `runner.New` call there.
3. Add the fetch command (near `fetchGitStatus`):

```go
func (m StatusModel) fetchMachineType() tea.Cmd {
	return func() tea.Msg {
		r := runner.New(m.dotsDir)
		result := r.Run("chezmoi", "data", "--format=json")
		if result.ExitCode != 0 {
			return machineTypeMsg{}
		}
		var data struct {
			MachineType string `json:"machine_type"`
		}
		if err := json.Unmarshal([]byte(result.Stdout), &data); err != nil {
			return machineTypeMsg{}
		}
		return machineTypeMsg{machineType: data.MachineType}
	}
}
```

4. Add `m.fetchMachineType()` to the `tea.Batch` in `Init()`, and a message case:

```go
	case machineTypeMsg:
		m.machineType = msg.machineType
		return m, nil
```

5. In `renderContent` (line 204), replace the machine line with:

```go
	machine := fmt.Sprintf("  %s %s", m.osName, m.arch)
	if m.machineType != "" {
		machine += " (" + m.machineType + ")"
	}
	b.WriteString(machine + "\n\n")
```

(No more "(unknown)" — this also anticipates Phase 3 deleting the machine_type prompt entirely.)

6. In `app.go`, route the new message (next to `gitStatusMsg`'s case, mirroring its style):

```go
	case machineTypeMsg:
		var cmd tea.Cmd
		m.statusTab, cmd = m.statusTab.Update(msg)
		return m, cmd
```

- [ ] **Step 2: Surface upstream state.** In `status.go`:

1. Extend `GitStatus`:

```go
type GitStatus struct {
	Ahead      int
	Behind     int
	Dirty      int
	DirtyFiles []string
	NoUpstream bool   // rev-list failed because no upstream is configured
	Err        string // any other rev-list failure
}
```

2. In `fetchGitStatus` (lines 257-265), replace the rev-list block:

```go
		result := r.Run("git", "rev-list", "--left-right", "--count", "HEAD...@{upstream}")
		if result.ExitCode == 0 {
			parts := strings.Fields(strings.TrimSpace(result.Stdout))
			if len(parts) == 2 {
				gs.Ahead, _ = strconv.Atoi(parts[0])
				gs.Behind, _ = strconv.Atoi(parts[1])
			}
		} else if strings.Contains(result.Stderr, "upstream") {
			gs.NoUpstream = true
		} else {
			gs.Err = strings.TrimSpace(result.Stderr)
		}
```

(git's message for a branch without upstream is `fatal: no upstream configured for branch '<name>'` — verified against git 2.55. A detached HEAD produces `fatal: HEAD does not point to a branch`, which deliberately falls to `gs.Err` → the red "Status unknown" state; that is correct, not a gap.)

3. In `renderContent`, replace ONLY the status-dot/status-text computation (lines 174-179, from `statusDot := ...` through the closing brace of the `if`) — the `b.WriteString(StyleTitle.Render("  Sync Status")...)` and `b.WriteString(fmt.Sprintf("  %s %s", statusDot, statusText)...)` lines that follow must remain:

```go
	statusDot := StyleStatusDot.Foreground(ColorGreen).Render("●")
	statusText := "In sync"
	switch {
	case m.gitStatus.Err != "":
		statusDot = StyleStatusDot.Foreground(ColorRed).Render("●")
		statusText = "Status unknown: " + m.gitStatus.Err
	case m.gitStatus.NoUpstream:
		statusDot = StyleStatusDot.Foreground(ColorYellow).Render("●")
		statusText = "No upstream configured — push/pull unavailable"
	case m.gitStatus.Ahead > 0 || m.gitStatus.Behind > 0 || m.gitStatus.Dirty > 0:
		statusDot = StyleStatusDot.Foreground(ColorYellow).Render("●")
		statusText = "Changes pending"
	}
```

- [ ] **Step 3: Honor `XDG_STATE_HOME` in `parseSyncLog`.** Replace ONLY the path construction (lines 286-290, from `home, err := os.UserHomeDir()` through the `logPath := ...` line) — the `os.ReadFile(logPath)` call and everything after it stays:

```go
	stateDir := os.Getenv("XDG_STATE_HOME")
	if stateDir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return nil, err
		}
		stateDir = filepath.Join(home, ".local", "state")
	}
	logPath := filepath.Join(stateDir, "dots", "sync.log")
```

(This matches lib.sh's `${XDG_STATE_HOME:-$HOME/.local/state}/dots` exactly — writer and reader agree in all configurations now.)

- [ ] **Step 4: Verify + commit**

Run: `cd tui && go build ./... && go test ./... && go vet ./... && gofmt -l .`
Expected: clean.

```bash
git add tui/internal/app/status.go tui/internal/app/app.go
git commit -m "fix: status tab loads chezmoi data async, warns on missing upstream, honors XDG_STATE_HOME"
```

### Task 9: Scheduler BROKEN state, visible end to end

Phase 1's `schedule.sh status` prints `Scheduled sync: BROKEN — ...` to **stderr** when the baked script path is missing. The TUI reads stdout only and knows just ACTIVE/INACTIVE — BROKEN silently renders as OFF.

**Files:**
- Modify: `tui/internal/scheduler/scheduler.go`
- Modify: `tui/internal/scheduler/scheduler_test.go`
- Modify: `tui/internal/app/settings.go`
- Modify: `tui/internal/app/system.go`

- [ ] **Step 1: Write the failing test** — append to `scheduler_test.go`:

```go
func TestParseStatusBroken(t *testing.T) {
	output := "\033[0;31mScheduled sync: BROKEN — script path in /Users/x/Library/LaunchAgents/com.dots.sync.plist is missing (/gone/sync.sh)\033[0m\n"
	status := scheduler.ParseStatus(output)

	if !status.Broken {
		t.Error("expected Broken=true")
	}
	if status.Active {
		t.Error("BROKEN must not read as Active")
	}
}
```

- [ ] **Step 2: Run to verify failure** — `cd tui && go test ./internal/scheduler/` → compile failure (`Broken` undefined).

- [ ] **Step 3: Implement.** In `scheduler.go`:

1. Add to `Status`: `Broken bool // schedule.sh reported a broken installation (e.g. baked script path missing)`.
2. `GetStatus` must see stderr (that's where `error()` writes BROKEN) and must check the exit code (the spec requires it: a hard failure — script missing, bash error — exits non-zero with no ACTIVE/BROKEN text at all and must not render as a false "OFF"):

```go
func (s *Scheduler) GetStatus() Status {
	result := s.runner.Run("bash", s.ScriptPath(), "status")
	combined := result.Stdout + "\n" + result.Stderr
	if result.ExitCode != 0 {
		return Status{Broken: true, Raw: combined}
	}
	return ParseStatus(combined)
}
```

(The `"\n"` join also keeps the `LastSync` `{`-prefix scan intact if stdout lacks a trailing newline.)

3. In `ParseStatus`, after `clean := ansi.Strip(output)`, add before the ACTIVE check:

```go
	if strings.Contains(clean, "BROKEN") {
		status.Broken = true
	}
```

and guard the active branch: `if !status.Broken && strings.Contains(clean, "ACTIVE") && !strings.Contains(clean, "INACTIVE") {`.

- [ ] **Step 4: Surface it in Settings.** In `settings.go`:

1. `scheduleStatusMsg` gains `broken bool`; `refreshStatus` passes `broken: status.Broken`.
2. Add model field `syncBroken bool`; the `scheduleStatusMsg` case sets `m.syncBroken = msg.broken`.
3. `syncToggleLabel`:

```go
func (m SettingsModel) syncToggleLabel() string {
	if m.syncBroken {
		return StyleError.Render("BROKEN") + StyleDimmed.Render(" (run scripts/schedule.sh status)")
	}
	if m.syncActive {
		return StyleSuccess.Render("ON") + " (" + m.syncBackend + ")"
	}
	return StyleDimmed.Render("OFF")
}
```

- [ ] **Step 5: Surface it on the System tab too.** `system.go` (lines ~321-327) maps `GetStatus()` to only Active/Inactive — a broken install would show a dimmed "Inactive". Replace that block:

```go
		// Schedule status
		status := m.scheduler.GetStatus()
		switch {
		case status.Broken:
			info.ScheduleStatus = StyleError.Render("Broken") + StyleDimmed.Render(" (run scripts/schedule.sh status)")
		case status.Active:
			info.ScheduleStatus = StyleSuccess.Render("Active") + " (" + status.Backend + ")"
		default:
			info.ScheduleStatus = StyleDimmed.Render("Inactive")
		}
```

- [ ] **Step 6: Verify + commit**

Run: `cd tui && go test ./internal/scheduler/ -v && go build ./... && go test ./... && gofmt -l .`
Expected: PASS / clean (existing ACTIVE/INACTIVE tests must still pass unchanged).

```bash
git add tui/internal/scheduler/ tui/internal/app/settings.go tui/internal/app/system.go
git commit -m "feat: surface schedule.sh BROKEN state in scheduler parsing, settings, and system tabs"
```

### Task 10: Settings — chezmoi data errors visible, dead field removed

**Files:**
- Modify: `tui/internal/app/settings.go`

- [ ] **Step 1: Check the exit code in `viewChezmoiData`** (lines 320-325):

```go
func (m SettingsModel) viewChezmoiData() tea.Cmd {
	return func() tea.Msg {
		result := m.runner.Run("chezmoi", "data")
		if result.ExitCode != 0 {
			return chezmoiDataMsg{data: StyleError.Render("chezmoi data failed:") + "\n" + strings.TrimSpace(result.Stderr)}
		}
		return chezmoiDataMsg{data: result.Stdout}
	}
}
```

(Add `"strings"` to imports if absent.)

- [ ] **Step 2: Delete the dead field** — remove `syncInterval string` from `SettingsModel` (line 44). Grep: `grep -rn "syncInterval" tui/` must print nothing.

- [ ] **Step 3: Verify + commit**

Run: `cd tui && go build ./... && go test ./... && go vet ./... && gofmt -l .`

```bash
git add tui/internal/app/settings.go
git commit -m "fix: settings surfaces chezmoi data failures; drop dead syncInterval field"
```

### Task 11: Homebrew — running guard and bundle result surfaced

**Files:**
- Modify: `tui/internal/app/homebrew.go`

- [ ] **Step 1: Guard the action keys** (lines 153-165). `b` must not double-run; Brewfile mutations are blocked mid-bundle:

```go
		case "a":
			if m.running {
				return m, nil
			}
			m.adding = true
			m.addInput.Focus()
			return m, textinput.Blink
		case "r":
			if m.running {
				return m, nil
			}
			if m.cursor < len(m.filtered) {
				m.removePackage(m.filtered[m.cursor])
				return m, m.loadBrewfile()
			}
		case "b":
			if m.running {
				return m, nil
			}
			m.running = true
			m.output = ""
			return m, tea.Batch(m.spinner.Tick, m.runBrewBundle())
```

- [ ] **Step 2: Check the exit code.** Add model field `bundleFailed bool`. Replace the `brewBundleCompleteMsg` case (lines 172-175):

```go
	case brewBundleCompleteMsg:
		m.running = false
		m.output = msg.output
		m.bundleFailed = msg.exitCode != 0
		if m.bundleFailed {
			code := msg.exitCode
			return m, func() tea.Msg {
				return ToastMsg{Message: fmt.Sprintf("brew bundle failed (exit %d)", code), Level: ToastError}
			}
		}
		return m, func() tea.Msg {
			return ToastMsg{Message: "brew bundle completed", Level: ToastSuccess}
		}
```

(Add `"fmt"` to imports if absent.)

- [ ] **Step 3: Error styling on the output box.** In `renderContent` (lines 270-272):

```go
	if m.output != "" {
		box := StyleBorder
		if m.bundleFailed {
			box = box.BorderForeground(ColorRed)
		}
		b.WriteString(box.Render(m.output) + "\n\n")
	}
```

(lipgloss styles are values — `BorderForeground` returns a modified copy; the shared `StyleBorder` is untouched.)

- [ ] **Step 4: Verify + commit**

Run: `cd tui && go build ./... && go test ./... && go vet ./... && gofmt -l .`

```bash
git add tui/internal/app/homebrew.go
git commit -m "fix: homebrew tab guards concurrent bundles and surfaces bundle failures"
```

---

## Chunk 5: Dead code, docs, final verification

### Task 12: Dead code removal + go mod tidy

**Files:**
- Modify: `tui/internal/app/theme.go`, `tui/internal/app/settings.go` (nothing further — done in Task 10), `tui/internal/app/system.go`, `tui/go.mod`/`go.sum`

- [ ] **Step 1: theme.go dead styles and colors.** Delete these **styles** (each confirmed zero references outside its declaration): `StyleSubtitle`, `StyleActiveTab`, `StyleInactiveTab` (app.go's `renderTabBar` builds its own inline tab styles — keeping the inline versions avoids any visual change; deletion beats deprecation).

Then delete these **colors** (unused after the style deletions): `ColorRosewater`, `ColorFlamingo`, `ColorPink`, `ColorMaroon`, `ColorTeal`, `ColorSky`, `ColorSapphire`, `ColorSubtext1`, `ColorSubtext0`, `ColorOverlay2`, `ColorSurface0`, `ColorBase`, `ColorMantle`, `ColorCrust`.

Keep: `ColorMauve`, `ColorRed`, `ColorPeach`, `ColorYellow`, `ColorGreen`, `ColorBlue`, `ColorLavender`, `ColorText`, `ColorOverlay1`, `ColorOverlay0`, `ColorSurface2`, `ColorSurface1` (scrollbar track).

Verify each deletion with grep before removing; after: `cd tui && go build ./...` catches any missed reference.

- [ ] **Step 2: system.go dead runner field.** Delete the `runner *runner.Runner` field (line 41), the `runner: runner.New(dotsDir),` initializer (line 60), and the now-unused `runner` import — `SystemModel` shells out via `exec.Command` directly and never used it.

- [ ] **Step 3: go mod tidy.** `github.com/atotto/clipboard` is directly imported by `app.go` but declared `// indirect`:

```bash
cd tui && go mod tidy && git diff go.mod
```
Expected diff: clipboard moves into the direct require block. Nothing else should churn; if other modules move, inspect before committing.

- [ ] **Step 4: Verify + commit**

Run: `cd tui && gofmt -l . && go build ./... && go test ./... && go vet ./...`
Expected: clean. Also `grep -rn "StyleSubtitle\|StyleActiveTab\|StyleInactiveTab\|ColorRosewater\|ColorCrust" tui/` prints nothing.

```bash
git add tui/internal/app/theme.go tui/internal/app/system.go tui/go.mod tui/go.sum
git commit -m "chore: remove dead theme styles/colors and unused runner field, go mod tidy"
```

### Task 13: CLAUDE.md drift

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Fix the four drift items:**

1. **Tab name** — Architecture → TUI Architecture bullet: `**Tabs:** Status, Configs, Packages (macOS only), Sync, System, Settings` → `**Tabs:** Status, Configs, Homebrew (macOS only), Sync, System, Settings` (the code's literal tab name is "Homebrew", app.go:30).
2. **Go version** — Go Standards: `**Go >= 1.22** required` → `**Go >= 1.24** required` (go.mod says 1.24.2).
3. **Testing section** — replace the brittle counted list under "Current Coverage" with suite descriptions:

```markdown
- **`internal/ansi/`** — table-driven tests for escape stripping (SGR, CSI, OSC)
- **`internal/runner/`** — exec hardening tests (timeout, process-group kill, 1 MB scan buffer, scanner errors)
- **`internal/scheduler/`** — status parsing (ACTIVE/INACTIVE/BROKEN), script path construction
- **`internal/app/`** — pure-helper tests (sync steps, preflight parsing, editor argv, config categories) and direct `Update()` tests for fix sequencing and cursor clamping
- **Scripts** — validated via `shellcheck` static analysis
```

4. **Context Loading table** — add two rows:

```markdown
| Runner/exec behavior | `tui/internal/runner/runner.go` |
| Scheduler status parsing | `tui/internal/scheduler/scheduler.go` and `scripts/schedule.sh` |
```

- [ ] **Step 2: Verify + commit**

Run: `grep -n "Packages\|1.22" CLAUDE.md || echo drift-gone` — expect `drift-gone`.

```bash
git add CLAUDE.md
git commit -m "docs: fix CLAUDE.md drift (Homebrew tab, Go 1.24, testing coverage, context table)"
```

### Task 14: Final verification (controller-driven, on the real machine)

**Files:** none (verification, merge, push)

- [ ] **Step 1: Full suite from the repo root**

Run: `make lint && make test && cd tui && gofmt -l . && cd ..`
Expected: shellcheck + vet + all Go tests green; gofmt silent.

- [ ] **Step 2: Build + version**

Run: `make build && ./tui/dots --version`
Expected: builds; prints the git-describe version.

- [ ] **Step 3: Merge to main, converge, watch CI** (controller): verify main hasn't moved; rebase the worktree branch onto main; `git merge --ff-only`; run `bash scripts/push.sh` (publishes to origin — intended); `gh run watch` the CI run for the merge commit to success.

- [ ] **Step 4: Interactive TUI walkthrough (user)** — present this checklist to the user for a 5-minute manual pass, since the agent cannot drive Bubble Tea:
  - Configs tab: all onboarded configs appear (starship, mise, gh, helix, btop, zed, ccstatusline, gh-dash, qman + home category with .zshrc/.gitconfig); `d` on a deliberately-dirtied plain file shows a real diff; `d` on a clean file says "No differences found."; `e` opens `$EDITOR` on the source file (test with `EDITOR="code --wait"` if available).
  - Sync tab: run a Full Sync; steps advance; quit (`q`) mid-run on a second attempt and verify no orphaned `bash`/`git` processes remain (`pgrep -f sync.sh`).
  - Status tab: shows real ahead/behind, machine line without "(unknown)".
  - Settings: View chezmoi data opens; Scheduled Sync shows OFF (or BROKEN only if the plist is stale).
  - Homebrew: `b` runs bundle; pressing `b` again mid-run does nothing; result box keeps its default gray border on success (red border on failure; a toast fires either way — success or error).

