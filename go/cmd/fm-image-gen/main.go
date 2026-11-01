package main

import (
	"flag"
	"fmt"
	"os"
	"strconv"

	"github.com/firstmate/firstmate/internal/imagegen"
)

type references []string

func (values *references) String() string { return fmt.Sprint([]string(*values)) }
func (values *references) Set(value string) error {
	*values = append(*values, value)
	return nil
}

func main() {
	var options imagegen.Options
	var seed int
	var hasSeed bool
	var refs references
	flags := flag.NewFlagSet("fm-image-gen", flag.ContinueOnError)
	flags.SetOutput(os.Stderr)
	flags.StringVar(&options.Prompt, "prompt", "", "image prompt")
	flags.StringVar(&options.Out, "out", "", "output PNG")
	flags.Var(&refs, "reference", "reference PNG (may be specified once for mflux)")
	flags.Func("width", "output width", func(value string) error {
		parsed, err := strconv.Atoi(value)
		if err != nil || parsed <= 0 {
			return fmt.Errorf("width must be a positive integer")
		}
		options.Width = parsed
		return nil
	})
	flags.Func("height", "output height", func(value string) error {
		parsed, err := strconv.Atoi(value)
		if err != nil || parsed <= 0 {
			return fmt.Errorf("height must be a positive integer")
		}
		options.Height = parsed
		return nil
	})
	flags.Func("seed", "generation seed", func(value string) error {
		parsed, err := strconv.Atoi(value)
		if err != nil || parsed < 0 {
			return fmt.Errorf("seed must be a non-negative integer")
		}
		seed, hasSeed = parsed, true
		return nil
	})
	flags.StringVar(&options.Engine, "engine", "auto", "mflux, mlx-serve, or auto")
	flags.Usage = func() {
		fmt.Fprintln(flags.Output(), "Usage: fm-image-gen.sh --prompt <text> --out <png> [--reference <png>]... [--width N] [--height N] [--seed N] [--engine mflux|mlx-serve|auto]")
	}
	if err := flags.Parse(os.Args[1:]); err != nil {
		os.Exit(2)
	}
	if flags.NArg() != 0 {
		flags.Usage()
		os.Exit(2)
	}
	options.References = refs
	if hasSeed {
		options.Seed = &seed
	}
	if err := imagegen.Run(options); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}
