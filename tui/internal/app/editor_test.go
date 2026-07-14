package app

import "testing"

func TestEditorCommand(t *testing.T) {
	cases := []struct {
		name     string
		editor   string
		files    []string
		wantPath string
		wantArgs []string
	}{
		{"plain", "vi", []string{"f.txt"}, "vi", []string{"vi", "f.txt"}},
		{"with flag", "code --wait", []string{"f.txt"}, "code", []string{"code", "--wait", "f.txt"}},
		{"multiple flags", "nvim -u NONE", []string{"a", "b"}, "nvim", []string{"nvim", "-u", "NONE", "a", "b"}},
		{"empty falls back to vi", "", []string{"f"}, "vi", []string{"vi", "f"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv("EDITOR", tc.editor)
			cmd := editorCommand(tc.files...)
			if cmd.Path != tc.wantPath && cmd.Args[0] != tc.wantPath {
				t.Errorf("argv0 = %q/%q, want %q", cmd.Path, cmd.Args[0], tc.wantPath)
			}
			if len(cmd.Args) != len(tc.wantArgs) {
				t.Fatalf("args = %v, want %v", cmd.Args, tc.wantArgs)
			}
			for i := range tc.wantArgs {
				if cmd.Args[i] != tc.wantArgs[i] {
					t.Errorf("args[%d] = %q, want %q", i, cmd.Args[i], tc.wantArgs[i])
				}
			}
		})
	}
}
