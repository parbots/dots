# Sync Tab Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the sync tab with real-time streaming progress, prominent action cards, responsive split-pane layout, and expandable scrollable history.

**Architecture:** Replace the current `SyncModel` with a new model that uses `RunStream` for real-time output, step detection via ANSI-stripped prefix matching, a focus system for actions vs history, and responsive wide/narrow layouts. The existing `RunStream` and `stripANSI` utilities are reused as-is.

**Tech Stack:** Go, Bubble Tea, Lip Gloss, Bubbles (spinner)

**Spec:** `docs/superpowers/specs/2026-03-30-sync-tab-redesign.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `tui/internal/app/sync.go` | Rewrite | SyncModel: layout, focus, step tracking, streaming, history |
| `tui/internal/app/sync_steps.go` | Create | Step definitions, step detection logic, ANSI stripping for matching |
| `tui/internal/app/sync_steps_test.go` | Create | Unit tests for step detection |
| `tui/internal/app/app.go` | Modify | Route `StreamLineMsg` directly to sync tab |
| `tui/internal/app/theme.go` | No change | Already has `StyleBorder`, `StyleDimmed`, `StyleSuccess`, `StyleError`, `stripANSI` |
| `tui/internal/app/status.go` | No change | `SyncLogEntry` and `parseSyncLog` stay here |

---

## Chunk 1: Step Detection Engine

### Task 1: Define step types and detection logic

**Files:**
- Create: `tui/internal/app/sync_steps.go`
- Create: `tui/internal/app/sync_steps_test.go`

- [ ] **Step 1: Write failing tests for step detection**

Create `tui/internal/app/sync_steps_test.go`:

```go
package app

import "testing"

func TestStepsForAction(t *testing.T) {
	tests := []struct {
		action syncAction
		want   []string
	}{
		{syncActionUpdate, []string{"Pull", "Apply"}},
		{syncActionPush, []string{"Capture", "Stage", "Commit", "Push"}},
		{syncActionFull, []string{"Push", "Pull"}},
	}
	for _, tt := range tests {
		steps := stepsForAction(tt.action)
		if len(steps) != len(tt.want) {
			t.Errorf("action %d: got %d steps, want %d", tt.action, len(steps), len(tt.want))
			continue
		}
		for i, s := range steps {
			if s.label != tt.want[i] {
				t.Errorf("action %d step %d: got %q, want %q", tt.action, i, s.label, tt.want[i])
			}
		}
	}
}

func TestDetectStep(t *testing.T) {
	steps := stepsForAction(syncActionUpdate)

	tests := []struct {
		line    string
		wantIdx int
		wantAdv bool
	}{
		{"\033[0;34mPulling latest changes...\033[0m", 0, true},
		{"Pulling latest changes...", 0, true},
		{"\033[0;32mGit pull complete.\033[0m", 1, true},
		{"\033[0;34mApplying chezmoi configs...\033[0m", 1, false}, // already at step 1
		{"\033[0;32mConfigs applied successfully.\033[0m", -1, true}, // signals done
		{"some random output", -1, false},
	}

	idx := -1
	for _, tt := range tests {
		newIdx, advanced := detectStep(tt.line, steps, idx)
		if advanced != tt.wantAdv {
			t.Errorf("line %q: advanced=%v, want %v", tt.line, advanced, tt.wantAdv)
		}
		if advanced {
			idx = newIdx
		}
	}
}

func TestDetectStepPush(t *testing.T) {
	steps := stepsForAction(syncActionPush)

	lines := []string{
		"\033[0;34mCapturing local config changes...\033[0m",
		"\033[0;34mStaging changes...\033[0m",
		"\033[0;34mCommitting: dots: update configs/\033[0m",
		"\033[0;34mPushing to remote...\033[0m",
		"\033[0;32mPush complete.\033[0m",
	}

	idx := -1
	for i, line := range lines {
		newIdx, advanced := detectStep(line, steps, idx)
		if !advanced {
			t.Errorf("line %d %q: expected step advance", i, line)
		}
		idx = newIdx
	}
	// After "Push complete", idx should be -1 (done signal)
	if idx != -1 {
		t.Errorf("expected idx=-1 (done), got %d", idx)
	}
}

