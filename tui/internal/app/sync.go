package app

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
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

// StreamLineMsg delivers a single line from a running script's stdout.
type StreamLineMsg struct {
	Line string
}

// RunCompleteMsg signals that a sync action has finished.
type RunCompleteMsg struct {
	Action   syncAction
	ExitCode int
	Err      string
	Output   string
}

// HangWarningMsg fires when no output is received for 10 seconds.
type HangWarningMsg struct {
	Seq int
}

type syncHistoryMsg []SyncLogEntry

type syncFocus int

const (
	focusActions syncFocus = iota
	focusHistory
)

// SyncModel is the Bubble Tea model for the sync tab.
type SyncModel struct {
	dotsDir string
	runner  *runner.Runner
	width   int
	height  int

	// Action selection
	selected int
	running  bool
	spinner  spinner.Model

	// Focus
	focus syncFocus

	// Step progress
	steps   []syncStep
	stepIdx int

	// Streaming log
	logLines []string
	lineCh chan string
	doneCh chan RunCompleteMsg
	scroll int // page-level scroll for renderScrollView

	// History
	history       []SyncLogEntry
	historyCursor int
	expanded      map[int]bool
}

// NewSyncModel creates a new SyncModel.
func NewSyncModel(dotsDir string) SyncModel {
	s := spinner.New(spinner.WithSpinner(spinner.Dot))
	s.Style = lipgloss.NewStyle().Foreground(ColorMauve)

	return SyncModel{
		dotsDir:  dotsDir,
		runner:   runner.New(dotsDir),
		spinner:  s,
		expanded: make(map[int]bool),
	}
}

// Init initializes the sync model.
func (m SyncModel) Init() tea.Cmd {
	return m.loadHistory()
}

func (m SyncModel) loadHistory() tea.Cmd {
	return func() tea.Msg {
		entries, _ := parseSyncLog()
		return syncHistoryMsg(entries)
	}
}

// SetSize updates the model dimensions.
func (m *SyncModel) SetSize(w, h int) {
	m.width = w
	m.height = h
}

func (m *SyncModel) initRun(action syncAction) tea.Cmd {
	if m.running {
		return nil
	}
	m.running = true
	m.logLines = nil
	m.scroll = 0
	m.steps = stepsForAction(action)
	m.stepIdx = -1
	m.focus = focusActions

	if len(m.steps) > 0 {
		m.steps[0].status = stepRunning
		m.stepIdx = 0
	}

	lineCh := make(chan string, 64)
	doneCh := make(chan RunCompleteMsg, 1)
	m.lineCh = lineCh
	m.doneCh = doneCh

	var script string
	switch action {
	case syncActionUpdate:
		script = filepath.Join(m.dotsDir, "scripts", "update.sh")
	case syncActionPush:
		script = filepath.Join(m.dotsDir, "scripts", "push.sh")
	case syncActionFull:
		script = filepath.Join(m.dotsDir, "scripts", "sync.sh")
	}

	go func() {
		result := m.runner.RunStream("bash", lineCh, script)
		close(lineCh)
		errStr := ""
		if result.ExitCode != 0 {
			errStr = result.Stderr
		}
		doneCh <- RunCompleteMsg{
			Action:   action,
			ExitCode: result.ExitCode,
			Err:      errStr,
			Output:   result.Stdout,
		}
	}()

	return tea.Batch(m.spinner.Tick, waitForLine(lineCh, doneCh))
}

// waitForLine drains lines first, then reads the completion message.
// No select is used — this guarantees all buffered lines are consumed
// before RunCompleteMsg is returned.
func waitForLine(lines <-chan string, done <-chan RunCompleteMsg) tea.Cmd {
	return func() tea.Msg {
		line, ok := <-lines
		if ok {
			return StreamLineMsg{Line: line}
		}
		return <-done
	}
}

// TriggerAction sets up and runs a sync action from outside the model.
func (m *SyncModel) TriggerAction(action syncAction) tea.Cmd {
	m.selected = int(action)
	return m.initRun(action)
}

