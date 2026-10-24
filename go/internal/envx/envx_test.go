package envx

import (
	"os"
	"testing"
)

func TestGet(t *testing.T) {
	f, _ := os.CreateTemp("", "env")
	defer os.Remove(f.Name())
	f.WriteString("FOO=bar\nexport BAZ='quoted'\nFOO=last\n")
	f.Close()
	got, _ := Get("FOO", f.Name())
	if got != "last" {
		t.Fatalf("got %q", got)
	}
	got, _ = Get("BAZ", f.Name())
	if got != "quoted" {
		t.Fatalf("got %q", got)
	}
	got, _ = Get("MISSING", f.Name())
	if got != "" {
		t.Fatalf("got %q", got)
	}
}
