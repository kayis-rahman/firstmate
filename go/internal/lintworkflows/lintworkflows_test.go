package lintworkflows

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func installFakeActionlint(t *testing.T, version string, exitCode int) string {
	t.Helper()
	binDir := t.TempDir()
	script := "#!/usr/bin/env bash\nif [ \"${1:-}\" = \"-version\" ]; then\n  printf '" + version + "\\n'\n  exit 0\nfi\nexit " + string(rune('0'+exitCode)) + "\n"
	if err := os.WriteFile(filepath.Join(binDir, "actionlint"), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	return binDir
}

func TestValidWorkflowPasses(t *testing.T) {
	binDir := installFakeActionlint(t, RequiredActionlint, 0)
	t.Setenv("PATH", binDir+":"+os.Getenv("PATH"))

	root := t.TempDir()
	wfDir := filepath.Join(root, ".github", "workflows")
	if err := os.MkdirAll(wfDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(wfDir, "ci.yml"), []byte("name: CI\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	var stdout, stderr bytes.Buffer
	rc := Run(root, nil, &stdout, &stderr)
	if rc != 0 {
		t.Fatalf("expected rc=0, got %d (stderr=%s)", rc, stderr.String())
	}
	if !strings.Contains(stdout.String(), "1 workflow files valid") {
		t.Fatalf("unexpected stdout: %s", stdout.String())
	}
}

func TestEmptyWorkflowsDirFails(t *testing.T) {
	root := t.TempDir()
	if err := os.MkdirAll(filepath.Join(root, ".github", "workflows"), 0o755); err != nil {
		t.Fatal(err)
	}
	var stdout, stderr bytes.Buffer
	rc := Run(root, nil, &stdout, &stderr)
	if rc != 1 || !strings.Contains(stderr.String(), "no GitHub workflow files found") {
		t.Fatalf("expected rc=1 with missing files message, got rc=%d stderr=%s", rc, stderr.String())
	}
}

func TestWrongActionlintVersionRefused(t *testing.T) {
	binDir := installFakeActionlint(t, "0.0.0", 0)
	t.Setenv("PATH", binDir+":"+os.Getenv("PATH"))

	root := t.TempDir()
	wfDir := filepath.Join(root, ".github", "workflows")
	if err := os.MkdirAll(wfDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(wfDir, "ci.yml"), []byte("name: CI\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	var stdout, stderr bytes.Buffer
	rc := Run(root, nil, &stdout, &stderr)
	if rc != 1 || !strings.Contains(stderr.String(), RequiredActionlint) || !strings.Contains(stderr.String(), "0.0.0") {
		t.Fatalf("expected version mismatch error, got rc=%d stderr=%s", rc, stderr.String())
	}
}
