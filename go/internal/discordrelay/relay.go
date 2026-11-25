package discordrelay

import (
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

var alertKinds = map[string]bool{"decision": true, "review-ready": true, "login": true, "blocker": true}
var idRe = regexp.MustCompile(`^[A-Za-z0-9._:-]{1,120}$`)

// EventIn is the input to emit.
type EventIn struct {
	ID   string `json:"id"`
	Kind string `json:"kind"`
	Text string `json:"text"`
}

type queuedEvent struct {
	Scope Scope `json:"scope"`
	EventIn
}

func eventFilename(id string) string {
	return hex.EncodeToString([]byte(id)) + ".json"
}

// WriteEvent queues an event for an already bound relay.
func WriteEvent(dir string, scope Scope, e EventIn) error {
	if _, err := loadBoundState(dir, scope, &State{}); err != nil {
		if os.IsNotExist(err) {
			return errors.New("state directory is unbound; start the relay before emitting events")
		}
		return err
	}
	if !idRe.MatchString(e.ID) {
		return errors.New("event id must match " + idRe.String())
	}
	if !alertKinds[e.Kind] {
		return fmt.Errorf("unknown alert kind %q", e.Kind)
	}
	if strings.TrimSpace(e.Text) == "" {
		return errors.New("event text is empty")
	}
	eventsDir := filepath.Join(dir, "events")
	b, _ := json.Marshal(queuedEvent{Scope: scope, EventIn: e})
	f, err := os.CreateTemp(eventsDir, ".emit-*")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	return publish(f, filepath.Join(eventsDir, eventFilename(e.ID)), b)
}

// Relay wires transport, inbox and durable state.
type Relay struct {
	Cfg  Config
	Chat Chat
	Box  Inbox
	St   *Store
	Now  func() time.Time
	Logf func(format string, args ...any)
}

func (r *Relay) logf(f string, a ...any) {
	if r.Logf != nil {
		r.Logf(f, a...)
	}
}

func (r *Relay) active(now time.Time) bool {
	return !r.St.S.LastOwnerAt.IsZero() && now.Sub(r.St.S.LastOwnerAt) < 2*time.Minute
}

func snowLess(a, b string) bool {
	if len(a) != len(b) {
		return len(a) < len(b)
	}
	return a < b
}

// Tick runs one full pass. Each stage persists before it advances, so a crash
// anywhere is repaired by the next pass. Stage errors are joined, not fatal.
func (r *Relay) Tick() error {
	inboundErr := r.pollInbound()
	err := errors.Join(inboundErr, r.markSeen(), r.enqueue(), r.markHandled(), r.pollReplies(), r.ingestEvents(),
		r.dispatchEvents())
	if inboundErr == nil {
		err = errors.Join(err, r.remind())
	}
	return err
}

func (r *Relay) pollInbound() error {
	const pageSize = 100
	s := &r.St.S
	first := s.Cursor == ""
	for {
		before := s.Cursor
		msgs, err := r.Chat.Fetch(before, pageSize)
		if err != nil {
			return err
		}
		if !first && len(msgs) == 0 {
			return nil
		}
		sort.Slice(msgs, func(i, j int) bool { return snowLess(msgs[i].ID, msgs[j].ID) })
		if first {
			s.Cursor = "0"
		}
		for _, m := range msgs {
			if !snowLess(s.Cursor, m.ID) {
				continue
			}
			s.Cursor = m.ID
			if m.ChannelID != r.Cfg.ChannelID || m.Bot || m.AuthorID != r.Cfg.OwnerID {
				continue
			}
			if m.At.After(s.LastOwnerAt) {
				s.LastOwnerAt = m.At
			}
			if _, seen := s.Messages[m.ID]; first || seen || strings.TrimSpace(m.Content) == "" {
				continue
			}
			s.Messages[m.ID] = &InMsg{Text: m.Content}
			if m.ReplyTo == "" {
				continue
			}
			for _, e := range s.Events {
				if alertKinds[e.Kind] && e.Posted && e.MsgID == m.ReplyTo && snowLess(e.MsgID, m.ID) {
					e.Answered = true
				}
			}
		}
		if s.Cursor == before {
			return errors.New("Discord inbound page did not advance the cursor")
		}
		if err := r.St.Save(); err != nil {
			return err
		}
		if first || len(msgs) < pageSize {
			return nil
		}
	}
}

func (r *Relay) markSeen() error {
	var ids []string
	for id, m := range r.St.S.Messages {
		if !m.Receipted {
			ids = append(ids, id)
		}
	}
	sort.Slice(ids, func(i, j int) bool { return snowLess(ids[i], ids[j]) })
	var errs []error
	for _, id := range ids {
		if err := r.Chat.React(id, "👀"); err != nil {
			errs = append(errs, fmt.Errorf("receipt %s: %w", id, err))
			continue
		}
		r.St.S.Messages[id].Receipted = true
		if err := r.St.Save(); err != nil {
			return err
		}
	}
	return errors.Join(errs...)
}

func (r *Relay) enqueue() error {
	s := &r.St.S
	var ids []string
	for id, m := range s.Messages {
		if !m.Enqueued {
			ids = append(ids, id)
		}
	}
	sort.Slice(ids, func(i, j int) bool { return snowLess(ids[i], ids[j]) })
	for _, id := range ids {
		m := s.Messages[id]
		noteID, announced, err := r.Box.Note("discord-"+id, m.Text)
		if err != nil {
			return fmt.Errorf("enqueue %s: %w", id, err)
		}
		m.NoteID = noteID
		if announced {
			m.Enqueued, m.Text = true, ""
		}
		if err := r.St.Save(); err != nil {
			return err
		}
		if !announced {
			return fmt.Errorf("enqueue %s: saved, wake not announced yet", id)
		}
	}
	return nil
}

// markHandled puts the acknowledged mark on every captured message whose note
// firstmate has handled. Acked is persisted only after the mark lands, so a
// failed mark is retried and a landed one is never repeated across restarts.
func (r *Relay) markHandled() error {
	s := &r.St.S
	var ids []string
	for id, m := range s.Messages {
		if !m.Acked && m.NoteID != "" {
			ids = append(ids, id)
		}
	}
	if len(ids) == 0 {
		return nil
	}
	handled, err := r.Box.Handled()
	if err != nil {
		return err
	}
	sort.Slice(ids, func(i, j int) bool { return snowLess(ids[i], ids[j]) })
	var errs []error
	for _, id := range ids {
		m := s.Messages[id]
		if !handled[m.NoteID] {
			continue
		}
		if err := r.Chat.React(id, "✅"); err != nil {
			errs = append(errs, fmt.Errorf("ack %s: %w", id, err))
			continue
		}
		m.Acked = true
		if err := r.St.Save(); err != nil {
			return err
		}
	}
	return errors.Join(errs...)
}

func (r *Relay) pollReplies() error {
	s := &r.St.S
	byNote := map[string]string{}
	unmapped := false
	for id, m := range s.Messages {
		if m.NoteID == "" {
			unmapped = true
		} else {
			byNote[m.NoteID] = id
		}
	}
	reps, err := r.Box.Replies(s.ReplyCursor)
	if err != nil {
		return err
	}
	sort.Slice(reps, func(i, j int) bool { return reps[i].Cursor < reps[j].Cursor })
	var errs []error
	blocked := false
	for _, rep := range reps {
		origin, mapped := byNote[rep.NoteID]
		changed := false
		if !s.SentReplies[rep.NoteID] {
			if !mapped && unmapped {
				blocked = true
				continue
			}
			if mapped {
				if _, err := r.Chat.Post(rep.Body, origin, false, rep.NoteID); err != nil {
					errs = append(errs, fmt.Errorf("reply %s: %w", rep.NoteID, err))
					blocked = true
					continue
				}
				s.SentReplies[rep.NoteID] = true
				changed = true
			}
		}
		if !blocked {
			s.ReplyCursor = rep.Cursor
			changed = true
		}
		if changed {
			if err := r.St.Save(); err != nil {
				return errors.Join(errors.Join(errs...), err)
			}
		}
	}
	return errors.Join(errs...)
}

func (r *Relay) ingestEvents() error {
	dir := r.St.eventsDir()
	files, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	for _, file := range files {
		if !file.Type().IsRegular() || !strings.HasSuffix(file.Name(), ".json") {
			continue
		}
		f := filepath.Join(dir, file.Name())
		var e queuedEvent
		b, err := os.ReadFile(f)
		if err != nil {
			return err
		}
		if json.Unmarshal(b, &e) != nil || e.Scope != r.St.S.Scope || !idRe.MatchString(e.ID) || file.Name() != eventFilename(e.ID) || !alertKinds[e.Kind] || strings.TrimSpace(e.Text) == "" {
			r.logf("rejecting malformed event file %s", filepath.Base(f))
			_ = os.Rename(f, f+".rejected")
			continue
		}
		if _, dup := r.St.S.Events[e.ID]; !dup {
			r.St.S.Events[e.ID] = &Event{Kind: e.Kind, Text: e.Text}
			if err := r.St.Save(); err != nil {
				return err
			}
		}
		_ = os.Remove(f) // only after the event is durable in state
	}
	return nil
}

func (r *Relay) dispatchEvents() error {
	s := &r.St.S
	ids := make([]string, 0)
	for id, e := range s.Events {
		if alertKinds[e.Kind] && !e.Posted {
			ids = append(ids, id)
		}
	}
	sort.Strings(ids)
	var errs []error
	for _, id := range ids {
		e := s.Events[id]
		msg := "🔔 " + e.Kind + " — " + e.Text
		mid, err := r.Chat.Post(msg, "", r.active(r.Now()), "")
		if err != nil {
			errs = append(errs, fmt.Errorf("alert %s: %w", id, err))
			continue
		}
		e.Posted, e.PostedAt, e.MsgID = true, r.Now(), mid
		if err := r.St.Save(); err != nil {
			return err
		}
	}
	return errors.Join(errs...)
}

func (r *Relay) remind() error {
	s := &r.St.S
	now := r.Now()
	if r.active(now) {
		return nil // suppressed while he is in the chat; re-evaluated next tick
	}
	ids := make([]string, 0)
	for id, e := range s.Events {
		if alertKinds[e.Kind] && e.Posted && !e.Answered && !e.Reminded && now.Sub(e.PostedAt) >= time.Minute {
			ids = append(ids, id)
		}
	}
	sort.Strings(ids)
	var errs []error
	for _, id := range ids {
		e := s.Events[id]
		if _, err := r.Chat.Post("Still waiting on you: "+e.Kind+" — "+e.Text, e.MsgID, false, ""); err != nil {
			errs = append(errs, fmt.Errorf("reminder %s: %w", id, err))
			continue
		}
		e.Reminded = true
		if err := r.St.Save(); err != nil {
			return err
		}
	}
	return errors.Join(errs...)
}
