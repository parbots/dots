package scheduler

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/parbots/dots/internal/runner"
)

// Status represents the current state of the scheduled sync.
type Status struct {
	Active   bool
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
	return ParseStatus(result.Stdout)
}

// ParseStatus parses the output of schedule.sh status into a Status struct.
func ParseStatus(output string) Status {
	status := Status{Raw: output}

	clean := stripANSI(output)

	if strings.Contains(clean, "ACTIVE") && !strings.Contains(clean, "INACTIVE") {
		status.Active = true
		if strings.Contains(clean, "launchd") {
			status.Backend = "launchd"
		} else if strings.Contains(clean, "systemd") {
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

func stripANSI(s string) string {
	var result strings.Builder
	i := 0
	for i < len(s) {
		if s[i] == '\033' {
			for i < len(s) && s[i] != 'm' {
				i++
			}
			i++
		} else {
			result.WriteByte(s[i])
			i++
		}
	}
	return result.String()
}
