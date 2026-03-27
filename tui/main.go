package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/parbots/dots/internal/app"
)

var version = "dev"

func main() {
	// Handle --version flag
	if len(os.Args) > 1 && os.Args[1] == "--version" {
		fmt.Printf("dots %s\n", version)
		os.Exit(0)
	}

	// Determine dots directory
	dotsDir := os.Getenv("DOTS_DIR")
	if dotsDir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: could not determine home directory: %v\n", err)
			os.Exit(1)
		}
		dotsDir = filepath.Join(home, "dev", "dots")
	}

	// Check dots directory exists
	if info, err := os.Stat(dotsDir); err != nil || !info.IsDir() {
		fmt.Fprintf(os.Stderr, "Error: dots directory not found: %s\n", dotsDir)
		fmt.Fprintf(os.Stderr, "Set DOTS_DIR environment variable or create %s\n", dotsDir)
		os.Exit(1)
	}

	// Check required dependencies
	deps := map[string]string{
		"chezmoi": "Install: brew install chezmoi (macOS) or https://www.chezmoi.io/install/",
		"git":     "Install: brew install git (macOS) or apt install git (Linux)",
	}
	if runtime.GOOS == "darwin" {
		deps["brew"] = "Install: https://brew.sh"
	}

	for dep, hint := range deps {
		if _, err := exec.LookPath(dep); err != nil {
			fmt.Fprintf(os.Stderr, "Error: required dependency %q not found in PATH\n", dep)
			fmt.Fprintf(os.Stderr, "%s\n", hint)
			os.Exit(1)
		}
	}

	// Create and run the program
	m := app.New(dotsDir)
	p := tea.NewProgram(m, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
