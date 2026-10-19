package firstmate

// Cross-realm branch dispatch (branch_bridge.go): the Go watcher announces an
// actionable close on the shared pi.events bus, a listening Node-side branch
// replies its verdict synchronously inside the emit, and an accepted wake is
// withheld from main until the branch reports its settlement. Every other
// shape - no readiness, a declined verdict, a rejected settlement, or a
// silent ready listener - keeps today's main delivery unchanged.

import (
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/MichaelKinsy/PiG/extensions/sdk"
)

// fakeBus is a synchronous dispatcher with the host bus's ordering: Emit runs
// every registered handler to completion before it returns, and a nested Emit
// from inside a handler (the Node realm's verdict reply) runs immediately.
type fakeBus struct {
	mu        sync.Mutex
	handlers  map[string][]sdk.EventBusHandler
	announces []string
}

func newFakeBus() *fakeBus {
	return &fakeBus{handlers: map[string][]sdk.EventBusHandler{}}
}

func (b *fakeBus) On(channel string, handler sdk.EventBusHandler) (func(), error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.handlers[channel] = append(b.handlers[channel], handler)
	return func() {}, nil
}

func (b *fakeBus) Emit(channel string, data any) error {
	b.mu.Lock()
	if channel == pigBridgeCloseEvent {
		fields, _ := data.(map[string]any)
		id, _ := fields["id"].(string)
		b.announces = append(b.announces, id)
	}
	handlers := append([]sdk.EventBusHandler(nil), b.handlers[channel]...)
	b.mu.Unlock()
	for _, handler := range handlers {
		if err := handler(sdk.Context{}, data); err != nil {
			return err
		}
	}
	return nil
}

func (b *fakeBus) announceCount() int {
	b.mu.Lock()
	defer b.mu.Unlock()
	return len(b.announces)
}