// Update handles messages for the sync model.
func (m SyncModel) Update(msg tea.Msg) (SyncModel, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		if m.running {
			switch msg.String() {
			case "ctrl+d":
				m.scroll += m.height / 2
			case "ctrl+u":
				m.scroll -= m.height / 2
				if m.scroll < 0 {
					m.scroll = 0
				}
			}
			return m, nil
		}
		switch msg.String() {
		case "j", "down":
			if m.focus == focusActions {
				if m.selected < len(actionCards)-1 {
					m.selected++
				}
			} else {
				if m.historyCursor < len(m.history)-1 {
					m.historyCursor++
				}
			}
		case "k", "up":
			if m.focus == focusActions {
				if m.selected > 0 {
					m.selected--
				}
			} else {
				if m.historyCursor > 0 {
					m.historyCursor--
				}
			}
		case "enter":
			if m.focus == focusActions {
				return m, m.initRun(syncAction(m.selected))
			}
			if len(m.history) > 0 {
				m.expanded[m.historyCursor] = !m.expanded[m.historyCursor]
			}
		case "f":
			if m.focus == focusActions {
				m.focus = focusHistory
			} else {
				m.focus = focusActions
			}
		case "ctrl+d":
			m.scroll += m.height / 2
		case "ctrl+u":
			m.scroll -= m.height / 2
			if m.scroll < 0 {
				m.scroll = 0
			}
		}
		return m, nil

	case StreamLineMsg:
		m.logLines = append(m.logLines, msg.Line)
		newIdx, advanced := detectStep(msg.Line, m.steps, m.stepIdx)
		if advanced {
			if m.stepIdx >= 0 && m.stepIdx < len(m.steps) {
				m.steps[m.stepIdx].status = stepDone
			}
			if newIdx >= 0 && newIdx < len(m.steps) {
				m.steps[newIdx].status = stepRunning
				m.stepIdx = newIdx
			} else {
				for i := range m.steps {
					if m.steps[i].status != stepDone {
						m.steps[i].status = stepDone
					}
				}
				m.stepIdx = len(m.steps)
			}
		}
		return m, waitForLine(m.lineCh, m.doneCh)

	case RunCompleteMsg:
		m.running = false
		m.focus = focusActions
		if msg.Err != "" {
			m.logLines = append(m.logLines, StyleError.Render("Error: "+msg.Err))
		}
		if msg.ExitCode == 0 {
			for i := range m.steps {
				m.steps[i].status = stepDone
			}
			m.logLines = append(m.logLines, StyleSuccess.Render("Completed successfully."))
		} else {
			for i := range m.steps {
				if m.steps[i].status == stepRunning {
					m.steps[i].status = stepFailed
				}
			}
			m.logLines = append(m.logLines, StyleError.Render(fmt.Sprintf("Exited with code %d", msg.ExitCode)))
		}
		// logLines windowing in renderProgress auto-scrolls to bottom
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

	return m, nil
}

// Action card rendering

type actionCard struct {
	icon string
	name string
	desc string
}

var actionCards = []actionCard{
	{icon: "⟳", name: "Update", desc: "Pull remote changes + apply configs"},
	{icon: "⬆", name: "Push", desc: "Capture + commit + push local edits"},
	{icon: "⇅", name: "Full Sync", desc: "Push local, then pull remote"},
}

func (m SyncModel) renderActions() string {
	var b strings.Builder

	titleStyle := StyleTitle
	if m.focus != focusActions {
		titleStyle = StyleDimmed
	}
	b.WriteString(titleStyle.Render("  Actions") + "\n\n")

	for i, card := range actionCards {
		selected := i == m.selected
		isRunning := m.running && i == m.selected

		var icon string
		if isRunning {
			icon = m.spinner.View()
		} else {
			icon = card.icon
		}

		nameStyle := lipgloss.NewStyle().Foreground(ColorOverlay1)
		if selected && m.focus == focusActions {
			nameStyle = lipgloss.NewStyle().Foreground(ColorMauve).Bold(true)
		}

		descStyle := StyleDimmed

		indicator := "  "
		if selected && m.focus == focusActions {
			indicator = StyleKey.Render("▸ ")
		}

		b.WriteString(indicator + icon + " " + nameStyle.Render(card.name) + "\n")
		b.WriteString("    " + descStyle.Render(card.desc) + "\n")
		if i < len(actionCards)-1 {
			b.WriteString("\n")
		}
	}

	return b.String()
}

// Progress pane rendering

