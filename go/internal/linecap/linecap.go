package linecap

const DefaultMax = 220
const Suffix = " [truncated]"

func CapLine(line string, max int) string {
	if max == 0 {
		max = DefaultMax
	}
	if len([]rune(line)) <= max {
		return line
	}
	runes := []rune(line)
	keep := max - len([]rune(Suffix))
	if keep < 0 {
		keep = 0
	}
	return string(runes[:keep]) + Suffix
}
