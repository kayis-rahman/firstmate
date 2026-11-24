package discordrelay

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"
)

const (
	owner   = "1000000000000000001"
	other   = "2000000000000000002"
	channel = "3000000000000000003"
)

type post struct {
	Content   string
	ReplyTo   string
	Silent    bool
	Reaction  string
	ReactedTo string
}

// fakeDiscord is a real HTTP server so the REST client is exercised too.
type fakeDiscord struct {
	mu    sync.Mutex
	msgs  []Message
	posts []post
	next  int
	srv   *httptest.Server
	token string
}

func newFake(t *testing.T) *fakeDiscord {
	f := &fakeDiscord{next: 5000, token: "test-token-value"}
	f.srv = httptest.NewServer(http.HandlerFunc(f.serve))
	t.Cleanup(f.srv.Close)
	return f
}

func (f *fakeDiscord) serve(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if r.Header.Get("Authorization") != "Bot "+f.token {
		http.Error(w, "no", 401)
		return
	}
	switch {
	case r.Method == "GET":
		after := r.URL.Query().Get("after")
		var out []map[string]any
		for i := len(f.msgs) - 1; i >= 0; i-- { // newest first, like Discord
			m := f.msgs[i]
			if after == "" || snowLess(after, m.ID) {
				out = append(out, map[string]any{"id": m.ID, "channel_id": m.ChannelID, "content": m.Content,
					"timestamp": m.At.Format(time.RFC3339), "author": map[string]any{"id": m.AuthorID, "bot": m.Bot}})
			}
		}
		json.NewEncoder(w).Encode(out)
	case r.Method == "POST":
		var b struct {
			Content string `json:"content"`
			Ref     *struct {
				ID string `json:"message_id"`
			} `json:"message_reference"`
			Flags int `json:"flags"`
		}
		json.NewDecoder(r.Body).Decode(&b)
		p := post{Content: b.Content, Silent: b.Flags&(1<<12) != 0}
		if b.Ref != nil {
			p.ReplyTo = b.Ref.ID
		}
		f.posts = append(f.posts, p)
		f.next++
		json.NewEncoder(w).Encode(map[string]string{"id": itoa(f.next)})
	case r.Method == "PUT":
		parts := strings.Split(r.URL.Path, "/")
		emoji, _ := url.PathUnescape(parts[6])
		f.posts = append(f.posts, post{Reaction: emoji, ReactedTo: parts[4]})
		w.WriteHeader(204)
	}
}

func itoa(n int) string { return strconv.Itoa(n) }

func (f *fakeDiscord) say(id, author, text string, at time.Time) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.msgs = append(f.msgs, Message{ID: id, ChannelID: channel, Content: text, AuthorID: author, At: at})
}

func (f *fakeDiscord) postsSnapshot() []post {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]post(nil), f.posts...)
}

type fakeInbox struct {
	mu      sync.Mutex
	notes   map[string]string // reqID -> text
	calls   int
	failing bool
	replies []Reply
	handled map[string]bool // note ids firstmate has acknowledged
}

func (b *fakeInbox) Note(req, text string) (string, bool, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.calls++
	if b.failing {
		return "", false, errors.New("inbox down")
	}
	if b.notes == nil {
		b.notes = map[string]string{}
	}
	if _, ok := b.notes[req]; !ok {
		b.notes[req] = text
	}
	return "note-" + req, true, nil
}

func (b *fakeInbox) Handled() (map[string]bool, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	m := map[string]bool{}
	for k := range b.handled {
		m[k] = true
	}
	return m, nil
}

func (b *fakeInbox) Replies(after string) ([]Reply, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	var out []Reply
	for _, r := range b.replies {
		if r.Cursor > after {
			out = append(out, r)
		}
	}
	return out, nil
}

type rig struct {
	t   *testing.T
	f   *fakeDiscord
	box *fakeInbox
	dir string
	now time.Time
	r   *Relay
}

func newRig(t *testing.T) *rig {
	g := &rig{t: t, f: newFake(t), box: &fakeInbox{}, dir: t.TempDir(), now: time.Date(2026, 1, 1, 12, 0, 0, 0, time.UTC)}
	g.open()
	return g
}

