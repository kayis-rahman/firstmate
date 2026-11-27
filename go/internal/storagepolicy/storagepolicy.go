package storagepolicy

import (
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

const reserveTargetKB = 30 * 1024 * 1024

// Run executes the storage policy check and optional cache cleanup, returning the exit code.
func Run(path string, clean, largeWork bool, home string, stdout, stderr io.Writer) int {
	info, err := os.Stat(path)
	if err != nil || !info.IsDir() {
		fmt.Fprintf(stderr, "error: filesystem path is not a directory: %s\n", path)
		return 2
	}

	totalKB, freeKB, ok := measureDF(path)
	if !ok || totalKB <= 0 {
		fmt.Fprintf(stderr, "error: could not measure filesystem at %s\n", path)
		return 2
	}

	freePct := (freeKB * 100) / totalKB
	reserveKB := int64(reserveTargetKB)
	if totalKB < reserveKB {
		reserveKB = totalKB
	}

	fmt.Fprintf(stdout, "filesystem=%s free=%d%% free_gib=%d reserve_target_gib=%d alert_below=15%% refuse_large_work_below=10%%\n",
		path, freePct, freeKB/1024/1024, reserveKB/1024/1024)

	if freePct < 15 {
		fmt.Fprintln(stdout, "alert=low-free-space")
	} else {
		fmt.Fprintln(stdout, "alert=none")
	}

	if freePct < 10 {
		fmt.Fprintln(stdout, "large_work=refused")
	} else if freeKB < reserveKB {
		fmt.Fprintln(stdout, "large_work=allowed-reserve-below-practical-target")
	} else {
		fmt.Fprintln(stdout, "large_work=allowed")
	}

	if largeWork && freePct < 10 {
		return 3
	}

	if home == "" {
		fmt.Fprintln(stderr, "HOME must be set")
		return 2
	}
	homeReal, err := filepath.EvalSymlinks(home)
	if err != nil {
		fmt.Fprintf(stderr, "error: cannot resolve HOME: %s\n", home)
		return 2
	}
	homeReal, err = filepath.Abs(homeReal)
	if err != nil {
		fmt.Fprintf(stderr, "error: cannot resolve HOME: %s\n", home)
		return 2
	}

	candidates := []string{
		home + "/Library/Caches/go-build",
		home + "/.cache/go-build",
		home + "/.cache/uv",
		home + "/Library/Caches/uv",
		home + "/.cache/huggingface/xet",
	}

	homePrefix := homeReal + "/"
	if homeReal == "/" {
		homePrefix = "/"
	}

	for _, candidate := range candidates {
		if _, err := os.Stat(candidate); err != nil {
			continue
		}
		cInfo, err := os.Lstat(candidate)
		if err != nil {
			continue
		}
		parentReal, err := filepath.EvalSymlinks(filepath.Dir(candidate))
		if err != nil {
			fmt.Fprintf(stdout, "cache=skipped reason=outside-home-or-unresolvable path=%s\n", candidate)
			continue
		}
		parentReal, err = filepath.Abs(parentReal)
		if err != nil || !strings.HasPrefix(parentReal+"/", homePrefix) {
			fmt.Fprintf(stdout, "cache=skipped reason=outside-home-or-unresolvable path=%s\n", candidate)
			continue
		}
		if cInfo.Mode()&os.ModeSymlink != 0 || !cInfo.IsDir() {
			fmt.Fprintf(stdout, "cache=skipped reason=not-a-real-directory path=%s\n", candidate)
			continue
		}
		fmt.Fprintf(stdout, "cache=candidate path=%s\n", candidate)
		if !clean {
			continue
		}
		if _, err := exec.LookPath("lsof"); err != nil {
			fmt.Fprintln(stdout, "cache=skipped reason=lsof-unavailable")
			continue
		}
		lsofOut, lsofErr := exec.Command("lsof", "+D", candidate).CombinedOutput()
		lsofRC := 0
		if lsofErr != nil {
			var exitErr *exec.ExitError
			if errors.As(lsofErr, &exitErr) {
				lsofRC = exitErr.ExitCode()
			} else {
				lsofRC = 2
			}
		}
		if len(strings.TrimSpace(string(lsofOut))) > 0 || lsofRC > 1 {
			fmt.Fprintf(stdout, "cache=skipped reason=active-or-cannot-verify path=%s\n", candidate)
			continue
		}
		if err := os.RemoveAll(candidate); err != nil {
			fmt.Fprintf(stderr, "error: failed to remove %s: %v\n", candidate, err)
			return 1
		}
		fmt.Fprintf(stdout, "cache=removed path=%s\n", candidate)
	}

	return 0
}

func measureDF(path string) (int64, int64, bool) {
	out, err := exec.Command("df", "-Pk", path).Output()
	if err != nil {
		return 0, 0, false
	}
	lines := strings.Split(strings.TrimRight(string(out), "\r\n"), "\n")
	if len(lines) < 2 {
		return 0, 0, false
	}
	fields := strings.Fields(lines[1])
	if len(fields) < 4 {
		return 0, 0, false
	}
	totalKB, err1 := strconv.ParseInt(fields[1], 10, 64)
	freeKB, err2 := strconv.ParseInt(fields[3], 10, 64)
	if err1 != nil || err2 != nil || totalKB < 0 || freeKB < 0 {
		return 0, 0, false
	}
	return totalKB, freeKB, true
}
