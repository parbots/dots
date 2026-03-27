package app

import (
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// ToastLevel determines the toast's visual style.
type ToastLevel int

const (
	ToastSuccess ToastLevel = iota
	ToastWarning
	ToastError
	ToastInfo
)

const toastDuration = 3 * time.Second

// ToastMsg triggers a new toast notification.
type ToastMsg struct {
	Message string
	Level   ToastLevel
}

// toastExpiredMsg signals that the current toast should be dismissed.
type toastExpiredMsg struct{}

// ToastModel manages toast notification display and auto-dismiss.
type ToastModel struct {
	message string
	level   ToastLevel
	visible bool
	width   int
}

func NewToastModel() ToastModel {
	return ToastModel{}
}

func (m ToastModel) Update(msg tea.Msg) (ToastModel, tea.Cmd) {
	switch msg := msg.(type) {
	case ToastMsg:
		m.message = msg.Message
		m.level = msg.Level
		m.visible = true
		return m, tea.Tick(toastDuration, func(time.Time) tea.Msg {
			return toastExpiredMsg{}
		})
	case toastExpiredMsg:
		m.visible = false
		return m, nil
	}
	return m, nil
}

func (m ToastModel) View() string {
	if !m.visible {
		return ""
	}

	var style lipgloss.Style
	var icon string

	switch m.level {
	case ToastSuccess:
		style = StyleSuccess
		icon = "  "
	case ToastWarning:
		style = StyleWarning
		icon = "  "
	case ToastError:
		style = StyleError
		icon = "  "
	default:
		style = lipgloss.NewStyle().Foreground(ColorBlue)
		icon = "  "
	}

	content := style.Render(icon + m.message)

	return lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(style.GetForeground()).
		Padding(0, 1).
		Width(m.width - 4).
		Render(content)
}

func (m *ToastModel) SetWidth(w int) {
	m.width = w
}
