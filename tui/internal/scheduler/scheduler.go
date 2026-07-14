package scheduler

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/parbots/dots/internal/ansi"
	"github.com/parbots/dots/internal/runner"
)

// Status represents the current state of the scheduled sync.
type Status struct {
	Active   bool
	Broken   bool   // schedule.sh reported a broken installation (e.g. baked script path missing)
	Backend  string // "launchd", "systemd", or ""
	LastSync string // last line from sync log, if available
	Raw      string // full output from schedule.sh status
}

// Scheduler manages scheduled sync via scripts/schedule.sh.
type Scheduler struct {
	dotsDir string
	runner  *runner.Runner
}

// New creates a Scheduler for the given dots directory.
func New(dotsDir string) *Scheduler {
	return &Scheduler{
		dotsDir: dotsDir,
		runner:  runner.New(dotsDir),
	}
}

// ScriptPath returns the path to schedule.sh.
func (s *Scheduler) ScriptPath() string {
	return filepath.Join(s.dotsDir, "scripts", "schedule.sh")
}

// Enable enables scheduled sync with the given interval (e.g., "30m", "3600").
func (s *Scheduler) Enable(interval string) error {
	args := []string{s.ScriptPath(), "enable"}
	if interval != "" {
		args = append(args, interval)
	}
	result := s.runner.Run("bash", args...)
	if result.ExitCode != 0 {
		return fmt.Errorf("schedule enable failed: %s", result.Stderr)
	}
	return nil
}

// Disable disables scheduled sync.
func (s *Scheduler) Disable() error {
	result := s.runner.Run("bash", s.ScriptPath(), "disable")
	if result.ExitCode != 0 {
		return fmt.Errorf("schedule disable failed: %s", result.Stderr)
	}
	return nil
}

// GetStatus returns the current scheduler status.
func (s *Scheduler) GetStatus() Status {
	result := s.runner.Run("bash", s.ScriptPath(), "status")
	combined := result.Stdout + "\n" + result.Stderr
	if result.ExitCode != 0 {
		return Status{Broken: true, Raw: combined}
	}
	return ParseStatus(combined)
}

// ParseStatus parses the output of schedule.sh status into a Status struct.
func ParseStatus(output string) Status {
	status := Status{Raw: output}

	clean := ansi.Strip(output)

	// Scope state detection to the "Scheduled sync:" line so text in the
	// trailing sync-log JSON (arbitrary details) can never masquerade as a
	// scheduler state.
	statusLine := clean
	for _, line := range strings.Split(clean, "\n") {
		if strings.HasPrefix(strings.TrimSpace(line), "Scheduled sync:") {
			statusLine = line
			break
		}
	}

	if strings.Contains(statusLine, "BROKEN") {
		status.Broken = true
	}

	if !status.Broken && strings.Contains(statusLine, "ACTIVE") && !strings.Contains(statusLine, "INACTIVE") {
		status.Active = true
		if strings.Contains(statusLine, "launchd") {
			status.Backend = "launchd"
		} else if strings.Contains(statusLine, "systemd") {
			status.Backend = "systemd"
		}
	}

	lines := strings.Split(strings.TrimSpace(clean), "\n")
	for i := len(lines) - 1; i >= 0; i-- {
		if strings.HasPrefix(lines[i], "{") {
			status.LastSync = lines[i]
			break
		}
	}

	return status
}
