package discordrelay

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"syscall"
	"time"
)

// InMsg is one inbound Discord message the relay has taken responsibility for.
type InMsg struct {
	Text      string `json:"text,omitempty"` // dropped once enqueued
	NoteID    string `json:"note_id,omitempty"`
	Enqueued  bool   `json:"enqueued"`
	Receipted bool   `json:"receipted"`
	Acked     bool   `json:"acked,omitempty"` // firstmate handled the note and the mark landed
	Rejected  bool   `json:"rejected,omitempty"`
}

// Event is an outbound alert or routine update.
type Event struct {
	Kind     string    `json:"kind"`
	Task     string    `json:"task,omitempty"`
	Text     string    `json:"text"`
	Urgent   bool      `json:"urgent"`
	Posted   bool      `json:"posted"`
	PostedAt time.Time `json:"posted_at"`
	MsgID    string    `json:"msg_id,omitempty"`
	Answered bool      `json:"answered"`
	Reminded bool      `json:"reminded"`
}

// State is the relay's whole durable memory, one atomically replaced file.
type State struct {
	Cursor      string            `json:"cursor"`
	Messages    map[string]*InMsg `json:"messages"`
	ReplyCursor string            `json:"reply_cursor"`
	SentReplies map[string]bool   `json:"sent_replies"`
	Events      map[string]*Event `json:"events"`
	Batch       []string          `json:"batch"`
	LastBatchAt time.Time         `json:"last_batch_at"`
	LastOwnerAt time.Time         `json:"last_owner_at"`
	Rejected    int               `json:"rejected_count"`
}

// Store persists State and holds an exclusive process lock.
type Store struct {
	S    State
	dir  string
	lock *os.File
}

// OpenStore creates dir (0700), takes the single-instance lock and loads state.
func OpenStore(dir string) (*Store, error) {
	if err := os.MkdirAll(filepath.Join(dir, "events"), 0o700); err != nil {
		return nil, err
	}
	lf, err := os.OpenFile(filepath.Join(dir, "relay.lock"), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, err
	}
	if err := syscall.Flock(int(lf.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		lf.Close()
		return nil, errors.New("another relay instance holds the state lock")
	}
	st := &Store{dir: dir, lock: lf}
	b, err := os.ReadFile(filepath.Join(dir, "state.json"))
	switch {
	case err == nil:
		if err := json.Unmarshal(b, &st.S); err != nil {
			lf.Close()
			return nil, errors.New("state.json is corrupt; restore a backup rather than guessing: " + err.Error())
		}
	case !os.IsNotExist(err):
		lf.Close()
		return nil, err
	}
	if st.S.Messages == nil {
		st.S.Messages = map[string]*InMsg{}
	}
	if st.S.SentReplies == nil {
		st.S.SentReplies = map[string]bool{}
	}
	if st.S.Events == nil {
		st.S.Events = map[string]*Event{}
	}
	return st, nil
}

// Save atomically replaces state.json.
func (s *Store) Save() error {
	b, err := json.Marshal(&s.S)
	if err != nil {
		return err
	}
	tmp := filepath.Join(s.dir, "state.json.tmp")
	f, err := os.OpenFile(tmp, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o600)
	if err != nil {
		return err
	}
	if _, err := f.Write(b); err != nil {
		f.Close()
		return err
	}
	if err := f.Sync(); err != nil {
		f.Close()
		return err
	}
	f.Close()
	return os.Rename(tmp, filepath.Join(s.dir, "state.json"))
}

// Close releases the lock.
func (s *Store) Close() { s.lock.Close() }

// EventsDir is where hooks drop event files.
func (s *Store) EventsDir() string { return filepath.Join(s.dir, "events") }
