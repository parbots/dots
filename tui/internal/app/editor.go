package app

import (
	"os"
	"os/exec"
	"strings"
)

// editorCommand builds an exec.Cmd for $EDITOR with the given file
// arguments. $EDITOR values with flags ("code --wait") are split into argv
// on whitespace; quoting is not supported (YAGNI). Falls back to vi.
func editorCommand(files ...string) *exec.Cmd {
	editor := strings.TrimSpace(os.Getenv("EDITOR"))
	if editor == "" {
		editor = "vi"
	}
	parts := strings.Fields(editor)
	args := append(parts[1:], files...)
	return exec.Command(parts[0], args...)
}
