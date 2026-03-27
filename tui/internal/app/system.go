package app

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/parbots/dots/internal/runner"
	"github.com/parbots/dots/internal/scheduler"
)

type systemInfo struct {
	Model          string
	Chip           string
	Memory         string
	Disk           string
	OSVersion      string
	KernelVersion  string
	Shell          string
	ShellVersion   string
	Hostname       string
	LocalIP        string
	Tools          map[string]string
	ChezmoiDoctor  string
	ScheduleStatus string
}

type systemInfoMsg struct {
	info systemInfo
}

// SystemModel is the Bubble Tea model for the system tab.
type SystemModel struct {
	dotsDir   string
	runner    *runner.Runner
	scheduler *scheduler.Scheduler
	info      systemInfo
	spinner   spinner.Model
	loading   bool
	cached    bool
	scroll    int
	content   string
	width     int
	height    int
}

// NewSystemModel creates a new SystemModel.
func NewSystemModel(dotsDir string) SystemModel {
	s := spinner.New(spinner.WithSpinner(spinner.Dot))
	s.Style = lipgloss.NewStyle().Foreground(ColorMauve)

	return SystemModel{
		dotsDir:   dotsDir,
		runner:    runner.New(dotsDir),
		scheduler: scheduler.New(dotsDir),
		spinner:   s,
		loading:   true,
	}
}

// Init does nothing — system info is gathered on first tab focus.
func (m SystemModel) Init() tea.Cmd {
	return nil
}

// Refresh starts gathering info if not cached. Returns spinner tick + gather cmd.
func (m *SystemModel) Refresh() tea.Cmd {
	if m.cached {
		m.loading = false
		return nil
	}
	m.loading = true
	return tea.Batch(m.spinner.Tick, m.gatherInfo())
}

// Update handles messages for the system model.
func (m SystemModel) Update(msg tea.Msg) (SystemModel, tea.Cmd) {
	switch msg := msg.(type) {
	case systemInfoMsg:
		m.info = msg.info
		m.loading = false
		m.cached = true
		m.content = m.renderContent()
		m.scroll = 0
		return m, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+d":
			m.scrollDown()
			return m, nil
		case "ctrl+u":
			m.scrollUp()
			return m, nil
		}

	case spinner.TickMsg:
		if m.loading {
			var cmd tea.Cmd
			m.spinner, cmd = m.spinner.Update(msg)
			return m, cmd
		}
	}

	return m, nil
}

// View renders the system tab.
func (m SystemModel) View() string {
	if m.loading {
		return m.spinner.View() + " Gathering system information..."
	}

	lines := strings.Split(m.content, "\n")
	totalLines := len(lines)
	visibleLines := m.height

	// Clamp scroll
	maxScroll := totalLines - visibleLines
	if maxScroll < 0 {
		maxScroll = 0
	}
	if m.scroll > maxScroll {
		m.scroll = maxScroll
	}

	// Slice visible lines
	end := m.scroll + visibleLines
	if end > totalLines {
		end = totalLines
	}
	visible := strings.Join(lines[m.scroll:end], "\n")

	// Render scrollbar
	bar := renderScrollbar(totalLines, visibleLines, m.scroll, visibleLines)
	if bar != "" {
		return lipgloss.JoinHorizontal(lipgloss.Top, visible, " ", bar)
	}
	return visible
}

// SetSize updates the model dimensions.
func (m *SystemModel) SetSize(w, h int) {
	m.width = w
	m.height = h
}

func (m *SystemModel) scrollDown() {
	lines := strings.Split(m.content, "\n")
	maxScroll := len(lines) - m.height
	if maxScroll < 0 {
		maxScroll = 0
	}
	m.scroll += m.height / 2
	if m.scroll > maxScroll {
		m.scroll = maxScroll
	}
}

func (m *SystemModel) scrollUp() {
	m.scroll -= m.height / 2
	if m.scroll < 0 {
		m.scroll = 0
	}
}

func (m SystemModel) renderContent() string {
	var b strings.Builder

	info := m.info

	// Hardware
	b.WriteString(StyleTitle.Render("  Hardware") + "\n")
	if info.Model != "" {
		b.WriteString(fmt.Sprintf("  Model:    %s\n", info.Model))
	}
	if info.Chip != "" {
		b.WriteString(fmt.Sprintf("  Chip:     %s\n", info.Chip))
	}
	if info.Memory != "" {
		b.WriteString(fmt.Sprintf("  Memory:   %s\n", info.Memory))
	}
	if info.Disk != "" {
		b.WriteString(fmt.Sprintf("  Disk:     %s\n", info.Disk))
	}
	b.WriteString("\n")

	// OS
	b.WriteString(StyleTitle.Render("  Operating System") + "\n")
	b.WriteString(fmt.Sprintf("  OS:       %s\n", info.OSVersion))
	b.WriteString(fmt.Sprintf("  Kernel:   %s\n", info.KernelVersion))
	b.WriteString(fmt.Sprintf("  Hostname: %s\n", info.Hostname))
	b.WriteString("\n")

	// Shell
	b.WriteString(StyleTitle.Render("  Shell") + "\n")
	b.WriteString(fmt.Sprintf("  %s %s\n", info.Shell, info.ShellVersion))
	b.WriteString("\n")

	// Dev Tools
	b.WriteString(StyleTitle.Render("  Developer Tools") + "\n")
	tools := []string{"chezmoi", "git", "brew", "nvim", "node", "go", "python3"}
	for _, tool := range tools {
		version, ok := info.Tools[tool]
		if ok && version != "" {
			check := StyleSuccess.Render("")
			b.WriteString(fmt.Sprintf("  %s %-10s %s\n", check, tool, StyleDimmed.Render(version)))
		} else {
			x := StyleError.Render("")
			b.WriteString(fmt.Sprintf("  %s %-10s %s\n", x, tool, StyleDimmed.Render("not found")))
		}
	}
	b.WriteString("\n")

	// Schedule
	b.WriteString(StyleTitle.Render("  Sync Schedule") + "\n")
	b.WriteString(fmt.Sprintf("  %s\n", info.ScheduleStatus))
	b.WriteString("\n")

	// Chezmoi health
	if info.ChezmoiDoctor != "" {
		b.WriteString(StyleTitle.Render("  Chezmoi Health") + "\n")
		for _, line := range strings.Split(info.ChezmoiDoctor, "\n") {
			if line == "" {
				continue
			}
			style := StyleDimmed
			if strings.Contains(line, "ok") {
				style = StyleSuccess
			} else if strings.Contains(line, "error") || strings.Contains(line, "FAIL") {
				style = StyleError
			}
			b.WriteString("  " + style.Render(line) + "\n")
		}
	}

	b.WriteString("\n")
	b.WriteString(renderHelpBar(m.width, [][2]string{
		{"ctrl+d/u", "scroll"},
	}))

	return b.String()
}

