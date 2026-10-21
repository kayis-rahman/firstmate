package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"

	"github.com/firstmate/firstmate/internal/linecap"
)

func main() {
	max := linecap.DefaultMax
	if len(os.Args) > 1 {
		if n, err := strconv.Atoi(os.Args[1]); err == nil {
			max = n
		}
	}
	sc := bufio.NewScanner(os.Stdin)
	sc.Buffer(make([]byte, 1024*1024), 1024*1024)
	for sc.Scan() {
		fmt.Println(linecap.CapLine(sc.Text(), max))
	}
}
