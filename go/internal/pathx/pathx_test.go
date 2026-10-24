package pathx

import "testing"

func TestDirname(t *testing.T) {
	cases := map[string]string{
		"":        ".",
		"foo":     ".",
		"a/b":     "a",
		"/":       "/",
		"a/b/":    "a",
		"/foo":    "/",
	}
	for in, want := range cases {
		if got := Dirname(in); got != want {
			t.Fatalf("Dirname(%q)=%q want %q", in, got, want)
		}
	}
}

func TestBasename(t *testing.T) {
	cases := map[string]string{
		"":     "",
		"foo":  "foo",
		"a/b":  "b",
		"/":    "/",
		"a/b/": "b",
	}
	for in, want := range cases {
		if got := Basename(in); got != want {
			t.Fatalf("Basename(%q)=%q want %q", in, got, want)
		}
	}
}
