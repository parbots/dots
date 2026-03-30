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
		{"Pulling latest changes...", 0, false},                      // already at step 0, no advance
		{"\033[0;32mGit pull complete.\033[0m", 1, true},
		{"\033[0;34mApplying chezmoi configs...\033[0m", 1, false},  // already at step 1 via completion
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
