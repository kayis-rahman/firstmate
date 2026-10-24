package main

import (
	"fmt"
	"os"

	"github.com/firstmate/firstmate/internal/tangle"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: fm-tangle-check <root>")
		os.Exit(2)
	}
	b, err := tangle.PrimaryTangleBranch(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(2)
	}
	if b != "" {
		fmt.Println(b)
	}
}
