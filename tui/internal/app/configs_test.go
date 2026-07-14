package app

import (
	"testing"
	"time"
)

func TestCategoryForTarget(t *testing.T) {
	cases := []struct {
		target string
		want   string
	}{
		{".config/kitty/kitty.conf", "kitty"},
		{".config/nvim/lua/config/init.lua", "nvim"},
		{".config/starship.toml", "starship.toml"},
		{".zshrc", "home"},
		{".gitconfig", "home"},
		{".oh-my-zsh/custom/plugins/foo/foo.zsh", "home"},
	}
	for _, tc := range cases {
		if got := categoryForTarget(tc.target); got != tc.want {
			t.Errorf("categoryForTarget(%q) = %q, want %q", tc.target, got, tc.want)
		}
	}
}

func TestCategoriesLoadedClampsBothCursors(t *testing.T) {
	m := NewConfigsModel(t.TempDir())
	m.cursor = 5
	m.fileCursor = 9
	m.inFiles = true

	small := []configCategory{
		{Name: "kitty", Files: []configFile{{TargetRel: ".config/kitty/kitty.conf"}}},
		{Name: "home", Files: []configFile{{TargetRel: ".zshrc"}}},
	}
	m2, _ := m.Update(categoriesLoadedMsg{categories: small})

	if m2.cursor > len(small)-1 {
		t.Errorf("category cursor not clamped: %d", m2.cursor)
	}
	if m2.fileCursor > len(m2.tree)-1 {
		t.Errorf("file cursor not clamped: %d (tree %d)", m2.fileCursor, len(m2.tree))
	}
}

func TestScanErrorSurfaced(t *testing.T) {
	m := NewConfigsModel(t.TempDir())
	m2, cmd := m.Update(categoriesLoadedMsg{err: "chezmoi exploded"})
	if cmd == nil {
		t.Fatal("expected a toast command for the error")
	}
	if msg, ok := cmd().(ToastMsg); !ok || msg.Level != ToastError {
		t.Errorf("expected an error toast, got %#v", cmd())
	}
	_ = m2
}

func TestBuildTreeHomeCategoryTerminates(t *testing.T) {
	// Regression: the old common-prefix walk infinite-looped on two
	// top-level dotfiles (basePath stuck at "." with a "/" guard).
	m := NewConfigsModel(t.TempDir())
	cat := configCategory{Name: "home", Files: []configFile{
		{TargetRel: ".gitconfig"},
		{TargetRel: ".zshrc"},
		{TargetRel: ".oh-my-zsh/custom/plugins/foo/foo.zsh"},
	}}

	done := make(chan []treeEntry, 1)
	go func() { done <- m.buildTree(cat) }()

	select {
	case entries := <-done:
		var fileNames []string
		for _, e := range entries {
			if !e.IsDir {
				fileNames = append(fileNames, e.Name)
			}
		}
		if len(fileNames) != 3 {
			t.Errorf("expected 3 files in tree, got %v", fileNames)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("buildTree did not terminate — common-prefix walk is looping")
	}
}