// open (re)creates the relay over the same state dir, as a restart does.
func (g *rig) open() {
	if g.r != nil {
		g.r.St.Close()
	}
	cfg := Config{APIBase: g.f.srv.URL, ChannelID: channel, OwnerID: owner, StateDir: g.dir}
	if err := cfg.Validate(); err != nil {
		g.t.Fatal(err)
	}
	st, err := OpenStore(g.dir)
	if err != nil {
		g.t.Fatal(err)
	}
	g.t.Cleanup(st.Close)
	g.r = &Relay{Cfg: cfg, Chat: &HTTPChat{Base: g.f.srv.URL, Channel: channel, Token: g.f.token}, Box: g.box, St: st,
		Now: func() time.Time { return g.now }}
}

func (g *rig) tick() {
	if err := g.r.Tick(); err != nil {
		g.t.Logf("tick: %v", err)
	}
}

func (g *rig) baseline() { g.tick() } // first tick sets the cursor on an empty channel

func TestCaptureAckAndThreadedReply(t *testing.T) {
	g := newRig(t)
	g.r.Cfg.Receipt = "reply"
	g.r.Cfg.Ack = "none"
	g.baseline()
	g.f.say("5001", owner, "ship the thing", g.now)
	g.tick()
	if g.box.notes["discord-5001"] != "ship the thing" {
		t.Fatalf("not captured: %v", g.box.notes)
	}
	ps := g.f.postsSnapshot()
	if len(ps) != 1 || ps[0].ReplyTo != "5001" || !ps[0].Silent {
		t.Fatalf("want one silent threaded receipt, got %+v", ps)
	}
	g.box.replies = []Reply{{NoteID: "note-discord-5001", Body: "done, PR is up", Cursor: "000000000001"}}
	g.tick()
	g.tick() // second pass must not resend
	ps = g.f.postsSnapshot()
	if len(ps) != 2 || ps[1].ReplyTo != "5001" || ps[1].Content != "done, PR is up" || ps[1].Silent {
		t.Fatalf("want threaded reply once, got %+v", ps)
	}
}

func TestReactionReceipt(t *testing.T) {
	g := newRig(t)
	g.r.Cfg.Receipt = "reaction"
	g.baseline()
	g.f.say("5001", owner, "hi", g.now)
	g.tick()
	ps := g.f.postsSnapshot()
	if len(ps) != 1 || ps[0].Reaction != "👀" || ps[0].ReactedTo != "5001" {
		t.Fatalf("want a reaction receipt, got %+v", ps)
	}
}

func TestSeenThenAcknowledgedOnceAcrossRestart(t *testing.T) {
	g := newRig(t)
	g.baseline()
	g.f.say("5001", owner, "do it", g.now)
	g.tick()
	g.tick()
	ps := g.f.postsSnapshot()
	if len(ps) != 1 || ps[0].Reaction != "👀" || ps[0].ReactedTo != "5001" {
		t.Fatalf("want exactly one seen mark and no ack yet, got %+v", ps)
	}
	g.box.handled = map[string]bool{"note-discord-5001": true}
	g.tick()
	g.open() // restart
	g.tick()
	g.tick()
	ps = g.f.postsSnapshot()
	if len(ps) != 2 || ps[1].Reaction != "✅" || ps[1].ReactedTo != "5001" {
		t.Fatalf("want one seen and one ack, got %+v", ps)
	}
}

func TestAckRetriedAfterFailureAndReplyMode(t *testing.T) {
	g := newRig(t)
	g.r.Cfg.Ack = "reply"
	g.baseline()
	g.f.say("5001", owner, "do it", g.now)
	g.tick()
	g.box.handled = map[string]bool{"note-discord-5001": true}
	g.f.token = "rotated" // marks fail while the transport is broken
	g.tick()
	if g.r.St.S.Messages["5001"].Acked {
		t.Fatal("acked despite failed mark")
	}
	g.f.token = "test-token-value"
	g.tick()
	g.tick()
	ps := g.f.postsSnapshot()
	if len(ps) != 2 || ps[1].Content != "Handled by firstmate." || ps[1].ReplyTo != "5001" || !ps[1].Silent {
		t.Fatalf("want one silent threaded ack, got %+v", ps)
	}
}

