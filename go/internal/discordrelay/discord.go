package discordrelay

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"time"
)

// Message is the subset of a Discord message the relay needs.
type Message struct {
	ID        string
	ChannelID string
	Content   string
	AuthorID  string
	Bot       bool
	At        time.Time
	ReplyTo   string
}

// Chat is the Discord transport, replaceable by a fake in tests.
type Chat interface {
	Fetch(after string, limit int) ([]Message, error)
	Post(content, replyTo string, silent bool, nonce string) (string, error)
	React(msgID, emoji string) error
}

// HTTPChat talks to the Discord REST API for one channel.
type HTTPChat struct {
	Channel, Token string
	Client         *http.Client
	base           string
}

func (h *HTTPChat) do(method, path string, body any) ([]byte, error) {
	var rd io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		rd = bytes.NewReader(b)
	}
	base := h.base
	if base == "" {
		base = "https://discord.com/api/v10"
	}
	req, err := http.NewRequest(method, base+path, rd)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bot "+h.Token)
	req.Header.Set("User-Agent", "fm-discord-relay (firstmate, 1)")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	c := h.Client
	if c == nil {
		c = &http.Client{Timeout: 20 * time.Second}
	}
	resp, err := c.Do(req)
	if err != nil {
		return nil, redactErr(err, h.Token)
	}
	defer resp.Body.Close()
	out, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if resp.StatusCode == http.StatusTooManyRequests {
		return nil, fmt.Errorf("discord rate limited, retry-after %s", resp.Header.Get("Retry-After"))
	}
	if resp.StatusCode/100 != 2 {
		return nil, fmt.Errorf("discord %s %s: status %d", method, path, resp.StatusCode)
	}
	return out, nil
}

// redactErr keeps the token out of logged transport errors.
func redactErr(err error, token string) error {
	if token == "" {
		return err
	}
	return fmt.Errorf("%s", bytes.ReplaceAll([]byte(err.Error()), []byte(token), []byte("[token]")))
}

// Fetch returns messages newer than after (any order).
func (h *HTTPChat) Fetch(after string, limit int) ([]Message, error) {
	q := url.Values{"limit": {strconv.Itoa(limit)}}
	if after != "" {
		q.Set("after", after)
	}
	b, err := h.do("GET", "/channels/"+h.Channel+"/messages?"+q.Encode(), nil)
	if err != nil {
		return nil, err
	}
	var raw []struct {
		ID        string    `json:"id"`
		Content   string    `json:"content"`
		ChannelID string    `json:"channel_id"`
		Timestamp time.Time `json:"timestamp"`
		Reference struct {
			Type      int    `json:"type"`
			MessageID string `json:"message_id"`
			ChannelID string `json:"channel_id"`
		} `json:"message_reference"`
		Author struct {
			ID  string `json:"id"`
			Bot bool   `json:"bot"`
		} `json:"author"`
	}
	if err := json.Unmarshal(b, &raw); err != nil {
		return nil, err
	}
	out := make([]Message, 0, len(raw))
	for _, m := range raw {
		msg := Message{ID: m.ID, ChannelID: m.ChannelID, Content: m.Content, AuthorID: m.Author.ID, Bot: m.Author.Bot, At: m.Timestamp}
		if m.Reference.Type == 0 && m.Reference.ChannelID == m.ChannelID {
			msg.ReplyTo = m.Reference.MessageID
		}
		out = append(out, msg)
	}
	return out, nil
}

// Post sends a message, optionally as a native threaded reply, optionally
// without a push notification.
func (h *HTTPChat) Post(content, replyTo string, silent bool, nonce string) (string, error) {
	body := map[string]any{"content": clip(Redact(content), messageLimit), "allowed_mentions": map[string]any{"parse": []string{}}}
	if replyTo != "" {
		body["message_reference"] = map[string]any{"message_id": replyTo, "fail_if_not_exists": true}
	}
	if nonce != "" {
		hash := sha256.Sum256([]byte(nonce))
		body["nonce"] = fmt.Sprintf("fm-%x", hash[:11])
		body["enforce_nonce"] = true
	}
	if silent {
		body["flags"] = 1 << 12 // SUPPRESS_NOTIFICATIONS
	}
	b, err := h.do("POST", "/channels/"+h.Channel+"/messages", body)
	if err != nil {
		return "", err
	}
	var r struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(b, &r); err != nil || r.ID == "" {
		return "", fmt.Errorf("discord post: unreadable response")
	}
	return r.ID, nil
}

const messageLimit = 2000

func textUnits(s string) int {
	n := 0
	for _, r := range s {
		n++
		if r > 0xffff {
			n++
		}
	}
	return n
}

func clip(s string, limit int) string {
	if textUnits(s) <= limit {
		return s
	}
	for i, r := range s {
		limit--
		if r > 0xffff {
			limit--
		}
		if limit < 1 {
			return s[:i] + "…"
		}
	}
	return s
}

// React adds the bot's reaction to a message.
func (h *HTTPChat) React(msgID, emoji string) error {
	_, err := h.do("PUT", "/channels/"+h.Channel+"/messages/"+msgID+"/reactions/"+url.PathEscape(emoji)+"/@me", nil)
	return err
}
