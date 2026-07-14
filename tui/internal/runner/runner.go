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
