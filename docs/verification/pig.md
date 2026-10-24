# PiG worker verification

The CLI and extension probes were exercised on 2026-10-20 with PiG 0.5.1+1.3.0.1402973a.

The capability probe ran `pig --version` and `pig --help`; PiG reported `0.5.1+1.3.0.1402973a` and advertised `--model`, `--thinking`, `--tui-mode`, `--approve`, `--exclude-tools`, and `--extension`.

The Pi-compatible extension probe ran `PI_CODING_AGENT=true pig --no-approve -e <task-state>/firstmate-pig-worker-integration-v1.pi-ext.ts --print "respond exactly PIG-WORKER-OK"` from a temporary directory and returned `PIG-WORKER-OK` with exit 0.

A later captain-confirmed isolated Firstmate spawn smoke launched a PiG worker, loaded the generated extension, observed busy and turn-end events, and completed a trivial task.
The smoke did not verify steering inbox delivery, interrupt, exit, or relaunch; those lifecycle paths remain unverified and must not be represented as exercised.

The focused portable regression is `bash tests/fm-pig-harness.test.sh`.
