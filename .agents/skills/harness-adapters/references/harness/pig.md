# PiG (`pig`) candidate adapter

PiG 0.5.1+1.3.0.1402973a is in supervised trial and is not yet a verified Firstmate worker runtime.

The current candidate launches the `pig` CLI in Firstmate's isolated task worktree and uses Pi's `pi-ext` busy-state extension through `-e`.
PiG reports `AI_AGENT=pig` to child processes, which distinguishes it from Pi.

## Verified CLI facts

- `pig --version` reports `0.5.1+1.3.0.1402973a`.
- `pig --help` lists `--model`, `--thinking`, `--tui-mode`, `--approve`, `--exclude-tools`, and `--extension`.
- A `pig --no-approve -e <extension> --print <prompt>` probe loaded the existing Pi-family extension and returned the requested response.
- The PiG process name is `pig`.

## Candidate Firstmate wiring

- `fm-spawn.sh` resolves `pig` and launches it with the one-positional-brief and `-e <state>/<task>.pi-ext.ts` form.
- The candidate busy-state mapping uses Pi's `pi-ext` events: `agent_start`, `agent_settled`, and `turn_end`.
- The candidate control mapping uses Pi's Escape interrupt and `/quit` exit.
- `fm-control.sh` refuses secondmate launches because PiG primary supervision is not implemented.
- Relaunch starts a fresh PiG process from the task brief; session resume is not enabled.

The candidate Firstmate spawn, busy events, process classification, steering, interrupt, exit, relaunch, and teardown still require the authorized isolated live smoke.
See [PiG verification](../../../../../docs/verification/pig.md) for commands and outstanding checks.
