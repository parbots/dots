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
	severityAsk preflightSeverity = iota
	severityWarn
)

// PreflightIssue represents a problem detected before running a sync action.
type PreflightIssue struct {
	Message  string
	Severity preflightSeverity
	FixCmd   func() tea.Cmd // for ask-severity: returns a cmd to execute the fix
}

// PreflightResultMsg carries the results of async pre-flight checks.
type PreflightResultMsg struct {
	Issues []PreflightIssue
	Action syncAction
}

// FixCompleteMsg reports that one preflight fix finished. The sync model
// chains on it: next queued fix, or start the pending script.
type FixCompleteMsg struct {
	Toast ToastMsg
}

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

// runPreflightChecks runs all pre-flight checks for the given action.
func runPreflightChecks(dotsDir string, action syncAction) []PreflightIssue {
	var issues []PreflightIssue

	if issue := checkChezmoiLock(); issue != nil {
		issues = append(issues, *issue)
	}

	// Check for chezmoi conflicts before update/full sync (which run chezmoi apply)
	if action == syncActionUpdate || action == syncActionFull {
		issues = append(issues, checkChezmoiConflicts(dotsDir)...)
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

// checkChezmoiConflicts detects files that have been modified locally since
// chezmoi last wrote them. These would cause interactive prompts (hanging the TUI)
// if not handled. Returns one issue per conflicted file with re-add as the fix.
func checkChezmoiConflicts(dotsDir string) []PreflightIssue {
	cmd := exec.Command("chezmoi", "status")
	out, err := cmd.Output()
	if err != nil {
		return nil
	}

	var issues []PreflightIssue
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		line = strings.TrimSpace(line)
		if len(line) < 3 {
			continue
		}
		// chezmoi status: two status chars + space + target path relative to ~.
		// A non-space first char means the file changed on disk since last apply.
		if !isLocallyModifiedStatus(line) {
			continue
		}
		path := strings.TrimSpace(line[2:])

		if line[0] == 'D' {
			// A local deletion can't be captured by re-add, and apply
			// --force would silently recreate the file. Be honest: warn,
			// and leave the decision to the user.
			issues = append(issues, PreflightIssue{
				Message:  fmt.Sprintf("Locally deleted: ~/%s — apply will restore it (use 'chezmoi forget' to keep the deletion)", path),
				Severity: severityWarn,
			})
			continue
		}

		filePath := path // capture for closure
		issues = append(issues, PreflightIssue{
			Message:  fmt.Sprintf("Local edit: ~/%s — press x to re-add (keep local)", filePath),
			Severity: severityAsk,
			FixCmd: func() tea.Cmd {
				return func() tea.Msg {
					readdCmd := exec.Command("chezmoi", "re-add", filePath)
					if err := readdCmd.Run(); err != nil {
						return FixCompleteMsg{Toast: ToastMsg{
							Message: fmt.Sprintf("Failed to re-add %s: %s", filePath, err),
							Level:   ToastError,
						}}
					}
					return FixCompleteMsg{Toast: ToastMsg{
						Message: fmt.Sprintf("Re-added ~/%s (local version kept)", filePath),
						Level:   ToastSuccess,
					}}
				}
			},
		})
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
		startTime, err := parseProcessStart(string(lstart), time.Local)
		if err != nil {
			continue
		}
		seconds := int(time.Since(startTime).Seconds())

		return &PreflightIssue{
			Message:  fmt.Sprintf("Chezmoi is running (PID %d, started %ds ago) — press x to kill", pid, seconds),
			Severity: severityAsk,
			FixCmd: func() tea.Cmd {
				return func() tea.Msg {
					syscall.Kill(pid, syscall.SIGTERM)
					time.Sleep(500 * time.Millisecond)
					return FixCompleteMsg{Toast: ToastMsg{Message: fmt.Sprintf("Killed chezmoi (PID %d)", pid), Level: ToastSuccess}}
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
					return FixCompleteMsg{Toast: ToastMsg{Message: "Editor error: " + err.Error(), Level: ToastError}}
				}
				return FixCompleteMsg{Toast: ToastMsg{Message: "Editor closed", Level: ToastSuccess}}
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
