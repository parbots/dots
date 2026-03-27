package app

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/parbots/dots/internal/runner"
)

type packageEntry struct {
	Type    string
	Name    string
	Comment string
}

type brewfileLoadedMsg struct {
	packages []packageEntry
}

type brewBundleCompleteMsg struct {
	output   string
	exitCode int
}

// HomebrewModel is the Bubble Tea model for the homebrew tab.
type HomebrewModel struct {
	dotsDir  string
	runner   *runner.Runner
	packages []packageEntry
	filtered []packageEntry
	cursor   int
	scroll   int
	search   textinput.Model
	adding   bool
	addInput textinput.Model
	running  bool
	spinner  spinner.Model
	output   string
	width    int
	height   int
}

// NewHomebrewModel creates a new HomebrewModel.
func NewHomebrewModel(dotsDir string) HomebrewModel {
	search := textinput.New()
	search.Placeholder = "Search packages..."
	search.CharLimit = 64

	addIn := textinput.New()
	addIn.Placeholder = "brew/cask name (e.g. brew \"ripgrep\")"
	addIn.CharLimit = 128

	s := spinner.New(spinner.WithSpinner(spinner.Dot))
	s.Style = lipgloss.NewStyle().Foreground(ColorMauve)

	return HomebrewModel{
		dotsDir:  dotsDir,
		runner:   runner.New(dotsDir),
		search:   search,
		addInput: addIn,
		spinner:  s,
	}
}

// Init initializes the homebrew model.
func (m HomebrewModel) Init() tea.Cmd {
	if runtime.GOOS != "darwin" {
		return nil
	}
	return m.loadBrewfile()
}

