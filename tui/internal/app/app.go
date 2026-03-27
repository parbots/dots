package app

import (
	"fmt"
	"runtime"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Model is the root Bubble Tea model composing all tabs.
type Model struct {
	activeTab   int
	tabs        []string
	statusTab   StatusModel
	configsTab  ConfigsModel
	packagesTab PackagesModel
	syncTab     SyncModel
	systemTab   SystemModel
	settingsTab SettingsModel
	toast       ToastModel
	width       int
	height      int
}

// New creates a new root Model with all sub-models.
func New(dotsDir string) Model {
	tabs := []string{"Status", "Configs", "Packages", "Sync", "System", "Settings"}
	if runtime.GOOS != "darwin" {
		filtered := make([]string, 0, len(tabs)-1)
		for _, t := range tabs {
			if t != "Packages" {
				filtered = append(filtered, t)
			}
		}
		tabs = filtered
	}

	return Model{
		tabs:        tabs,
		statusTab:   NewStatusModel(dotsDir),
		configsTab:  NewConfigsModel(dotsDir),
		packagesTab: NewPackagesModel(dotsDir),
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
		cmds = append(cmds, m.packagesTab.Init())
	}
	return tea.Batch(cmds...)
}

// Update handles messages for the root model.
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		contentHeight := msg.Height - 8 // header + tab bar + separator + footer
		m.statusTab.SetSize(msg.Width, contentHeight)
		m.configsTab.SetSize(msg.Width, contentHeight)
		m.packagesTab.SetSize(msg.Width, contentHeight)
		m.syncTab.SetSize(msg.Width, contentHeight)
		m.systemTab.SetSize(msg.Width, contentHeight)
		m.settingsTab.SetSize(msg.Width, contentHeight)
		m.toast.SetWidth(msg.Width)
		return m, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "tab":
			m.activeTab = (m.activeTab + 1) % len(m.tabs)
			return m, m.onTabSwitch()
		case "shift+tab":
			m.activeTab = (m.activeTab - 1 + len(m.tabs)) % len(m.tabs)
			return m, m.onTabSwitch()
		default:
			return m, m.updateActiveTab(msg)
		}

	case QuickActionMsg:
		// Switch to the Sync tab
		for i, t := range m.tabs {
			if t == "Sync" {
				m.activeTab = i
				break
			}
		}
		// Map action string to syncAction and trigger
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

	default:
		return m, m.updateActiveTab(msg)
	}
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

func (m Model) onTabSwitch() tea.Cmd {
	tabName := m.tabs[m.activeTab]
	if tabName == "System" {
		m.systemTab.loading = true
		return m.systemTab.Refresh()
	}
	return nil
}

func (m Model) updateActiveTab(msg tea.Msg) tea.Cmd {
	tabName := m.tabs[m.activeTab]
	var cmd tea.Cmd
	switch tabName {
	case "Status":
		m.statusTab, cmd = m.statusTab.Update(msg)
	case "Configs":
		m.configsTab, cmd = m.configsTab.Update(msg)
	case "Packages":
		m.packagesTab, cmd = m.packagesTab.Update(msg)
	case "Sync":
		m.syncTab, cmd = m.syncTab.Update(msg)
	case "System":
		m.systemTab, cmd = m.systemTab.Update(msg)
	case "Settings":
		m.settingsTab, cmd = m.settingsTab.Update(msg)
	}
	return cmd
}

func (m Model) activeTabView() string {
	tabName := m.tabs[m.activeTab]
	switch tabName {
	case "Status":
		return m.statusTab.View()
	case "Configs":
		return m.configsTab.View()
	case "Packages":
		return m.packagesTab.View()
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
			tabs = append(tabs, StyleActiveTab.Padding(0, 2).Render(t))
		} else {
			tabs = append(tabs, StyleInactiveTab.Padding(0, 2).Render(t))
		}
	}
	return "  " + strings.Join(tabs, " ")
}

func (m Model) renderFooter() string {
	return StyleHelp.Render(fmt.Sprintf("  %s navigate tabs  %s quit",
		StyleKey.Render("tab/shift+tab"),
		StyleKey.Render("q")))
}
