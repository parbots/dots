package app

import (
	"fmt"
	"os/exec"
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/parbots/dots/internal/runner"
	"github.com/parbots/dots/internal/scheduler"
)

type settingsItem int

const (
	settingSyncToggle settingsItem = iota
	settingSyncInterval
	settingViewData
	settingEditConfig
	settingReinit
)

type scheduleActionDoneMsg struct {
	err error
}

type settingsEditorDoneMsg struct {
	err error
}

type chezmoiDataMsg struct {
	data string
}

// SettingsModel is the Bubble Tea model for the settings tab.
type SettingsModel struct {
	dotsDir      string
	runner       *runner.Runner
	scheduler    *scheduler.Scheduler
	syncActive   bool
	syncBackend  string
	syncInterval string
	cursor       int
	spinner      spinner.Model
	processing   bool
	message      string
	intervals    []string
	intervalIdx  int
	width        int
	height       int
}

// NewSettingsModel creates a new SettingsModel.
func NewSettingsModel(dotsDir string) SettingsModel {
	s := spinner.New(spinner.WithSpinner(spinner.Dot))
	s.Style = lipgloss.NewStyle().Foreground(ColorMauve)

	return SettingsModel{
		dotsDir:   dotsDir,
		runner:    runner.New(dotsDir),
		scheduler: scheduler.New(dotsDir),
		spinner:   s,
		intervals: []string{"15m", "30m", "1h", "2h"},
	}
}

// Init initializes the settings model.
func (m SettingsModel) Init() tea.Cmd {
	return m.refreshStatus()
}

// Update handles messages for the settings model.
func (m SettingsModel) Update(msg tea.Msg) (SettingsModel, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		if m.processing {
			return m, nil
		}
		switch msg.String() {
		case "j", "down":
			if m.cursor < int(settingReinit) {
				m.cursor++
			}
		case "k", "up":
			if m.cursor > 0 {
				m.cursor--
			}
		case "enter":
			return m.handleAction()
		}

	case scheduleActionDoneMsg:
		m.processing = false
		if msg.err != nil {
			m.message = StyleError.Render("Error: " + msg.err.Error())
		} else {
			m.message = StyleSuccess.Render("Done.")
		}
		return m, m.refreshStatus()

	case settingsEditorDoneMsg:
		m.processing = false
		if msg.err != nil {
			m.message = StyleError.Render("Editor error: " + msg.err.Error())
		} else {
			m.message = StyleSuccess.Render("Editor closed.")
		}
		return m, nil

	case chezmoiDataMsg:
		m.processing = false
		return m, func() tea.Msg {
			return ToastMsg{Message: msg.data, Level: ToastInfo}
		}

	case scheduleStatusMsg:
		m.syncActive = msg.active
		m.syncBackend = msg.backend
		return m, nil

	case spinner.TickMsg:
		if m.processing {
			var cmd tea.Cmd
			m.spinner, cmd = m.spinner.Update(msg)
			return m, cmd
		}
	}

	return m, nil
}

// View renders the settings tab.
func (m SettingsModel) View() string {
	var b strings.Builder

	b.WriteString(StyleTitle.Render("  Settings") + "\n\n")

	items := []struct {
		label string
		value string
	}{
		{
			label: "Scheduled Sync",
			value: m.syncToggleLabel(),
		},
		{
			label: "Sync Interval",
			value: m.intervals[m.intervalIdx],
		},
		{
			label: "View chezmoi data",
			value: "",
		},
		{
			label: "Edit chezmoi config",
			value: "",
		},
		{
			label: "Re-initialize chezmoi",
			value: "",
		},
	}

	for i, item := range items {
		cursor := "  "
		style := lipgloss.NewStyle().Foreground(ColorText)
		if i == m.cursor {
			cursor = StyleKey.Render("> ")
			style = style.Foreground(ColorMauve).Bold(true)
		}

		line := cursor + style.Render(item.label)
		if item.value != "" {
			line += "  " + StyleDimmed.Render(item.value)
		}
		b.WriteString(line + "\n")
	}

	if m.processing {
		b.WriteString("\n  " + m.spinner.View() + " Processing...")
	}

	if m.message != "" {
		b.WriteString("\n  " + m.message)
	}

	b.WriteString("\n\n")
	b.WriteString(renderHelpBar(m.width, [][2]string{
		{"j/k", "navigate"},
		{"enter", "select"},
		{"tab", "tabs"},
		{"y", "copy"},
		{"q", "quit"},
	}))

	return b.String()
}

// SetSize updates the model dimensions.
func (m *SettingsModel) SetSize(w, h int) {
	m.width = w
	m.height = h
}

func (m SettingsModel) syncToggleLabel() string {
	if m.syncActive {
		return StyleSuccess.Render("ON") + " (" + m.syncBackend + ")"
	}
	return StyleDimmed.Render("OFF")
}

func (m SettingsModel) handleAction() (SettingsModel, tea.Cmd) {
	switch settingsItem(m.cursor) {
	case settingSyncToggle:
		m.processing = true
		m.message = ""
		if m.syncActive {
			return m, tea.Batch(m.spinner.Tick, m.disableSync())
		}
		return m, tea.Batch(m.spinner.Tick, m.enableSync())

	case settingSyncInterval:
		m.intervalIdx = (m.intervalIdx + 1) % len(m.intervals)
		m.message = StyleSuccess.Render("Interval set to " + m.intervals[m.intervalIdx])
		if m.syncActive {
			m.processing = true
			return m, tea.Batch(m.spinner.Tick, m.enableSync())
		}
		return m, nil

	case settingViewData:
		m.processing = true
		m.message = ""
		return m, tea.Batch(m.spinner.Tick, m.viewChezmoiData())

	case settingEditConfig:
		c := exec.Command("chezmoi", "edit-config")
		return m, tea.ExecProcess(c, func(err error) tea.Msg {
			return settingsEditorDoneMsg{err: err}
		})

	case settingReinit:
		m.processing = true
		m.message = ""
		return m, tea.Batch(m.spinner.Tick, m.reinitChezmoi())
	}

	return m, nil
}

func (m SettingsModel) refreshStatus() tea.Cmd {
	return func() tea.Msg {
		status := m.scheduler.GetStatus()
		return scheduleStatusMsg{
			active:  status.Active,
			backend: status.Backend,
		}
	}
}

type scheduleStatusMsg struct {
	active  bool
	backend string
}

func (m SettingsModel) enableSync() tea.Cmd {
	return func() tea.Msg {
		interval := m.intervals[m.intervalIdx]
		err := m.scheduler.Enable(interval)
		return scheduleActionDoneMsg{err: err}
	}
}

func (m SettingsModel) disableSync() tea.Cmd {
	return func() tea.Msg {
		err := m.scheduler.Disable()
		return scheduleActionDoneMsg{err: err}
	}
}

func (m SettingsModel) viewChezmoiData() tea.Cmd {
	return func() tea.Msg {
		result := m.runner.Run("chezmoi", "data")
		return chezmoiDataMsg{data: result.Stdout}
	}
}

func (m SettingsModel) reinitChezmoi() tea.Cmd {
	return func() tea.Msg {
		result := m.runner.Run("chezmoi", "init", "--apply")
		var err error
		if result.ExitCode != 0 {
			err = fmt.Errorf("chezmoi init failed: %s", result.Stderr)
		}
		return scheduleActionDoneMsg{err: err}
	}
}
