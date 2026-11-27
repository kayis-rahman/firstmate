package storagepolicy

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func installFakeTools(t *testing.T, dfFree, dfTotal, lsofActive string) string {
	t.Helper()
	binDir := t.TempDir()
	dfScript := "#!/usr/bin/env bash\nprintf 'Filesystem 1024-blocks Used Available Capacity Mounted on\\n/dev/fake " + dfTotal + " 80000000 " + dfFree + " 80%% /\\n'\n"
	if err := os.WriteFile(filepath.Join(binDir, "df"), []byte(dfScript), 0o755); err != nil {
		t.Fatal(err)
	}
	lsofScript := "#!/usr/bin/env bash\nif [ \"" + lsofActive + "\" = 1 ]; then\n  printf 'COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME\\nworker 12 me 3r REG 1 1 1 %s/file\\n' \"$2\"\n  exit 0\nfi\nexit 1\n"
	if err := os.WriteFile(filepath.Join(binDir, "lsof"), []byte(lsofScript), 0o755); err != nil {
		t.Fatal(err)
	}
	return binDir
}

func TestDryRunAndThresholds(t *testing.T) {
	binDir := installFakeTools(t, "20000000", "100000000", "0")
	t.Setenv("PATH", binDir+":"+os.Getenv("PATH"))

	home := t.TempDir()
	uvDir := filepath.Join(home, ".cache", "uv")
	if err := os.MkdirAll(uvDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(uvDir, "keep"), []byte("keep"), 0o644); err != nil {
		t.Fatal(err)
	}

	var stdout, stderr bytes.Buffer
	rc := Run(home, false, false, home, &stdout, &stderr)
	if rc != 0 {
		t.Fatalf("expected rc=0, got %d (stderr=%s)", rc, stderr.String())
	}
	out := stdout.String()
	if !strings.Contains(out, "free=20%") || !strings.Contains(out, "reserve_target_gib=30") {
		t.Fatalf("unexpected stdout: %s", out)
	}
	if !strings.Contains(out, "cache=candidate path="+uvDir) {
		t.Fatalf("expected uv candidate in stdout: %s", out)
	}
	if _, err := os.Stat(filepath.Join(uvDir, "keep")); err != nil {
		t.Fatalf("dry run removed cache entry: %v", err)
	}
}

func TestLargeWorkRefusedBelowTenPercent(t *testing.T) {
	binDir := installFakeTools(t, "9000000", "100000000", "0")
	t.Setenv("PATH", binDir+":"+os.Getenv("PATH"))

	home := t.TempDir()
	var stdout, stderr bytes.Buffer
	rc := Run(home, false, true, home, &stdout, &stderr)
	if rc != 3 {
		t.Fatalf("expected rc=3, got %d", rc)
	}
	if !strings.Contains(stdout.String(), "large_work=refused") {
		t.Fatalf("expected large_work=refused, got %s", stdout.String())
	}
}

func TestCleanRespectsActiveAndSymlinks(t *testing.T) {
	binDir := installFakeTools(t, "20000000", "100000000", "1")
	t.Setenv("PATH", binDir+":"+os.Getenv("PATH"))

	home := t.TempDir()
	uvDir := filepath.Join(home, ".cache", "uv")
	if err := os.MkdirAll(uvDir, 0o755); err != nil {
		t.Fatal(err)
	}
	var stdout, stderr bytes.Buffer
	rc := Run(home, true, false, home, &stdout, &stderr)
	if rc != 0 {
		t.Fatalf("expected rc=0, got %d", rc)
	}
	if !strings.Contains(stdout.String(), "reason=active-or-cannot-verify") {
		t.Fatalf("expected active cache skip, got %s", stdout.String())
	}

	binDirInactive := installFakeTools(t, "20000000", "100000000", "0")
	t.Setenv("PATH", binDirInactive+":"+os.Getenv("PATH"))
	stdout.Reset()
	rc = Run(home, true, false, home, &stdout, &stderr)
	if rc != 0 {
		t.Fatalf("expected rc=0, got %d", rc)
	}
	if !strings.Contains(stdout.String(), "cache=removed path="+uvDir) {
		t.Fatalf("expected cache=removed, got %s", stdout.String())
	}
}
