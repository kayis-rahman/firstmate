package discordrelay

import (
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

// Urgent kinds are delivered immediately with a push; everything else is a
// routine update that is batched into a quiet digest.
var urgentKinds = map[string]bool{"decision": true, "review-ready": true, "login": true, "blocker": true}

var (
	idRe   = regexp.MustCompile(`^[A-Za-z0-9._:-]{1,120}$`)
	kindRe = regexp.MustCompile(`^[a-z][a-z-]{0,31}$`)
)

// EventIn is the hook file format dropped into <state_dir>/events/.
type EventIn struct {
	ID   string `json:"id"`
	Kind string `json:"kind"`
	Task string `json:"task,omitempty"`
	Text string `json:"text"`
}

// WriteEvent durably drops an event file (write temp, then rename) so a hook
// can hand work to the relay even when the relay is down.
func WriteEvent(eventsDir string, e EventIn) error {
	if !idRe.MatchString(e.ID) {
		return errors.New("event id must match " + idRe.String())
	}
	if !kindRe.MatchString(e.Kind) {
		return errors.New("event kind must match " + kindRe.String())
	}
	if strings.TrimSpace(e.Text) == "" {
		return errors.New("event text is empty")
	}
	if err := os.MkdirAll(eventsDir, 0o700); err != nil {
		return err
	}
	b, _ := json.Marshal(e)
	tmp := filepath.Join(eventsDir, ".tmp-"+e.ID)
	if err := os.WriteFile(tmp, b, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, filepath.Join(eventsDir, e.ID+".json"))
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
	return !r.St.S.LastOwnerAt.IsZero() && now.Sub(r.St.S.LastOwnerAt) < r.Cfg.activeWindow()
}

func (r *Relay) clip(s string) string {
	s = Redact(s)
	rs := []rune(s)
	if len(rs) > r.Cfg.MaxMessageRune {
		return string(rs[:r.Cfg.MaxMessageRune-1]) + "…"
	}
	return s
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
	var errs []error
	for _, step := range []func() error{r.pollInbound, r.enqueue, r.markHandled, r.pollReplies, r.ingestEvents, r.dispatchEvents, r.remind} {
		if err := step(); err != nil {
			errs = append(errs, err)
		}
	}
	return errors.Join(errs...)
}

func (r *Relay) pollInbound() error {
	s := &r.St.S
	first := s.Cursor == ""
	limit := 100
	if first {
		limit = 1
	}
	msgs, err := r.Chat.Fetch(s.Cursor, limit)
	if err != nil {
		return err
	}
	sort.Slice(msgs, func(i, j int) bool { return snowLess(msgs[i].ID, msgs[j].ID) })
	if first {
		// Baseline: never replay channel history on first start. An empty
		// channel baselines at "0" so its first message is captured.
		s.Cursor = "0"
		if len(msgs) > 0 {
			s.Cursor = msgs[len(msgs)-1].ID
		}
		return r.St.Save()
	}
	for _, m := range msgs {
		if _, seen := s.Messages[m.ID]; !seen && !snowLess(m.ID, s.Cursor) && m.ID != s.Cursor {
			switch {
			case m.ChannelID != "" && m.ChannelID != r.Cfg.ChannelID:
				// wrong channel: ignore silently
			case m.Bot:
				// our own and other bots' messages are never input
			case m.AuthorID != r.Cfg.OwnerID:
				s.Rejected++
				s.Messages[m.ID] = &InMsg{Rejected: true}
				r.logf("rejected message %s from non-owner", m.ID)
			case strings.TrimSpace(m.Content) == "":
				// attachments (voice) stay with the existing bridge in this build
			default:
				s.Messages[m.ID] = &InMsg{Text: m.Content}
				at := m.At
				if at.IsZero() {
					at = r.Now()
				}
				if at.After(s.LastOwnerAt) {
					s.LastOwnerAt = at
				}
				for _, e := range s.Events {
					if e.Posted {
						e.Answered = true
					}
				}
			}
		}
		if snowLess(s.Cursor, m.ID) {
			s.Cursor = m.ID
		}
	}
	if len(msgs) == 0 {
		return nil
	}
	return r.St.Save()
}

func (r *Relay) enqueue() error {
	s := &r.St.S
	ids := make([]string, 0)
	for id, m := range s.Messages {
		if !m.Rejected && (!m.Enqueued || (!m.Receipted && r.Cfg.Receipt != "none")) {
			ids = append(ids, id)
		}
	}
	sort.Slice(ids, func(i, j int) bool { return snowLess(ids[i], ids[j]) })
	var errs []error
	for _, id := range ids {
		m := s.Messages[id]
		if !m.Enqueued {
			noteID, announced, err := r.Box.Note("discord-"+id, m.Text)
			if err != nil {
				errs = append(errs, fmt.Errorf("enqueue %s: %w", id, err))
				break // preserve order
			}
			m.NoteID = noteID
			if !announced {
				if err := r.St.Save(); err != nil {
					return err
				}
				errs = append(errs, fmt.Errorf("enqueue %s: saved, wake not announced yet", id))
				break
			}
			m.Enqueued, m.Text = true, ""
			if err := r.St.Save(); err != nil {
				return err
			}
		}
		if !m.Receipted && r.Cfg.Receipt != "none" {
			var err error
			if r.Cfg.Receipt == "reaction" {
				err = r.Chat.React(id, "👀")
			} else {
				_, err = r.Chat.Post("Queued for firstmate.", id, true)
			}
			if err != nil {
				errs = append(errs, fmt.Errorf("receipt %s: %w", id, err))
				continue
			}
			m.Receipted = true
			if err := r.St.Save(); err != nil {
				return err
			}
		}
	}
	return errors.Join(errs...)
}

// markHandled puts the acknowledged mark on every captured message whose note
// firstmate has handled. Acked is persisted only after the mark lands, so a
// failed mark is retried and a landed one is never repeated across restarts.
func (r *Relay) markHandled() error {
	s := &r.St.S
	var ids []string
	for id, m := range s.Messages {
		if m.Enqueued && !m.Acked && m.NoteID != "" && !m.Rejected {
			ids = append(ids, id)
		}
	}
	if len(ids) == 0 || r.Cfg.Ack == "none" {
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
		if r.Cfg.Ack == "reaction" {
			err = r.Chat.React(id, "✅")
		} else {
			_, err = r.Chat.Post("Handled by firstmate.", id, true)
		}
		if err != nil {
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
	for _, m := range s.Messages {
		if !m.Rejected && !m.Enqueued {
			return nil // a reply could belong to a note not yet mapped
		}
	}
	byNote := map[string]string{}
	for id, m := range s.Messages {
		if m.NoteID != "" {
			byNote[m.NoteID] = id
		}
	}
	reps, err := r.Box.Replies(s.ReplyCursor)
	if err != nil {
		return err
	}
	sort.Slice(reps, func(i, j int) bool { return reps[i].Cursor < reps[j].Cursor })
	for _, rep := range reps {
		if origin, ok := byNote[rep.NoteID]; ok && !s.SentReplies[rep.NoteID] {
			if _, err := r.Chat.Post(r.clip(rep.Body), origin, false); err != nil {
				return fmt.Errorf("reply %s: %w", rep.NoteID, err)
			}
			s.SentReplies[rep.NoteID] = true
		}
		s.ReplyCursor = rep.Cursor
		if err := r.St.Save(); err != nil {
			return err
		}
	}
	return nil
}

func (r *Relay) ingestEvents() error {
	files, _ := filepath.Glob(filepath.Join(r.St.EventsDir(), "*.json"))
	sort.Strings(files)
	for _, f := range files {
		var e EventIn
		b, err := os.ReadFile(f)
		if err == nil {
			err = json.Unmarshal(b, &e)
		}
		if err != nil || !idRe.MatchString(e.ID) || !kindRe.MatchString(e.Kind) || strings.TrimSpace(e.Text) == "" {
			r.logf("rejecting malformed event file %s", filepath.Base(f))
			_ = os.Rename(f, f+".rejected")
			continue
		}
		if _, dup := r.St.S.Events[e.ID]; !dup {
			ev := &Event{Kind: e.Kind, Task: e.Task, Text: e.Text, Urgent: urgentKinds[e.Kind]}
			r.St.S.Events[e.ID] = ev
			if !ev.Urgent {
				r.St.S.Batch = append(r.St.S.Batch, e.ID)
			}
			if err := r.St.Save(); err != nil {
				return err
			}
		}
		_ = os.Remove(f) // only after the event is durable in state
	}
	return nil
}

func eventLine(e *Event) string {
	if e.Task != "" {
		return e.Task + ": " + e.Text
	}
	return e.Text
}

func (r *Relay) dispatchEvents() error {
	s := &r.St.S
	now := r.Now()
	ids := make([]string, 0)
	for id, e := range s.Events {
		if e.Urgent && !e.Posted {
			ids = append(ids, id)
		}
	}
	sort.Strings(ids)
	var errs []error
	for _, id := range ids {
		e := s.Events[id]
		msg := r.clip("🔔 " + e.Kind + " — " + eventLine(e))
		mid, err := r.Chat.Post(msg, "", r.active(now)) // quiet while he is in the chat
		if err != nil {
			errs = append(errs, fmt.Errorf("alert %s: %w", id, err))
			continue
		}
		e.Posted, e.PostedAt, e.MsgID = true, now, mid
		if err := r.St.Save(); err != nil {
			return err
		}
	}
	if len(s.Batch) > 0 && now.Sub(s.LastBatchAt) >= r.Cfg.batchWindow() {
		counts := map[string]int{}
		var order []string
		for _, id := range s.Batch {
			l := eventLine(s.Events[id])
			if counts[l] == 0 {
				order = append(order, l)
			}
			counts[l]++
		}
		var sb strings.Builder
		fmt.Fprintf(&sb, "Fleet update (%d)", len(s.Batch))
		for _, l := range order {
			sb.WriteString("\n• " + l)
			if counts[l] > 1 {
				fmt.Fprintf(&sb, " (x%d)", counts[l])
			}
		}
		if _, err := r.Chat.Post(r.clip(sb.String()), "", true); err != nil {
			errs = append(errs, fmt.Errorf("digest: %w", err))
		} else {
			for _, id := range s.Batch {
				s.Events[id].Posted = true
			}
			s.Batch, s.LastBatchAt = nil, now
			if err := r.St.Save(); err != nil {
				return err
			}
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
		if e.Urgent && e.Posted && !e.Answered && !e.Reminded && now.Sub(e.PostedAt) >= r.Cfg.reminderAfter() {
			ids = append(ids, id)
		}
	}
	sort.Strings(ids)
	var errs []error
	for _, id := range ids {
		e := s.Events[id]
		// Mark first: a reminder is sent at most once, even across a crash.
		e.Reminded = true
		if err := r.St.Save(); err != nil {
			return err
		}
		if _, err := r.Chat.Post(r.clip("Still waiting on you: "+e.Kind+" — "+eventLine(e)), e.MsgID, false); err != nil {
			errs = append(errs, fmt.Errorf("reminder %s: %w", id, err))
		}
	}
	return errors.Join(errs...)
}
