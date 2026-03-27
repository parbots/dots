package app

import (
	"fmt"
	"runtime"
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Model is the root Bubble Tea model composing all tabs.
type Model struct {
	activeTab   int
	tabs        []string
	statusTab   StatusModel
	configsTab  ConfigsModel
	homebrewTab HomebrewModel
	syncTab     SyncModel
	systemTab   SystemModel
	settingsTab SettingsModel
	toast       ToastModel
	width       int
	height      int
}

// New creates a new root Model with all sub-models.
func New(dotsDir string) Model {
	tabs := []string{"Status", "Configs", "Homebrew", "Sync", "System", "Settings"}
	if runtime.GOOS != "darwin" {
		filtered := make([]string, 0, len(tabs)-1)
		for _, t := range tabs {
			if t != "Homebrew" {
				filtered = append(filtered, t)
			}
		}
		tabs = filtered
	}

	return Model{
		tabs:        tabs,
		statusTab:   NewStatusModel(dotsDir),
		configsTab:  NewConfigsModel(dotsDir),
		homebrewTab: NewHomebrewModel(dotsDir),
		syncTab:     NewSyncModel(dotsDir),
		systemTab:   NewSystemModel(dotsDir),
		settingsTab: NewSettingsModel(dotsDir),
		toast:       NewToastModel(),
	}
}

// Init batches all sub-model Init calls.
func (m Model) Init() tea.Cmd {
	cmds := []tea.Cmd{
		m.statusTab.Init(),
		m.configsTab.Init(),
		m.syncTab.Init(),
		m.systemTab.Init(),
		m.settingsTab.Init(),
	}
	if runtime.GOOS == "darwin" {
		cmds = append(cmds, m.homebrewTab.Init())
	}
	return tea.Batch(cmds...)
}

// Update handles messages for the root model.
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		contentHeight := msg.Height - 8
		m.statusTab.SetSize(msg.Width, contentHeight)
		m.configsTab.SetSize(msg.Width, contentHeight)
		m.homebrewTab.SetSize(msg.Width, contentHeight)
		m.syncTab.SetSize(msg.Width, contentHeight)
		m.systemTab.SetSize(msg.Width, contentHeight)
		m.settingsTab.SetSize(msg.Width, contentHeight)
		m.toast.SetWidth(msg.Width)
		return m, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c":
			return m, tea.Quit
		case "q":
			// Let the active tab consume "q" first (e.g., configs diff view close)
			if m.tabs[m.activeTab] == "Configs" && m.configsTab.showDiff {
				break // fall through to active tab routing below
			}
			return m, tea.Quit
		case "tab":
			m.activeTab = (m.activeTab + 1) % len(m.tabs)
			if m.tabs[m.activeTab] == "System" {
				cmds = append(cmds, m.systemTab.Refresh())
			}
			return m, tea.Batch(cmds...)
		case "shift+tab":
			m.activeTab = (m.activeTab - 1 + len(m.tabs)) % len(m.tabs)
			if m.tabs[m.activeTab] == "System" {
				cmds = append(cmds, m.systemTab.Refresh())
			}
			return m, tea.Batch(cmds...)
		}

	case QuickActionMsg:
		for i, t := range m.tabs {
			if t == "Sync" {
				m.activeTab = i
				break
			}
		}
		var action syncAction
		switch msg.Action {
		case "update":
			action = syncActionUpdate
		case "push":
			action = syncActionPush
		case "sync":
			action = syncActionFull
		default:
			return m, nil
		}
		cmd := m.syncTab.TriggerAction(action)
		return m, cmd

	case ToastMsg:
		var cmd tea.Cmd
		m.toast, cmd = m.toast.Update(msg)
		return m, cmd

	case toastExpiredMsg:
		var cmd tea.Cmd
		m.toast, cmd = m.toast.Update(msg)
		return m, cmd

	// Route tab-specific messages directly to the right tab regardless of active tab
	case systemInfoMsg:
		var cmd tea.Cmd
		m.systemTab, cmd = m.systemTab.Update(msg)
		return m, cmd

	case gitStatusMsg:
		var cmd tea.Cmd
		m.statusTab, cmd = m.statusTab.Update(msg)
		return m, cmd

	case syncLogMsg:
		var cmd tea.Cmd
		m.statusTab, cmd = m.statusTab.Update(msg)
		return m, cmd

	case RunCompleteMsg:
		var cmd tea.Cmd
		m.syncTab, cmd = m.syncTab.Update(msg)
		return m, cmd

	case syncHistoryMsg:
		var cmd tea.Cmd
		m.syncTab, cmd = m.syncTab.Update(msg)
		return m, cmd

	// Route configs tab messages
	case categoriesLoadedMsg, diffResultMsg, editorFinishedMsg:
		var cmd tea.Cmd
		m.configsTab, cmd = m.configsTab.Update(msg)
		return m, cmd

	// Route homebrew tab messages
	case brewfileLoadedMsg, brewBundleCompleteMsg:
		var cmd tea.Cmd
		m.homebrewTab, cmd = m.homebrewTab.Update(msg)
		return m, cmd

	// Route settings tab messages
	case scheduleStatusMsg, scheduleActionDoneMsg, settingsEditorDoneMsg, chezmoiDataMsg:
		var cmd tea.Cmd
		m.settingsTab, cmd = m.settingsTab.Update(msg)
		return m, cmd

	// Route spinner ticks to ALL tabs that are loading so each spinner
	// maintains its own tick chain independently
	case spinner.TickMsg:
		var cmds []tea.Cmd
		if m.statusTab.loading {
			var cmd tea.Cmd
			m.statusTab, cmd = m.statusTab.Update(msg)
			cmds = append(cmds, cmd)
		}
		if m.systemTab.loading {
			var cmd tea.Cmd
			m.systemTab, cmd = m.systemTab.Update(msg)
			cmds = append(cmds, cmd)
		}
		if m.syncTab.running {
			var cmd tea.Cmd
			m.syncTab, cmd = m.syncTab.Update(msg)
			cmds = append(cmds, cmd)
		}
		if m.homebrewTab.running {
			var cmd tea.Cmd
			m.homebrewTab, cmd = m.homebrewTab.Update(msg)
			cmds = append(cmds, cmd)
		}
		if m.settingsTab.processing {
			var cmd tea.Cmd
			m.settingsTab, cmd = m.settingsTab.Update(msg)
			cmds = append(cmds, cmd)
		}
		return m, tea.Batch(cmds...)
	}

	// Route all messages (including keys that didn't match above) to the active tab
	var cmd tea.Cmd
	switch m.tabs[m.activeTab] {
	case "Status":
		m.statusTab, cmd = m.statusTab.Update(msg)
	case "Configs":
		m.configsTab, cmd = m.configsTab.Update(msg)
	case "Homebrew":
		m.homebrewTab, cmd = m.homebrewTab.Update(msg)
	case "Sync":
		m.syncTab, cmd = m.syncTab.Update(msg)
	case "System":
		m.systemTab, cmd = m.systemTab.Update(msg)
	case "Settings":
		m.settingsTab, cmd = m.settingsTab.Update(msg)
	}
	cmds = append(cmds, cmd)

	return m, tea.Batch(cmds...)
}