func TestRestartReplayAfterInboxOutage(t *testing.T) {
	g := newRig(t)
	g.baseline()
	g.box.failing = true
	g.f.say("5001", owner, "important", g.now)
	g.tick()
	if len(g.box.notes) != 0 {
		t.Fatal("should not have enqueued while inbox is down")
	}
	g.open() // crash/restart: cursor already advanced past 5001
	g.box.failing = false
	g.tick()
	if g.box.notes["discord-5001"] != "important" {
		t.Fatalf("pending message lost across restart: %v", g.box.notes)
	}
	if n := len(g.box.notes); n != 1 {
		t.Fatalf("want exactly one note, got %d", n)
	}
	g.open()
	g.tick()
	if got := g.box.calls; got != 2 {
		t.Fatalf("restart after success must not re-enqueue; inbox calls=%d", got)
	}
}

func TestDuplicateDeliveryAndEventDedupe(t *testing.T) {
	g := newRig(t)
	g.baseline()
	g.f.say("5001", owner, "once", g.now)
	g.tick()
	// Discord redelivers the same message (cursor lost / replayed fetch).
	g.r.St.S.Cursor = "0"
	g.tick()
	if g.box.calls != 1 {
		t.Fatalf("duplicate message enqueued again, calls=%d", g.box.calls)
	}
	ev := EventIn{ID: "pr-7", Kind: "review-ready", Task: "t1", Text: "PR ready"}
	for i := 0; i < 2; i++ {
		if err := WriteEvent(g.r.St.EventsDir(), ev); err != nil {
			t.Fatal(err)
		}
		g.tick()
	}
	n := 0
	for _, p := range g.f.postsSnapshot() {
		if strings.Contains(p.Content, "PR ready") {
			n++
		}
	}
	if n != 1 {
		t.Fatalf("duplicate event alerted %d times", n)
	}
}

func TestUnauthorizedSenderAndBots(t *testing.T) {
	g := newRig(t)
	g.baseline()
	g.f.say("5001", other, "do evil", g.now)
	g.f.msgs = append(g.f.msgs, Message{ID: "5002", ChannelID: channel, Content: "bot", AuthorID: owner, Bot: true})
	g.f.msgs = append(g.f.msgs, Message{ID: "5003", ChannelID: "999999999", Content: "wrong channel", AuthorID: owner})
	g.tick()
	if g.box.calls != 0 || len(g.f.postsSnapshot()) != 0 {
		t.Fatalf("unauthorized input acted on: calls=%d posts=%v", g.box.calls, g.f.postsSnapshot())
	}
	if g.r.St.S.Rejected != 1 || !g.r.St.S.LastOwnerAt.IsZero() {
		t.Fatalf("rejection not counted or owner presence spoofed: %+v", g.r.St.S)
	}
}

func TestUrgentImmediateRoutineBatched(t *testing.T) {
	g := newRig(t)
	g.baseline()
	WriteEvent(g.r.St.EventsDir(), EventIn{ID: "a", Kind: "progress", Task: "t1", Text: "tests green"})
	WriteEvent(g.r.St.EventsDir(), EventIn{ID: "b", Kind: "progress", Task: "t1", Text: "tests green"})
	WriteEvent(g.r.St.EventsDir(), EventIn{ID: "c", Kind: "blocker", Task: "t2", Text: "login needed"})
	g.now = g.now.Add(time.Minute) // less than the batch window since zero? LastBatchAt is zero so first digest is due
	g.r.St.S.LastBatchAt = g.now
	g.tick()
	ps := g.f.postsSnapshot()
	if len(ps) != 1 || ps[0].Silent || !strings.Contains(ps[0].Content, "login needed") {
		t.Fatalf("want one immediate loud blocker alert, got %+v", ps)
	}
	g.now = g.now.Add(11 * time.Minute)
	g.tick()
	ps = g.f.postsSnapshot()
	last := ps[0]
	for _, p := range ps {
		if strings.HasPrefix(p.Content, "Fleet update") {
			last = p
		}
	}
	if !last.Silent || !strings.Contains(last.Content, "t1: tests green (x2)") {
		t.Fatalf("want one quiet collapsed digest, got %+v", last)
	}
}

func alertRig(t *testing.T) (*rig, int) {
	g := newRig(t)
	g.baseline()
	WriteEvent(g.r.St.EventsDir(), EventIn{ID: "d1", Kind: "decision", Task: "t1", Text: "pick option"})
	g.tick()
	return g, len(g.f.postsSnapshot())
}

