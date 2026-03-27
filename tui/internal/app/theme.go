package app

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// Catppuccin Mocha palette
var (
	ColorRosewater = lipgloss.Color("#f5e0dc")
	ColorFlamingo  = lipgloss.Color("#f2cdcd")
	ColorPink      = lipgloss.Color("#f5c2e7")
	ColorMauve     = lipgloss.Color("#cba6f7")
	ColorRed       = lipgloss.Color("#f38ba8")
	ColorMaroon    = lipgloss.Color("#eba0ac")
	ColorPeach     = lipgloss.Color("#fab387")
	ColorYellow    = lipgloss.Color("#f9e2af")
	ColorGreen     = lipgloss.Color("#a6e3a1")
	ColorTeal      = lipgloss.Color("#94e2d5")
	ColorSky       = lipgloss.Color("#89dceb")
	ColorSapphire  = lipgloss.Color("#74c7ec")
	ColorBlue      = lipgloss.Color("#89b4fa")
	ColorLavender  = lipgloss.Color("#b4befe")
	ColorText      = lipgloss.Color("#cdd6f4")
	ColorSubtext1  = lipgloss.Color("#bac2de")
	ColorSubtext0  = lipgloss.Color("#a6adc8")
	ColorOverlay2  = lipgloss.Color("#9399b2")
	ColorOverlay1  = lipgloss.Color("#7f849c")
	ColorOverlay0  = lipgloss.Color("#6c7086")
	ColorSurface2  = lipgloss.Color("#585b70")
	ColorSurface1  = lipgloss.Color("#45475a")
	ColorSurface0  = lipgloss.Color("#313244")
	ColorBase      = lipgloss.Color("#1e1e2e")
	ColorMantle    = lipgloss.Color("#181825")
	ColorCrust     = lipgloss.Color("#11111b")
)

// Shared styles
var (
	StyleTitle = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorMauve)

	StyleSubtitle = lipgloss.NewStyle().
			Foreground(ColorSubtext0)

	StyleSuccess = lipgloss.NewStyle().
			Foreground(ColorGreen)

	StyleWarning = lipgloss.NewStyle().
			Foreground(ColorYellow)

	StyleError = lipgloss.NewStyle().
			Foreground(ColorRed)

	StyleBorder = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(ColorSurface2)

	StyleActiveTab = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorMauve).
			Border(lipgloss.NormalBorder(), false, false, true, false).
			BorderForeground(ColorMauve)

	StyleInactiveTab = lipgloss.NewStyle().
				Foreground(ColorOverlay1).
				Border(lipgloss.NormalBorder(), false, false, true, false).
				BorderForeground(ColorSurface0)

	StyleStatusDot = lipgloss.NewStyle().
			Bold(true)

	StyleDimmed = lipgloss.NewStyle().
			Foreground(ColorOverlay0)

	StyleKey = lipgloss.NewStyle().
			Foreground(ColorLavender).
			Bold(true)

	StyleHelp = lipgloss.NewStyle().
			Foreground(ColorOverlay1)
)

// renderScrollbar renders a vertical scrollbar for the given dimensions.
// Returns an empty string if all content fits on screen.
func renderScrollbar(totalLines, visibleLines, offset, height int) string {
	if totalLines <= visibleLines || height <= 0 {
		return ""
	}

	thumbSize := max(1, height*visibleLines/totalLines)
	maxOffset := totalLines - visibleLines
	thumbPos := 0
	if maxOffset > 0 {
		thumbPos = offset * (height - thumbSize) / maxOffset
	}

	trackStyle := lipgloss.NewStyle().Foreground(ColorSurface1)
	thumbStyle := lipgloss.NewStyle().Foreground(ColorOverlay1)

	var sb strings.Builder
	for i := range height {
		if i > 0 {
			sb.WriteByte('\n')
		}
		if i >= thumbPos && i < thumbPos+thumbSize {
			sb.WriteString(thumbStyle.Render("┃"))
		} else {
			sb.WriteString(trackStyle.Render("│"))
		}
	}
	return sb.String()
}

// renderHelpBar renders a divider line followed by keybinding hints.
// Each pair in bindings is [key, description].
func renderHelpBar(width int, bindings [][2]string) string {
	divider := lipgloss.NewStyle().
		Foreground(ColorSurface2).
		Render(strings.Repeat("─", width))

	var parts []string
	for _, b := range bindings {
		parts = append(parts, StyleKey.Render(b[0])+" "+b[1])
	}

	help := StyleHelp.Render("  " + strings.Join(parts, "  "))
	return divider + "\n" + help
}

// helpBarHeight is the number of lines the help bar occupies (divider + hints).
const helpBarHeight = 2

// renderScrollView renders scrollable content with a pinned help bar at the bottom.
// The scrollbar is aligned to the right edge and the help bar is pinned below.
func renderScrollView(content string, scroll *int, width, height int, bindings [][2]string) string {
	helpBar := renderHelpBar(width, bindings)
	contentHeight := height - helpBarHeight

	if contentHeight <= 0 {
		return helpBar
	}

	lines := strings.Split(content, "\n")
	totalLines := len(lines)

	// Clamp scroll
	maxScroll := totalLines - contentHeight
	if maxScroll < 0 {
		maxScroll = 0
	}
	if *scroll > maxScroll {
		*scroll = maxScroll
	}
	if *scroll < 0 {
		*scroll = 0
	}

	// Slice visible lines
	end := *scroll + contentHeight
	if end > totalLines {
		end = totalLines
	}
	visible := strings.Join(lines[*scroll:end], "\n")

	// Render scrollbar aligned to the right edge
	bar := renderScrollbar(totalLines, contentHeight, *scroll, contentHeight)
	if bar != "" {
		// Pad content to fill width minus scrollbar column, then join
		contentStyle := lipgloss.NewStyle().Width(width - 2) // 1 space + 1 scrollbar char
		visible = lipgloss.JoinHorizontal(lipgloss.Top,
			contentStyle.Render(visible),
			" ",
			bar,
		)
	}

	return visible + "\n" + helpBar
}

// renderScrollViewAutoScroll is like renderScrollView but auto-scrolls to keep cursorLine visible.
func renderScrollViewAutoScroll(content string, scroll *int, cursorLine, width, height int, bindings [][2]string) string {
	contentHeight := height - helpBarHeight
	if contentHeight <= 0 {
		return renderHelpBar(width, bindings)
	}

	totalLines := len(strings.Split(content, "\n"))
	maxScroll := totalLines - contentHeight
	if maxScroll < 0 {
		maxScroll = 0
	}

	// Auto-scroll to keep cursor visible with some context below
	// If cursor is near the end of content, snap to bottom
	if cursorLine+contentHeight/4 >= totalLines {
		*scroll = maxScroll
	} else if cursorLine >= *scroll+contentHeight {
		*scroll = cursorLine - contentHeight + 1
	}
	if cursorLine < *scroll {
		*scroll = cursorLine
	}

	return renderScrollView(content, scroll, width, height, bindings)
}

// stripANSI removes ANSI escape sequences from a string.
func stripANSI(s string) string {
	var result strings.Builder
	i := 0
	for i < len(s) {
		if s[i] == '\033' {
			for i < len(s) && s[i] != 'm' {
				i++
			}
			i++
		} else {
			result.WriteByte(s[i])
			i++
		}
	}
	return result.String()
}
