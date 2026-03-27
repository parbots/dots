package runner_test

import (
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
	if result.Duration < 0 {
		t.Errorf("expected non-negative duration, got %v", result.Duration)
	}
}

func TestRunFailure(t *testing.T) {
	r := runner.New(t.TempDir())
	result := r.Run("false")

	if result.ExitCode == 0 {
		t.Error("expected non-zero exit code")
	}
}

func TestRunStream(t *testing.T) {
	r := runner.New(t.TempDir())
	lines := make(chan string, 10)

	go func() {
		r.RunStream("echo", lines, "line1")
		close(lines)
	}()

	var received []string
	timeout := time.After(5 * time.Second)
	for {
		select {
		case line, ok := <-lines:
			if !ok {
				goto done
			}
			received = append(received, line)
		case <-timeout:
			t.Fatal("timeout waiting for stream output")
		}
	}
done:

	if len(received) == 0 {
		t.Error("expected at least one line of output")
	}
}
