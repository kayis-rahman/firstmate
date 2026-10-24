package pathx

func Dirname(p string) string {
	if p == "" {
		p = "."
	}
	// trailing slash handling
	for len(p) > 1 && p[len(p)-1] == '/' {
		p = p[:len(p)-1]
	}
	if p == "/" {
		return "/"
	}
	// if no slash
	hasSlash := false
	for i := range p {
		if p[i] == '/' {
			hasSlash = true
		}
	}
	if !hasSlash {
		return "."
	}
	// remove last component
	last := len(p) - 1
	for last >= 0 && p[last] == '/' {
		last--
	}
	for last >= 0 && p[last] != '/' {
		last--
	}
	for last > 0 && p[last] == '/' {
		last--
	}
	if last < 0 {
		return "/"
	}
	res := p[:last+1]
	if res == "" {
		res = "/"
	}
	return res
}

func Basename(p string) string {
	if p == "" {
		return ""
	}
	for len(p) > 1 && p[len(p)-1] == '/' {
		p = p[:len(p)-1]
	}
	if p == "/" {
		return "/"
	}
	idx := -1
	for i := len(p) - 1; i >= 0; i-- {
		if p[i] == '/' {
			idx = i
			break
		}
	}
	if idx < 0 {
		return p
	}
	return p[idx+1:]
}