func (m SyncModel) renderProgress() string {
	var b strings.Builder

	b.WriteString(StyleTitle.Render("  Progress") + "\n\n")

	if len(m.steps) > 0 {
		var stepParts []string
		for _, step := range m.steps {
			var icon string
			var style lipgloss.Style
			switch step.status {
			case stepPending:
				icon = "·"
				style = lipgloss.NewStyle().Foreground(ColorOverlay0)
			case stepRunning:
				icon = m.spinner.View()
				style = lipgloss.NewStyle().Foreground(ColorMauve)
			case stepDone:
				icon = "✓"
				style = lipgloss.NewStyle().Foreground(ColorGreen)
			case stepFailed:
				icon = "✗"
				style = lipgloss.NewStyle().Foreground(ColorRed)
			}
			stepParts = append(stepParts, icon+" "+style.Render(step.label))
		}
		b.WriteString("  " + strings.Join(stepParts, "   ") + "\n")
		b.WriteString("  " + lipgloss.NewStyle().Foreground(ColorSurface2).Render(
			strings.Repeat("─", 30)) + "\n")
	}

	if len(m.logLines) > 0 {
		maxLogLines := m.height / 3
		if maxLogLines < 5 {
			maxLogLines = 5
		}
		start := 0
		if len(m.logLines) > maxLogLines {
			start = len(m.logLines) - maxLogLines
		}
		for _, line := range m.logLines[start:] {
			b.WriteString("  " + line + "\n")
		}
	} else if !m.running {
		b.WriteString(StyleDimmed.Render("  No output yet. Select an action and press enter.") + "\n")
	}

	return b.String()
}

// History rendering

func (m SyncModel) renderHistory() string {
	var b strings.Builder

	titleStyle := StyleTitle
	if m.focus != focusHistory {
		titleStyle = StyleDimmed
	}

	count := len(m.history)
	if count > 50 {
		count = 50
	}
	b.WriteString(titleStyle.Render(fmt.Sprintf("  History (%d)", count)) + "\n")

	if len(m.history) == 0 {
		b.WriteString(StyleDimmed.Render("  No sync history.") + "\n")
		return b.String()
	}

	start := 0
	if len(m.history) > 50 {
		start = len(m.history) - 50
	}
	entries := m.history[start:]

	for i := len(entries) - 1; i >= 0; i-- {
		entry := entries[i]
		globalIdx := start + i

		resultStyle := StyleSuccess
		resultIcon := "✓"
		if entry.Result != "success" {
			resultStyle = StyleError
			resultIcon = "✗"
		}

		indicator := "  "
		if m.focus == focusHistory && m.historyCursor == len(entries)-1-i {
			indicator = StyleKey.Render("▸ ")
		}

		expandIcon := "▸"
		if m.expanded[globalIdx] {
			expandIcon = "▾"
		}

		b.WriteString(fmt.Sprintf("%s%s %s  %-8s  %s %s  %s\n",
			indicator,
			StyleDimmed.Render(expandIcon),
			StyleDimmed.Render(entry.Timestamp),
			entry.Action,
			resultStyle.Render(resultIcon),
			resultStyle.Render(entry.Result),
			StyleDimmed.Render(fmt.Sprintf("%dms", entry.DurationMs)),
		))

		if m.expanded[globalIdx] {
			details := entry.Details
			if details == "" {
				details = "No additional details."
			}
			b.WriteString("    " + StyleDimmed.Render(details) + "\n")
		}
	}

	return b.String()
}

// View renders the sync tab.
func (m SyncModel) View() string {
	return renderScrollView(m.renderContent(), &m.scroll, m.width, m.height, [][2]string{
		{"j/k", "select"},
		{"enter", "run/expand"},
		{"f", "focus"},
		{"ctrl+d/u", "scroll"},
		{"tab", "tabs"},
		{"y", "copy"},
		{"q", "quit"},
	})
}

func (m SyncModel) renderContent() string {
	if m.width >= 80 {
		return m.renderWideLayout()
	}
	return m.renderNarrowLayout()
}

func (m SyncModel) renderWideLayout() string {
	var b strings.Builder

	actionsWidth := m.width * 30 / 100
	if actionsWidth < 25 {
		actionsWidth = 25
	}
	progressWidth := m.width - actionsWidth - 3

	actionsStyle := lipgloss.NewStyle().Width(actionsWidth)
	progressStyle := lipgloss.NewStyle().Width(progressWidth)

	topRow := lipgloss.JoinHorizontal(lipgloss.Top,
		actionsStyle.Render(m.renderActions()),
		"   ",
		progressStyle.Render(m.renderProgress()),
	)
	b.WriteString(topRow)
	b.WriteString("\n")

	b.WriteString("  " + lipgloss.NewStyle().Foreground(ColorSurface2).Render(
		strings.Repeat("─", m.width-4)) + "\n")

	b.WriteString(m.renderHistory())
	b.WriteString("\n")

	return b.String()
}

func (m SyncModel) renderNarrowLayout() string {
	var b strings.Builder

	b.WriteString(m.renderActions())
	b.WriteString("\n")
	b.WriteString(m.renderProgress())
	b.WriteString("\n")
	b.WriteString(m.renderHistory())
	b.WriteString("\n")

	return b.String()
}