// View renders the full UI.
func (m Model) View() string {
	var b strings.Builder

	// Header: gradient "d o t s" with dot art
	b.WriteString(m.renderHeader())
	b.WriteString("\n")

	// Tab bar
	b.WriteString(m.renderTabBar())
	b.WriteString("\n")

	// Separator
	sep := lipgloss.NewStyle().
		Foreground(ColorSurface2).
		Render(strings.Repeat("─", m.width))
	b.WriteString(sep)
	b.WriteString("\n")

	// Active tab content
	b.WriteString(m.activeTabView())

	// Toast overlay
	if toast := m.toast.View(); toast != "" {
		b.WriteString("\n" + toast)
	}

	// Footer
	b.WriteString("\n")
	b.WriteString(m.renderFooter())

	return b.String()
}

func (m Model) activeTabView() string {
	tabName := m.tabs[m.activeTab]
	switch tabName {
	case "Status":
		return m.statusTab.View()
	case "Configs":
		return m.configsTab.View()
	case "Homebrew":
		return m.homebrewTab.View()
	case "Sync":
		return m.syncTab.View()
	case "System":
		return m.systemTab.View()
	case "Settings":
		return m.settingsTab.View()
	}
	return ""
}

func (m Model) renderHeader() string {
	title := "d o t s"
	// Gradient from Mauve (#cba6f7) to Lavender (#b4befe)
	colors := []lipgloss.Color{
		"#cba6f7", // d
		"#cba6f7", // space
		"#c9adf5", // o
		"#c9adf5", // space
		"#c1b4f3", // t
		"#c1b4f3", // space
		"#b4befe", // s
	}

	var rendered strings.Builder
	for i, ch := range title {
		color := colors[0]
		if i < len(colors) {
			color = colors[i]
		}
		style := lipgloss.NewStyle().Foreground(color).Bold(true)
		rendered.WriteString(style.Render(string(ch)))
	}

	// Dot art pattern alongside the title
	dots := lipgloss.NewStyle().Foreground(ColorSurface2).Render("  ·  ·  ·")

	return "\n  " + rendered.String() + dots + "\n"
}

func (m Model) renderTabBar() string {
	var tabs []string
	for i, t := range m.tabs {
		if i == m.activeTab {
			style := lipgloss.NewStyle().
				Bold(true).
				Foreground(ColorMauve).
				Underline(true)
			tabs = append(tabs, style.Render(t))
		} else {
			style := lipgloss.NewStyle().
				Foreground(ColorOverlay1)
			tabs = append(tabs, style.Render(t))
		}
	}
	return "  " + strings.Join(tabs, "  ")
}

func (m Model) renderFooter() string {
	return StyleHelp.Render(fmt.Sprintf("  %s navigate tabs  %s/%s scroll  %s quit",
		StyleKey.Render("tab/shift+tab"),
		StyleKey.Render("ctrl+d"), StyleKey.Render("ctrl+u"),
		StyleKey.Render("q")))
}
