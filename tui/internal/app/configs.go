package app

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/parbots/dots/internal/runner"
)

// configFile is one chezmoi-managed file, known by its target path.
type configFile struct {
	TargetRel  string // path relative to ~, as printed by `chezmoi managed`
	SourcePath string // absolute path in the chezmoi source dir ("" if unresolved)
	IsTemplate bool   // source is a .tmpl — chezmoi re-add cannot capture edits
	Dirty      bool   // chezmoi status lists a pending difference for this target
}

type configCategory struct {
	Name       string
	Icon       string
	Files      []configFile
	DirtyCount int
}

// treeEntry represents a single row in the file tree view.
type treeEntry struct {
	Name       string // display name
	Path       string // target path relative to ~ (empty for directories)
	SourcePath string
	Depth      int
	IsDir      bool
	IsLast     bool // last sibling at this level
	Dirty      bool
}

type diffResultMsg struct {
	Content string
}

type categoriesLoadedMsg struct {
	categories []configCategory
	err        string // non-empty when discovery failed
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
					if entry.SourcePath == "" {
						return m, func() tea.Msg {
							return ToastMsg{Message: "No source path for " + entry.Path, Level: ToastError}
						}
					}
					c := editorCommand(entry.SourcePath)
					return m, tea.ExecProcess(c, func(err error) tea.Msg {
						return editorFinishedMsg{err: err}
					})
				}
			}
		}

	case categoriesLoadedMsg:
		if msg.err != "" {
			return m, func() tea.Msg {
				return ToastMsg{Message: msg.err, Level: ToastError}
			}
		}
		m.categories = msg.categories
		if m.cursor >= len(m.categories) {
			m.cursor = max(0, len(m.categories)-1)
		}
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
	// Common prefix of all target-relative paths in the category.
	// filepath.Dir on relative paths bottoms out at "." — that (not "/")
	// is the loop's floor, and it is the correct base for top-level
	// dotfiles: filepath.Rel(".", ".zshrc") == ".zshrc".
	basePath := ""
	if len(cat.Files) > 0 {
		basePath = filepath.Dir(cat.Files[0].TargetRel)
		for _, f := range cat.Files[1:] {
			for basePath != "." && !strings.HasPrefix(f.TargetRel, basePath+"/") {
				basePath = filepath.Dir(basePath)
			}
		}
	}

	// Build relative paths and sort
	type fileInfo struct {
		RelPath string
		File    configFile
	}
	var files []fileInfo
	for _, f := range cat.Files {
		rel, err := filepath.Rel(basePath, f.TargetRel)
		if err != nil || strings.HasPrefix(rel, "..") {
			rel = f.TargetRel
		}
		files = append(files, fileInfo{RelPath: rel, File: f})
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
			Name:       parts[len(parts)-1],
			Path:       f.File.TargetRel,
			SourcePath: f.File.SourcePath,
			Depth:      len(parts) - 1,
			IsDir:      false,
			Dirty:      f.File.Dirty,
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
		if f.IsTemplate {
			return true
		}
	}
	return false
}

// SetSize updates the model dimensions.
func (m *ConfigsModel) SetSize(w, h int) {
	m.width = w
	m.height = h
	m.diffView.Width = w
	m.diffView.Height = h - 2
}

// categoryForTarget derives a presentation category from a target path:
// .config/<name>/... (or a file directly under .config) groups under <name>;
// everything else is a top-level dotfile in the "home" category.
func categoryForTarget(target string) string {
	rest, ok := strings.CutPrefix(target, ".config/")
	if !ok {
		return "home"
	}
	if i := strings.IndexByte(rest, '/'); i >= 0 {
		return rest[:i]
	}
	return rest
}

func (m ConfigsModel) scanCategories() tea.Cmd {
	return func() tea.Msg {
		r := runner.New(m.dotsDir)

		managed := r.Run("chezmoi", "managed", "--include=files")
		if managed.ExitCode != 0 {
			return categoriesLoadedMsg{err: "chezmoi managed failed: " + strings.TrimSpace(managed.Stderr)}
		}
		var targets []string
		for _, line := range strings.Split(strings.TrimSpace(managed.Stdout), "\n") {
			if line = strings.TrimSpace(line); line != "" {
				targets = append(targets, line)
			}
		}
		sort.Strings(targets)

		// Targets with pending differences per chezmoi status \u2014 either a
		// local edit or an unapplied source change (both matter to a user
		// browsing configs, matching the tab's existing behavior).
		dirtyFiles := make(map[string]bool)
		if st := r.Run("chezmoi", "status"); st.ExitCode == 0 {
			for _, line := range strings.Split(strings.TrimSpace(st.Stdout), "\n") {
				if len(line) > 3 {
					dirtyFiles[strings.TrimSpace(line[2:])] = true
				}
			}
		}

		// Resolve all source paths in one call. chezmoi prints results
		// sorted by TARGET PATH, not argument order \u2014 the sort.Strings on
		// targets above is load-bearing: it makes arg order match output
		// order (chezmoi's sort matches Go's byte-wise string sort).
		sourceFor := make(map[string]string, len(targets))
		home, homeErr := os.UserHomeDir()
		if homeErr == nil && len(targets) > 0 {
			args := make([]string, 0, len(targets)+1)
			args = append(args, "source-path")
			for _, t := range targets {
				args = append(args, filepath.Join(home, t))
			}
			if sp := r.Run("chezmoi", args...); sp.ExitCode == 0 {
				lines := strings.Split(strings.TrimSpace(sp.Stdout), "\n")
				if len(lines) == len(targets) {
					for i, t := range targets {
						sourceFor[t] = strings.TrimSpace(lines[i])
					}
				}
			}
			// A source-path failure degrades gracefully: files still list,
			// editing falls back to an error toast for unresolved entries.
		}

		iconMap := map[string]string{
			"kitty": " ",
			"nvim":  " ",
			"home":  " ",
		}
		defaultIcon := " "

		grouped := make(map[string][]configFile)
		var order []string
		for _, t := range targets {
			cat := categoryForTarget(t)
			if _, seen := grouped[cat]; !seen {
				order = append(order, cat)
			}
			src := sourceFor[t]
			grouped[cat] = append(grouped[cat], configFile{
				TargetRel:  t,
				SourcePath: src,
				IsTemplate: strings.HasSuffix(src, ".tmpl"),
				Dirty:      dirtyFiles[t],
			})
		}
		sort.Strings(order)

		var cats []configCategory
		for _, name := range order {
			files := grouped[name]
			dirtyCount := 0
			for _, f := range files {
				if f.Dirty {
					dirtyCount++
				}
			}
			icon := defaultIcon
			if ic, ok := iconMap[name]; ok {
				icon = ic
			}
			cats = append(cats, configCategory{Name: name, Icon: icon, Files: files, DirtyCount: dirtyCount})
		}

		return categoriesLoadedMsg{categories: cats}
	}
}

func (m ConfigsModel) fetchDiff(targetRel string) tea.Cmd {
	return func() tea.Msg {
		home, err := os.UserHomeDir()
		if err != nil {
			return diffResultMsg{Content: StyleError.Render("Error: " + err.Error())}
		}
		result := m.runner.Run("chezmoi", "diff", filepath.Join(home, targetRel))
		if result.ExitCode != 0 {
			return diffResultMsg{Content: StyleError.Render("chezmoi diff failed:") + "\n" + strings.TrimSpace(result.Stderr)}
		}
		content := result.Stdout
		if strings.TrimSpace(content) == "" {
			content = "No differences found."
		}
		return diffResultMsg{Content: content}
	}
}
