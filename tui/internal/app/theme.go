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
