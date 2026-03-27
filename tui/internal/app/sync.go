package app

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/parbots/dots/internal/runner"
)

type syncAction int

const (
	syncActionUpdate syncAction = iota
	syncActionPush
	syncActionFull
)

// OutputLineMsg carries a single line of streaming output.
type OutputLineMsg struct {
	Line string
}

// RunCompleteMsg signals that a sync action has finished.
type RunCompleteMsg struct {
	Action   syncAction
	ExitCode int
	Err      string
	Output   string
}

type syncHistoryMsg []SyncLogEntry

// SyncModel is the Bubble Tea model for the sync tab.
type SyncModel struct {
	dotsDir  string
	runner   *runner.Runner
	selected int
	running  bool
	spinner  spinner.Model
	output   viewport.Model
	lines    []string
	history  []SyncLogEntry
	width    int
	height   int
}

// NewSyncModel creates a new SyncModel.
func NewSyncModel(dotsDir string) SyncModel {
	s := spinner.New(spinner.WithSpinner(spinner.Dot))
	s.Style = lipgloss.NewStyle().Foreground(ColorMauve)

	vp := viewport.New(0, 0)

	return SyncModel{
		dotsDir: dotsDir,
		runner:  runner.New(dotsDir),
		spinner: s,
		output:  vp,
	}
}

// Init initializes the sync model.
func (m SyncModel) Init() tea.Cmd {
	return m.loadHistory()
}

// Update handles messages for the sync model.
func (m SyncModel) Update(msg tea.Msg) (SyncModel, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		if m.running {
			return m, nil
		}
		switch msg.String() {
		case "h", "left":
			if m.selected > 0 {
				m.selected--
			}
		case "l", "right":
			if m.selected < 2 {
				m.selected++
			}
		case "enter":
			m.running = true
			m.lines = nil
			m.output.SetContent("")
			action := syncAction(m.selected)
			return m, tea.Batch(m.spinner.Tick, m.runScript(action))
		}

	case RunCompleteMsg:
		m.running = false
		if msg.Output != "" {
			m.lines = strings.Split(strings.TrimRight(msg.Output, "\n"), "\n")
		}
		content := strings.Join(m.lines, "\n")
		if msg.Err != "" {
			content += "\n" + StyleError.Render("Error: "+msg.Err)
		}
		if msg.ExitCode == 0 {
			content += "\n" + StyleSuccess.Render("Completed successfully.")
		} else {
			content += "\n" + StyleError.Render(fmt.Sprintf("Exited with code %d", msg.ExitCode))
		}
		m.output.SetContent(content)
		m.output.GotoBottom()
		return m, m.loadHistory()

	case syncHistoryMsg:
		m.history = []SyncLogEntry(msg)
		return m, nil

	case spinner.TickMsg:
		if m.running {
			var cmd tea.Cmd
			m.spinner, cmd = m.spinner.Update(msg)
			return m, cmd
		}
	}

	// Forward viewport messages
	var cmd tea.Cmd
	m.output, cmd = m.output.Update(msg)
	return m, cmd
}

// View renders the sync tab.
func (m SyncModel) View() string {
	var b strings.Builder

	b.WriteString(StyleTitle.Render("  Sync Actions") + "\n\n")

	// Buttons
	labels := []string{"  Update", "  Push", "  Full Sync"}
	for i, label := range labels {
		style := lipgloss.NewStyle().
			Padding(0, 2).
			Border(lipgloss.RoundedBorder())
		if i == m.selected {
			style = style.
				Foreground(ColorMauve).
				BorderForeground(ColorMauve).
				Bold(true)
		} else {
			style = style.
				Foreground(ColorOverlay1).
				BorderForeground(ColorSurface2)
		}
		b.WriteString(style.Render(label))
		if i < len(labels)-1 {
			b.WriteString("  ")
		}
	}
	b.WriteString("\n\n")

	// Running indicator
	if m.running {
		b.WriteString("  " + m.spinner.View() + " Running...\n\n")
	}

	// Output viewport
	if len(m.lines) > 0 || m.output.TotalLineCount() > 0 {
		b.WriteString(StyleTitle.Render("  Output") + "\n")
		b.WriteString(m.output.View())
		b.WriteString("\n\n")
	}

	// History
	b.WriteString(StyleTitle.Render("  History") + "\n")
	if len(m.history) == 0 {
		b.WriteString(StyleDimmed.Render("  No sync history.") + "\n")
	} else {
		start := 0
		if len(m.history) > 8 {
			start = len(m.history) - 8
		}
		for _, entry := range m.history[start:] {
			resultStyle := StyleSuccess
			if entry.Result != "success" {
				resultStyle = StyleError
			}
			b.WriteString(fmt.Sprintf("  %s  %-8s  %s  %s\n",
				StyleDimmed.Render(entry.Timestamp),
				entry.Action,
				resultStyle.Render(entry.Result),
				StyleDimmed.Render(fmt.Sprintf("%dms", entry.DurationMs)),
			))
		}
	}
	b.WriteString("\n")

	b.WriteString(StyleHelp.Render(fmt.Sprintf("  %s select  %s run",
		StyleKey.Render("h/l"), StyleKey.Render("enter"))))

	return b.String()
}

// SetSize updates the model dimensions.
func (m *SyncModel) SetSize(w, h int) {
	m.width = w
	m.height = h
	m.output.Width = w
	m.output.Height = h / 3
}

func (m SyncModel) runScript(action syncAction) tea.Cmd {
	return func() tea.Msg {
		var script string
		switch action {
		case syncActionUpdate:
			script = filepath.Join(m.dotsDir, "scripts", "update.sh")
		case syncActionPush:
			script = filepath.Join(m.dotsDir, "scripts", "push.sh")
		case syncActionFull:
			script = filepath.Join(m.dotsDir, "scripts", "sync.sh")
		}

		result := m.runner.Run("bash", script)
		errStr := ""
		if result.ExitCode != 0 {
			errStr = result.Stderr
		}
		return RunCompleteMsg{
			Action:   action,
			ExitCode: result.ExitCode,
			Err:      errStr,
			Output:   result.Stdout,
		}
	}
}

func (m SyncModel) loadHistory() tea.Cmd {
	return func() tea.Msg {
		home, err := os.UserHomeDir()
		if err != nil {
			return syncHistoryMsg(nil)
		}
		logPath := filepath.Join(home, ".local", "state", "dots", "sync.log")
		data, err := os.ReadFile(logPath)
		if err != nil {
			return syncHistoryMsg(nil)
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
		return syncHistoryMsg(entries)
	}
}
