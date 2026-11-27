package tapverify

import (
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

var (
	planRe     = regexp.MustCompile(`^1\.\.[1-9][0-9]*$`)
	okRe       = regexp.MustCompile(`^ok - `)
	notOkRe    = regexp.MustCompile(`^not ok`)
	completeRe = regexp.MustCompile(`^FM_TEST_COMPLETE$`)
)

func failVerify(msg string, stdout, stderr io.Writer) int {
	fmt.Fprintf(stdout, "::error::%s\n", msg)
	fmt.Fprintf(stderr, "fm-test-tap-verify: %s\n", msg)
	return 1
}

// Verify runs script under bashBin and enforces TAP completeness.
func Verify(script, bashBin string, stdout, stderr io.Writer) int {
	info, err := os.Stat(script)
	if err != nil || info.IsDir() {
		return failVerify("not a file: "+script, stdout, stderr)
	}
	if bashBin == "" {
		bashBin = "bash"
	}

	cmd := exec.Command(bashBin, script)
	out, runErr := cmd.CombinedOutput()
	status := 0
	if runErr != nil {
		var exitErr *exec.ExitError
		if errors.As(runErr, &exitErr) {
			status = exitErr.ExitCode()
		} else {
			status = 1
		}
	}

	_, _ = stdout.Write(out)

	planCount := 0
	okCount := 0
	notOkCount := 0
	completeCount := 0
	planned := 0

	lines := strings.Split(strings.TrimSuffix(string(out), "\n"), "\n")
	if len(out) == 0 {
		lines = nil
	}
	for _, line := range lines {
		line = strings.TrimSuffix(line, "\r")
		if planRe.MatchString(line) {
			planCount++
			if n, err := strconv.Atoi(strings.TrimPrefix(line, "1..")); err == nil {
				planned = n
			}
		}
		if okRe.MatchString(line) {
			okCount++
		}
		if notOkRe.MatchString(line) {
			notOkCount++
		}
		if completeRe.MatchString(line) {
			completeCount++
		}
	}

	label := filepath.Base(script)

	if status != 0 {
		return failVerify(fmt.Sprintf("%s exited %d (planned %d, ok %d, not ok %d, complete %d)",
			label, status, planned, okCount, notOkCount, completeCount), stdout, stderr)
	}
	if planCount != 1 {
		return failVerify(fmt.Sprintf("%s must print exactly one TAP plan 1..N, got %d (ok %d, complete %d)",
			label, planCount, okCount, completeCount), stdout, stderr)
	}
	if completeCount != 1 {
		return failVerify(fmt.Sprintf("%s exited 0 without a single FM_TEST_COMPLETE (planned %d, ok %d); an early exit must fail",
			label, planned, okCount), stdout, stderr)
	}
	if notOkCount != 0 {
		return failVerify(fmt.Sprintf("%s printed %d not-ok line(s) (planned %d, ok %d)",
			label, notOkCount, planned, okCount), stdout, stderr)
	}
	if okCount != planned {
		return failVerify(fmt.Sprintf("%s planned %d ok lines, got %d",
			label, planned, okCount), stdout, stderr)
	}

	fmt.Fprintf(stdout, "fm-test-tap-verify: %s: %d planned, %d ok, complete, exit 0\n",
		label, planned, okCount)
	return 0
}
