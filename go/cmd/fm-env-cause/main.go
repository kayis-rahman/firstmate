package main

import (
	"fmt"
	"io"
	"os"
	"runtime"

	"github.com/firstmate/firstmate/internal/envcause"
)

func usage() {
	fmt.Fprintln(os.Stderr, "usage: fm-env-cause.sh classify [--darwin <0|1|auto>] [file | -]")
	fmt.Fprintln(os.Stderr, "       (reads failure text from the file, or stdin when the file is - or absent)")
	os.Exit(2)
}

func main() {
	args := os.Args[1:]
	if len(args) < 1 || args[0] != "classify" {
		usage()
	}
	args = args[1:]

	darwin := "auto"
	if len(args) >= 1 && args[0] == "--darwin" {
		if len(args) < 2 {
			usage()
		}
		darwin = args[1]
		switch darwin {
		case "0", "1", "auto":
		default:
			usage()
		}
		args = args[2:]
	}
	if len(args) > 1 {
		usage()
	}

	if darwin == "auto" {
		if runtime.GOOS == "darwin" {
			darwin = "1"
		} else {
			darwin = "0"
		}
	}
	if darwin != "1" {
		os.Exit(0)
	}

	var data string
	if len(args) == 1 && args[0] != "-" {
		info, err := os.Stat(args[0])
		if err != nil || info.IsDir() {
			os.Exit(0)
		}
		b, err := os.ReadFile(args[0])
		if err != nil {
			os.Exit(0)
		}
		data = string(b)
	} else {
		b, _ := io.ReadAll(os.Stdin)
		data = string(b)
	}
	if data == "" {
		os.Exit(0)
	}
	out := envcause.Classify(darwin, data)
	if out != "" {
		fmt.Println(out)
	}
}
