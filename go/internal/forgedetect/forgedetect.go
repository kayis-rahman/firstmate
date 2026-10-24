package forgedetect

import (
	"fmt"
	"os/exec"
	"strings"
)

func Detect(dir string) (string, error) {
	out, err := exec.Command("git", "-C", dir, "rev-parse", "--is-inside-work-tree").Output()
	if err != nil || strings.TrimSpace(string(out)) != "true" {
		return "", fmt.Errorf("%s is not a git work tree", dir)
	}
	var urls []string
	if o, _ := exec.Command("git", "-C", dir, "config", "--get-all", "remote.origin.url").Output(); len(o) > 0 {
		urls = append(urls, strings.Split(string(o), "\n")...)
	}
	if o, _ := exec.Command("git", "-C", dir, "config", "--get-all", "remote.origin.pushurl").Output(); len(o) > 0 {
		urls = append(urls, strings.Split(string(o), "\n")...)
	}
	for _, url := range urls {
		url = strings.TrimSpace(url)
		if url == "" {
			continue
		}
		if strings.HasPrefix(url, "ssh://") {
			auth := url[len("ssh://"):]
			if i := strings.Index(auth, "/"); i >= 0 {
				auth = auth[:i]
			}
			if strings.HasSuffix(auth, ":29418") {
				return fmt.Sprintf("forge=gerrit evidence=origin remote %s uses SSH port 29418", url), nil
			}
		}
	}
	if o, _ := exec.Command("git", "-C", dir, "config", "--get-all", "remote.origin.push").Output(); len(o) > 0 {
		for _, r := range strings.Split(string(o), "\n") {
			r = strings.TrimSpace(r)
			if strings.Contains(r, ":refs/for/") {
				return fmt.Sprintf("forge=gerrit evidence=origin push refspec %s targets refs/for/", r), nil
			}
		}
	}
	return "forge=none", nil
}
