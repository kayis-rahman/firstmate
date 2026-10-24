# PiG

PiG has two distinct Firstmate integrations: a primary adapter and a crewmate/scout worker adapter.
The primary adapter owns primary-session supervision; the worker adapter supports crew and scout dispatch only, not secondmates.
The worker smoke verified Firstmate spawn, extension loading, busy and turn-end events, and completion of a trivial task.
Worker steering inbox delivery, interrupt, exit, and relaunch remain unverified.

## Primary adapter

The primary live verification on 2026-10-17 used PiG 0.4.1+1.0.3, macOS arm64, and Go 1.27.2.

| Fact | Value |
|---|---|
| Binary | `pig`, resolved from `PATH`. |
| Identity | PiG primary startup sets `FM_PIG_HARNESS=pig`; `../../../bin/fm-harness.sh` trusts it only when the exact `pig` executable is in the process ancestry. |
| Session lock | The session lock names the PiG process; PiG's isolated Node extension process is accepted when the lock owner is an exact live `pig` process and the tracked Pi extension marker names its live descendant. |
| Model | `openai-codex/gpt-6-luna` produced live responses at medium effort; an earlier smoke also exercised `openai-codex/gpt-5.5`, while PiG rejected `gpt-5.3-codex-spark` with its unsupported-model diagnostic. |
| Thinking | `--thinking medium` was exercised live; PiG documents `off`, `minimal`, `low`, `medium`, `high`, `xhigh`, and `max`, and an earlier integration check exercised `minimal`. |
| Primary extensions | The Pi supervision path uses `.pi/extensions/fm-primary-turnend-guard.ts`, `.pi/extensions/fm-primary-pi-watch.ts`, and `.pi/extensions/fm-branch-supervision.ts`, loaded with `-e` from the Firstmate repository. |
| Go runtime extension | `.pig/extensions/firstmate` builds and tests against the released PiG v0.4.1 SDK v0.3.1; it provides session-start, watcher, turn-end/pre-tool guards, Calm's working-row widget, and a shared-event bridge to the Node supervision extension. |
| Go commands | `.pig/extensions/fm-firstmate` auto-registers `/ahoy` and `/bearings`; direct TUI invocation and the full Bearings data read were verified live. |
| Lifecycle control | Primary interrupt and exit were verified live after a clean completed turn; relaunch was refused before stopping the live agent. |
| Background wake coverage | The Go watcher and Node supervision extension exchange branch offers over the shared `pi.events` bus; actionable and decision-owned wake routing were verified across realms on 2026-10-19. |

The primary verification exercised session-start delivery, both pre-tool denials, watcher continuity across tested turns, actionable wake delivery, and healthy and unhealthy turn-end behavior on 2026-10-17.
A cross-realm live run on 2026-10-19 additionally verified managed-branch delivery over the shared event bus, including accepting an eligible wake and declining a decision-owned wake.
The Go extension synthesizes a next-turn user message directing PiG to follow the already-loaded `ahoy` or `bearings` skill; it does not reimplement either skill.
PiG auto-discovers the top-level `.pig/extensions/fm-firstmate` resource in the Firstmate repository, while the Pi supervision files are explicitly loaded with `-e`.
Run the credentialed end-to-end verification only in a throwaway `FM_HOME` and named Herdr lab, using `openai-codex/gpt-6-luna` at medium effort:

```sh
FM_PIG_PRIMARY_LIVE_E2E=1 \
FM_PIG_PRIMARY_LIVE_MODEL=openai-codex/gpt-6-luna \
FM_PIG_PRIMARY_LIVE_THINKING=medium \
FM_PIG_PRIMARY_LIVE_CODE_ROOT=<Firstmate-repository> \
bash tests/fm-pig-primary-supervision-live-e2e.test.sh
```

The test must not point `FM_HOME` at the primary home or a secondmate home.
Use a verified non-PiG worker harness in `config/crew-harness` before dispatching crew or scout work from a PiG primary.
`../../../bin/fm-harness.sh secondmate` applies the same primary-only boundary when the secondmate harness is absent or `default`.

## Worker adapter

The worker adapter is a separate launch path that invokes the external `pig` CLI in Firstmate's isolated task worktree and loads the Pi-compatible busy-state extension through `-e`.
PiG 0.5.1+1.3.0.1402973a reported `AI_AGENT=pig` to child processes, which distinguishes this worker version from Pi.

### Verified CLI facts

- `pig --version` reported `0.5.1+1.3.0.1402973a`.
- `pig --help` listed `--model`, `--thinking`, `--tui-mode`, `--approve`, `--exclude-tools`, and `--extension`.
- A `pig --no-approve -e <extension> --print <prompt>` probe loaded the Pi-compatible extension and returned the requested response.
- The PiG worker process name is `pig`.

### Firstmate wiring and limits

- `fm-spawn.sh` resolves `pig` and launches it with one positional brief and `-e <state>/<task>.pi-ext.ts`.
- The busy-state mapping uses Pi's `pi-ext` events: `agent_start`, `agent_settled`, and `turn_end`; the supervised worker smoke verified busy and turn-end events.
- The control mapping is configured for Pi's Escape interrupt and `/quit` exit, but neither has been verified live with the worker adapter.
- `fm-control.sh` refuses secondmate launches because the worker adapter has no primary-supervision protocol.
- Relaunch is configured to start a fresh PiG process from the task brief; this path is not yet verified, and session resume is not enabled.
- Steering inbox delivery has not been verified with the worker adapter.

See [PiG verification](../../../../../docs/verification/pig.md) for worker evidence and unverified lifecycle paths.
