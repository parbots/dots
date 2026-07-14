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
