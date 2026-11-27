package forgedetect

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func initRepo(t *testing.T) string {
	t.Helper()
	d := t.TempDir()
	if out, err := exec.Command("git", "init", "-q", d).CombinedOutput(); err != nil {
		t.Fatalf("git init failed: %v (%s)", err, string(out))
	}
	return d
}

func TestDetectNone(t *testing.T) {
	d := initRepo(t)
	res, err := Detect(d)
	if err != nil {
		t.Fatal(err)
	}
	if res != "forge=none" {
		t.Fatalf("got %q, want forge=none", res)
	}
}

func TestDetectSSHPort29418(t *testing.T) {
	d := initRepo(t)
	if err := exec.Command("git", "-C", d, "remote", "add", "origin", "ssh://someone@review.example:29418/group/apps/console").Run(); err != nil {
		t.Fatal(err)
	}
	res, err := Detect(d)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(res, "forge=gerrit evidence=") || !strings.Contains(res, "29418") {
		t.Fatalf("unexpected result: %q", res)
	}
}

func TestDetectRefsForPushRefspec(t *testing.T) {
	d := initRepo(t)
	if err := exec.Command("git", "-C", d, "remote", "add", "origin", "https://review.example/group/apps/console").Run(); err != nil {
		t.Fatal(err)
	}
	if err := exec.Command("git", "-C", d, "config", "--add", "remote.origin.push", "HEAD:refs/for/master").Run(); err != nil {
		t.Fatal(err)
	}
	res, err := Detect(d)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(res, "forge=gerrit evidence=") || !strings.Contains(res, "refs/for/") {
		t.Fatalf("unexpected result: %q", res)
	}
}

func TestDetectPortInPathIsNone(t *testing.T) {
	d := initRepo(t)
	if err := exec.Command("git", "-C", d, "remote", "add", "origin", "ssh://git@host.example/29418/project.git").Run(); err != nil {
		t.Fatal(err)
	}
	res, err := Detect(d)
	if err != nil {
		t.Fatal(err)
	}
	if res != "forge=none" {
		t.Fatalf("got %q, want forge=none", res)
	}
}

func TestDetectMissingAndPlainDir(t *testing.T) {
	if _, err := Detect(filepath.Join(os.TempDir(), "nope-nope-nope")); err == nil {
		t.Fatal("expected error for missing dir")
	}
	plain := t.TempDir()
	if _, err := Detect(plain); err == nil {
		t.Fatal("expected error for non-git dir")
	}
}
