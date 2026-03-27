package app

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/parbots/dots/internal/runner"
)

type configCategory struct {
	Name  string
	Icon  string
	Files []string
}

type diffResultMsg struct {
	Content string
}

type categoriesLoadedMsg struct {
	categories []configCategory
}

type editorFinishedMsg struct {
	err error
}

// ConfigsModel is the Bubble Tea model for the configs tab.
type ConfigsModel struct {
	dotsDir    string
	runner     *runner.Runner
	categories []configCategory
	cursor     int
	fileCursor int
	inFiles    bool
	scroll     int
	diffView   viewport.Model
	showDiff   bool
	width      int
	height     int
}

// NewConfigsModel creates a new ConfigsModel.
func NewConfigsModel(dotsDir string) ConfigsModel {
	vp := viewport.New(0, 0)
	return ConfigsModel{
		dotsDir:  dotsDir,
		runner:   runner.New(dotsDir),
		diffView: vp,
	}
}

// Init initializes the configs model.
func (m ConfigsModel) Init() tea.Cmd {
	return m.scanCategories()
}

// Update handles messages for the configs model.
func (m ConfigsModel) Update(msg tea.Msg) (ConfigsModel, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		if m.showDiff {
			switch msg.String() {
			case "esc", "q":
				m.showDiff = false
				return m, nil
			default:
				var cmd tea.Cmd
				m.diffView, cmd = m.diffView.Update(msg)
				return m, cmd
			}
		}

		switch msg.String() {
		case "j", "down":
			if m.inFiles {
				if m.cursor < len(m.categories) && m.fileCursor < len(m.categories[m.cursor].Files)-1 {
					m.fileCursor++
				}
			} else {
				if m.cursor < len(m.categories)-1 {
					m.cursor++
				}
			}
		case "k", "up":
			if m.inFiles {
				if m.fileCursor > 0 {
					m.fileCursor--
				}
			} else {
				if m.cursor > 0 {
					m.cursor--
				}
			}
		case "ctrl+d":
			if m.inFiles {
				if m.cursor < len(m.categories) {
					m.fileCursor += m.height / 2
					maxFile := len(m.categories[m.cursor].Files) - 1
					if m.fileCursor > maxFile {
						m.fileCursor = maxFile
					}
				}
			} else {
				m.cursor += m.height / 2
				if m.cursor >= len(m.categories) {
					m.cursor = len(m.categories) - 1
				}
				if m.cursor < 0 {
					m.cursor = 0
				}
			}
		case "ctrl+u":
			if m.inFiles {
				m.fileCursor -= m.height / 2
				if m.fileCursor < 0 {
					m.fileCursor = 0
				}
			} else {
				m.cursor -= m.height / 2
				if m.cursor < 0 {
					m.cursor = 0
				}
			}
		case "enter", "l":
			if !m.inFiles {
				m.inFiles = true
				m.fileCursor = 0
				m.scroll = 0
			}
		case "esc", "h":
			if m.inFiles {
				m.inFiles = false
				m.scroll = 0
			}
		case "d":
			if m.inFiles && m.cursor < len(m.categories) {
				cat := m.categories[m.cursor]
				if m.fileCursor < len(cat.Files) {
					file := cat.Files[m.fileCursor]
					return m, m.fetchDiff(file)
				}
			}
		case "e":
			if m.inFiles && m.cursor < len(m.categories) {
				cat := m.categories[m.cursor]
				if m.fileCursor < len(cat.Files) {
					file := cat.Files[m.fileCursor]
					editor := os.Getenv("EDITOR")
					if editor == "" {
						editor = "vi"
					}
					c := exec.Command(editor, file)
					return m, tea.ExecProcess(c, func(err error) tea.Msg {
						return editorFinishedMsg{err: err}
					})
				}
			}
		}

	case categoriesLoadedMsg:
		m.categories = msg.categories
		return m, nil

	case diffResultMsg:
		m.showDiff = true
		m.diffView.SetContent(msg.Content)
		m.diffView.GotoTop()
		return m, nil

	case editorFinishedMsg:
		if msg.err != nil {
			return m, tea.Batch(m.scanCategories(), func() tea.Msg {
				return ToastMsg{Message: "Editor error: " + msg.err.Error(), Level: ToastError}
			})
		}
		return m, tea.Batch(m.scanCategories(), func() tea.Msg {
			return ToastMsg{Message: "Editor closed, configs reloaded", Level: ToastSuccess}
		})
	}

	return m, nil
}

