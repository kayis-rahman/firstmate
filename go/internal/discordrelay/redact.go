package discordrelay

import "regexp"

var secretPatterns = []*regexp.Regexp{
	regexp.MustCompile(`https?://(?:[a-z]+\.)?discord(?:app)?\.com/api/(?:v\d+/)?webhooks/\S+`),
	regexp.MustCompile(`[A-Za-z0-9_-]{23,28}\.[A-Za-z0-9_-]{6,7}\.[A-Za-z0-9_-]{27,}`), // bot token shape
	regexp.MustCompile(`(?i)\b(?:bearer|bot)\s+[A-Za-z0-9._~+/=-]{20,}`),
	regexp.MustCompile(`(?i)\b(?:token|secret|password|api[_-]?key)\s*[=:]\s*\S{8,}`),
	regexp.MustCompile(`\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})\b`),
}

// Redact masks recognized credential shapes.
func Redact(s string) string {
	for _, p := range secretPatterns {
		s = p.ReplaceAllString(s, "[redacted]")
	}
	return s
}
