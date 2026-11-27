package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/firstmate/firstmate/internal/lintworkflows"
)

func usage(w io.Writer) {
	fmt.Fprintln(w, "fm-lint-workflows.sh - owner of firstmate's GitHub workflow lint.")
	fmt.Fprintln(w)
	fmt.Fprintln(w, "Usage:")
	fmt.Fprintln(w, "  fm-lint-workflows.sh                 lint workflows under this repo")
	fmt.Fprintln(w, "  fm-lint-workflows.sh --root <dir>    lint workflows under <dir>")
	fmt.Fprintln(w, "  fm-lint-workflows.sh <path>...       lint explicit workflow files")
	fmt.Fprintln(w, "  fm-lint-workflows.sh --required-version")
	fmt.Fprintln(w, "  fm-lint-workflows.sh --help")
}

func main() {
	args := os.Args[1:]
	if len(args) >= 1 && args[0] == "--required-version" {
		fmt.Println(lintworkflows.RequiredActionlint)
		os.Exit(0)
	}

	explicitRoot := ""
	i := 0
	for i < len(args) {
		arg := args[i]
		switch {
		case arg == "--root":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "fm-lint-workflows.sh: --root requires a directory.")
				os.Exit(2)
			}
			explicitRoot = args[i+1]
			i += 2
		case strings.HasPrefix(arg, "--root="):
			explicitRoot = strings.TrimPrefix(arg, "--root=")
			i++
		case arg == "--help" || arg == "-h":
			usage(os.Stdout)
			os.Exit(0)
		case arg == "--":
			i++
			goto doneFlags
		case strings.HasPrefix(arg, "-"):
			fmt.Fprintf(os.Stderr, "fm-lint-workflows.sh: unknown option: %s\n", arg)
			os.Exit(2)
		default:
			goto doneFlags
		}
	}
doneFlags:

	root := os.Getenv("FM_LINT_WORKFLOWS_ROOT")
	if root == "" {
		root = os.Getenv("FM_ROOT_OVERRIDE")
	}
	if root == "" {
		if exe, err := os.Executable(); err == nil {
			root = filepath.Clean(filepath.Join(filepath.Dir(exe), "..", ".."))
		}
	}
	if explicitRoot != "" {
		info, err := os.Stat(explicitRoot)
		if err != nil || !info.IsDir() {
			fmt.Fprintf(os.Stderr, "fm-lint-workflows.sh: --root is not a directory: %s\n", explicitRoot)
			os.Exit(2)
		}
		abs, err := filepath.Abs(explicitRoot)
		if err == nil {
			root = abs
		} else {
			root = explicitRoot
		}
	}

	os.Exit(lintworkflows.Run(root, args[i:], os.Stdout, os.Stderr))
}
