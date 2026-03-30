# Sync Tab Redesign

## Overview

Redesign the TUI sync tab to show real-time streaming progress, prominent action cards, and an expandable scrollable history. Replace the current sparse layout with a responsive split-pane design.

## Layout

Three sections in a responsive layout:

- **Wide terminals (>=80 cols):** Actions left column (~30%), Progress right column (~70%), History full-width below
- **Narrow terminals (<80 cols):** Single column stacked vertically: Actions, Progress, History

### ASCII Reference (wide)

```
┌─ Actions ──────────────┐ ┌─ Progress ─────────────────────────┐
│                         │ │                                     │
│  ⟳ Update               │ │  ✓ Pull    ⠋ Apply                  │
│  Pull + apply configs   │ │  ──────────────────────────────     │
│                         │ │  Pulling latest changes...          │
│  ⬆ Push                 │ │  Git pull complete.                 │
│  Commit + push edits    │ │  Applying chezmoi configs...        │
│                         │ │                                     │
│  ⇅ Full Sync            │ │                                     │
│  Push then pull         │ │                                     │
│                         │ │                                     │
└─────────────────────────┘ └─────────────────────────────────────┘
┌─ History (12 entries) ──────────────────────────────────────────┐
│ ▸ 2026-03-30 19:16  sync   ✓ success  1.2s                     │
│   pushed 3 files, pulled 0 changes                              │
│ ▸ 2026-03-30 13:28  sync   ✓ success  0.8s                     │
│   pushed 1 file, pulled 2 changes                               │
└─────────────────────────────────────────────────────────────────┘
```

## Section 1: Action Cards

Vertical list of three action cards with borders. Each card shows:

- Icon + name (bold, Mauve-colored when selected, dimmed otherwise)
- One-line description (dimmed text)

Cards:

| Action    | Icon | Description                      |
| --------- | ---- | -------------------------------- |
| Update    | ⟳    | Pull remote changes + apply configs |
| Push      | ⬆    | Capture + commit + push local edits |
| Full Sync | ⇅    | Push local, then pull remote     |

Navigation: `j/k` to select, `enter` to run. While running, input is blocked and the active card shows a spinner next to its name.

## Section 2: Progress

### Step Indicators

Horizontal row at the top of the progress pane. Each step shows a status icon and label:

- `·` pending (dimmed)
- Spinner (running, Mauve-colored)
- `✓` completed (green)
- `✗` failed (red)

Steps per action:

- **Update:** Pull -> Apply
- **Push:** Capture -> Stage -> Commit -> Push
- **Full Sync:** Push -> Pull

### Streaming Log

Below the step indicators. Lines appear in real-time as the script outputs them. Auto-scrolls to bottom as new lines arrive. Scrollable with `ctrl+d/u`. Persists after completion with a success/error summary line at the end.

### Step Detection

Match script output lines against known string prefixes to advance step state:

**Update steps:**
- "Pulling latest" -> Pull running
- "Git pull complete" -> Pull done, Apply running
- "Applying chezmoi" -> Apply running (redundant but safe)
- "Configs applied" or "Update complete" -> Apply done

**Push steps:**
- "Capturing local" -> Capture running
- "Staging changes" -> Stage running
- "Committing:" -> Commit running
- "Pushing to remote" -> Push running
- "Push complete" -> Push done
- "No changes to push" -> all done (early exit)

**Full Sync steps:**
- "Phase 1:" -> Push running
- "push ok" or Push sub-script completes -> Push done, Pull running
- "Phase 2:" -> Pull running
- "Sync complete" -> Pull done

## Section 3: History

Scrollable list of all sync log entries (no cap at 8). Part of the overall page scroll via the existing `renderScrollView` pattern.

### Collapsed entry

```
▸ 2026-03-30 19:16  sync   ✓ success  1.2s
```

### Expanded entry

```
▾ 2026-03-30 19:16  sync   ✓ success  1.2s
  pushed 3 files, pulled 0 changes
  details from sync log...
```

Expansion toggled via `[/]` to move history cursor + `enter` to expand/collapse.

The `details` field from the JSON sync log provides expansion content. For entries without details, show "No additional details."

## Focus Management

Two focus zones, toggled with `f`:

| Focus   | j/k          | enter              | ctrl+d/u       |
| ------- | ------------ | ------------------ | -------------- |
| Actions | Select card  | Run selected action | Scroll log     |
| History | Move cursor  | Expand/collapse    | Scroll log     |

Default focus: Actions. After a run completes, focus returns to Actions.

Visual indicator: the focused section's title is highlighted (Mauve), unfocused is dimmed.

## Implementation

### Files Changed

- **`tui/internal/app/sync.go`** — Major rewrite: new layout, focus state, step tracking, streaming, expandable history
- **`tui/internal/app/app.go`** — Route new `StreamLineMsg` to sync tab
- **`tui/internal/app/theme.go`** — Add styles for card borders, step icons if needed

### No Changes

- **`tui/internal/runner/runner.go`** — `RunStream` already exists and meets our needs
- **Scripts** — No changes to shell scripts

### New Message Types

- `StreamLineMsg{Line string}` — A single line from the running script's stdout

### Streaming Architecture

1. `runScript` starts `RunStream` in a goroutine with a `chan string`
2. Returns a `tea.Cmd` that reads one line from the channel and returns `StreamLineMsg`
3. `StreamLineMsg` handler: appends line to log, updates step state, returns a new `tea.Cmd` to read next line
4. When channel closes (script done), the goroutine sends `RunCompleteMsg` via a final `tea.Cmd`

Channel-based subscription pattern (idiomatic Bubble Tea):

```go
func waitForLine(lines <-chan string, done <-chan RunCompleteMsg) tea.Cmd {
    return func() tea.Msg {
        select {
        case line, ok := <-lines:
            if ok {
                return StreamLineMsg{Line: line}
            }
        case msg := <-done:
            return msg
        }
        return nil
    }
}
```

### SyncModel Changes

New fields:

```go
type SyncModel struct {
    // Existing
    dotsDir  string
    runner   *runner.Runner
    selected int
    running  bool
    spinner  spinner.Model
    width    int
    height   int

    // New: focus
    focus    syncFocus  // focusActions or focusHistory

    // New: step progress
    steps    []syncStep
    stepIdx  int

    // New: streaming log
    logLines []string

    // New: history
    history       []SyncLogEntry
    historyCursor int
    expanded      map[int]bool

    // Streaming channels
    lineCh chan string
    doneCh chan RunCompleteMsg
}
```

Remove: `output viewport.Model`, `lines []string`, `scroll int` (replaced by logLines + renderScrollView)

### Responsive Layout

```go
func (m SyncModel) renderContent() string {
    if m.width >= 80 {
        return m.renderWideLayout()
    }
    return m.renderNarrowLayout()
}
```

Wide layout uses `lipgloss.JoinHorizontal` for the top row (actions + progress), then appends history below. Narrow layout stacks all three vertically.