// nodeBranch listens like the fm-branch-supervision extension: verdict inside
// the announce, settlement on its own schedule.
func (b *fakeBus) nodeBranch(t *testing.T, accept bool, settleAfter time.Duration, failed bool) {
	t.Helper()
	_, err := b.On(pigBridgeCloseEvent, func(_ sdk.Context, data any) error {
		fields, _ := data.(map[string]any)
		id, _ := fields["id"].(string)
		if err := b.Emit(pigBridgeResultEvent, map[string]any{"id": id, "accepted": accept}); err != nil {
			return err
		}
		if accept {
			go func() {
				time.Sleep(settleAfter)
				payload := map[string]any{"id": id}
				if failed {
					payload["failed"] = true
				}
				_ = b.Emit(pigBridgeHandledEvent, payload)
			}()
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}

func bridgedWatcher(t *testing.T, home watchHome, host watchHost, bus *fakeBus) *watcher {
	t.Helper()
	w := newTestWatcher(t, home, host)
	w.branchBridge = newBranchBridge(bus)
	return w
}

func assertDeliveredToMainOnce(t *testing.T, host *fakeHost) {
	t.Helper()
	eventually(t, "the wake follow-up on main", func() bool { return len(host.sent()) >= 1 })
	sent := host.sent()[0]
	if !strings.HasPrefix(sent, "followUp|ENC[watcher]:FIRSTMATE WATCHER WAKE: signal: wake one") {
		t.Fatalf("delivered %q, want the encoded watcher wake as a follow-up", sent)
	}
}

func TestBranchAcceptedWakeIsHandledOffMainAndFinished(t *testing.T) {
	home := newWatchHome(t, armScriptOnce)
	host := newFakeHost()
	bus := newFakeBus()
	w := bridgedWatcher(t, home, host, bus)
	bus.nodeBranch(t, true, 50*time.Millisecond, false)
	// The Node realm announces its listener every session start.
	if err := bus.Emit(pigBridgeReadyEvent, nil); err != nil {
		t.Fatal(err)
	}
	if err := w.onSessionStart(); err != nil {
		t.Fatal(err)
	}
	eventually(t, "the cross-realm announce", func() bool { return bus.announceCount() == 1 })
	eventually(t, "the branch settlement to finish the pending record", func() bool {
		watchMu.Lock()
		defer watchMu.Unlock()
		return len(w.generation.pending) == 0
	})
	if got := len(host.sent()); got != 0 {
		t.Fatalf("main received %d wakes, want none while the branch handled the wake: %v", got, host.sent())
	}
	if _, err := os.Stat(w.actionableHandoff); !os.IsNotExist(err) {
		t.Fatalf("handoff file still present after branch handling: %v", err)
	}
	if bus.announceCount() != 1 {
		t.Fatalf("announced %d closes, want exactly one", bus.announceCount())
	}
}

func TestBranchDeclinedOfferStillDeliversToMain(t *testing.T) {
	home := newWatchHome(t, armScriptOnce)
	host := newFakeHost()
	bus := newFakeBus()
	w := bridgedWatcher(t, home, host, bus)
	bus.nodeBranch(t, false, 0, false)
	if err := bus.Emit(pigBridgeReadyEvent, nil); err != nil {
		t.Fatal(err)
	}
	if err := w.onSessionStart(); err != nil {
		t.Fatal(err)
	}
	assertDeliveredToMainOnce(t, host)
}

func TestBranchRejectedSettlementFallsBackToMain(t *testing.T) {
	home := newWatchHome(t, armScriptOnce)
	host := newFakeHost()
	bus := newFakeBus()
	w := bridgedWatcher(t, home, host, bus)
	bus.nodeBranch(t, true, 50*time.Millisecond, true)
	if err := bus.Emit(pigBridgeReadyEvent, nil); err != nil {
		t.Fatal(err)
	}
	if err := w.onSessionStart(); err != nil {
		t.Fatal(err)
	}
	assertDeliveredToMainOnce(t, host)
}

func TestSilentReadyBranchTimesOutAndDeliversToMain(t *testing.T) {
	home := newWatchHome(t, armScriptOnce)
	host := newFakeHost()
	bus := newFakeBus()
	w := bridgedWatcher(t, home, host, bus)
	// Ready, but no listener answers the close: the bounded no-verdict
	// fallback must deliver to main exactly as before the bridge.
	if err := bus.Emit(pigBridgeReadyEvent, nil); err != nil {
		t.Fatal(err)
	}
	if err := w.onSessionStart(); err != nil {
		t.Fatal(err)
	}
	assertDeliveredToMainOnce(t, host)
}

func TestNoReadinessMeansNoAnnounceAndOrdinaryMainDelivery(t *testing.T) {
	home := newWatchHome(t, armScriptOnce)
	host := newFakeHost()
	bus := newFakeBus()
	w := bridgedWatcher(t, home, host, bus)
	if err := w.onSessionStart(); err != nil {
		t.Fatal(err)
	}
	assertDeliveredToMainOnce(t, host)
	if got := bus.announceCount(); got != 0 {
		t.Fatalf("announced %d closes without a ready listener, want none", got)
	}
}

func TestNilBridgeKeepsOrdinaryMainDelivery(t *testing.T) {
	home := newWatchHome(t, armScriptOnce)
	host := newFakeHost()
	w := newTestWatcher(t, home, host)
	if err := w.onSessionStart(); err != nil {
		t.Fatal(err)
	}
	assertDeliveredToMainOnce(t, host)
}

func TestBridgeChannelsMatchTheNodeContract(t *testing.T) {
	// The channel names are a cross-language contract with
	// .pi/extensions/lib/fm-branch-dispatch.ts; this pins the Go side to the
	// strings the Node side exports.
	source, err := os.ReadFile(filepath.Join("..", "..", "..", ".pi", "extensions", "lib", "fm-branch-dispatch.ts"))
	if err != nil {
		t.Fatalf("could not read the Node dispatch contract: %v", err)
	}
	for name, value := range map[string]string{
		"FM_PIG_WATCH_READY_EVENT":   pigBridgeReadyEvent,
		"FM_PIG_WATCH_CLOSE_EVENT":   pigBridgeCloseEvent,
		"FM_PIG_WATCH_RESULT_EVENT":  pigBridgeResultEvent,
		"FM_PIG_WATCH_HANDLED_EVENT": pigBridgeHandledEvent,
	} {
		if !strings.Contains(string(source), name+" = \""+value+"\"") {
			t.Fatalf("channel %s=%q is not the value %s exports", name, value, ".pi/extensions/lib/fm-branch-dispatch.ts")
		}
	}
}
