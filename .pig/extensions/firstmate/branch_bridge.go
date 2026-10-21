package firstmate

// Cross-realm branch dispatch for PiG (docs/supervision-protocols/pig.md
// "Branch dispatch over the shared bus"; the Node-side contract lives in
// .pi/extensions/lib/fm-branch-dispatch.ts).
//
// PiG runs wake delivery in this Go extension while the supervision branch
// conversation lives in the Node fm-branch-supervision extension. The
// in-process FM_BRANCH_DISPATCH_EVENT handshake cannot cross that realm
// boundary, so the shared pi.events bus carries the SAME offer verdict
// instead: this side announces each actionable close on
// fm-pig-watch:actionable-close {id, message} with result and handled
// listeners already registered, the Node side replies synchronously on
// fm-pig-watch:dispatch-result {id, accepted} before its handler returns, and
// an accepted wake reports its settlement on fm-pig-watch:handled {id,
// failed?}. Resolution means handling is complete (the branch ran its drain
// acknowledgement); a failed settlement - or no verdict inside the bound -
// means deliver the wake to main exactly as before the bridge existed.
//
// Readiness gates every offer: the Node realm announces itself once per
// session on fm-pig-watch:bridge-ready, so a home without the branch
// extension never waits - no listener means no latency and no behavior
// change. Every payload crosses as JSON values; no promise or function ever
// leaves the Node realm, and this file never gains an independent eligibility
// rule - the Node side reuses the Pi branch's own checks.

import (
	"strconv"
	"sync"
	"time"

	"github.com/MichaelKinsy/PiG/extensions/sdk"
)

const (
	pigBridgeReadyEvent   = "fm-pig-watch:bridge-ready"
	pigBridgeCloseEvent   = "fm-pig-watch:actionable-close"
	pigBridgeResultEvent  = "fm-pig-watch:dispatch-result"
	pigBridgeHandledEvent = "fm-pig-watch:handled"

	// How long a READY bridge may stay silent before the offer is treated as
	// declined. A live listener answers inside the same synchronous emit, so
	// this bound only covers a listener that vanished between readiness and
	// the close - the safe direction is always main delivery.
	bridgeVerdictTimeout = 2 * time.Second
)

// branchBus is the shared pi.events surface the bridge needs. sdk.EventBus
// implements it; tests substitute a synchronous fake of the same shape.
type branchBus interface {
	Emit(channel string, data any) error
	On(channel string, handler sdk.EventBusHandler) (func(), error)
}

// branchOffer is one in-flight cross-realm offer. verdict is answered inside
// the announce emit; handled arrives when the branch settlement resolves
// (true) or rejects (false).
type branchOffer struct {
	verdict chan bool
	handled chan bool
}

type branchBridge struct {
	bus branchBus

	mu     sync.Mutex
	ready  bool
	nextID uint64
	offers map[string]*branchOffer
}

func newBranchBridge(bus branchBus) *branchBridge {
	b := &branchBridge{bus: bus, offers: map[string]*branchOffer{}}
	if bus == nil {
		return b
	}
	if _, err := bus.On(pigBridgeReadyEvent, func(sdk.Context, any) error {
		b.setReady(true)
		return nil
	}); err != nil {
		return b
	}
	_, _ = bus.On(pigBridgeResultEvent, func(_ sdk.Context, data any) error {
		fields, _ := data.(map[string]any)
		id, _ := fields["id"].(string)
		accepted, _ := fields["accepted"].(bool)
		if offer := b.offerByID(id); offer != nil {
			select {
			case offer.verdict <- accepted:
			default:
			}
		}
		return nil
	})
	_, _ = bus.On(pigBridgeHandledEvent, func(_ sdk.Context, data any) error {
		fields, _ := data.(map[string]any)
		id, _ := fields["id"].(string)
		failed, _ := fields["failed"].(bool)
		if offer := b.offerByID(id); offer != nil {
			select {
			case offer.handled <- !failed:
			default:
			}
		}
		return nil
	})
	return b
}

func (b *branchBridge) setReady(ready bool) {
	b.mu.Lock()
	b.ready = ready
	b.mu.Unlock()
}

func (b *branchBridge) offerByID(id string) *branchOffer {
	if id == "" {
		return nil
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.offers[id]
}

func (b *branchBridge) forget(id string) {
	b.mu.Lock()
	delete(b.offers, id)
	b.mu.Unlock()
}

// ready reports whether the Node realm announced a listening branch.
func (b *branchBridge) listening() bool {
	if b == nil {
		return false
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.ready
}

// offer announces one actionable close and waits for the branch's verdict. A
// nil offer result means the branch declined (or no verdict arrived inside
// the bound) and the caller must deliver to main as before the bridge.
func (b *branchBridge) announce(message string) *branchOffer {
	if b == nil || b.bus == nil {
		return nil
	}
	b.mu.Lock()
	if !b.ready {
		b.mu.Unlock()
		return nil
	}
	b.nextID++
	id := "pig-offer-" + strconv.FormatUint(b.nextID, 10)
	offer := &branchOffer{verdict: make(chan bool, 1), handled: make(chan bool, 1)}
	b.offers[id] = offer
	b.mu.Unlock()
	if err := b.bus.Emit(pigBridgeCloseEvent, map[string]any{"id": id, "message": message}); err != nil {
		b.forget(id)
		return nil
	}
	select {
	case accepted := <-offer.verdict:
		if !accepted {
			b.forget(id)
			return nil
		}
		return offer
	case <-time.After(bridgeVerdictTimeout):
		b.forget(id)
		return nil
	}
}

// settle waits for the accepted offer's settlement report. true means the
// branch handled the wake; false means its settlement rejected, or the
// watcher began closing - both mean deliver to main exactly as before.
func (b *branchBridge) settle(w *watcher, offer *branchOffer) bool {
	if b == nil || offer == nil {
		return false
	}
	defer func() {
		b.mu.Lock()
		for id, pending := range b.offers {
			if pending == offer {
				delete(b.offers, id)
			}
		}
		b.mu.Unlock()
	}()
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	for {
		select {
		case handled := <-offer.handled:
			return handled
		case <-ticker.C:
			if w.closingNow() {
				return false
			}
		}
	}
}

// closingNow reports whether the watcher is shutting down; a settlement wait
// must not outlive the extension's own session.
func (w *watcher) closingNow() bool {
	watchMu.Lock()
	defer watchMu.Unlock()
	return w.closing
}
