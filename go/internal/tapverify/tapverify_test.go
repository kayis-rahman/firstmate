package tapverify

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeSuite(t *testing.T, name, body string) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), name)
	if err := os.WriteFile(p, []byte("#!/usr/bin/env bash\nset -u\n"+body), 0o644); err != nil {
		t.Fatal(err)
	}
	return p
}

func TestVerifyCompleteSuitePasses(t *testing.T) {
	suite := writeSuite(t, "ok.sh", "printf '1..1\\nok - good\\nFM_TEST_COMPLETE\\n'\n")
	var stdout, stderr bytes.Buffer
	rc := Verify(suite, "bash", &stdout, &stderr)
	if rc != 0 {
		t.Fatalf("expected rc=0, got %d (stdout=%s stderr=%s)", rc, stdout.String(), stderr.String())
	}
	if !strings.Contains(stdout.String(), "1 planned, 1 ok, complete, exit 0") {
		t.Fatalf("unexpected stdout: %s", stdout.String())
	}
}

func TestVerifyEarlyExitFails(t *testing.T) {
	suite := writeSuite(t, "early.sh", "printf '1..2\\nok - one\\n'\nexit 0\n")
	var stdout, stderr bytes.Buffer
	rc := Verify(suite, "bash", &stdout, &stderr)
	if rc == 0 {
		t.Fatalf("expected nonzero rc")
	}
	if !strings.Contains(stderr.String(), "without a single FM_TEST_COMPLETE") {
		t.Fatalf("unexpected stderr: %s", stderr.String())
	}
}

func TestVerifyNotOkFails(t *testing.T) {
	suite := writeSuite(t, "notok.sh", "printf '1..1\\nnot ok - boom\\nok - bad\\nFM_TEST_COMPLETE\\n'\n")
	var stdout, stderr bytes.Buffer
	rc := Verify(suite, "bash", &stdout, &stderr)
	if rc == 0 {
		t.Fatalf("expected nonzero rc")
	}
	if !strings.Contains(stderr.String(), "not-ok") {
		t.Fatalf("unexpected stderr: %s", stderr.String())
	}
}

func TestVerifyOkCountMismatchFails(t *testing.T) {
	suite := writeSuite(t, "mismatch.sh", "printf '1..2\\nok - one\\nFM_TEST_COMPLETE\\n'\n")
	var stdout, stderr bytes.Buffer
	rc := Verify(suite, "bash", &stdout, &stderr)
	if rc == 0 {
		t.Fatalf("expected nonzero rc")
	}
	if !strings.Contains(stderr.String(), "planned 2 ok lines, got 1") {
		t.Fatalf("unexpected stderr: %s", stderr.String())
	}
}
