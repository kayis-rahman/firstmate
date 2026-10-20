# PiG worker verification

PiG worker smoke was exercised on 2026-10-20 with PiG 0.5.1+1.3.0.1402973a.

The initial capability probe ran `pig --version` and `pig --help`; PiG reported `0.5.1+1.3.0.1402973a` and advertised `--model`, `--thinking`, `--tui-mode`, `--approve`, `--exclude-tools`, and `--extension`.

The Pi-compatible extension probe ran `PI_CODING_AGENT=true pig --no-approve -e <task-state>/firstmate-pig-worker-integration-v1.pi-ext.ts --print "respond exactly PIG-WORKER-OK"` from a temporary directory and returned `PIG-WORKER-OK` with exit 0.

PiG worker spawn through Firstmate, terminal/process-state classification, steering, interrupt, exit, relaunch, and teardown remain pending the authorized isolated spawn smoke; this record does not claim those paths verified.

The focused portable regression is `bash tests/fm-pig-harness.test.sh`; the Firstmate worker spawn smoke is the live guard that must be completed before claiming the adapter verified.
