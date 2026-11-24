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
	Content       string
	ReplyTo       string
	Silent        bool
	Reaction      string
	ReactedTo     string
	Nonce         string
	EnforceNonce  bool
	RequireParent bool
}

// fakeDiscord is a real HTTP server so the REST client is exercised too.
type fakeDiscord struct {
	mu            sync.Mutex
	msgs          []Message
	posts         []post
	next          int
	srv           *httptest.Server
	token         string
	postStatus    int
	fetchStatus   int
	missingParent string
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
		if f.fetchStatus != 0 {
			w.WriteHeader(f.fetchStatus)
			return
		}
		after := r.URL.Query().Get("after")
		var out []map[string]any
		for i := len(f.msgs) - 1; i >= 0; i-- { // newest first, like Discord
			m := f.msgs[i]
			if after == "" || snowLess(after, m.ID) {
				row := map[string]any{"id": m.ID, "channel_id": m.ChannelID, "content": m.Content,
					"timestamp": m.At.Format(time.RFC3339), "author": map[string]any{"id": m.AuthorID, "bot": m.Bot}}
				if m.ReplyTo != "" {
					row["message_reference"] = map[string]any{"message_id": m.ReplyTo, "channel_id": m.ChannelID}
				}
				out = append(out, row)
			}
		}
		json.NewEncoder(w).Encode(out)
	case r.Method == "POST":
		if f.postStatus != 0 {
			w.WriteHeader(f.postStatus)
			return
		}
		var b struct {
			Content string `json:"content"`
			Ref     *struct {
				ID            string `json:"message_id"`
				RequireParent bool   `json:"fail_if_not_exists"`
			} `json:"message_reference"`
			Flags        int    `json:"flags"`
			Nonce        string `json:"nonce"`
			EnforceNonce bool   `json:"enforce_nonce"`
		}
		json.NewDecoder(r.Body).Decode(&b)
		p := post{Content: b.Content, Silent: b.Flags&(1<<12) != 0, Nonce: b.Nonce, EnforceNonce: b.EnforceNonce}
		if b.Ref != nil {
			p.ReplyTo = b.Ref.ID
			p.RequireParent = b.Ref.RequireParent
			if p.RequireParent && p.ReplyTo == f.missingParent {
				w.WriteHeader(http.StatusNotFound)
				return
			}
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
	mu          sync.Mutex
	notes       map[string]string // reqID -> text
	calls       int
	failing     bool
	wakePending bool
	replies     []Reply
	handled     map[string]bool // note ids firstmate has acknowledged
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
	return "note-" + req, !b.wakePending, nil
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
	g := &rig{t: t, f: newFake(t), box: &fakeInbox{}, dir: filepath.Join(t.TempDir(), "relay[shadow]"), now: time.Date(2026, 1, 1, 12, 0, 0, 0, time.UTC)}
	g.open()
	return g
}

// open (re)creates the relay over the same state dir, as a restart does.
func (g *rig) open() {
	if g.r != nil {
		g.r.St.Close()
	}
	cfg := Config{ChannelID: channel, OwnerID: owner, StateDir: g.dir}
	if err := cfg.Validate(); err != nil {
		g.t.Fatal(err)
	}
	st, err := OpenStore(g.dir, Scope{channel, owner, g.dir})
	if err != nil {
		g.t.Fatal(err)
	}
	g.t.Cleanup(st.Close)
	g.r = &Relay{Cfg: cfg, Chat: &HTTPChat{base: g.f.srv.URL, Channel: channel, Token: g.f.token}, Box: g.box, St: st,
		Now: func() time.Time { return g.now }}
}

func (g *rig) tick() {
	if err := g.r.Tick(); err != nil {
		g.t.Logf("tick: %v", err)
	}
}

func (g *rig) emit(e EventIn) error {
	return WriteEvent(g.dir, Scope{channel, owner, g.dir}, e)
}

func (g *rig) baseline() { g.tick() } // first tick sets the cursor on an empty channel

func TestCaptureAckAndThreadedReply(t *testing.T) {
	g := newRig(t)
	g.baseline()
	g.f.say("5001", owner, "ship the thing", g.now)
	g.tick()
	if g.box.notes["discord-5001"] != "ship the thing" {
		t.Fatalf("not captured: %v", g.box.notes)
	}
	ps := g.f.postsSnapshot()
	if len(ps) != 1 || ps[0].ReactedTo != "5001" || ps[0].Reaction != "👀" {
		t.Fatalf("want one seen reaction, got %+v", ps)
	}
	g.box.replies = []Reply{{NoteID: "note-discord-5001", Body: "done, PR is up", Cursor: "000000000001"}}
	g.tick()
	g.tick() // second pass must not resend
	ps = g.f.postsSnapshot()
	if len(ps) != 2 || ps[1].ReplyTo != "5001" || ps[1].Content != "done, PR is up" || ps[1].Silent || !ps[1].RequireParent || !ps[1].EnforceNonce || ps[1].Nonce == "" {
		t.Fatalf("want threaded reply once, got %+v", ps)
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

func TestAckRetriedAfterFailure(t *testing.T) {
	g := newRig(t)
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
	if len(ps) != 2 || ps[1].Reaction != "✅" || ps[1].ReactedTo != "5001" {
		t.Fatalf("want one acknowledged reaction, got %+v", ps)
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
	if ps := g.f.postsSnapshot(); len(ps) != 1 || ps[0].Reaction != "👀" {
		t.Fatalf("seen must not wait for inbox recovery: %+v", ps)
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

func TestSeenForAllCapturesWhileWakeIsPending(t *testing.T) {
	g := newRig(t)
	g.baseline()
	g.box.wakePending = true
	g.f.say("5001", owner, "first", g.now)
	g.f.say("5002", owner, "second", g.now)
	g.tick()
	if ps := g.f.postsSnapshot(); len(ps) != 2 || ps[0].Reaction != "👀" || ps[1].Reaction != "👀" || ps[1].ReactedTo != "5002" || g.box.calls != 1 {
		t.Fatalf("expected both seen marks with only one enqueue attempt: %+v, calls=%d", ps, g.box.calls)
	}
	g.open()
	g.box.wakePending = false
	g.tick()
	if len(g.box.notes) != 2 || len(g.f.postsSnapshot()) != 2 {
		t.Fatal("expected both notes and no repeated reactions after restart")
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
	ev := EventIn{ID: "pr-7", Kind: "review-ready", Text: "PR ready"}
	for i := 0; i < 2; i++ {
		if err := g.emit(ev); err != nil {
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
	if !g.r.St.S.LastOwnerAt.IsZero() {
		t.Fatalf("owner presence spoofed: %+v", g.r.St.S)
	}
}

func alertRig(t *testing.T) (*rig, int) {
	g := newRig(t)
	g.baseline()
	g.emit(EventIn{ID: "d1", Kind: "decision", Text: "pick option"})
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

func TestOnlyReferencedAlertIsAnswered(t *testing.T) {
	g, _ := alertRig(t)
	if err := g.emit(EventIn{ID: "second", Kind: "blocker", Text: "second alert"}); err != nil {
		t.Fatal(err)
	}
	g.tick()
	first := g.r.St.S.Events["d1"].MsgID
	second := g.r.St.S.Events["second"].MsgID
	g.now = g.now.Add(30 * time.Second)
	g.f.say("5100", owner, "unrelated chat", g.now)
	g.f.msgs = append(g.f.msgs, Message{ID: "5101", ChannelID: channel, AuthorID: owner, Content: "answer", ReplyTo: first, At: g.now})
	g.tick()
	g.open()
	if !g.r.St.S.Events["d1"].Answered || g.r.St.S.Events["second"].Answered {
		t.Fatal("expected only the referenced alert to be answered")
	}
	n := len(g.f.postsSnapshot())
	g.now = g.now.Add(time.Minute)
	g.tick()
	if len(g.f.postsSnapshot()) != n {
		t.Fatal("reminded while the owner was active")
	}
	g.now = g.now.Add(time.Minute)
	g.tick()
	g.tick()
	if ps := g.f.postsSnapshot(); len(ps) != n+1 || ps[n].ReplyTo != second {
		t.Fatalf("expected one reminder for only the unanswered alert: %+v", ps)
	}
}

func TestAlertQuietWhileActive(t *testing.T) {
	g := newRig(t)
	g.baseline()
	g.f.say("5001", owner, "", g.now)
	g.emit(EventIn{ID: "x", Kind: "login", Text: "login needed"})
	g.tick()
	if ps := g.f.postsSnapshot(); len(ps) != 1 || !ps[0].Silent {
		t.Fatalf("want a silent alert while active, got %+v", ps)
	}
}

func TestRedactsSecretsAndRejectsBadEvents(t *testing.T) {
	g := newRig(t)
	g.baseline()
	hook := "https://discord.com/api/webhooks/123456789012345678/AbCdEfGh-token"
	g.emit(EventIn{ID: "s", Kind: "blocker", Text: "see " + hook + " github_pat_abcde_abcdefghijklmno_abcdefghijklmnop token=abcdefgh12345"})
	os.WriteFile(filepath.Join(g.r.St.eventsDir(), "bad.json"), []byte("{nope"), 0o600)
	g.tick()
	ps := g.f.postsSnapshot()
	if len(ps) != 1 || strings.Contains(ps[0].Content, "webhooks") || strings.Contains(ps[0].Content, "abcdefgh12345") || strings.Contains(ps[0].Content, "github_pat_") {
		t.Fatalf("secret leaked: %+v", ps)
	}
	if _, err := os.Stat(filepath.Join(g.r.St.eventsDir(), "bad.json.rejected")); err != nil {
		t.Fatal("malformed event not quarantined")
	}
}

func TestSecondInstanceRefusedAndConfigValidation(t *testing.T) {
	g := newRig(t)
	if _, err := OpenStore(g.dir, Scope{channel, owner, g.dir}); err == nil {
		t.Fatal("second instance must be refused")
	}
	c := Config{ChannelID: channel, OwnerID: "abc", StateDir: "x"}
	if c.Validate() == nil {
		t.Fatal("non-snowflake owner accepted")
	}
	for _, field := range []string{"api_base", "receipt", "ack", "active_chat_seconds", "max_message_runes", "token_env", "inbox_cmd", "poll_seconds", "reminder_seconds", "batch_seconds"} {
		path := filepath.Join(t.TempDir(), "config.json")
		c := map[string]any{"channel_id": channel, "owner_id": owner, "state_dir": g.dir, field: "removed"}
		b, err := json.Marshal(c)
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, b, 0o600); err != nil {
			t.Fatal(err)
		}
		if _, err := LoadConfig(path); err == nil {
			t.Fatalf("removed config field %q accepted", field)
		}
	}
}

func TestScopeMismatchRefusedAfterRestart(t *testing.T) {
	g := newRig(t)
	g.baseline()
	g.r.St.Close()
	for _, scope := range []Scope{{other, owner, g.dir}, {channel, other, g.dir}, {channel, owner, t.TempDir()}} {
		if st, err := OpenStore(g.dir, scope); err == nil {
			st.Close()
			t.Fatalf("opened with mismatched scope %+v", scope)
		}
	}
	g.open()
	if g.r.St.S.Cursor != "0" {
		t.Fatal("matching scope lost its baseline")
	}
}

func blockSave(t *testing.T, g *rig) func() {
	t.Helper()
	path := filepath.Join(g.dir, "state.json.tmp")
	if err := os.Mkdir(path, 0o700); err != nil {
		t.Fatal(err)
	}
	return func() {
		if err := os.Remove(path); err != nil {
			t.Fatal(err)
		}
	}
}

func TestFailedSaveDoesNotConsumeEventOrExposeCapture(t *testing.T) {
	g := newRig(t)
	g.baseline()
	restore := blockSave(t, g)
	g.f.say("5001", owner, "capture", g.now)
	e := EventIn{ID: "pending", Kind: "decision", Text: "decide"}
	if err := g.emit(e); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 2; i++ {
		if err := g.r.Tick(); err == nil {
			t.Fatal("expected write error")
		}
	}
	if g.box.calls != 0 || len(g.f.postsSnapshot()) != 0 {
		t.Fatal("uncommitted capture or alert was dispatched")
	}
	if _, err := os.Stat(filepath.Join(g.r.St.eventsDir(), eventFilename(e.ID))); err != nil {
		t.Fatal(err)
	}
	restore()
	g.open()
	g.tick()
	if g.box.notes["discord-5001"] != "capture" || len(g.f.postsSnapshot()) != 2 {
		t.Fatal("capture or alert was lost after restart")
	}
}

func TestReplyReusesNonceAfterFailedSave(t *testing.T) {
	g := newRig(t)
	g.baseline()
	g.f.say("5001", owner, "capture", g.now)
	g.tick()
	g.box.replies = []Reply{{NoteID: "note-discord-5001", Body: "reply", Cursor: "1"}}
	restore := blockSave(t, g)
	if err := g.r.Tick(); err == nil {
		t.Fatal("expected write error after posting reply")
	}
	restore()
	g.open()
	g.tick()
	ps := g.f.postsSnapshot()
	if len(ps) != 3 || !ps[1].EnforceNonce || !ps[2].EnforceNonce || ps[1].Nonce == "" || ps[1].Nonce != ps[2].Nonce {
		t.Fatalf("reply retries did not use the same enforced nonce: %+v", ps)
	}
}

func TestReminderRetriedAfterDiscordRejection(t *testing.T) {
	g, n := alertRig(t)
	g.now = g.now.Add(time.Minute)
	for _, status := range []int{http.StatusTooManyRequests, http.StatusServiceUnavailable} {
		g.f.postStatus = status
		if err := g.r.Tick(); err == nil || g.r.St.S.Events["d1"].Reminded {
			t.Fatalf("status %d consumed reminder or hid the error", status)
		}
		g.open()
	}
	g.f.postStatus = 0
	g.tick()
	g.tick()
	if ps := g.f.postsSnapshot(); len(ps) != n+1 || ps[n].ReplyTo == "" || !ps[n].RequireParent {
		t.Fatalf("want one native reminder after recovery: %+v", ps)
	}
}

func TestOlderOwnerMessageHoldsButDoesNotAnswer(t *testing.T) {
	g, n := alertRig(t)
	g.now = g.now.Add(time.Minute)
	g.f.say("5000", owner, "sent before the alert", g.now.Add(-time.Minute))
	g.tick()
	if ps := g.f.postsSnapshot(); len(ps) != n+1 || ps[n].Reaction != "👀" {
		t.Fatalf("expected capture but no reminder while active: %+v", ps)
	}
	g.now = g.now.Add(time.Minute)
	g.tick()
	if ps := g.f.postsSnapshot(); len(ps) != n+2 || ps[n+1].ReplyTo != "5001" {
		t.Fatalf("expected held reminder at the two-minute boundary: %+v", ps)
	}
}

func TestStartupEmptyOwnerMessageCountsAsPresence(t *testing.T) {
	g := newRig(t)
	g.f.say("4999", owner, "", g.now.Add(-time.Minute))
	g.f.say("5000", other, "newer message", g.now)
	if err := g.emit(EventIn{ID: "a", Kind: "blocker", Text: "quiet"}); err != nil {
		t.Fatal(err)
	}
	g.tick()
	if ps := g.f.postsSnapshot(); len(ps) != 1 || !ps[0].Silent || g.box.calls != 0 {
		t.Fatalf("expected quiet alert without replay: %+v, inbox calls=%d", ps, g.box.calls)
	}
}

func TestUnknownAlertKindRejectedByEmitAndSpool(t *testing.T) {
	g := newRig(t)
	g.baseline()
	e := EventIn{ID: "typo", Kind: "blokcer", Text: "not an alert"}
	if err := g.emit(e); err == nil {
		t.Fatal("emit accepted unknown alert kind")
	}
	b, err := json.Marshal(queuedEvent{Scope: g.r.St.S.Scope, EventIn: e})
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(g.r.St.eventsDir(), eventFilename(e.ID))
	if err := os.WriteFile(path, b, 0o600); err != nil {
		t.Fatal(err)
	}
	g.tick()
	if _, err := os.Stat(path + ".rejected"); err != nil || len(g.f.postsSnapshot()) != 0 {
		t.Fatalf("expected unknown kind quarantined without delivery: %v", err)
	}
}

func TestCaseDistinctOccurrenceIDsBothDeliver(t *testing.T) {
	g := newRig(t)
	g.baseline()
	for _, id := range []string{"Review-7", "review-7", "Review-7"} {
		if err := g.emit(EventIn{ID: id, Kind: "review-ready", Text: id}); err != nil {
			t.Fatal(err)
		}
	}
	files, err := os.ReadDir(g.r.St.eventsDir())
	if err != nil {
		t.Fatal(err)
	}
	if len(files) != 2 || strings.EqualFold(files[0].Name(), files[1].Name()) {
		t.Fatalf("spool filenames collide under case folding: %v", files)
	}
	g.tick()
	g.tick()
	ps := g.f.postsSnapshot()
	if len(ps) != 2 || !strings.HasSuffix(ps[0].Content, "Review-7") || !strings.HasSuffix(ps[1].Content, "review-7") {
		t.Fatalf("expected one delivery per exact ID: %+v", ps)
	}
}

func TestEmitRequiresBoundScope(t *testing.T) {
	g := newRig(t)
	e := EventIn{ID: "a", Kind: "decision", Text: "private decision"}
	scope := Scope{channel, owner, g.dir}
	fresh := filepath.Join(t.TempDir(), "unbound")
	if err := WriteEvent(fresh, scope, e); err == nil {
		t.Fatal("emit accepted an unbound directory")
	}
	for _, wrong := range []Scope{{other, owner, g.dir}, {channel, other, g.dir}, {channel, owner, fresh}} {
		if err := WriteEvent(g.dir, wrong, e); err == nil {
			t.Fatalf("emit accepted mismatched scope %+v", wrong)
		}
	}
	b, err := json.Marshal(e)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(g.r.St.eventsDir(), eventFilename(e.ID)), b, 0o600); err != nil {
		t.Fatal(err)
	}
	g.tick()
	if len(g.f.postsSnapshot()) != 0 {
		t.Fatal("unscoped event was delivered")
	}
	results := make(chan error, 8)
	for i := 0; i < cap(results); i++ {
		go func() { results <- WriteEvent(g.dir, scope, e) }()
	}
	for i := 0; i < cap(results); i++ {
		if err := <-results; err != nil {
			t.Fatal(err)
		}
	}
	g.tick()
	g.tick()
	if ps := g.f.postsSnapshot(); len(ps) != 1 || !strings.Contains(ps[0].Content, e.Text) {
		t.Fatalf("expected one delivery from the literal state directory: %+v", ps)
	}
}

func TestFailedInboundStillPushesAlertAndHoldsReminder(t *testing.T) {
	for _, failSave := range []bool{false, true} {
		g, n := alertRig(t)
		g.now = g.now.Add(time.Minute)
		g.f.msgs = append(g.f.msgs, Message{ID: "5100", ChannelID: channel, AuthorID: owner, Content: "the answer", ReplyTo: g.r.St.S.Events["d1"].MsgID, At: g.now})
		if err := g.emit(EventIn{ID: "next", Kind: "blocker", Text: "new blocker"}); err != nil {
			t.Fatal(err)
		}
		g.f.postStatus = http.StatusServiceUnavailable
		g.f.fetchStatus = http.StatusTooManyRequests
		g.tick()
		g.f.postStatus = 0
		var restore func()
		if failSave {
			g.f.fetchStatus = 0
			restore = blockSave(t, g)
		}
		if err := g.r.Tick(); err == nil {
			t.Fatal("inbound failure was not reported")
		}
		if restore != nil {
			restore()
		}
		ps := g.f.postsSnapshot()
		if len(ps) != n+1 || ps[n].Silent || !strings.Contains(ps[n].Content, "new blocker") {
			t.Fatalf("expected only a new alert with a push during inbound failure (save failure=%v): %+v", failSave, ps)
		}
		g.f.fetchStatus = 0
		g.tick()
		if !g.r.St.S.Events["d1"].Answered || g.r.St.S.Events["d1"].Reminded {
			t.Fatal("expected a committed answer without a stale reminder")
		}
	}
}

func TestBlockedReplyDoesNotBlockMappedAnswer(t *testing.T) {
	for _, blocker := range []string{"missing parent", "unmapped note"} {
		t.Run(blocker, func(t *testing.T) {
			g := newRig(t)
			g.baseline()
			g.f.say("5002", owner, "mapped", g.now)
			g.tick()
			if blocker == "missing parent" {
				g.f.missingParent = "5003"
			} else {
				g.box.failing = true
			}
			g.f.say("5003", owner, "first note", g.now)
			g.tick()
			n := len(g.f.postsSnapshot())
			g.box.replies = []Reply{{"note-discord-5003", "first reply", "1"}, {"note-discord-5002", "second reply", "2"}}
			g.tick()
			g.open()
			g.tick()
			if ps := g.f.postsSnapshot(); len(ps) != n+1 || ps[n].ReplyTo != "5002" || g.r.St.S.ReplyCursor != "" {
				t.Fatalf("expected only the independent reply with the cursor pinned: %+v", ps)
			}
			g.box.failing = false
			g.f.missingParent = ""
			g.tick()
			if ps := g.f.postsSnapshot(); len(ps) != n+2 || ps[n+1].ReplyTo != "5003" || g.r.St.S.ReplyCursor != "2" {
				t.Fatalf("expected recovered reply and cursor progress without duplication: %+v", ps)
			}
		})
	}
}

func TestExecInboxAgainstStub(t *testing.T) {
	dir := t.TempDir()
	stub := filepath.Join(dir, "fm-inbox.sh")
	for _, key := range []string{"FM_HOME", "FM_STATE_OVERRIDE", "FM_DATA_OVERRIDE", "FM_CONFIG_OVERRIDE", "FM_ROOT_OVERRIDE", "FM_DISCORD_RELAY_TOKEN", "FM_WAKE_QUEUE", "FM_WAKE_QUEUE_LOCK"} {
		t.Setenv(key, "not-the-bound-home")
	}
	script := `#!/bin/sh
[ "$FM_HOME" = "${0%/*}" ] || exit 2
[ -z "${FM_STATE_OVERRIDE+x}${FM_DATA_OVERRIDE+x}${FM_CONFIG_OVERRIDE+x}${FM_ROOT_OVERRIDE+x}${FM_DISCORD_RELAY_TOKEN+x}${FM_WAKE_QUEUE+x}${FM_WAKE_QUEUE_LOCK+x}" ] || exit 2
case "$1" in
note)
  [ "$#" = 6 ] && [ "$2" = --request-id ] && [ "$3" = discord-1 ] &&
  [ "$4" = --json ] && [ "$5" = -- ] && [ "$6" = - ] || exit 2
  [ "$(cat)" = - ] || exit 2
  echo '{"id":"n-1","outcome":"created"}'; exit 3;;
receipts) echo '{"replies":[{"id":"n-1","body":"hi","cursor":"000000000002"}],"handled":[{"id":"n-1"}]}';;
esac
`
	os.WriteFile(stub, []byte(script), 0o755)
	e := ExecInbox{Cmd: stub, Home: dir}
	id, announced, err := e.Note("discord-1", "-")
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
