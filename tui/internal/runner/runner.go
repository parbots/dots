package runner

import (
	"bufio"
	"bytes"
	"context"
	"os/exec"
	"time"
)

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

// Run executes a command synchronously and returns the result.
func (r *Runner) Run(name string, args ...string) RunResult {
	start := time.Now()

	cmd := exec.Command(name, args...)
	cmd.Dir = r.DotsDir

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
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
		Stdout:   stdout.String(),
		Stderr:   stderr.String(),
		ExitCode: exitCode,
		Duration: duration,
	}
}

// RunStream executes a command and sends stdout lines to the provided channel.
// The caller is responsible for closing the channel after RunStream returns.
func (r *Runner) RunStream(name string, lines chan<- string, args ...string) RunResult {
	start := time.Now()

	cmd := exec.Command(name, args...)
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