// View renders the configs tab.
func (m ConfigsModel) View() string {
	if m.showDiff {
		title := StyleTitle.Render("  Diff Preview") + "  " + StyleHelp.Render("(esc to close)")
		return title + "\n" + m.diffView.View()
	}

	var bindings [][2]string
	if !m.inFiles {
		bindings = [][2]string{
			{"j/k", "navigate"},
			{"enter", "open"},
			{"ctrl+d/u", "scroll"},
			{"tab", "tabs"},
			{"y", "copy"},
			{"q", "quit"},
		}
	} else {
		bindings = [][2]string{
			{"j/k", "navigate"},
			{"d", "diff"},
			{"e", "edit"},
			{"esc", "back"},
			{"ctrl+d/u", "scroll"},
			{"tab", "tabs"},
			{"y", "copy"},
			{"q", "quit"},
		}
	}

	return renderScrollViewAutoScroll(m.renderContent(), &m.scroll, m.cursorContentLine(), m.width, m.height, bindings)
}

// cursorContentLine returns the line in rendered content where the active cursor is.
func (m ConfigsModel) cursorContentLine() int {
	headerLines := 2 // title + blank line
	if !m.inFiles {
		return headerLines + m.cursor
	}
	return headerLines + m.fileCursor
}

func (m ConfigsModel) renderContent() string {
	var b strings.Builder

	if len(m.categories) == 0 {
		return StyleDimmed.Render("  No config categories found.")
	}

	if !m.inFiles {
		b.WriteString(StyleTitle.Render("  Config Categories") + "\n\n")
		for i, cat := range m.categories {
			cursor := "  "
			style := lipgloss.NewStyle().Foreground(ColorText)
			if i == m.cursor {
				cursor = StyleKey.Render("> ")
				style = style.Foreground(ColorMauve).Bold(true)
			}
			b.WriteString(fmt.Sprintf("%s%s %s  %s\n",
				cursor,
				cat.Icon,
				style.Render(cat.Name),
				StyleDimmed.Render(fmt.Sprintf("(%d files)", len(cat.Files))),
			))
		}
	} else {
		cat := m.categories[m.cursor]
		b.WriteString(StyleTitle.Render(fmt.Sprintf("  %s %s", cat.Icon, cat.Name)) + "\n\n")
		for i, file := range cat.Files {
			cursor := "  "
			style := lipgloss.NewStyle().Foreground(ColorText)
			if i == m.fileCursor {
				cursor = StyleKey.Render("> ")
				style = style.Foreground(ColorLavender)
			}
			b.WriteString(fmt.Sprintf("%s%s\n", cursor, style.Render(filepath.Base(file))))
		}
	}

	return b.String()
}

// SetSize updates the model dimensions.
func (m *ConfigsModel) SetSize(w, h int) {
	m.width = w
	m.height = h
	m.diffView.Width = w
	m.diffView.Height = h - 2
}

func (m ConfigsModel) scanCategories() tea.Cmd {
	return func() tea.Msg {
		var cats []configCategory

		iconMap := map[string]string{
			"kitty": "\uf490 ",
			"nvim":  "\uf36f ",
			"zsh":   "\ue6b2 ",
		}
		defaultIcon := "\uf15b "

		configDir := filepath.Join(m.dotsDir, "configs", "dot_config")
		entries, err := os.ReadDir(configDir)
		if err == nil {
			for _, entry := range entries {
				if !entry.IsDir() {
					continue
				}
				name := entry.Name()
				icon := defaultIcon
				if ic, ok := iconMap[name]; ok {
					icon = ic
				}

				var files []string
				err := filepath.Walk(filepath.Join(configDir, name), func(path string, info os.FileInfo, err error) error {
					if err != nil {
						return nil
					}
					if !info.IsDir() {
						files = append(files, path)
					}
					return nil
				})
				if err == nil && len(files) > 0 {
					cats = append(cats, configCategory{Name: name, Icon: icon, Files: files})
				}
			}
		}

		// Check for zshrc template
		zshrc := filepath.Join(m.dotsDir, "configs", "dot_zshrc.tmpl")
		if _, err := os.Stat(zshrc); err == nil {
			icon := iconMap["zsh"]
			cats = append(cats, configCategory{Name: "zsh", Icon: icon, Files: []string{zshrc}})
		}

		return categoriesLoadedMsg{categories: cats}
	}
}

func (m ConfigsModel) fetchDiff(file string) tea.Cmd {
	return func() tea.Msg {
		result := m.runner.Run("chezmoi", "diff", file)
		content := result.Stdout
		if content == "" {
			content = "No differences found."
		}
		return diffResultMsg{Content: content}
	}
}