func TestReminderSentOnceAfterAMinute(t *testing.T) {
	g, n := alertRig(t)
	g.now = g.now.Add(30 * time.Second)
	g.tick()
	if len(g.f.postsSnapshot()) != n {
		t.Fatal("reminded too early")
	}
	g.now = g.now.Add(40 * time.Second)
	g.tick()
	g.now = g.now.Add(time.Hour)
	g.tick()
	g.open()
	g.tick()
	ps := g.f.postsSnapshot()
	if len(ps) != n+1 || !strings.HasPrefix(ps[n].Content, "Still waiting") || ps[n].ReplyTo == "" {
		t.Fatalf("want exactly one threaded reminder, got %+v", ps)
	}
}

func TestReminderSuppressedWhenAnsweredOrActive(t *testing.T) {
	g, n := alertRig(t)
	g.now = g.now.Add(30 * time.Second)
	g.f.say("5100", owner, "go with option 2", g.now)
	g.tick() // answered: captured, receipt posted
	g.now = g.now.Add(5 * time.Minute)
	g.tick()
	for _, p := range g.f.postsSnapshot()[n:] {
		if strings.HasPrefix(p.Content, "Still waiting") {
			t.Fatal("reminded after the captain answered")
		}
	}

	g2, n2 := alertRig(t)
	g2.r.St.S.LastOwnerAt = g2.now.Add(50 * time.Second) // chatting about something else
	g2.now = g2.now.Add(70 * time.Second)
	g2.tick()
	if len(g2.f.postsSnapshot()) != n2 {
		t.Fatal("reminded while captain is active in chat")
	}
}

func TestAlertQuietWhileActive(t *testing.T) {
	g := newRig(t)
	g.baseline()
	g.r.St.S.LastOwnerAt = g.now
	WriteEvent(g.r.St.EventsDir(), EventIn{ID: "x", Kind: "login", Text: "login needed"})
	g.tick()
	if ps := g.f.postsSnapshot(); len(ps) != 1 || !ps[0].Silent {
		t.Fatalf("want a silent alert while active, got %+v", ps)
	}
}

func TestRedactsSecretsAndRejectsBadEvents(t *testing.T) {
	g := newRig(t)
	g.baseline()
	hook := "https://discord.com/api/webhooks/123456789012345678/AbCdEfGh-token"
	WriteEvent(g.r.St.EventsDir(), EventIn{ID: "s", Kind: "blocker", Text: "see " + hook + " token=abcdefgh12345"})
	os.WriteFile(filepath.Join(g.r.St.EventsDir(), "bad.json"), []byte("{nope"), 0o600)
	g.tick()
	ps := g.f.postsSnapshot()
	if len(ps) != 1 || strings.Contains(ps[0].Content, "webhooks") || strings.Contains(ps[0].Content, "abcdefgh12345") {
		t.Fatalf("secret leaked: %+v", ps)
	}
	if _, err := os.Stat(filepath.Join(g.r.St.EventsDir(), "bad.json.rejected")); err != nil {
		t.Fatal("malformed event not quarantined")
	}
}

func TestSecondInstanceRefusedAndConfigValidation(t *testing.T) {
	g := newRig(t)
	if _, err := OpenStore(g.dir); err == nil {
		t.Fatal("second instance must be refused")
	}
	c := Config{ChannelID: channel, OwnerID: "abc", StateDir: "x"}
	if c.Validate() == nil {
		t.Fatal("non-snowflake owner accepted")
	}
	c = Config{APIBase: "http://evil.example", ChannelID: channel, OwnerID: owner, StateDir: "x"}
	if c.Validate() == nil {
		t.Fatal("plain http remote accepted")
	}
}

func TestExecInboxAgainstStub(t *testing.T) {
	dir := t.TempDir()
	stub := filepath.Join(dir, "fm-inbox.sh")
	script := `#!/bin/sh
case "$1" in
note) echo '{"id":"n-1","outcome":"created"}'; exit 3;;
receipts) echo '{"replies":[{"id":"n-1","body":"hi","cursor":"000000000002"}],"handled":[{"id":"n-1"}]}';;
esac
`
	os.WriteFile(stub, []byte(script), 0o755)
	e := ExecInbox{Cmd: stub, Home: dir}
	id, announced, err := e.Note("discord-1", "text")
	if err != nil || id != "n-1" || announced {
		t.Fatalf("note: %v %v %v", id, announced, err)
	}
	if h, err := e.Handled(); err != nil || !h["n-1"] {
		t.Fatalf("handled: %v %v", h, err)
	}
	rs, err := e.Replies("")
	if err != nil || len(rs) != 1 || rs[0].Body != "hi" {
		t.Fatalf("replies: %v %v", rs, err)
	}
}
