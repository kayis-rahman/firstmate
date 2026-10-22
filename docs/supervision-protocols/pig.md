Mode: PiG primary adapter; supervision lifecycle partially verified, with the managed branch now wired over the shared bus.

The 2026-10-19 live run verified session-start digest delivery, direct `/ahoy`
and `/bearings` invocation, pre-tool denials, actionable wake delivery to main,
a healthy-cycle turn-end check, and `fm-control` interrupt, relaunch refusal,
and exit. The 2026-10-19 cross-realm live run additionally verified the
managed supervision branch over the shared pi.events bus: the Go watcher
announced an actionable close, the Node `fm-branch-supervision` extension
answered `accepted=true`, the branch handled the wake off main, and reported
`handled` on settlement. A decision-owned wake was declined and delivered to
main exactly as before the bridge. The live evidence is recorded in
[supervision verification](../verification/supervision.md#pig-primary-recheck-live-verification-2026-10-19).

PiG requires explicit `-e` paths; configure the Pi supervision path when launching
from the Firstmate repository:

```sh
pig --approve \
  -e .pi/extensions/fm-primary-turnend-guard.ts \
  -e .pi/extensions/fm-primary-pi-watch.ts \
  -e .pi/extensions/fm-branch-supervision.ts
```

The `/afk` and `/quiet` routes are configured to use the Pi branch and skip the
away daemon. Configuring these extensions does not verify watcher restoration,
wake-drain acknowledgement, ship-ready landing, or section 9 escalation wording;
direct TUI invocation is unverified as well.

## Branch dispatch over the shared bus

PiG runs the watcher in its Go extension and the supervision branch in its Node
extension, so the in-process `fm-branch-supervision:dispatch` event cannot
carry the offer. The shared `pi.events` bus (the same bus across Node, Go,
Rust and Python realms) carries the same verdict instead, in the Go realm's
`branch_bridge.go` and the Node realm's bridge listener in
`.pi/extensions/fm-branch-supervision.ts`:

- `fm-pig-watch:bridge-ready` (Node -> Go, once per session): the Node
  branch extension announces a listener. No announcement means no offer and
  no latency - main delivery exactly as before the bridge.
- `fm-pig-watch:actionable-close` {id, message} (Go -> Node): the watcher
  announces one actionable close with result and handled listeners already
  registered. The Node side runs the identical eligibility, ownership, and
  cooldown checks as the Pi dispatch listener, replies synchronously on
  `fm-pig-watch:dispatch-result` {id, accepted} before its handler returns,
  and an accepted wake reports its settlement on
  `fm-pig-watch:handled` {id, failed?}.
- A declined verdict, a rejected settlement, a listener that never answers
  within the bound, or no ready announcement falls back to main delivery
  exactly as before the bridge.

The Go unit tests in `.pig/extensions/firstmate/branch_bridge_test.go` cover
accept, decline, rejected settlement, timeout, no-readiness, nil-bridge, and
the cross-language channel-name contract against
`.pi/extensions/lib/fm-branch-dispatch.ts`.