// Update handles messages for the homebrew model.
func (m HomebrewModel) Update(msg tea.Msg) (HomebrewModel, tea.Cmd) {
	if runtime.GOOS != "darwin" {
		return m, nil
	}

	switch msg := msg.(type) {
	case tea.KeyMsg:
		// If search is focused
		if m.search.Focused() {
			switch msg.String() {
			case "esc":
				m.search.Blur()
				m.search.SetValue("")
				m.filterPackages()
				return m, nil
			case "enter":
				m.search.Blur()
				return m, nil
			}
			var cmd tea.Cmd
			m.search, cmd = m.search.Update(msg)
			m.filterPackages()
			return m, cmd
		}

		// If adding
		if m.adding {
			switch msg.String() {
			case "esc":
				m.adding = false
				m.addInput.Blur()
				return m, nil
			case "enter":
				line := strings.TrimSpace(m.addInput.Value())
				if line != "" {
					m.addPackageLine(line)
				}
				m.adding = false
				m.addInput.Blur()
				m.addInput.SetValue("")
				return m, m.loadBrewfile()
			}
			var cmd tea.Cmd
			m.addInput, cmd = m.addInput.Update(msg)
			return m, cmd
		}

		switch msg.String() {
		case "j", "down":
			if m.cursor < len(m.filtered)-1 {
				m.cursor++
			}
		case "k", "up":
			if m.cursor > 0 {
				m.cursor--
			}
		case "ctrl+d":
			m.cursor += m.height / 2
			if m.cursor >= len(m.filtered) {
				m.cursor = len(m.filtered) - 1
			}
			if m.cursor < 0 {
				m.cursor = 0
			}
		case "ctrl+u":
			m.cursor -= m.height / 2
			if m.cursor < 0 {
				m.cursor = 0
			}
		case "/":
			m.search.Focus()
			return m, textinput.Blink
		case "a":
			m.adding = true
			m.addInput.Focus()
			return m, textinput.Blink
		case "r":
			if m.cursor < len(m.filtered) {
				m.removePackage(m.filtered[m.cursor])
				return m, m.loadBrewfile()
			}
		case "b":
			m.running = true
			return m, tea.Batch(m.spinner.Tick, m.runBrewBundle())
		}

	case brewfileLoadedMsg:
		m.packages = msg.packages
		m.filterPackages()
		return m, nil

	case brewBundleCompleteMsg:
		m.running = false
		m.output = msg.output
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

// View renders the homebrew tab.
func (m HomebrewModel) View() string {
	if runtime.GOOS != "darwin" {
		return StyleDimmed.Render("  Homebrew tab is only available on macOS.")
	}

	bindings := [][2]string{
		{"j/k", "navigate"},
		{"/", "search"},
		{"a", "add"},
		{"r", "remove"},
		{"b", "brew bundle"},
		{"ctrl+d/u", "scroll"},
		{"tab", "tabs"},
		{"y", "copy"},
		{"q", "quit"},
	}

	return renderScrollViewAutoScroll(m.renderContent(), &m.scroll, m.cursorContentLine(), m.width, m.height, bindings)
}

// cursorContentLine returns the line number in rendered content where the cursor is.
func (m HomebrewModel) cursorContentLine() int {
	// Count header lines (title + blank + optional search/add/spinner/output)
	headerLines := 2 // title + blank line
	if m.search.Focused() {
		headerLines += 2
	} else if m.adding {
		headerLines += 2
	}
	if m.running {
		headerLines += 2
	}
	if m.output != "" {
		headerLines += strings.Count(m.output, "\n") + 3
	}

	// Count lines through the grouped package list to find cursor position
	groups := map[string][]packageEntry{
		"tap":  {},
		"brew": {},
		"cask": {},
	}
	for _, p := range m.filtered {
		groups[p.Type] = append(groups[p.Type], p)
	}

	line := headerLines
	idx := 0
	for _, typ := range []string{"tap", "brew", "cask"} {
		pkgs := groups[typ]
		if len(pkgs) == 0 {
			continue
		}
		line++ // group header
		for range pkgs {
			if idx == m.cursor {
				return line
			}
			line++
			idx++
		}
		line++ // blank line after group
	}
	return line
}

func (m HomebrewModel) renderContent() string {
	var b strings.Builder

	b.WriteString(StyleTitle.Render("  Brewfile Packages") + "\n\n")

	if m.search.Focused() {
		b.WriteString("  " + m.search.View() + "\n\n")
	} else if m.adding {
		b.WriteString("  " + m.addInput.View() + "\n\n")
	}

	if m.running {
		b.WriteString("  " + m.spinner.View() + " Running brew bundle...\n\n")
	}

	if m.output != "" {
		b.WriteString(StyleBorder.Render(m.output) + "\n\n")
	}

	// Group by type
	groups := map[string][]packageEntry{
		"tap":  {},
		"brew": {},
		"cask": {},
	}
	for _, p := range m.filtered {
		groups[p.Type] = append(groups[p.Type], p)
	}

	idx := 0
	for _, typ := range []string{"tap", "brew", "cask"} {
		pkgs := groups[typ]
		if len(pkgs) == 0 {
			continue
		}
		header := StyleTitle.Foreground(ColorLavender).Render(fmt.Sprintf("  %s (%d)", strings.ToUpper(typ[:1])+typ[1:], len(pkgs)))
		b.WriteString(header + "\n")
		for _, p := range pkgs {
			cursor := "  "
			style := lipgloss.NewStyle().Foreground(ColorText)
			if idx == m.cursor {
				cursor = StyleKey.Render("> ")
				style = style.Foreground(ColorMauve)
			}
			line := fmt.Sprintf("%s%s", cursor, style.Render(p.Name))
			if p.Comment != "" {
				line += "  " + StyleDimmed.Render(p.Comment)
			}
			b.WriteString(line + "\n")
			idx++
		}
		b.WriteString("\n")
	}

	return b.String()
}

// SetSize updates the model dimensions.
func (m *HomebrewModel) SetSize(w, h int) {
	m.width = w
	m.height = h
}

func (m HomebrewModel) loadBrewfile() tea.Cmd {
	return func() tea.Msg {
		brewfilePath := filepath.Join(m.dotsDir, "configs", "Brewfile")
		data, err := os.ReadFile(brewfilePath)
		if err != nil {
			return brewfileLoadedMsg{}
		}

		var pkgs []packageEntry
		for _, line := range strings.Split(string(data), "\n") {
			line = strings.TrimSpace(line)
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}

			var comment string
			if idx := strings.Index(line, "#"); idx > 0 {
				comment = strings.TrimSpace(line[idx+1:])
				line = strings.TrimSpace(line[:idx])
			}

			parts := strings.SplitN(line, " ", 2)
			if len(parts) < 2 {
				continue
			}

			typ := parts[0]
			name := strings.Trim(strings.TrimSpace(parts[1]), "\"")
			// Handle comma-separated options after name
			if idx := strings.Index(name, ","); idx > 0 {
				name = strings.TrimSpace(name[:idx])
				name = strings.Trim(name, "\"")
			}

			if typ == "tap" || typ == "brew" || typ == "cask" {
				pkgs = append(pkgs, packageEntry{Type: typ, Name: name, Comment: comment})
			}
		}
		return brewfileLoadedMsg{packages: pkgs}
	}
}

func (m *HomebrewModel) filterPackages() {
	query := strings.ToLower(m.search.Value())
	if query == "" {
		m.filtered = m.packages
	} else {
		m.filtered = nil
		for _, p := range m.packages {
			if strings.Contains(strings.ToLower(p.Name), query) ||
				strings.Contains(strings.ToLower(p.Comment), query) {
				m.filtered = append(m.filtered, p)
			}
		}
	}
	if m.cursor >= len(m.filtered) {
		m.cursor = 0
	}
}

func (m *HomebrewModel) addPackageLine(line string) {
	brewfilePath := filepath.Join(m.dotsDir, "configs", "Brewfile")
	f, err := os.OpenFile(brewfilePath, os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = f.WriteString("\n" + line + "\n")
}

func (m *HomebrewModel) removePackage(pkg packageEntry) {
	brewfilePath := filepath.Join(m.dotsDir, "configs", "Brewfile")
	data, err := os.ReadFile(brewfilePath)
	if err != nil {
		return
	}

	var lines []string
	for _, line := range strings.Split(string(data), "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, pkg.Type) && strings.Contains(trimmed, fmt.Sprintf("\"%s\"", pkg.Name)) {
			continue
		}
		lines = append(lines, line)
	}
	_ = os.WriteFile(brewfilePath, []byte(strings.Join(lines, "\n")), 0644)
}

func (m HomebrewModel) runBrewBundle() tea.Cmd {
	return func() tea.Msg {
		result := m.runner.Run("brew", "bundle", "--file="+filepath.Join(m.dotsDir, "configs", "Brewfile"))
		return brewBundleCompleteMsg{
			output:   result.Stdout + result.Stderr,
			exitCode: result.ExitCode,
		}
	}
}