func (m SystemModel) gatherInfo() tea.Cmd {
	return func() tea.Msg {
		info := systemInfo{
			Tools: make(map[string]string),
		}

		// Hostname
		info.Hostname, _ = os.Hostname()

		// Kernel
		if out, err := exec.Command("uname", "-r").Output(); err == nil {
			info.KernelVersion = strings.TrimSpace(string(out))
		}

		// Disk
		if out, err := exec.Command("df", "-h", "/").Output(); err == nil {
			lines := strings.Split(string(out), "\n")
			if len(lines) >= 2 {
				fields := strings.Fields(lines[1])
				if len(fields) >= 4 {
					info.Disk = fmt.Sprintf("%s used / %s total (%s)", fields[2], fields[1], fields[4])
				}
			}
		}

		// Shell
		info.Shell = os.Getenv("SHELL")
		if info.Shell != "" {
			if out, err := exec.Command(info.Shell, "--version").Output(); err == nil {
				info.ShellVersion = strings.TrimSpace(strings.Split(string(out), "\n")[0])
			}
		}

		// Platform-specific
		if runtime.GOOS == "darwin" {
			if out, err := exec.Command("sysctl", "-n", "hw.model").Output(); err == nil {
				info.Model = strings.TrimSpace(string(out))
			}
			if out, err := exec.Command("sysctl", "-n", "machdep.cpu.brand_string").Output(); err == nil {
				info.Chip = strings.TrimSpace(string(out))
			}
			if out, err := exec.Command("sysctl", "-n", "hw.memsize").Output(); err == nil {
				memStr := strings.TrimSpace(string(out))
				memBytes, _ := strconv.ParseInt(memStr, 10, 64)
				if memBytes > 0 {
					info.Memory = fmt.Sprintf("%d GB", memBytes/(1024*1024*1024))
				}
			}
			if out, err := exec.Command("sw_vers", "-productVersion").Output(); err == nil {
				info.OSVersion = "macOS " + strings.TrimSpace(string(out))
			}
		} else {
			// Linux
			if data, err := os.ReadFile("/etc/os-release"); err == nil {
				for _, line := range strings.Split(string(data), "\n") {
					if strings.HasPrefix(line, "PRETTY_NAME=") {
						info.OSVersion = strings.Trim(strings.TrimPrefix(line, "PRETTY_NAME="), "\"")
						break
					}
				}
			}
			if out, err := exec.Command("free", "-h").Output(); err == nil {
				lines := strings.Split(string(out), "\n")
				if len(lines) >= 2 {
					fields := strings.Fields(lines[1])
					if len(fields) >= 2 {
						info.Memory = fields[1]
					}
				}
			}
		}

		// Tool versions
		toolCmds := map[string][]string{
			"chezmoi": {"chezmoi", "--version"},
			"git":     {"git", "--version"},
			"brew":    {"brew", "--version"},
			"nvim":    {"nvim", "--version"},
			"node":    {"node", "--version"},
			"go":      {"go", "version"},
			"python3": {"python3", "--version"},
		}
		for tool, args := range toolCmds {
			if out, err := exec.Command(args[0], args[1:]...).Output(); err == nil {
				ver := strings.TrimSpace(strings.Split(string(out), "\n")[0])
				info.Tools[tool] = ver
			}
		}

		// Schedule status
		status := m.scheduler.GetStatus()
		if status.Active {
			info.ScheduleStatus = StyleSuccess.Render("Active") + " (" + status.Backend + ")"
		} else {
			info.ScheduleStatus = StyleDimmed.Render("Inactive")
		}

		// Chezmoi doctor
		if out, err := exec.Command("chezmoi", "doctor").Output(); err == nil {
			info.ChezmoiDoctor = strings.TrimSpace(string(out))
		} else {
			// chezmoi doctor may exit non-zero but still have useful output
			if exitErr, ok := err.(*exec.ExitError); ok {
				info.ChezmoiDoctor = strings.TrimSpace(string(out)) + "\n" + strings.TrimSpace(string(exitErr.Stderr))
			}
		}

		return systemInfoMsg{info: info}
	}
}
