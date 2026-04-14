package app

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"

	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/parbots/dots/internal/runner"
)

type configCategory struct {
	Name       string
	Icon       string
	Files      []string
	DirtyCount int
}

// treeEntry represents a single row in the file tree view.
type treeEntry struct {
	Name   string // display name
	Path   string // full source path (empty for directories)
	Depth  int
	IsDir  bool
	IsLast bool // last sibling at this level
	Dirty  bool
}

type diffResultMsg struct {
	Content string
}

type categoriesLoadedMsg struct {
	categories []configCategory
	dirtyFiles map[string]bool
}

type editorFinishedMsg struct {
	err error
}

// ConfigsModel is the Bubble Tea model for the configs tab.
type ConfigsModel struct {
	dotsDir    string
	runner     *runner.Runner
	categories []configCategory
	tree       []treeEntry // flattened tree for the selected category
	cursor     int
	fileCursor int
	inFiles    bool
	scroll     int
	diffView   viewport.Model
	showDiff   bool
	dirtyFiles map[string]bool // set of dirty target paths from chezmoi status
	width      int
	height     int
}

// NewConfigsModel creates a new ConfigsModel.
func NewConfigsModel(dotsDir string) ConfigsModel {
	vp := viewport.New(0, 0)
	return ConfigsModel{
		dotsDir:    dotsDir,
		runner:     runner.New(dotsDir),
		diffView:   vp,
		dirtyFiles: make(map[string]bool),
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
				if m.fileCursor < len(m.tree)-1 {
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
				m.fileCursor += m.height / 2
				if m.fileCursor >= len(m.tree) {
					m.fileCursor = len(m.tree) - 1
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
			if m.inFiles {
				// If cursor is on a file, do nothing (use d/e for actions)
			} else {
				m.inFiles = true
				m.fileCursor = 0
				m.scroll = 0
				if m.cursor < len(m.categories) {
					m.tree = m.buildTree(m.categories[m.cursor])
				}
			}
		case "esc", "h":
			if m.inFiles {
				m.inFiles = false
				m.scroll = 0
			}
		case "d":
			if m.inFiles && m.fileCursor < len(m.tree) {
				entry := m.tree[m.fileCursor]
				if !entry.IsDir {
					return m, m.fetchDiff(entry.Path)
				}
			}
		case "e":
			if m.inFiles && m.fileCursor < len(m.tree) {
				entry := m.tree[m.fileCursor]
				if !entry.IsDir {
					editor := os.Getenv("EDITOR")
					if editor == "" {
						editor = "vi"
					}
					c := exec.Command(editor, entry.Path)
					return m, tea.ExecProcess(c, func(err error) tea.Msg {
						return editorFinishedMsg{err: err}
					})
				}
			}
		}

	case categoriesLoadedMsg:
		m.categories = msg.categories
		m.dirtyFiles = msg.dirtyFiles
		// Refresh tree if we're in files view
		if m.inFiles && m.cursor < len(m.categories) {
			m.tree = m.buildTree(m.categories[m.cursor])
			if m.fileCursor >= len(m.tree) {
				m.fileCursor = max(0, len(m.tree)-1)
			}
		}
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
		content := title + "\n" + m.diffView.View()
		return renderScrollView(content, &m.scroll, m.width, m.height, [][2]string{
			{"ctrl+d/u", "scroll"},
			{"esc", "close"},
		})
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
			info := StyleDimmed.Render(fmt.Sprintf("(%d files)", len(cat.Files)))
			if cat.DirtyCount > 0 {
				info = StyleWarning.Render(fmt.Sprintf("(%d files, %d modified)", len(cat.Files), cat.DirtyCount))
			}
			b.WriteString(fmt.Sprintf("%s%s %s  %s\n",
				cursor,
				cat.Icon,
				style.Render(cat.Name),
				info,
			))
		}
	} else {
		cat := m.categories[m.cursor]
		b.WriteString(StyleTitle.Render(fmt.Sprintf("  %s %s", cat.Icon, cat.Name)) + "\n\n")
		for i, entry := range m.tree {
			cursor := "  "
			nameStyle := lipgloss.NewStyle().Foreground(ColorText)
			if i == m.fileCursor {
				cursor = StyleKey.Render("> ")
				if entry.IsDir {
					nameStyle = nameStyle.Foreground(ColorMauve).Bold(true)
				} else {
					nameStyle = nameStyle.Foreground(ColorLavender)
				}
			}

			// Build tree prefix
			indent := strings.Repeat("  ", entry.Depth)
			var prefix string
			if entry.Depth > 0 {
				if entry.IsLast {
					prefix = "└─ "
				} else {
					prefix = "├─ "
				}
			}

			// Icon and dirty indicator
			icon := ""
			if entry.IsDir {
				icon = StyleDimmed.Render(" ")
			}

			dirty := ""
			if entry.Dirty {
				dirty = " " + StyleWarning.Render("●")
			}

			treeChars := StyleDimmed.Render(prefix)
			b.WriteString(fmt.Sprintf("%s%s%s%s%s%s\n", cursor, indent, treeChars, icon, nameStyle.Render(entry.Name), dirty))
		}

		// Warn about template files that chezmoi re-add can't capture
		if cat.DirtyCount > 0 && m.hasTemplateFiles(cat) {
			b.WriteString("\n")
			noteStyle := lipgloss.NewStyle().Foreground(ColorPeach)
			b.WriteString(noteStyle.Render("  Note: .tmpl files are skipped by chezmoi re-add.") + "\n")
			b.WriteString(noteStyle.Render("  Edit the source template directly, not the deployed file.") + "\n")
		}
	}

	return b.String()
}

