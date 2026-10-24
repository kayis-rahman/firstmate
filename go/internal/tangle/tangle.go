package tangle

import (
	"fmt"
	"os/exec"
	"strings"
)

func DefaultBranch(dir string) (string, error) {
	out, err := exec.Command("git", "-C", dir, "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD").Output()
	if err == nil {
		ref := strings.TrimSpace(string(out))
		if ref != "" {
			return strings.TrimPrefix(ref, "origin/"), nil
		}
	}
	for _, b := range []string{"main", "master"} {
		if err := exec.Command("git", "-C", dir, "show-ref", "--verify", "--quiet", "refs/heads/"+b).Run(); err == nil {
			return b, nil
		}
	}
	return "", fmt.Errorf("no default branch")
}

func PrimaryTangleBranch(root string) (string, error) {
	if err := exec.Command("git", "-C", root, "rev-parse", "--is-inside-work-tree").Run(); err != nil {
		return "", nil
	}
	out, err := exec.Command("git", "-C", root, "symbolic-ref", "--quiet", "--short", "HEAD").Output()
	if err != nil {
		return "", nil // detached
	}
	cur := strings.TrimSpace(string(out))
	if cur == "" {
		return "", nil
	}
	def, err := DefaultBranch(root)
	if err != nil {
		return "", nil
	}
	if cur == def {
		return "", nil
	}
	return cur, nil
}
