package app

import (
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

// fakeFix returns a PreflightIssue whose fix appends its name to order.
func fakeFix(name string, order *[]string) PreflightIssue {
	return PreflightIssue{
		Message:  name,
		Severity: severityAsk,
		FixCmd: func() tea.Cmd {
			return func() tea.Msg {
				*order = append(*order, name)
				return FixCompleteMsg{Toast: ToastMsg{Message: name, Level: ToastSuccess}}
			}
		},
	}
}

func drain(cmd tea.Cmd) []tea.Msg {
	if cmd == nil {
		return nil
	}
	msg := cmd()
	if batch, ok := msg.(tea.BatchMsg); ok {
		var msgs []tea.Msg
		for _, c := range batch {
			msgs = append(msgs, drain(c)...)
		}
		return msgs
	}
	return []tea.Msg{msg}
}

func TestInitRunResetsAwaitingResolve(t *testing.T) {
	m := NewSyncModel(t.TempDir())
	m.awaitingResolve = true
	m.pendingAction = syncActionPush
	m.fixQueue = []tea.Cmd{func() tea.Msg { return nil }}

	m.initRun(syncActionUpdate)

	if m.awaitingResolve {
		t.Error("initRun must reset awaitingResolve")
	}
	if m.fixQueue != nil {
		t.Error("initRun must clear fixQueue")
	}
}

func TestDoubleXDoesNotRaceFixes(t *testing.T) {
	var order []string
	m := NewSyncModel(t.TempDir())
	m.awaitingResolve = true
	m.pendingAction = syncActionPush
	m.preflightIssues = []PreflightIssue{
		fakeFix("fix1", &order),
		fakeFix("fix2", &order),
	}

	m2, cmd := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'x'}})
	m = m2
	msgs := drain(cmd)
	// Second x before fix1's completion must be a no-op.
	m2, cmd2 := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'x'}})
	m = m2
	if cmd2 != nil {
		t.Fatal("second x while a fix is in flight must dispatch nothing")
	}
	if len(order) != 1 {
		t.Fatalf("only fix1 may have run; order=%v", order)
	}
	if m.running {
		t.Fatal("script must not start")
	}
	// Feed fix1's completion: fix2 still pending as an ask issue, no start.
	var fc FixCompleteMsg
	for _, msg := range msgs {
		if f, ok := msg.(FixCompleteMsg); ok {
			fc = f
		}
	}
	m2, _ = m.Update(fc)
	m = m2
	if m.running {
		t.Fatal("script must not start while an ask issue remains")
	}
	if m.fixInFlight {
		t.Fatal("fixInFlight must clear on completion")
	}
}

func TestFixAllRunsSequentiallyThenStarts(t *testing.T) {
	var order []string
	m := NewSyncModel(t.TempDir())
	m.awaitingResolve = true
	m.pendingAction = syncActionPush
	m.preflightIssues = []PreflightIssue{
		fakeFix("fix1", &order),
		fakeFix("fix2", &order),
	}

	// Press X: only the FIRST fix may be dispatched; the second waits.
	m2, cmd := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'X'}})
	m = m2
	if m.running {
		t.Fatal("script must not start while fixes are pending")
	}
	msgs := drain(cmd)
	if len(order) != 1 || order[0] != "fix1" {
		t.Fatalf("after X, exactly fix1 must have run; order=%v", order)
	}

	// Feed fix1's completion back: fix2 must run next, still no script.
	var fc FixCompleteMsg
	found := false
	for _, msg := range msgs {
		if f, ok := msg.(FixCompleteMsg); ok {
			fc, found = f, true
		}
	}
	if !found {
		t.Fatal("expected a FixCompleteMsg from the first fix")
	}
	m2, cmd = m.Update(fc)
	m = m2
	if m.running {
		t.Fatal("script must not start before the last fix completes")
	}
	msgs = drain(cmd)
	if len(order) != 2 || order[1] != "fix2" {
		t.Fatalf("fix2 must run after fix1 completes; order=%v", order)
	}

	// Feed fix2's completion: now the script may start.
	found = false
	for _, msg := range msgs {
		if f, ok := msg.(FixCompleteMsg); ok {
			fc, found = f, true
		}
	}
	if !found {
		t.Fatal("expected a FixCompleteMsg from the second fix")
	}
	m2, _ = m.Update(fc)
	m = m2
	if !m.running {
		t.Error("script must start once all fixes completed")
	}
	if m.awaitingResolve {
		t.Error("awaitingResolve must be false after start")
	}
	if m.cancelRun != nil {
		m.cancelRun() // clean up the goroutine startScript spawned
	}
}
