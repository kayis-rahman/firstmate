package lintworkflows

import (
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

const RequiredActionlint = "1.7.12"

// Run executes the workflow lint check and returns the exit code.
func Run(root string, files []string, stdout, stderr io.Writer) int {
	if len(files) > 0 {
		for _, path := range files {
			if !strings.HasSuffix(path, ".yml") && !strings.HasSuffix(path, ".yaml") {
				fmt.Fprintf(stderr, "fm-lint-workflows.sh: not a workflow YAML file: %s\n", path)
				return 2
			}
			info, err := os.Stat(path)
			if err != nil || info.IsDir() {
				fmt.Fprintf(stderr, "fm-lint-workflows.sh: workflow file not found: %s\n", path)
				return 2
			}
		}
	} else {
		wfDir := filepath.Join(root, ".github", "workflows")
		entries, err := os.ReadDir(wfDir)
		if err == nil {
			for _, e := range entries {
				name := e.Name()
				if !strings.HasSuffix(name, ".yml") && !strings.HasSuffix(name, ".yaml") {
					continue
				}
				full := filepath.Join(wfDir, name)
				info, err := os.Stat(full)
				if err == nil && info.Mode().IsRegular() {
					files = append(files, full)
				}
			}
		}
		sort.Strings(files)
		if len(files) == 0 {
			fmt.Fprintf(stderr, "fm-lint-workflows.sh: no GitHub workflow files found under %s\n", wfDir)
			return 1
		}
	}

	actionlintBin, err := exec.LookPath("actionlint")
	if err != nil {
		fmt.Fprintf(stderr, "fm-lint-workflows.sh: actionlint not found; install actionlint %s with bin/fm-install-actionlint.sh <destination-directory> and put that directory on PATH.\n", RequiredActionlint)
		return 1
	}

	verOut, err := exec.Command(actionlintBin, "-version").Output()
	resolved := ""
	if err == nil {
		lines := strings.Split(string(verOut), "\n")
		if len(lines) > 0 {
			resolved = strings.TrimRight(lines[0], "\r")
		}
	}
	fmt.Fprintf(stderr, "fm-lint-workflows.sh: actionlint %s (pinned %s)\n", resolved, RequiredActionlint)
	if resolved != RequiredActionlint {
		fmt.Fprintf(stderr, "fm-lint-workflows.sh: actionlint %s required for CI parity, found %s. Install %s with bin/fm-install-actionlint.sh <destination-directory>.\n",
			RequiredActionlint, resolved, RequiredActionlint)
		return 1
	}

	cmdArgs := append([]string{"-no-color", "-shellcheck=", "-pyflakes=", "--"}, files...)
	cmd := exec.Command(actionlintBin, cmdArgs...)
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	if err := cmd.Run(); err != nil {
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			return exitErr.ExitCode()
		}
		return 1
	}

	fmt.Fprintf(stdout, "fm-lint-workflows.sh: %d workflow files valid\n", len(files))
	return 0
}
