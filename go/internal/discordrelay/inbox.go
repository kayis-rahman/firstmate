package discordrelay

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

// Reply is a firstmate answer recorded against a note id.
type Reply struct {
	NoteID string
	Body   string
	Cursor string
}

// Inbox is bin/fm-inbox.sh, replaceable by a fake in tests.
type Inbox interface {
	// Note enqueues idempotently by request id; announced=false means the note
	// is saved but its wake is not yet announced, so the caller must retry.
	Note(reqID, text string) (noteID string, announced bool, err error)
	Replies(after string) ([]Reply, error)
	// Handled reports which of the given note ids firstmate has acknowledged.
	Handled() (map[string]bool, error)
}

// ExecInbox shells out to fm-inbox.sh with FM_HOME set.
type ExecInbox struct{ Cmd, Home string }

func (e ExecInbox) run(stdin string, args ...string) ([]byte, int, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, e.Cmd, args...)
	cmd.Env = append(os.Environ(), "FM_HOME="+e.Home)
	var out bytes.Buffer
	cmd.Stdin = strings.NewReader(stdin)
	cmd.Stdout = &out
	err := cmd.Run()
	var ee *exec.ExitError
	if errors.As(err, &ee) {
		return out.Bytes(), ee.ExitCode(), nil
	}
	if err != nil {
		return nil, -1, err
	}
	return out.Bytes(), 0, nil
}

// Note implements Inbox. Exit 3 is "saved but wake not announced".
func (e ExecInbox) Note(reqID, text string) (string, bool, error) {
	out, code, err := e.run(text, "note", "--request-id", reqID, "--json", "--", "-")
	if err != nil {
		return "", false, err
	}
	if code != 0 && code != 3 {
		return "", false, fmt.Errorf("fm-inbox note exited %d", code)
	}
	var r struct {
		ID string `json:"id"`
	}
	if json.Unmarshal(bytes.TrimSpace(out), &r) != nil || r.ID == "" {
		return "", false, errors.New("fm-inbox note: unreadable JSON")
	}
	return r.ID, code == 0, nil
}

// Replies implements Inbox.
func (e ExecInbox) Replies(after string) ([]Reply, error) {
	args := []string{"receipts", "--all-replies"}
	if after != "" {
		args = append(args, "--after", after)
	}
	out, code, err := e.run("", args...)
	if err != nil || code != 0 {
		return nil, fmt.Errorf("fm-inbox receipts failed (code %d)", code)
	}
	var r struct {
		Replies []struct {
			ID     string `json:"id"`
			Body   string `json:"body"`
			Cursor string `json:"cursor"`
		} `json:"replies"`
	}
	if err := json.Unmarshal(bytes.TrimSpace(out), &r); err != nil {
		return nil, err
	}
	rs := make([]Reply, 0, len(r.Replies))
	for _, x := range r.Replies {
		rs = append(rs, Reply{x.ID, x.Body, x.Cursor})
	}
	return rs, nil
}

// Handled implements Inbox from the receipts view of handled notes.
func (e ExecInbox) Handled() (map[string]bool, error) {
	out, code, err := e.run("", "receipts", "--all-handled")
	if err != nil || code != 0 {
		return nil, fmt.Errorf("fm-inbox receipts failed (code %d)", code)
	}
	var r struct {
		Handled []struct {
			ID string `json:"id"`
		} `json:"handled"`
	}
	if err := json.Unmarshal(bytes.TrimSpace(out), &r); err != nil {
		return nil, err
	}
	m := make(map[string]bool, len(r.Handled))
	for _, h := range r.Handled {
		m[h.ID] = true
	}
	return m, nil
}
