package app

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
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
