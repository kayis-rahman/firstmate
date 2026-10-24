package envx

import (
	"bufio"
	"os"
	"regexp"
	"strings"
)

var keyRe = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)

func Get(key, file string) (string, error) {
	if !keyRe.MatchString(key) {
		return "", nil
	}
	f, err := os.Open(file)
	if err != nil {
		if os.IsNotExist(err) {
			return "", nil
		}
		return "", err
	}
	defer f.Close()
	var last string
	found := false
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 1024*1024), 1024*1024)
	lineRe := regexp.MustCompile(`^\s*(export\s+)?` + regexp.QuoteMeta(key) + `=`)
	for sc.Scan() {
		line := sc.Text()
		if !lineRe.MatchString(line) {
			continue
		}
		idx := strings.Index(line, "=")
		val := line[idx+1:]
		val = strings.TrimLeft(val, " \t")
		val = strings.TrimRight(val, " \t\r")
		if len(val) >= 2 {
			if (val[0] == '"' && val[len(val)-1] == '"') || (val[0] == '\'' && val[len(val)-1] == '\'') {
				val = val[1 : len(val)-1]
			}
		}
		last = val
		found = true
	}
	if !found {
		return "", nil
	}
	return last, nil
}