func TestDetectStepIgnoresRepeatedTrigger(t *testing.T) {
	steps := stepsForAction(syncActionUpdate)

	// First trigger advances to step 0
	idx, _ := detectStep("Pulling latest changes...", steps, -1)

	// Same trigger again should NOT advance
	_, advanced := detectStep("Pulling latest changes...", steps, idx)
	if advanced {
		t.Error("expected no advance on repeated trigger for already-passed step")
	}
}

func TestDetectStepPushEarlyExit(t *testing.T) {
	steps := stepsForAction(syncActionPush)
	idx := -1

	// "No changes to push" should signal all done
	newIdx, advanced := detectStep("\033[0;33mNo changes to push.\033[0m", steps, idx)
	if !advanced {
		t.Error("expected advance on early exit")
	}
	if newIdx != -1 {
		t.Errorf("expected idx=-1 (done), got %d", newIdx)
	}
}

func TestDetectStepFullSync(t *testing.T) {
	steps := stepsForAction(syncActionFull)

	lines := []string{
		"\033[0;34mPhase 1: Pushing local changes...\033[0m",
		"\033[0;34mPhase 2: Pulling remote changes...\033[0m",
		"\033[0;32mSync complete.\033[0m",
	}

	idx := -1
	for i, line := range lines {
		newIdx, advanced := detectStep(line, steps, idx)
		if !advanced {
			t.Errorf("line %d %q: expected step advance", i, line)
		}
		idx = newIdx
	}
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd tui && go test ./internal/app/ -run "TestStepsFor|TestDetectStep" -v`
Expected: FAIL — `stepsForAction` and `detectStep` are not defined.

- [ ] **Step 3: Implement step types and detection**

Create `tui/internal/app/sync_steps.go`:

```go
package app

import "strings"

// stepStatus represents the current state of a step.
type stepStatus int

const (
	stepPending stepStatus = iota
	stepRunning
	stepDone
	stepFailed
)

// syncStep defines a step in a sync action with its detection trigger.
type syncStep struct {
	label   string
	trigger string // prefix to match (after ANSI stripping)
	status  stepStatus
}

// stepsForAction returns the step definitions for a given sync action.
func stepsForAction(action syncAction) []syncStep {
	switch action {
	case syncActionUpdate:
		return []syncStep{
			{label: "Pull", trigger: "Pulling latest"},
			{label: "Apply", trigger: "Applying chezmoi"},
		}
	case syncActionPush:
		return []syncStep{
			{label: "Capture", trigger: "Capturing local"},
			{label: "Stage", trigger: "Staging changes"},
			{label: "Commit", trigger: "Committing:"},
			{label: "Push", trigger: "Pushing to remote"},
		}
	case syncActionFull:
		return []syncStep{
			{label: "Push", trigger: "Phase 1:"},
			{label: "Pull", trigger: "Phase 2:"},
		}
	}
	return nil
}

// completionTriggers are prefixes that signal a step (or the whole action) is done.
var completionTriggers = map[string]bool{
	"Git pull complete":            true,
	"Configs applied":              true,
	"Update complete":              true,
	"Push complete":                true,
	"Sync complete":                true,
}

// earlyExitTriggers signal the entire action is done early.
var earlyExitTriggers = map[string]bool{
	"No changes to push": true,
}

// detectStep checks a line against step triggers and returns the new step index
// and whether a step transition occurred.
// Returns idx=-1 and advanced=true to signal "all done".
// The line is ANSI-stripped before matching.
func detectStep(line string, steps []syncStep, currentIdx int) (int, bool) {
	clean := stripANSI(line)

	// Check early exit
	for prefix := range earlyExitTriggers {
		if strings.HasPrefix(clean, prefix) {
			return -1, true
		}
	}

	// Check completion triggers (advance past current step)
	for prefix := range completionTriggers {
		if strings.HasPrefix(clean, prefix) {
			// If we're at or past the last step, signal done
			if currentIdx >= len(steps)-1 {
				return -1, true
			}
			// Otherwise advance to next step
			return currentIdx + 1, true
		}
	}

	// Check step triggers (start a new step)
	for i, step := range steps {
		if i <= currentIdx {
			continue // already past this step
		}
		if strings.HasPrefix(clean, step.trigger) {
			return i, true
		}
	}

	return currentIdx, false
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd tui && go test ./internal/app/ -run "TestStepsFor|TestDetectStep" -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tui/internal/app/sync_steps.go tui/internal/app/sync_steps_test.go
git commit -m "feat(sync): add step detection engine for streaming progress"
```

---

## Chunk 2: Streaming Messages and App Routing

### Task 2: Add StreamLineMsg and route it in app.go

**Files:**
- Modify: `tui/internal/app/sync.go` (add message type only)
- Modify: `tui/internal/app/app.go:170-177` (add routing)

- [ ] **Step 1: Add StreamLineMsg type to sync.go**

Add near the top of `sync.go`, next to the existing `RunCompleteMsg`:

```go
// StreamLineMsg delivers a single line from a running script's stdout.
type StreamLineMsg struct {
	Line string
}
```

- [ ] **Step 2: Route StreamLineMsg directly to sync tab in app.go**

In `app.go`, add a case alongside the existing `RunCompleteMsg` routing (around line 170):

```go
	case StreamLineMsg:
		var cmd tea.Cmd
		m.syncTab, cmd = m.syncTab.Update(msg)
		return m, cmd
```

- [ ] **Step 3: Verify it compiles**

Run: `cd tui && go build ./...`
Expected: Compiles with no errors.

- [ ] **Step 4: Commit**

```bash
git add tui/internal/app/sync.go tui/internal/app/app.go
git commit -m "feat(sync): add StreamLineMsg type and direct routing in app"
```

---

## Chunk 3: Rewrite SyncModel

### Task 3: Replace sync.go with complete rewrite

**Files:**
- Rewrite: `tui/internal/app/sync.go`

This task replaces the entire `sync.go` file atomically to avoid intermediate compilation failures. Write the complete new file containing all sections below.

- [ ] **Step 1: Write the new SyncModel struct and constructor**

The new `sync.go` file starts with these types and constructor:

```go
type syncFocus int

const (
	focusActions syncFocus = iota
	focusHistory
)

// SyncModel is the Bubble Tea model for the sync tab.
type SyncModel struct {
	dotsDir string
	runner  *runner.Runner
	width   int
	height  int

	// Action selection
	selected int
	running  bool
	spinner  spinner.Model

	// Focus
	focus syncFocus

	// Step progress
	steps   []syncStep
	stepIdx int

	// Streaming log
	logLines  []string
	logScroll int // scroll offset within the streaming log (auto-scrolls to bottom)
	lineCh    chan string
	scroll    int // page-level scroll for renderScrollView

	// History
	history       []SyncLogEntry
	historyCursor int
	expanded      map[int]bool
}

// NewSyncModel creates a new SyncModel.
func NewSyncModel(dotsDir string) SyncModel {
	s := spinner.New(spinner.WithSpinner(spinner.Dot))
	s.Style = lipgloss.NewStyle().Foreground(ColorMauve)

	return SyncModel{
		dotsDir:  dotsDir,
		runner:   runner.New(dotsDir),
		spinner:  s,
		expanded: make(map[int]bool),
	}
}
```

Also include `SetSize`:

```go
// SetSize updates the model dimensions.
func (m *SyncModel) SetSize(w, h int) {
	m.width = w
	m.height = h
}
```

- [ ] **Step 2: Write the streaming initRun and TriggerAction**

```go
func (m *SyncModel) initRun(action syncAction) tea.Cmd {
	if m.running {
		return nil // guard against double-start
	}
	m.running = true
	m.logLines = nil
	m.logScroll = 0
	m.steps = stepsForAction(action)
	m.stepIdx = -1
	m.focus = focusActions

	// Mark first step as running
	if len(m.steps) > 0 {
		m.steps[0].status = stepRunning
		m.stepIdx = 0
	}

	lineCh := make(chan string, 64)
	doneCh := make(chan RunCompleteMsg, 1)
	m.lineCh = lineCh

	var script string
	switch action {
	case syncActionUpdate:
		script = filepath.Join(m.dotsDir, "scripts", "update.sh")
	case syncActionPush:
		script = filepath.Join(m.dotsDir, "scripts", "push.sh")
	case syncActionFull:
		script = filepath.Join(m.dotsDir, "scripts", "sync.sh")
	}

	// Start the script in a goroutine
	go func() {
		result := m.runner.RunStream("bash", lineCh, script)
		close(lineCh)
		errStr := ""
		if result.ExitCode != 0 {
			errStr = result.Stderr
		}
		doneCh <- RunCompleteMsg{
			Action:   action,
			ExitCode: result.ExitCode,
			Err:      errStr,
			Output:   result.Stdout,
		}
	}()

	return tea.Batch(m.spinner.Tick, waitForLine(lineCh, doneCh))
}

func waitForLine(lines <-chan string, done <-chan RunCompleteMsg) tea.Cmd {
	return func() tea.Msg {
		select {
		case line, ok := <-lines:
			if ok {
				return StreamLineMsg{Line: line}
			}
			return <-done
		case msg := <-done:
			return msg
		}
	}
}
```

Also include `TriggerAction`:

```go
// TriggerAction sets up and runs a sync action from outside the model.
func (m *SyncModel) TriggerAction(action syncAction) tea.Cmd {
	m.selected = int(action)
	return m.initRun(action)
}
```

And the `Init` and `loadHistory` methods (unchanged logic):

```go
// Init initializes the sync model.
func (m SyncModel) Init() tea.Cmd {
	return m.loadHistory()
}

func (m SyncModel) loadHistory() tea.Cmd {
	return func() tea.Msg {
		entries, _ := parseSyncLog()
		return syncHistoryMsg(entries)
	}
}
```

- [ ] **Step 3: Write the Update method**

```go
// Update handles messages for the sync model.
func (m SyncModel) Update(msg tea.Msg) (SyncModel, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		if m.running {
			// Only allow scrolling while running
			switch msg.String() {
			case "ctrl+d":
				m.scroll += m.height / 2
			case "ctrl+u":
				m.scroll -= m.height / 2
				if m.scroll < 0 {
					m.scroll = 0
				}
			}
			return m, nil
		}
		switch msg.String() {
		case "j", "down":
			if m.focus == focusActions {
				if m.selected < 2 {
					m.selected++
				}
			} else {
				if m.historyCursor < len(m.history)-1 {
					m.historyCursor++
				}
			}
		case "k", "up":
			if m.focus == focusActions {
				if m.selected > 0 {
					m.selected--
				}
			} else {
				if m.historyCursor > 0 {
					m.historyCursor--
				}
			}
		case "enter":
			if m.focus == focusActions {
				return m, m.initRun(syncAction(m.selected))
			}
			// Toggle history expansion
			if len(m.history) > 0 {
				m.expanded[m.historyCursor] = !m.expanded[m.historyCursor]
			}
		case "f":
			if m.focus == focusActions {
				m.focus = focusHistory
			} else {
				m.focus = focusActions
			}
		case "ctrl+d":
			m.scroll += m.height / 2
		case "ctrl+u":
			m.scroll -= m.height / 2
			if m.scroll < 0 {
				m.scroll = 0
			}
		}
		return m, nil

	case StreamLineMsg:
		m.logLines = append(m.logLines, msg.Line)
		// Detect step transitions
		newIdx, advanced := detectStep(msg.Line, m.steps, m.stepIdx)
		if advanced {
			// Mark current step done
			if m.stepIdx >= 0 && m.stepIdx < len(m.steps) {
				m.steps[m.stepIdx].status = stepDone
			}
			if newIdx >= 0 && newIdx < len(m.steps) {
				m.steps[newIdx].status = stepRunning
				m.stepIdx = newIdx
			} else {
				// All done — mark remaining steps done
				for i := range m.steps {
					if m.steps[i].status != stepDone {
						m.steps[i].status = stepDone
					}
				}
				m.stepIdx = len(m.steps)
			}
		}
		// Auto-scroll log to bottom
		m.logScroll = len(m.logLines)
		return m, waitForLine(m.lineCh, m.doneCh)

	case RunCompleteMsg:
		m.running = false
		m.focus = focusActions // reset focus per spec
		// Append stderr on failure
		if msg.Err != "" {
			m.logLines = append(m.logLines, StyleError.Render("Error: "+msg.Err))
		}
		// Mark steps based on result
		if msg.ExitCode == 0 {
			for i := range m.steps {
				m.steps[i].status = stepDone
			}
			m.logLines = append(m.logLines, StyleSuccess.Render("Completed successfully."))
		} else {
			// Mark current running step as failed
			for i := range m.steps {
				if m.steps[i].status == stepRunning {
					m.steps[i].status = stepFailed
				}
			}
			m.logLines = append(m.logLines, StyleError.Render(fmt.Sprintf("Exited with code %d", msg.ExitCode)))
		}
		m.logScroll = len(m.logLines)
		return m, m.loadHistory()

	case syncHistoryMsg:
		m.history = []SyncLogEntry(msg)
		return m, nil

	case spinner.TickMsg:
		if m.running {
			var cmd tea.Cmd
			m.spinner, cmd = m.spinner.Update(msg)
			return m, cmd
		}
	}

	return m, nil
}
```

- [ ] **Step 4: Write action card rendering**

```go
type actionCard struct {
	icon string
	name string
	desc string
}

var actionCards = []actionCard{
	{icon: "⟳", name: "Update", desc: "Pull remote changes + apply configs"},
	{icon: "⬆", name: "Push", desc: "Capture + commit + push local edits"},
	{icon: "⇅", name: "Full Sync", desc: "Push local, then pull remote"},
}

func (m SyncModel) renderActions() string {
	var b strings.Builder

	titleStyle := StyleTitle
	if m.focus != focusActions {
		titleStyle = StyleDimmed
	}
	b.WriteString(titleStyle.Render("  Actions") + "\n\n")

	for i, card := range actionCards {
		selected := i == m.selected
		isRunning := m.running && i == m.selected

		var icon string
		if isRunning {
			icon = m.spinner.View()
		} else {
			icon = card.icon
		}

		nameStyle := lipgloss.NewStyle().Foreground(ColorOverlay1)
		if selected && m.focus == focusActions {
			nameStyle = lipgloss.NewStyle().Foreground(ColorMauve).Bold(true)
		}

		descStyle := StyleDimmed

		// Selection indicator
		indicator := "  "
		if selected && m.focus == focusActions {
			indicator = StyleKey.Render("▸ ")
		}

		b.WriteString(indicator + icon + " " + nameStyle.Render(card.name) + "\n")
		b.WriteString("    " + descStyle.Render(card.desc) + "\n")
		if i < len(actionCards)-1 {
			b.WriteString("\n")
		}
	}

	return b.String()
}
```

- [ ] **Step 5: Write progress pane rendering**

```go
func (m SyncModel) renderProgress() string {
	var b strings.Builder

	b.WriteString(StyleTitle.Render("  Progress") + "\n\n")

	// Step indicators
	if len(m.steps) > 0 {
		var stepParts []string
		for _, step := range m.steps {
			var icon string
			var style lipgloss.Style
			switch step.status {
			case stepPending:
				icon = "·"
				style = lipgloss.NewStyle().Foreground(ColorOverlay0)
			case stepRunning:
				icon = m.spinner.View()
				style = lipgloss.NewStyle().Foreground(ColorMauve)
			case stepDone:
				icon = "✓"
				style = lipgloss.NewStyle().Foreground(ColorGreen)
			case stepFailed:
				icon = "✗"
				style = lipgloss.NewStyle().Foreground(ColorRed)
			}
			stepParts = append(stepParts, icon+" "+style.Render(step.label))
		}
		b.WriteString("  " + strings.Join(stepParts, "   ") + "\n")
		b.WriteString("  " + lipgloss.NewStyle().Foreground(ColorSurface2).Render(
			strings.Repeat("─", 30)) + "\n")
	}

	// Streaming log (windowed: show last N lines that fit in the available height)
	if len(m.logLines) > 0 {
		maxLogLines := m.height/3
		if maxLogLines < 5 {
			maxLogLines = 5
		}
		start := 0
		if len(m.logLines) > maxLogLines {
			start = len(m.logLines) - maxLogLines
		}
		for _, line := range m.logLines[start:] {
			b.WriteString("  " + line + "\n")
		}
	} else if !m.running {
		b.WriteString(StyleDimmed.Render("  No output yet. Select an action and press enter.") + "\n")
	}

	return b.String()
}
```

- [ ] **Step 6: Write history section rendering**

```go
func (m SyncModel) renderHistory() string {
	var b strings.Builder

	titleStyle := StyleTitle
	if m.focus != focusHistory {
		titleStyle = StyleDimmed
	}

	count := len(m.history)
	if count > 50 {
		count = 50
	}
	b.WriteString(titleStyle.Render(fmt.Sprintf("  History (%d)", count)) + "\n")

	if len(m.history) == 0 {
		b.WriteString(StyleDimmed.Render("  No sync history.") + "\n")
		return b.String()
	}

	// Show most recent 50 entries (newest last in the slice, display newest first)
	start := 0
	if len(m.history) > 50 {
		start = len(m.history) - 50
	}
	entries := m.history[start:]

	for i := len(entries) - 1; i >= 0; i-- {
		entry := entries[i]
		globalIdx := start + i // index into m.history for expansion tracking

		resultStyle := StyleSuccess
		resultIcon := "✓"
		if entry.Result != "success" {
			resultStyle = StyleError
			resultIcon = "✗"
		}

		// Cursor indicator
		indicator := "  "
		if m.focus == focusHistory && m.historyCursor == len(entries)-1-i {
			indicator = StyleKey.Render("▸ ")
		}

		// Expand/collapse icon
		expandIcon := "▸"
		if m.expanded[globalIdx] {
			expandIcon = "▾"
		}

		b.WriteString(fmt.Sprintf("%s%s %s  %-8s  %s %s  %s\n",
			indicator,
			StyleDimmed.Render(expandIcon),
			StyleDimmed.Render(entry.Timestamp),
			entry.Action,
			resultStyle.Render(resultIcon),
			resultStyle.Render(entry.Result),
			StyleDimmed.Render(fmt.Sprintf("%dms", entry.DurationMs)),
		))

		if m.expanded[globalIdx] {
			details := entry.Details
			if details == "" {
				details = "No additional details."
			}
			b.WriteString("    " + StyleDimmed.Render(details) + "\n")
		}
	}

	return b.String()
}
```

- [ ] **Step 7: Write responsive layout composition and View**

```go
// View renders the sync tab.
func (m SyncModel) View() string {
	return renderScrollView(m.renderContent(), &m.scroll, m.width, m.height, [][2]string{
		{"j/k", "select"},
		{"enter", "run"},
		{"f", "focus"},
		{"ctrl+d/u", "scroll"},
		{"tab", "tabs"},
		{"y", "copy"},
		{"q", "quit"},
	})
}

func (m SyncModel) renderContent() string {
	if m.width >= 80 {
		return m.renderWideLayout()
	}
	return m.renderNarrowLayout()
}

func (m SyncModel) renderWideLayout() string {
	var b strings.Builder

	// Top row: actions (left) + progress (right)
	actionsWidth := m.width * 30 / 100
	if actionsWidth < 25 {
		actionsWidth = 25
	}
	progressWidth := m.width - actionsWidth - 3 // 3 for gap

	actionsStyle := lipgloss.NewStyle().Width(actionsWidth)
	progressStyle := lipgloss.NewStyle().Width(progressWidth)

	topRow := lipgloss.JoinHorizontal(lipgloss.Top,
		actionsStyle.Render(m.renderActions()),
		"   ",
		progressStyle.Render(m.renderProgress()),
	)
	b.WriteString(topRow)
	b.WriteString("\n")

	// Separator
	b.WriteString("  " + lipgloss.NewStyle().Foreground(ColorSurface2).Render(
		strings.Repeat("─", m.width-4)) + "\n")

	// History (full width)
	b.WriteString(m.renderHistory())
	b.WriteString("\n")

	return b.String()
}

func (m SyncModel) renderNarrowLayout() string {
	var b strings.Builder

	b.WriteString(m.renderActions())
	b.WriteString("\n")
	b.WriteString(m.renderProgress())
	b.WriteString("\n")
	b.WriteString(m.renderHistory())
	b.WriteString("\n")

	return b.String()
}
```

- [ ] **Step 8: Write the complete sync.go file**

Combine ALL sections above (Steps 1-7) into a single complete `sync.go` file. The file should import `fmt`, `path/filepath`, `strings`, the Bubble Tea packages (`spinner`, `tea`, `lipgloss`), and `runner`. It should NOT import `viewport`. Write the complete file atomically to avoid intermediate compilation failures.

- [ ] **Step 9: Verify it compiles**

Run: `cd tui && go build ./...`
Expected: Compiles with no errors.

- [ ] **Step 10: Run all tests**

Run: `cd tui && go test ./... -v`
Expected: All tests pass.

- [ ] **Step 11: Commit**

```bash
git add tui/internal/app/sync.go
git commit -m "feat(sync): complete sync tab rewrite with streaming, steps, and responsive layout"
```

---

## Chunk 4: Integration and Polish

### Task 4: Manual testing and bug fixes

**Files:**
- Possibly modify: `tui/internal/app/sync.go`, `tui/internal/app/app.go`

- [ ] **Step 1: Build and run the TUI**

Run: `cd /Users/parkerb/dev/dots && make build && tui/dots`

- [ ] **Step 2: Test wide layout**

Ensure terminal is >= 80 columns wide. Navigate to the Sync tab. Verify:
- Actions cards render on the left with icons and descriptions
- Progress pane renders on the right
- History renders full-width below
- `j/k` moves the action selector
- `f` toggles focus between actions and history

- [ ] **Step 3: Test streaming**

Select "Update" and press enter. Verify:
- Spinner appears on the active card
- Step indicators advance in real-time
- Log lines stream in as the script runs
- Success/error summary appears when done

- [ ] **Step 4: Test history expansion**

Press `f` to focus history. Use `j/k` to move cursor. Press `enter` to expand/collapse entries. Verify details appear.

- [ ] **Step 5: Test narrow layout**

Resize terminal to < 80 columns. Verify sections stack vertically and remain readable.

- [ ] **Step 6: Test TriggerAction from Status tab**

If the Status tab has quick action buttons that trigger sync, verify they still work (navigate to Status, trigger an action, confirm it switches to Sync tab and runs).

- [ ] **Step 7: Fix any issues found and commit**

```bash
git add -A
git commit -m "fix(sync): polish sync tab after manual testing"
```

---

### Task 5: Final commit and cleanup

- [ ] **Step 1: Run full test suite**

Run: `cd tui && go test ./... -v`
Expected: All pass.

- [ ] **Step 2: Run linter**

Run: `make lint`
Expected: Clean.

- [ ] **Step 3: Final commit if any cleanup was needed**

```bash
git add tui/
git commit -m "chore(sync): final cleanup for sync tab redesign"
```
