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
	Message  string
	Severity preflightSeverity
	FixCmd   func() tea.Cmd // for ask-severity: returns a cmd to execute the fix
	AutoFix  func() error   // for autofix-severity: runs synchronously
}

// PreflightResultMsg carries the results of async pre-flight checks.
type PreflightResultMsg struct {
	Issues []PreflightIssue
	Action syncAction
}

// runPreflightChecks runs all pre-flight checks for the given action.
func runPreflightChecks(dotsDir string, action syncAction) []PreflightIssue {
	var issues []PreflightIssue

	if issue := checkChezmoiLock(); issue != nil {
		issues = append(issues, *issue)
	}

	if issue := checkGitConflicts(dotsDir); issue != nil {
		issues = append(issues, *issue)
	}

	if action == syncActionUpdate {
		if issue := checkDirtyTree(dotsDir); issue != nil {
			issues = append(issues, *issue)
		}
	}

	if issue := checkRemoteReachable(dotsDir); issue != nil {
		issues = append(issues, *issue)
	}

	return issues
}

func checkChezmoiLock() *PreflightIssue {
	out, err := exec.Command("pgrep", "-x", "chezmoi").Output()
	if err != nil {
		return nil
	}

	myPid := os.Getpid()
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		pid, err := strconv.Atoi(strings.TrimSpace(line))
		if err != nil || pid == myPid {
			continue
		}

		// Check how long the process has been running
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
			return &PreflightIssue{
				Message:  fmt.Sprintf("Stale chezmoi process (PID %d, running %ds) — killing", pid, seconds),
				Severity: severityAutofix,
				AutoFix: func() error {
					return syscall.Kill(pid, syscall.SIGTERM)
				},
			}
		}

		return &PreflightIssue{
			Message:  fmt.Sprintf("Chezmoi is running (PID %d, started %ds ago) — press x to kill", pid, seconds),
			Severity: severityAsk,
			FixCmd: func() tea.Cmd {
				return func() tea.Msg {
					syscall.Kill(pid, syscall.SIGTERM)
					time.Sleep(500 * time.Millisecond)
					return ToastMsg{Message: fmt.Sprintf("Killed chezmoi (PID %d)", pid), Level: ToastSuccess}
				}
			},
		}
	}

	return nil
}

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
			c := exec.Command(editor, files...)
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
