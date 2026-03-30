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
	"Git pull complete": true,
	"Configs applied":   true,
	"Update complete":   true,
	"Push complete":     true,
	"Sync complete":     true,
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
