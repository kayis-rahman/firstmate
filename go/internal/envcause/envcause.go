package envcause

import (
	"fmt"
	"os"
	"regexp"
	"strings"
)

func Classify(darwin string, text string) string {
	d := darwin
	if d == "auto" {
		if os.Getenv("GOOS") == "darwin" {
			d = "1"
		} else {
			// best effort: rely on runtime.GOOS at call site via main
			d = "0"
		}
	}
	if d != "1" {
		return ""
	}
	lower := strings.ToLower(text)
	if !strings.Contains(lower, "no route to host") && !strings.Contains(text, "EHOSTUNREACH") && !strings.Contains(lower, "host is unreachable") {
		return ""
	}
	re := regexp.MustCompile(`\b(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}|169\.254\.[0-9]{1,3}\.[0-9]{1,3})\b(:[0-9]+)?`)
	lan := re.FindString(text)
	if lan == "" {
		return ""
	}
	return fmt.Sprintf("cause: (likely, not certain) %s is a local-network address and this failure pattern on macOS - a fresh program gets \"No route to host\" while other tools reach the same address - usually means Local Network privacy is blocking that program; allow it under System Settings > Privacy & Security > Local Network. The OS reports a blocked local-network connection exactly this way, so reachability from other tools does not rule it out.", lan)
}
