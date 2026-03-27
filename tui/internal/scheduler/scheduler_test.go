package scheduler_test

import (
	"strings"
	"testing"

	"github.com/parbots/dots/internal/scheduler"
)

func TestParseStatusActive(t *testing.T) {
	output := "\033[0;32mScheduled sync: ACTIVE (launchd)\033[0m\n"
	status := scheduler.ParseStatus(output)

	if !status.Active {
		t.Error("expected Active to be true")
	}
}

func TestParseStatusInactive(t *testing.T) {
	output := "\033[0;33mScheduled sync: INACTIVE\033[0m\n"
	status := scheduler.ParseStatus(output)

	if status.Active {
		t.Error("expected Active to be false")
	}
}

func TestScheduleScriptPath(t *testing.T) {
	s := scheduler.New("/home/user/dev/dots")
	path := s.ScriptPath()

	if !strings.HasSuffix(path, "scripts/schedule.sh") {
		t.Errorf("expected path ending in scripts/schedule.sh, got %s", path)
	}
}
