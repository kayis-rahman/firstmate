# PiG

PiG is a distinct Go-native harness selected as `pig`, never as `pi` or `pi-signed`.
Its executable and anchored process identity are both `pig`.
Firstmate's `FM_PIG_HARNESS=pig` launch marker is accepted only with matching PiG process ancestry.

## Operating facts

| Fact | Value |
|---|---|
| Configuration | PiG defaults to `~/.pig`; `PIG_HOME` selects the config root and `PIG_CODING_AGENT_DIR` selects the agent directory. PiG does not read or write `~/.pi`. |
| Model | PiG accepts `--model` and `--thinking`; use `pig --list-models` and `pig auth check` for its own catalog and authentication evidence. |
| Trust | Project resources require trust; an explicit `-e` path is available for a Firstmate-owned extension outside the project. |
| Extension compatibility | PiG's Node subprocess runtime accepts a Pi-compatible TypeScript default export. This confirms loading and registration only; each Firstmate extension's behavior still needs live verification. |
| TUI | `--tui-mode regular` is supported. Escape cancels the active dialog or model turn; Ctrl+C clears the editor, and a second Ctrl+C exits. |

PiG 0.4.0+1.0.0 has an EXPERIMENTAL Firstmate adapter.
Repository checks cover distinct harness detection, launch construction, trust setup, and CLI model/effort handling; these checks do not establish live integration behavior.
Interactive/fleet lifecycle parity, busy/settled reporting, durable steering, interrupt, recovery, and primary supervision remain unverified.
Do not gate PiG dispatch or recovery based on this experimental status, because existing fleet workers use PiG.

PiG's own documentation is the authority for its installed CLI, model catalog, trust behavior, and extension API.
The distinct native PiG extension port and Calm behavior parity are separate work; Firstmate's Pi-compatible Node extension path is compatibility behavior and has not been validated for Calm parity.