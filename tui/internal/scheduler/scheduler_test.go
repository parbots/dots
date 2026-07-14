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

func TestParseStatusBroken(t *testing.T) {
	output := "\033[0;31mScheduled sync: BROKEN — script path in /Users/x/Library/LaunchAgents/com.dots.sync.plist is missing (/gone/sync.sh)\033[0m\n"
	status := scheduler.ParseStatus(output)

	if !status.Broken {
		t.Error("expected Broken=true")
	}
	if status.Active {
		t.Error("BROKEN must not read as Active")
	}
}

func TestParseStatusIgnoresLogText(t *testing.T) {
	output := "Scheduled sync: ACTIVE (launchd)\nLast sync:\n{\"result\":\"failure\",\"details\":\"push BROKEN INACTIVE weirdness\"}\n"
	status := scheduler.ParseStatus(output)
	if !status.Active || status.Broken {
		t.Errorf("log text must not affect state: Active=%v Broken=%v", status.Active, status.Broken)
	}
	if status.LastSync == "" {
		t.Error("LastSync should still be captured from the log line")
	}
}

func TestGetStatusHardFailure(t *testing.T) {
	// No scripts/schedule.sh in an empty dir: bash exits non-zero.
	s := scheduler.New(t.TempDir())
	status := s.GetStatus()
	if !status.Broken {
		t.Error("a hard schedule.sh failure must report Broken")
	}
}

func TestScheduleScriptPath(t *testing.T) {
	s := scheduler.New("/home/user/dev/dots")
	path := s.ScriptPath()

	if !strings.HasSuffix(path, "scripts/schedule.sh") {
		t.Errorf("expected path ending in scripts/schedule.sh, got %s", path)
	}
}
