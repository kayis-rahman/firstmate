package main

import (
	"fmt"
	"io"
	"os"

	"github.com/firstmate/firstmate/internal/tapverify"
)

func usage(w io.Writer) {
	fmt.Fprintln(w, "Usage: fm-test-tap-verify.sh TEST_SCRIPT")
	fmt.Fprintln(w, "       fm-test-tap-verify.sh -h|--help")
	fmt.Fprintln(w)
	fmt.Fprintln(w, "Run TEST_SCRIPT under the Bash running this helper and require a TAP")
	fmt.Fprintln(w, "plan 1..N, N `ok - ` lines, zero `not ok` lines, FM_TEST_COMPLETE, and")
	fmt.Fprintln(w, "exit status 0.")
}

func main() {
	args := os.Args[1:]
	if len(args) >= 1 && (args[0] == "-h" || args[0] == "--help") {
		usage(os.Stdout)
		os.Exit(0)
	}
	if len(args) != 1 {
		usage(os.Stderr)
		os.Exit(2)
	}
	bashBin := os.Getenv("FM_TAP_VERIFY_BASH")
	if bashBin == "" {
		bashBin = os.Getenv("BASH")
	}
	os.Exit(tapverify.Verify(args[0], bashBin, os.Stdout, os.Stderr))
}
