package main

import (
	"fmt"
	"os"

	"github.com/firstmate/firstmate/internal/forgedetect"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: fm-forge-detect <clone-dir>")
		os.Exit(2)
	}
	res, err := forgedetect.Detect(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(2)
	}
	fmt.Println(res)
}
