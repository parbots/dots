package app

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/parbots/dots/internal/runner"
)

// SyncLogEntry represents a single entry in the sync log.
type SyncLogEntry struct {
	Timestamp  string `json:"timestamp"`
	Action     string `json:"action"`
	Result     string `json:"result"`
	DurationMs int    `json:"duration_ms"`
	Details    string `json:"details"`
}

// GitStatus holds the current git sync state.
type GitStatus struct {
	Ahead      int
	Behind     int
	Dirty      int
	DirtyFiles []string
}

// QuickActionMsg is sent when the user triggers a quick action.
type QuickActionMsg struct {
	Action string
}

type gitStatusMsg struct {
	status GitStatus
}

type syncLogMsg struct {
	entries []SyncLogEntry
}

// StatusModel is the Bubble Tea model for the status tab.
type StatusModel struct {
	dotsDir     string
	gitStatus   GitStatus
	logEntries  []SyncLogEntry
	machineType string
	osName      string
	arch        string
	spinner     spinner.Model
	loading     bool
	expanded    bool
	width       int
	height      int
}

// NewStatusModel creates a new StatusModel.
func NewStatusModel(dotsDir string) StatusModel {
	s := spinner.New(spinner.WithSpinner(spinner.Dot))
	s.Style = lipgloss.NewStyle().Foreground(ColorMauve)

	osName := runtime.GOOS
	if osName == "darwin" {
		osName = "macOS"
	} else if osName == "linux" {
		osName = "Linux"
	}

	// Read machine type from chezmoi data
	machineType := "unknown"
	r := runner.New(dotsDir)
	result := r.Run("chezmoi", "data", "--format=json")
	if result.ExitCode == 0 {
		var data map[string]interface{}
		if err := json.Unmarshal([]byte(result.Stdout), &data); err == nil {
			if mt, ok := data["machine_type"].(string); ok {
				machineType = mt
			}
		}
	}

	return StatusModel{
		dotsDir:     dotsDir,
		spinner:     s,
		loading:     true,
		machineType: machineType,
		osName:      osName,
		arch:        runtime.GOARCH,
	}
}

// Init initializes the status model.
func (m StatusModel) Init() tea.Cmd {
	return tea.Batch(
		m.spinner.Tick,
		m.fetchGitStatus(),
		m.fetchSyncLog(),
	)
}

// Update handles messages for the status model.
func (m StatusModel) Update(msg tea.Msg) (StatusModel, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "u":
			return m, func() tea.Msg { return QuickActionMsg{Action: "update"} }
		case "p":
			return m, func() tea.Msg { return QuickActionMsg{Action: "push"} }
		case "s":
			return m, func() tea.Msg { return QuickActionMsg{Action: "sync"} }
		case "enter":
			m.expanded = !m.expanded
			return m, nil
		}

	case gitStatusMsg:
		m.gitStatus = msg.status
		m.loading = false
		return m, nil

	case syncLogMsg:
		m.logEntries = msg.entries
		return m, nil

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return m, cmd
	}

	return m, nil
}

