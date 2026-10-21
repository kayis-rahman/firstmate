package main

import (
	"fmt"
	"os"

	"github.com/firstmate/firstmate/internal/envx"
)

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "usage: fm-env-get <key> <file>")
		os.Exit(2)
	}
	v, err := envx.Get(os.Args[1], os.Args[2])
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(2)
	}
	fmt.Print(v)
}