// buildTree converts a flat file list into a tree structure.
func (m ConfigsModel) buildTree(cat configCategory) []treeEntry {
	// Get the base path for the category to compute relative paths
	basePath := ""
	if len(cat.Files) > 0 {
		// Find common prefix
		basePath = filepath.Dir(cat.Files[0])
		for _, f := range cat.Files[1:] {
			for !strings.HasPrefix(f, basePath+"/") && basePath != "/" {
				basePath = filepath.Dir(basePath)
			}
		}
	}

	// Build relative paths and sort
	type fileInfo struct {
		RelPath string
		AbsPath string
		Dirty   bool
	}
	var files []fileInfo
	for _, f := range cat.Files {
		rel, _ := filepath.Rel(basePath, f)
		dirty := m.isFileDirty(f)
		files = append(files, fileInfo{RelPath: rel, AbsPath: f, Dirty: dirty})
	}
	sort.Slice(files, func(i, j int) bool {
		return files[i].RelPath < files[j].RelPath
	})

	// Build tree entries from sorted relative paths
	var entries []treeEntry
	seenDirs := make(map[string]bool)

	for _, f := range files {
		parts := strings.Split(f.RelPath, "/")

		// Add directory entries for parent directories we haven't seen
		for depth := 0; depth < len(parts)-1; depth++ {
			dirPath := strings.Join(parts[:depth+1], "/")
			if !seenDirs[dirPath] {
				seenDirs[dirPath] = true
				entries = append(entries, treeEntry{
					Name:  parts[depth],
					Depth: depth,
					IsDir: true,
				})
			}
		}

		// Add the file entry
		entries = append(entries, treeEntry{
			Name:  parts[len(parts)-1],
			Path:  f.AbsPath,
			Depth: len(parts) - 1,
			IsDir: false,
			Dirty: f.Dirty,
		})
	}

	// Calculate IsLast for each entry
	for i := range entries {
		isLast := true
		for j := i + 1; j < len(entries); j++ {
			if entries[j].Depth < entries[i].Depth {
				break
			}
			if entries[j].Depth == entries[i].Depth {
				isLast = false
				break
			}
		}
		entries[i].IsLast = isLast
	}

	return entries
}

// hasTemplateFiles returns true if any file in the category is a .tmpl file.
func (m ConfigsModel) hasTemplateFiles(cat configCategory) bool {
	for _, f := range cat.Files {
		if strings.HasSuffix(f, ".tmpl") {
			return true
		}
	}
	return false
}

// isFileDirty checks if a source file has changes vs the target.
func (m ConfigsModel) isFileDirty(sourcePath string) bool {
	// Convert source path to a target-relative path for lookup
	// e.g., configs/dot_config/nvim/init.lua -> .config/nvim/init.lua
	configsDir := filepath.Join(m.dotsDir, "configs")
	rel, err := filepath.Rel(configsDir, sourcePath)
	if err != nil {
		return false
	}
	// Convert chezmoi source naming: dot_ -> .
	rel = strings.ReplaceAll(rel, "dot_", ".")
	// Remove .tmpl suffix
	rel = strings.TrimSuffix(rel, ".tmpl")
	return m.dirtyFiles[rel]
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

		// Get dirty files from chezmoi status
		dirtyFiles := make(map[string]bool)
		r := runner.New(m.dotsDir)
		result := r.Run("chezmoi", "status")
		if result.ExitCode == 0 {
			for _, line := range strings.Split(strings.TrimSpace(result.Stdout), "\n") {
				line = strings.TrimSpace(line)
				if len(line) > 3 {
					// chezmoi status format: "XY path" where XY are status codes
					target := strings.TrimSpace(line[2:])
					dirtyFiles[target] = true
				}
			}
		}

		iconMap := map[string]string{
			"kitty": "\uf490 ",
			"nvim":  "\uf36f ",
			"zsh":   "\ue6b2 ",
		}
		defaultIcon := "\uf15b "
		configsDir := filepath.Join(m.dotsDir, "configs")

		configDir := filepath.Join(configsDir, "dot_config")
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
				dirtyCount := 0
				err := filepath.Walk(filepath.Join(configDir, name), func(path string, info os.FileInfo, err error) error {
					if err != nil {
						return nil
					}
					if !info.IsDir() {
						files = append(files, path)
						// Check if this source file maps to a dirty target
						rel, relErr := filepath.Rel(configsDir, path)
						if relErr == nil {
							target := strings.ReplaceAll(rel, "dot_", ".")
							target = strings.TrimSuffix(target, ".tmpl")
							if dirtyFiles[target] {
								dirtyCount++
							}
						}
					}
					return nil
				})
				if err == nil && len(files) > 0 {
					cats = append(cats, configCategory{Name: name, Icon: icon, Files: files, DirtyCount: dirtyCount})
				}
			}
		}

		// Check for zshrc template
		zshrc := filepath.Join(configsDir, "dot_zshrc.tmpl")
		if _, err := os.Stat(zshrc); err == nil {
			icon := iconMap["zsh"]
			dirtyCount := 0
			if dirtyFiles[".zshrc"] {
				dirtyCount = 1
			}
			cats = append(cats, configCategory{Name: "zsh", Icon: icon, Files: []string{zshrc}, DirtyCount: dirtyCount})
		}

		return categoriesLoadedMsg{categories: cats, dirtyFiles: dirtyFiles}
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