// View renders the status tab.
func (m StatusModel) View() string {
	if m.loading {
		return m.spinner.View() + " Loading status..."
	}

	var b strings.Builder

	// Sync status
	statusDot := StyleStatusDot.Foreground(ColorGreen).Render("●")
	statusText := "In sync"
	if m.gitStatus.Ahead > 0 || m.gitStatus.Behind > 0 || m.gitStatus.Dirty > 0 {
		statusDot = StyleStatusDot.Foreground(ColorYellow).Render("●")
		statusText = "Changes pending"
	}
	b.WriteString(StyleTitle.Render("  Sync Status") + "\n")
	b.WriteString(fmt.Sprintf("  %s %s", statusDot, statusText) + "\n")

	if m.gitStatus.Ahead > 0 {
		b.WriteString(fmt.Sprintf("    %s ahead of remote\n", StyleWarning.Render(fmt.Sprintf("%d", m.gitStatus.Ahead))))
	}
	if m.gitStatus.Behind > 0 {
		b.WriteString(fmt.Sprintf("    %s behind remote\n", StyleWarning.Render(fmt.Sprintf("%d", m.gitStatus.Behind))))
	}

	// Last sync
	if len(m.logEntries) > 0 {
		last := m.logEntries[len(m.logEntries)-1]
		t, err := time.Parse(time.RFC3339, last.Timestamp)
		rel := last.Timestamp
		if err == nil {
			rel = relativeTime(t)
		}
		b.WriteString(fmt.Sprintf("  Last sync: %s (%s)\n", rel, last.Result))
	}
	b.WriteString("\n")

	// Machine identity
	b.WriteString(StyleTitle.Render("  Machine") + "\n")
	b.WriteString(fmt.Sprintf("  %s %s (%s)", m.osName, m.arch, m.machineType) + "\n\n")

	// Uncommitted files
	b.WriteString(StyleTitle.Render("  Uncommitted Changes") + "\n")
	if m.gitStatus.Dirty == 0 {
		b.WriteString(StyleSuccess.Render("  Working tree clean") + "\n")
	} else {
		b.WriteString(StyleWarning.Render(fmt.Sprintf("  %d uncommitted file(s)", m.gitStatus.Dirty)) + "\n")
		if m.expanded {
			for _, f := range m.gitStatus.DirtyFiles {
				b.WriteString(StyleDimmed.Render("    "+f) + "\n")
			}
		} else if m.gitStatus.Dirty > 0 {
			b.WriteString(StyleDimmed.Render("  Press enter to expand") + "\n")
		}
	}
	b.WriteString("\n")

	// Recent activity
	b.WriteString(StyleTitle.Render("  Recent Activity") + "\n")
	if len(m.logEntries) == 0 {
		b.WriteString(StyleDimmed.Render("  No recent activity") + "\n")
	} else {
		start := 0
		if len(m.logEntries) > 5 {
			start = len(m.logEntries) - 5
		}
		for _, entry := range m.logEntries[start:] {
			resultStyle := StyleSuccess
			if entry.Result != "success" {
				resultStyle = StyleError
			}
			b.WriteString(fmt.Sprintf("  %s %s %s\n",
				StyleDimmed.Render(entry.Timestamp),
				entry.Action,
				resultStyle.Render(entry.Result),
			))
		}
	}
	b.WriteString("\n")

	// Quick actions
	b.WriteString(StyleHelp.Render(fmt.Sprintf("  %s update  %s push  %s sync",
		StyleKey.Render("u"), StyleKey.Render("p"), StyleKey.Render("s"))))

	return b.String()
}

// SetSize updates the model dimensions.
func (m *StatusModel) SetSize(w, h int) {
	m.width = w
	m.height = h
}

func (m StatusModel) fetchGitStatus() tea.Cmd {
	return func() tea.Msg {
		r := runner.New(m.dotsDir)
		gs := GitStatus{}

		// Ahead/behind
		result := r.Run("git", "rev-list", "--left-right", "--count", "HEAD...@{upstream}")
		if result.ExitCode == 0 {
			parts := strings.Fields(strings.TrimSpace(result.Stdout))
			if len(parts) == 2 {
				fmt.Sscanf(parts[0], "%d", &gs.Ahead)
				fmt.Sscanf(parts[1], "%d", &gs.Behind)
			}
		}

		// Dirty files
		result = r.Run("git", "status", "--porcelain")
		if result.ExitCode == 0 {
			lines := strings.Split(strings.TrimSpace(result.Stdout), "\n")
			for _, line := range lines {
				line = strings.TrimSpace(line)
				if line != "" {
					gs.DirtyFiles = append(gs.DirtyFiles, line)
				}
			}
			gs.Dirty = len(gs.DirtyFiles)
		}

		return gitStatusMsg{status: gs}
	}
}

func (m StatusModel) fetchSyncLog() tea.Cmd {
	return func() tea.Msg {
		home, err := os.UserHomeDir()
		if err != nil {
			return syncLogMsg{}
		}
		logPath := filepath.Join(home, ".local", "state", "dots", "sync.log")
		data, err := os.ReadFile(logPath)
		if err != nil {
			return syncLogMsg{}
		}

		var entries []SyncLogEntry
		for _, line := range strings.Split(strings.TrimSpace(string(data)), "\n") {
			line = strings.TrimSpace(line)
			if line == "" {
				continue
			}
			var entry SyncLogEntry
			if err := json.Unmarshal([]byte(line), &entry); err == nil {
				entries = append(entries, entry)
			}
		}
		return syncLogMsg{entries: entries}
	}
}

func relativeTime(t time.Time) string {
	d := time.Since(t)
	switch {
	case d < time.Minute:
		return "just now"
	case d < time.Hour:
		m := int(d.Minutes())
		if m == 1 {
			return "1 minute ago"
		}
		return fmt.Sprintf("%d minutes ago", m)
	case d < 24*time.Hour:
		h := int(d.Hours())
		if h == 1 {
			return "1 hour ago"
		}
		return fmt.Sprintf("%d hours ago", h)
	default:
		days := int(d.Hours() / 24)
		if days == 1 {
			return "1 day ago"
		}
		return fmt.Sprintf("%d days ago", days)
	}
}
