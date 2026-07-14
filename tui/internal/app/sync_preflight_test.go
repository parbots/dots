package app

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

func setupTestRepo(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	run := func(args ...string) {
		cmd := exec.Command("git", args...)
		cmd.Dir = dir
		cmd.Run()
	}
	run("init")
	run("config", "user.email", "test@test.com")
	run("config", "user.name", "test")
	os.WriteFile(filepath.Join(dir, "f.txt"), []byte("hello"), 0644)
	run("add", ".")
	run("commit", "-m", "init")
	return dir
}

func TestCheckChezmoiLock_NoProcess(t *testing.T) {
	issue := checkChezmoiLock()
	if issue != nil {
		t.Errorf("expected no issue, got %q", issue.Message)
	}
}

func TestCheckGitConflicts_Clean(t *testing.T) {
	dir := setupTestRepo(t)
	issue := checkGitConflicts(dir)
	if issue != nil {
		t.Errorf("expected no issue, got %q", issue.Message)
	}
}

func TestCheckDirtyTree_Clean(t *testing.T) {
	dir := setupTestRepo(t)
	issue := checkDirtyTree(dir)
	if issue != nil {
		t.Errorf("expected no issue, got %q", issue.Message)
	}
}

func TestCheckDirtyTree_Dirty(t *testing.T) {
	dir := setupTestRepo(t)
	os.WriteFile(filepath.Join(dir, "f.txt"), []byte("modified"), 0644)

	issue := checkDirtyTree(dir)
	if issue == nil {
		t.Fatal("expected dirty tree issue")
	}
	if issue.Severity != severityWarn {
		t.Errorf("expected severityWarn, got %d", issue.Severity)
	}
}

func TestRunPreflightChecks_NoIssues(t *testing.T) {
	dir := setupTestRepo(t)
	issues := runPreflightChecks(dir, syncActionPush)
	for _, issue := range issues {
		if issue.Severity != severityWarn {
			t.Errorf("unexpected non-warn issue: %q (severity %d)", issue.Message, issue.Severity)
		}
	}
}

func TestParseProcessStart_LocalTime(t *testing.T) {
	// Fix a non-UTC zone so the test fails under the old UTC time.Parse
	// regardless of the machine's own zone.
	loc := time.FixedZone("UTC-7", -7*3600)
	now := time.Date(2026, 7, 14, 12, 0, 0, 0, loc)
	lstart := now.Add(-30 * time.Second).Format("Mon Jan  2 15:04:05 2006")

	start, err := parseProcessStart(lstart, loc)
	if err != nil {
		t.Fatalf("parseProcessStart: %v", err)
	}
	age := now.Sub(start)
	if age < 25*time.Second || age > 35*time.Second {
		t.Errorf("age = %v, want ~30s (UTC parsing would be off by 7h)", age)
	}
}

func TestIsLocallyModifiedStatus(t *testing.T) {
	cases := []struct {
		line string
		want bool
	}{
		{"MM .zshrc", true},
		{"DA .config/nvim/lua/plugins/snacks/picker.lua", true},
		{"AM .config/foo/bar", true},
		{" M .config/gh", false},       // apply-side change only, no local edit
		{" A .config/new/file", false}, // apply would add; nothing local
		{"", false},
		{"X", false}, // too short
	}
	for _, tc := range cases {
		if got := isLocallyModifiedStatus(tc.line); got != tc.want {
			t.Errorf("isLocallyModifiedStatus(%q) = %v, want %v", tc.line, got, tc.want)
		}
	}
}
