package ansi_test

import (
	"testing"

	"github.com/parbots/dots/internal/ansi"
)

func TestStrip(t *testing.T) {
	cases := []struct {
		name string
		in   string
		want string
	}{
		{"plain", "hello", "hello"},
		{"empty", "", ""},
		{"sgr color", "\033[0;32mgreen\033[0m", "green"},
		{"sgr bold multi", "\033[1m\033[35mbold\033[0m plain", "bold plain"},
		{"cursor up (non-SGR CSI)", "\033[2Aline", "line"},
		{"erase line", "before\033[Kafter", "beforeafter"},
		{"csi with params", "\033[1;31;40mx\033[0m", "x"},
		{"osc title BEL", "\033]0;window title\aname", "name"},
		{"osc title ST", "\033]0;window title\033\\name", "name"},
		{"bare two-char escape", "\033(Btext", "text"},
		{"truncated escape at end", "text\033[", "text"},
		{"mixed", "\033[0;34mPhase 1:\033[0m Pushing", "Phase 1: Pushing"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := ansi.Strip(tc.in); got != tc.want {
				t.Errorf("Strip(%q) = %q, want %q", tc.in, got, tc.want)
			}
		})
	}
}
