package main

import (
	"fmt"
	"os"

	"github.com/firstmate/firstmate/internal/pathx"
)

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "usage: fm-path dirname|basename <path>")
		os.Exit(2)
	}
	switch os.Args[1] {
	case "dirname":
		fmt.Print(pathx.Dirname(os.Args[2]))
	case "basename":
		fmt.Print(pathx.Basename(os.Args[2]))
	default:
		fmt.Fprintln(os.Stderr, "unknown subcommand")
		os.Exit(2)
	}
}
