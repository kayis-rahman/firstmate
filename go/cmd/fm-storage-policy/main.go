package main

import (
	"fmt"
	"io"
	"os"

	"github.com/firstmate/firstmate/internal/storagepolicy"
)

func printUsage(w io.Writer) {
	fmt.Fprintln(w, "Usage: bin/fm-storage-policy.sh [--path PATH] [--large-work] [--clean]")
	fmt.Fprintln(w)
	fmt.Fprintln(w, "Reports free space on PATH (default: /). --large-work exits nonzero below 10% free.")
	fmt.Fprintln(w, "--clean removes only recognized Go build, uv, and Hugging Face Xet caches, and")
	fmt.Fprintln(w, "only when lsof confirms the cache is not open. Without --clean this is a dry run.")
}

func main() {
	path := "/"
	clean := false
	largeWork := false

	args := os.Args[1:]
	for i := 0; i < len(args); {
		switch args[i] {
		case "--path":
			if i+1 >= len(args) {
				printUsage(os.Stderr)
				os.Exit(2)
			}
			path = args[i+1]
			i += 2
		case "--clean":
			clean = true
			i++
		case "--large-work":
			largeWork = true
			i++
		case "-h", "--help":
			printUsage(os.Stdout)
			os.Exit(0)
		default:
			printUsage(os.Stderr)
			os.Exit(2)
		}
	}

	os.Exit(storagepolicy.Run(path, clean, largeWork, os.Getenv("HOME"), os.Stdout, os.Stderr))
}
