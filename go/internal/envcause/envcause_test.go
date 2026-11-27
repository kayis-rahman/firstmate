package envcause

import (
	"strings"
	"testing"
)

const observedError = "failed to connect to database: 192.168.0.100:5435 (192.168.0.100): dial error: dial tcp 192.168.0.100:5435: connect: no route to host"

func TestClassifyObservedError(t *testing.T) {
	out := Classify("1", observedError)
	if !strings.Contains(out, "192.168.0.100:5435") || !strings.Contains(out, "Local Network privacy") {
		t.Fatalf("unexpected classify output: %q", out)
	}
}

func TestClassifyCaseInsensitive(t *testing.T) {
	for _, msg := range []string{
		"connect: No Route To Host 192.168.1.10",
		"dial tcp 10.0.0.5:5432: connect: host is unreachable",
		"connect: ehostunreach 172.16.0.1",
	} {
		out := Classify("1", msg)
		if !strings.Contains(out, "Local Network privacy") {
			t.Fatalf("expected match for %q, got %q", msg, out)
		}
	}
}

func TestClassifyNonMatching(t *testing.T) {
	cases := []struct {
		darwin string
		text   string
	}{
		{"0", observedError},
		{"1", "connect: no route to host"},
		{"1", "dial tcp 8.8.8.8:53: connect: no route to host"},
		{"1", "connection refused 192.168.0.100:5435"},
	}
	for _, tc := range cases {
		if out := Classify(tc.darwin, tc.text); out != "" {
			t.Fatalf("expected empty output for (%q, %q), got %q", tc.darwin, tc.text, out)
		}
	}
}
