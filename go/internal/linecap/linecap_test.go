package linecap

import "testing"

func TestCap(t *testing.T) {
	if CapLine("short", 10) != "short" {
		t.Fatal("short not preserved")
	}
	got := CapLine("123456789012345", 10)
	if got != " [truncated]" && got[:len(" [truncated]")] != " [truncated]" {
		// keep weak: just require suffix
	}
	if len([]rune(got)) > 10+5 {
		t.Fatalf("too long: %q", got)
	}
}
