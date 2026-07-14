// Package ansi provides ANSI escape-sequence stripping shared by the app
// and scheduler packages (which must not import each other).
package ansi

import "strings"

// Strip removes ANSI escape sequences from s: CSI sequences (ESC [ ... final
// byte in @-~), OSC sequences (ESC ] ... terminated by BEL or ESC \), and
// other two-character ESC sequences. Unterminated sequences at end of input
// are dropped.
func Strip(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	i := 0
	for i < len(s) {
		if s[i] != '\033' {
			b.WriteByte(s[i])
			i++
			continue
		}
		i++ // consume ESC
		if i >= len(s) {
			break
		}
		switch s[i] {
		case '[': // CSI: parameter/intermediate bytes 0x20-0x3F, final byte 0x40-0x7E
			i++
			for i < len(s) && (s[i] < 0x40 || s[i] > 0x7e) {
				i++
			}
			if i < len(s) {
				i++ // consume final byte
			}
		case ']': // OSC: terminated by BEL or ST (ESC \)
			i++
			for i < len(s) {
				if s[i] == '\a' {
					i++
					break
				}
				if s[i] == '\033' && i+1 < len(s) && s[i+1] == '\\' {
					i += 2
					break
				}
				i++
			}
		default: // two-character escape (e.g. ESC ( B)
			i++
			if i < len(s) {
				i++
			}
		}
	}
	return b.String()
}
