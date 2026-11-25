package discordrelay

import (
	"encoding/json"
	"errors"
	"fmt"
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
}

// Event is an outbound alert.
type Event struct {
	Kind     string    `json:"kind"`
	Text     string    `json:"text,omitempty"`
	Posted   bool      `json:"posted"`
	PostedAt time.Time `json:"posted_at"`
	MsgID    string    `json:"msg_id,omitempty"`
	Answered bool      `json:"answered"`
	Reminded bool      `json:"reminded"`
}

type Scope struct {
	ChannelID string `json:"channel_id"`
	OwnerID   string `json:"owner_id"`
	InboxHome string `json:"inbox_home"`
}

// State is the relay's whole durable memory, one atomically replaced file.
type State struct {
	Scope       Scope             `json:"scope"`
	Cursor      string            `json:"cursor"`
	Messages    map[string]*InMsg `json:"messages"`
	ReplyCursor string            `json:"reply_cursor"`
	SentReplies map[string]bool   `json:"sent_replies"`
	Events      map[string]*Event `json:"events"`
	LastOwnerAt time.Time         `json:"last_owner_at"`
}

// Store persists State and holds an exclusive process lock.
type Store struct {
	S         State
	dir       string
	lock      *os.File
	committed []byte
}

// OpenStore creates dir (0700), takes the single-instance lock and loads state.
func OpenStore(dir string, scope Scope) (*Store, error) {
	if err := mkdirDurable(filepath.Join(dir, "events")); err != nil {
		return nil, err
	}
	lf, err := os.OpenFile(filepath.Join(dir, "relay.lock"), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, err
	}
	if err := syscall.Flock(int(lf.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		lf.Close()
		return nil, fmt.Errorf("cannot acquire lock for state directory %s: %w", dir, err)
	}
	st := &Store{dir: dir, lock: lf}
	b, err := loadBoundState(dir, scope, &st.S)
	switch {
	case err == nil:
		st.committed = b
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
	if st.committed == nil {
		st.S.Scope = scope
		if err := st.Save(); err != nil {
			lf.Close()
			return nil, err
		}
	}
	return st, nil
}

func loadBoundState(dir string, scope Scope, state *State) ([]byte, error) {
	b, err := os.ReadFile(filepath.Join(dir, "state.json"))
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(b, state); err != nil {
		return nil, fmt.Errorf("state.json is corrupt; restore a backup rather than guessing: %w", err)
	}
	if state.Scope != scope {
		return nil, errors.New("state directory is not bound to this channel, owner and inbox home")
	}
	return b, nil
}

// Save atomically replaces state.json.
func (s *Store) Save() error {
	b, err := json.Marshal(&s.S)
	if err == nil {
		err = s.replace(b)
	}
	if err != nil {
		if s.committed != nil {
			var committed State
			_ = json.Unmarshal(s.committed, &committed)
			s.S = committed
		}
		return err
	}
	s.committed = b
	return nil
}

func (s *Store) replace(b []byte) error {
	tmp := filepath.Join(s.dir, "state.json.tmp")
	f, err := os.OpenFile(tmp, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o600)
	if err != nil {
		return err
	}
	return publish(f, filepath.Join(s.dir, "state.json"), b)
}

func publish(f *os.File, dest string, b []byte) error {
	if _, err := f.Write(b); err != nil {
		f.Close()
		return err
	}
	if err := f.Sync(); err != nil {
		f.Close()
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	if err := os.Rename(f.Name(), dest); err != nil {
		return err
	}
	return syncDir(filepath.Dir(dest))
}

func syncDir(path string) error {
	d, err := os.Open(path)
	if err != nil {
		return err
	}
	defer d.Close()
	return d.Sync()
}

func mkdirDurable(path string) error {
	info, err := os.Stat(path)
	if err == nil {
		if !info.IsDir() {
			return fmt.Errorf("%s is not a directory", path)
		}
		return nil
	}
	if !os.IsNotExist(err) {
		return err
	}
	parent := filepath.Dir(path)
	if err := mkdirDurable(parent); err != nil {
		return err
	}
	if err := os.Mkdir(path, 0o700); err != nil && !os.IsExist(err) {
		return err
	}
	return syncDir(parent)
}

// Close releases the lock.
func (s *Store) Close() { s.lock.Close() }

func (s *Store) eventsDir() string { return filepath.Join(s.dir, "events") }
