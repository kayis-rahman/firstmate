# PiG (`pig`)

PiG is a supported crewmate and scout worker runtime, verified for spawn, extension load, busy and turn-end events, and completion of a trivial task.
It is not supported as a primary or secondmate runtime.

The adapter launches the `pig` CLI in Firstmate's isolated task worktree and uses Pi's `pi-ext` busy-state extension through `-e`.
PiG reports `AI_AGENT=pig` to child processes, which distinguishes it from Pi.

## Verified CLI facts

- `pig --version` reports `0.5.1+1.3.0.1402973a`.
- `pig --help` lists `--model`, `--thinking`, `--tui-mode`, `--approve`, `--exclude-tools`, and `--extension`.
- A `pig --no-approve -e <extension> --print <prompt>` probe loaded the existing Pi-family extension and returned the requested response.
- The PiG process name is `pig`.

## Firstmate wiring

- `fm-spawn.sh` resolves `pig` and launches it with the one-positional-brief and `-e <state>/<task>.pi-ext.ts` form.
- The busy-state mapping uses Pi's `pi-ext` events: `agent_start`, `agent_settled`, and `turn_end`; the supervised smoke verified busy and turn-end events.
- The control mapping is configured for Pi's Escape interrupt and `/quit` exit, but neither has been verified live with PiG.
- `fm-control.sh` refuses secondmate launches because PiG has no primary supervision protocol.
- Relaunch is configured to start a fresh PiG process from the task brief; this path is not yet verified, and session resume is not enabled.
- Steering inbox delivery has not been verified with PiG.

See [PiG verification](../../../../../docs/verification/pig.md) for the evidence and unverified lifecycle paths.
