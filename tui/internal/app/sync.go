package app

import (
	"fmt"
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
	scroll   int
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
		case "ctrl+d":
			m.scroll += m.height / 2
			return m, nil
		case "ctrl+u":
			m.scroll -= m.height / 2
			if m.scroll < 0 {
				m.scroll = 0
			}
			return m, nil
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
	return renderScrollView(m.renderContent(), &m.scroll, m.width, m.height, [][2]string{
		{"h/l", "select"},
		{"enter", "run"},
		{"ctrl+d/u", "scroll"},
		{"tab", "tabs"},
		{"y", "copy"},
		{"q", "quit"},
	})
}

func (m SyncModel) renderContent() string {
	var b strings.Builder

	b.WriteString(StyleTitle.Render("  Sync Actions") + "\n\n")

	// Buttons (rendered horizontally)
	labels := []string{"  Update", "  Push", "  Full Sync"}
	var buttons []string
	for i, label := range labels {
		if i == m.selected {
			style := lipgloss.NewStyle().
				Foreground(ColorBase).
				Background(ColorMauve).
				Bold(true).
				Padding(0, 2)
			buttons = append(buttons, style.Render(label))
		} else {
			style := lipgloss.NewStyle().
				Foreground(ColorOverlay1).
				Padding(0, 2)
			buttons = append(buttons, style.Render(label))
		}
	}
	b.WriteString("  " + lipgloss.JoinHorizontal(lipgloss.Center, buttons...) + "\n\n")

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

	return b.String()
}

// SetSize updates the model dimensions.
func (m *SyncModel) SetSize(w, h int) {
	m.width = w
	m.height = h
	m.output.Width = w
	m.output.Height = h / 3
}

// TriggerAction sets up and runs a sync action from outside the model.
func (m *SyncModel) TriggerAction(action syncAction) tea.Cmd {
	m.selected = int(action)
	m.running = true
	m.lines = nil
	m.output.SetContent("")
	return tea.Batch(m.spinner.Tick, m.runScript(action))
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
		entries, _ := parseSyncLog()
		return syncHistoryMsg(entries)
	}
}
