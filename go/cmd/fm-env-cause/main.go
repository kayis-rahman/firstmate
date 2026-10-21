package main

import (
	"fmt"
	"os"
	"runtime"

	"github.com/firstmate/firstmate/internal/envcause"
)

func main() {
	args := os.Args[1:]
	darwin := "auto"
	if len(args) >= 1 && args[0] == "classify" {
		args = args[1:]
	} else if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "usage: fm-env-cause classify [--darwin <0|1|auto>] [file | -]")
		os.Exit(2)
	}
	// parse --darwin
	if len(args) >= 2 && args[0] == "--darwin" {
		darwin = args[1]
		args = args[2:]
	}
	if darwin == "auto" {
		if runtime.GOOS == "darwin" {
			darwin = "1"
		} else {
			darwin = "0"
		}
	}
	data := ""
	if len(args) == 0 || args[0] == "-" {
		b, _ := os.ReadFile("/dev/stdin")
		data = string(b)
	} else {
		b, err := os.ReadFile(args[0])
		if err != nil {
			os.Exit(0)
		}
		data = string(b)
	}
	out := envcause.Classify(darwin, data)
	if out != "" {
		fmt.Println(out)
	}
}
