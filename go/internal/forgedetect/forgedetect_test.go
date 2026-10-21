package forgedetect

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestDetectNone(t *testing.T) {
	d := t.TempDir()
	exec.Command("git", "init", d).Run()
	res, err := Detect(d)
	if err != nil {
		t.Fatal(err)
	}
	if res != "forge=none" {
		t.Fatalf("got %s", res)
	}
}

func TestDetectMissing(t *testing.T) {
	_, err := Detect(filepath.Join(os.TempDir(), "nope-nope-nope"))
	if err == nil {
		t.Fatal("expected error")
	}
}
