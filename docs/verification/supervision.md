# Supervision verification

Operator behavior and active limits remain in the linked current guides.

### PiG primary integration, live verification, 2026-10-17

The installed PiG 0.4.1+1.0.3 runtime was exercised on macOS arm64 with
`openai-codex/gpt-6-luna` at medium effort in a named Herdr lab and throwaway
Firstmate homes. It also passed `bin/fm-control.sh` interrupt and clean-state
exit, and verified that unsupported PiG primary-only worker relaunch is refused
while preserving the live agent. Background delivery to a separate managed
supervision branch and filtering host transcript rows remain unverified because
PiG's released SDK cannot create managed agent sessions or filter host rows.

### PiG primary recheck, live verification, 2026-10-19

A second installed PiG primary run used a separate scratch home and an
explicitly named non-default Herdr session, with `FM_PIG_PRIMARY_LIVE_CODE_ROOT`
set to the plain Firstmate checkout because the test worktree is linked. The
model quoted the injected session-start digest from that scratch home, directly
invoked `/ahoy` and `/bearings`, accepted both pre-tool denials, received an
actionable status wake in main, and passed the healthy-cycle turn-end check.
The run also verified `fm-control.sh` interrupt, primary-only relaunch refusal,
and exit behavior. The first primary's watcher was confirmed live after the
actionable wake. The second-home recovery assertion did not pass: the
extension-loaded marker and session lock existed, but the test did not observe
a live watcher lock before its timeout. This is an unresolved recovery result,
not evidence that automatic recovery works or that the owning PiG extension
failed to load. The probe did not exercise dispatch intake, worker briefing or
spawn, ship-ready landing, section 9 escalation wording, or wake-drain
acknowledgement. The exact output and current SDK/API research are in the
private task report; no managed background branch capability was proven.

### PiG cross-realm branch dispatch, live verification, 2026-10-19

A live run in a real Firstmate checkout (not the linked worktree) loaded the
real Go `firstmate` extension and the real Node `fm-branch-supervision` plus a
passive bus observer, with a pre-seeded eligible status wake. The observer
recorded, in order: `fm-pig-watch:bridge-ready {}`,
`fm-pig-watch:dispatch-result {"id":"pig-offer-1","accepted":true}`,
then `fm-pig-watch:actionable-close {"id":"pig-offer-1",...}`. The branch
session file was created, the branch ran the wake as a real agent turn
(`fm-branch-prompt` system prompt, `bash` tool, drain and acknowledgement), and
reported `fm-pig-watch:handled {"id":"pig-offer-1"}` 33 seconds later. Main
received no `FIRSTMATE WATCHER WAKE` envelope for that wake; the durable
outcome store gained no duplicate for the declined path. A later stale-endpoint
wake was declined (`accepted:false`) and delivered to main exactly as before
the bridge. The transport is therefore verified end to end: ready, verdict,
settlement, and the declined fallback, with no new process. Go unit tests in
`.pig/extensions/firstmate/branch_bridge_test.go` cover accept, decline,
rejected settlement, timeout, no-readiness, nil-bridge, and the cross-language
channel-name contract.

Remaining unverified for PiG: watcher restoration in a second home, wake-drain
acknowledgement, dispatch intake, worker briefing or spawn, ship-ready landing,
section 9 escalation wording, and `/afk`/`/quiet` posture behavior.
