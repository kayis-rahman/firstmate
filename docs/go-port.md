# Go port status and helper inventory

This document owns the Go port inventory for `bin/` scripts and the helper-phase parity record.
Shell remains the default execution path for every ported helper until a home explicitly opts in via `config/go-pilot`.

## Helper phase selection

The helper phase targets standalone executed helper scripts with existing `tests/` suites, excluding sourced `*-lib.sh` libraries and lifecycle-core scripts (`spawn`, `watch`, `teardown`, `wake`, `classify`, `control`, `send`, `brief`, `backends`, `afk`).

Picked helper set (all at full parity):

- `forge-detect` (`bin/fm-forge-detect.sh` -> `go/cmd/fm-forge-detect`)
- `env-cause` (`bin/fm-env-cause.sh` -> `go/cmd/fm-env-cause`)
- `storage-policy` (`bin/fm-storage-policy.sh` -> `go/cmd/fm-storage-policy`)
- `test-tap-verify` (`bin/fm-test-tap-verify.sh` -> `go/cmd/fm-test-tap-verify`)
- `lint-workflows` (`bin/fm-lint-workflows.sh` -> `go/cmd/fm-lint-workflows`)

Pre-existing non-helper or direct-Go binaries in `go/cmd/`:

- `fm-image-gen` (`bin/fm-image-gen.sh`) and `fm-discord-relay` already invoke Go directly.
- `fm-path` (`bin/fm-path-lib.sh`), `fm-line-cap` (`bin/fm-line-cap-lib.sh`), `fm-env-get` (`bin/fm-env-lib.sh`), and `fm-tangle-check` (`bin/fm-tangle-lib.sh`) are sourced libraries whose Go binaries cannot replace shell sourcing, so they remain unlisted for `config/go-pilot` routing.

## Helper parity results

Each picked helper passed its full `tests/` suite in both default shell mode and scratch `config/go-pilot` Go mode, plus Go unit tests (`go test ./...`).

| Tool | Test suite | Shell passes | Go-pilot passes | Go unit tests | Status |
| --- | --- | --- | --- | --- | --- |
| forge-detect | `tests/fm-forge-detect.test.sh` | 5 | 5 | 5 | full parity |
| env-cause | `tests/fm-env-cause.test.sh` | 10 | 10 | 3 | full parity |
| storage-policy | `tests/fm-storage-policy.test.sh` | 7 | 7 | 3 | full parity |
| test-tap-verify | `tests/fm-test-tap-verify.test.sh` | 8 | 8 | 4 | full parity |
| lint-workflows | `tests/fm-lint-workflows.test.sh` | 16 | 16 | 3 | full parity |

## `bin/` script inventory

| script | lines | executed or sourced | phase | Go status |
| --- | --- | --- | --- | --- |
| bin/fm-afk-contract.sh | 710 | executed | core-lifecycle | shell |
| bin/fm-afk-launch.sh | 1020 | executed | core-lifecycle | shell |
| bin/fm-afk-return.sh | 936 | executed | core-lifecycle | shell |
| bin/fm-afk-start.sh | 181 | executed | core-lifecycle | shell |
| bin/fm-agent-process-lib.sh | 134 | sourced | library | shell |
| bin/fm-agy-trust.sh | 241 | executed | helper | shell |
| bin/fm-approval-failover.sh | 95 | executed | helper | shell |
| bin/fm-arm-pretool-check.sh | 216 | executed | helper | shell |
| bin/fm-backend-hometag-lib.sh | 53 | sourced | library | shell |
| bin/fm-backend.sh | 1692 | executed | core-lifecycle | shell |
| bin/fm-backlog-handoff.sh | 1100 | executed | helper | shell |
| bin/fm-backlog-receive.sh | 188 | executed | helper | shell |
| bin/fm-backlog-transition-lib.sh | 1239 | sourced | library | shell |
| bin/fm-bearings-board.sh | 459 | executed | helper | shell |
| bin/fm-bearings-snapshot.sh | 747 | executed | later-ops | shell |
| bin/fm-bootstrap.sh | 1905 | executed | later-ops | shell |
| bin/fm-branch-outcome.sh | 851 | executed | helper | shell |
| bin/fm-branch-prompt.sh | 201 | executed | helper | shell |
| bin/fm-branch-report.sh | 160 | executed | helper | shell |
| bin/fm-brief-heading-lib.sh | 95 | sourced | library | shell |
| bin/fm-brief.sh | 864 | executed | core-lifecycle | shell |
| bin/fm-busy-event.sh | 422 | executed | helper | shell |
| bin/fm-busy-lib.sh | 1344 | sourced | library | shell |
| bin/fm-capacity.sh | 1392 | executed | helper | shell |
| bin/fm-captain-hold.sh | 2435 | executed | later-ops | shell |
| bin/fm-cd-pretool-check.sh | 208 | executed | helper | shell |
| bin/fm-check-lib.sh | 74 | sourced | library | shell |
| bin/fm-check-register.sh | 42 | executed | helper | shell |
| bin/fm-check-unregister.sh | 52 | executed | helper | shell |
| bin/fm-classify-lib.sh | 3063 | sourced | library | shell |
| bin/fm-claude-account-quota.sh | 147 | executed | helper | shell |
| bin/fm-claude-stop-autoarm.sh | 811 | executed | later-ops | shell |
| bin/fm-claude-trust.sh | 594 | executed | helper | shell |
| bin/fm-codex-stop-park.sh | 307 | executed | later-ops | shell |
| bin/fm-composer-lib.sh | 2629 | sourced | library | shell |
| bin/fm-config-inherit-lib.sh | 1467 | sourced | library | shell |
| bin/fm-config-push.sh | 264 | executed | helper | shell |
| bin/fm-contributions.sh | 862 | executed | helper | shell |
| bin/fm-control-lib.sh | 652 | sourced | library | shell |
| bin/fm-control.sh | 1335 | executed | core-lifecycle | shell |
| bin/fm-cortex-plugin.sh | 66 | executed | later-ops | shell |
| bin/fm-credential-source-lib.sh | 139 | sourced | library | shell |
| bin/fm-crew-state.sh | 1645 | executed | later-ops | shell |
| bin/fm-cursor-lib.sh | 293 | sourced | library | shell |
| bin/fm-decision-api.sh | 112 | executed | helper | shell |
| bin/fm-decision-hold.sh | 232 | executed | helper | shell |
| bin/fm-devin-config.sh | 59 | executed | helper | shell |
| bin/fm-discord-front-desk-gate.sh | 20 | executed | helper | shell |
| bin/fm-discord-poll.sh | 38 | executed | helper | shell |
| bin/fm-dispatch-resolve.sh | 831 | executed | helper | shell |
| bin/fm-doc-audience-check.sh | 269 | executed | helper | shell |
| bin/fm-dod-lib.sh | 1234 | sourced | library | shell |
| bin/fm-ensure-agents-md.sh | 269 | executed | helper | shell |
| bin/fm-env-cause.sh | 103 | executed | helper | ported (full parity) |
| bin/fm-env-lib.sh | 32 | sourced | library | pilot-only (sourced lib, not routed) |
| bin/fm-exclude-tools-lib.sh | 64 | sourced | library | shell |
| bin/fm-extension.sh | 16 | executed | helper | shell |
| bin/fm-external-review-lib.sh | 201 | sourced | library | shell |
| bin/fm-ff-lib.sh | 594 | sourced | library | shell |
| bin/fm-fleet-ledger.sh | 234 | executed | later-ops | shell |
| bin/fm-fleet-snapshot.sh | 2116 | executed | later-ops | shell |
| bin/fm-fleet-sync.sh | 465 | executed | later-ops | shell |
| bin/fm-fleet-ui.sh | 2424 | executed | later-ops | shell |
| bin/fm-fleet-view.sh | 96 | executed | later-ops | shell |
| bin/fm-forge-detect.sh | 78 | executed | helper | ported (full parity) |
| bin/fm-gate-refuse-lib.sh | 175 | sourced | library | shell |
| bin/fm-gemini-lib.sh | 107 | sourced | library | shell |
| bin/fm-git-push-guard.sh | 163 | executed | helper | shell |
| bin/fm-git-strip-ai-trailers.sh | 386 | executed | helper | shell |
| bin/fm-go-pilot-build.sh | 14 | executed | helper | shell |
| bin/fm-go-pilot.sh | 51 | executed | helper | shell |
| bin/fm-guard.sh | 306 | executed | helper | shell |
| bin/fm-harness.sh | 719 | executed | helper | shell |
| bin/fm-hc-ci-cleanup.sh | 178 | executed | helper | shell |
| bin/fm-hc-lab.sh | 419 | executed | helper | shell |
| bin/fm-herdr-ci-cleanup.sh | 115 | executed | helper | shell |
| bin/fm-herdr-groups.sh | 540 | executed | helper | shell |
| bin/fm-herdr-lab.sh | 681 | executed | helper | shell |
| bin/fm-herdr-session-cleanup.sh | 337 | executed | later-ops | shell |
| bin/fm-hermes-hook.sh | 26 | executed | helper | shell |
| bin/fm-hermes-lib.sh | 207 | sourced | library | shell |
| bin/fm-hermes-process-lib.sh | 41 | sourced | library | shell |
| bin/fm-hold-reason-lib.sh | 78 | sourced | library | shell |
| bin/fm-home-seed.sh | 1023 | executed | helper | shell |
| bin/fm-home-summary-refresh.sh | 257 | executed | helper | shell |
| bin/fm-hook-host-lib.sh | 36 | sourced | library | shell |
| bin/fm-host-mirror.sh | 334 | executed | helper | shell |
| bin/fm-housekeeping.sh | 247 | executed | helper | shell |
| bin/fm-hygiene.sh | 349 | executed | helper | shell |
| bin/fm-image-gen.sh | 5 | executed | helper | direct-go (pre-existing) |
| bin/fm-inactive-reconcile.sh | 871 | executed | helper | shell |
| bin/fm-inbox.sh | 1190 | executed | later-ops | shell |
| bin/fm-install-actionlint.sh | 84 | executed | helper | shell |
| bin/fm-install-hc.sh | 90 | executed | helper | shell |
| bin/fm-install-herdr.sh | 98 | executed | helper | shell |
| bin/fm-install-shellcheck.sh | 84 | executed | helper | shell |
| bin/fm-install-treehouse.sh | 95 | executed | helper | shell |
| bin/fm-jev-mem-guard.sh | 7 | executed | helper | shell |
| bin/fm-kimi-trust-lib.sh | 89 | sourced | library | shell |
| bin/fm-kimi-turnend-hook.sh | 276 | executed | later-ops | shell |
| bin/fm-lab-home.sh | 110 | executed | helper | shell |
| bin/fm-landed-lib.sh | 79 | sourced | library | shell |
| bin/fm-lane-vitals-lib.sh | 321 | sourced | library | shell |
| bin/fm-lavish-capture.sh | 21 | executed | helper | shell |
| bin/fm-lavish-health.sh | 24 | executed | helper | shell |
| bin/fm-lavish-url.sh | 461 | executed | helper | shell |
| bin/fm-lease-lib.sh | 333 | sourced | library | shell |
| bin/fm-lease.sh | 211 | executed | helper | shell |
| bin/fm-line-cap-lib.sh | 51 | sourced | library | pilot-only (sourced lib, not routed) |
| bin/fm-lint-workflows.sh | 155 | executed | helper | ported (full parity) |
| bin/fm-lint.sh | 1409 | executed | helper | shell |
| bin/fm-live-lab.sh | 897 | executed | helper | shell |
| bin/fm-lock-lib.sh | 104 | sourced | library | shell |
| bin/fm-lock.sh | 361 | executed | helper | shell |
| bin/fm-mail-check.sh | 396 | executed | later-ops | shell |
| bin/fm-mail.sh | 651 | executed | later-ops | shell |
| bin/fm-marker-lib.sh | 12 | sourced | library | shell |
| bin/fm-merge-authority-lib.sh | 192 | sourced | library | shell |
| bin/fm-merge-local.sh | 208 | executed | helper | shell |
| bin/fm-merge-outcome-lib.sh | 115 | sourced | library | shell |
| bin/fm-model-preflight.sh | 141 | executed | helper | shell |
| bin/fm-nm-run-lib.sh | 716 | sourced | library | shell |
| bin/fm-omp-process-lib.sh | 36 | sourced | library | shell |
| bin/fm-omp-profile-lib.sh | 81 | sourced | library | shell |
| bin/fm-on.sh | 125 | executed | helper | shell |
| bin/fm-operational-input.sh | 435 | executed | helper | shell |
| bin/fm-osc7501.sh | 640 | executed | helper | shell |
| bin/fm-parent-channel-lib.sh | 197 | sourced | library | shell |
| bin/fm-park.sh | 938 | executed | later-ops | shell |
| bin/fm-path-lib.sh | 39 | sourced | library | pilot-only (sourced lib, not routed) |
| bin/fm-peek.sh | 46 | executed | helper | shell |
| bin/fm-pending-reply-lib.sh | 1702 | sourced | library | shell |
| bin/fm-pipeline-spend.sh | 298 | executed | helper | shell |
| bin/fm-polytoken-lib.sh | 506 | sourced | library | shell |
| bin/fm-pr-check.sh | 651 | executed | later-ops | shell |
| bin/fm-pr-health.sh | 498 | executed | later-ops | shell |
| bin/fm-pr-lib.sh | 1871 | sourced | library | shell |
| bin/fm-pr-merge.sh | 2046 | executed | later-ops | shell |
| bin/fm-pr-poll.sh | 556 | executed | later-ops | shell |
| bin/fm-pr-reviewers.sh | 105 | executed | later-ops | shell |
| bin/fm-pr-state.sh | 175 | executed | later-ops | shell |
| bin/fm-primary-scope-lib.sh | 42 | sourced | library | shell |
| bin/fm-procevent-lavish.sh | 978 | executed | later-ops | shell |
| bin/fm-procevent-lib.sh | 1365 | sourced | library | shell |
| bin/fm-procevent-quota.sh | 328 | executed | later-ops | shell |
| bin/fm-procevent-remote-reply.sh | 884 | executed | later-ops | shell |
| bin/fm-procevent-when.sh | 638 | executed | later-ops | shell |
| bin/fm-procevent.sh | 2606 | executed | later-ops | shell |
| bin/fm-project-capacity-lib.sh | 229 | sourced | library | shell |
| bin/fm-project-mode.sh | 315 | executed | helper | shell |
| bin/fm-project-origin-lib.sh | 180 | sourced | library | shell |
| bin/fm-promote.sh | 528 | executed | later-ops | shell |
| bin/fm-public-followup-collect.sh | 125 | executed | later-ops | shell |
| bin/fm-public-followup-emit.sh | 419 | executed | later-ops | shell |
| bin/fm-public-followup-lib.sh | 599 | sourced | library | shell |
| bin/fm-public-followup.sh | 1681 | executed | later-ops | shell |
| bin/fm-push-transition-lib.sh | 176 | sourced | library | shell |
| bin/fm-quota-axi-lib.sh | 189 | sourced | library | shell |
| bin/fm-quota-choose.sh | 402 | executed | helper | shell |
| bin/fm-record-export.sh | 84 | executed | helper | shell |
| bin/fm-record-hygiene-lib.sh | 117 | sourced | library | shell |
| bin/fm-remote-delta-read.sh | 231 | executed | later-ops | shell |
| bin/fm-remote-doctor.sh | 1413 | executed | later-ops | shell |
| bin/fm-remote-entrypoint.sh | 193 | executed | later-ops | shell |
| bin/fm-remote-file.sh | 234 | executed | later-ops | shell |
| bin/fm-remote-herdr-guard.sh | 135 | executed | later-ops | shell |
| bin/fm-remote-herdr-identity-lib.sh | 114 | sourced | library | shell |
| bin/fm-remote-herdr-owner-lib.sh | 176 | sourced | library | shell |
| bin/fm-remote-home-provision.sh | 283 | executed | later-ops | shell |
| bin/fm-remote-home-seed.sh | 272 | executed | later-ops | shell |
| bin/fm-remote-inherit-push.sh | 210 | executed | later-ops | shell |
| bin/fm-remote-inherit.sh | 239 | executed | later-ops | shell |
| bin/fm-remote-job-lib.sh | 1522 | sourced | library | shell |
| bin/fm-remote-job-reap-orphans.sh | 137 | executed | later-ops | shell |
| bin/fm-remote-job-worker.sh | 1352 | executed | later-ops | shell |
| bin/fm-remote-readiness-lib.sh | 81 | sourced | library | shell |
| bin/fm-remote-secondmate-control.sh | 574 | executed | core-lifecycle | shell |
| bin/fm-remote-secondmate-relaunch.sh | 96 | executed | later-ops | shell |
| bin/fm-review-check.sh | 126 | executed | helper | shell |
| bin/fm-review-diff.sh | 245 | executed | helper | shell |
| bin/fm-rex-marks.sh | 493 | executed | later-ops | shell |
| bin/fm-role-lib.sh | 544 | sourced | library | shell |
| bin/fm-role.sh | 82 | executed | helper | shell |
| bin/fm-secondmate-charter-lib.sh | 44 | sourced | library | shell |
| bin/fm-secondmate-liveness-lib.sh | 427 | sourced | library | shell |
| bin/fm-secondmate-nudge-lib.sh | 116 | sourced | library | shell |
| bin/fm-secondmate-parent-lib.sh | 70 | sourced | library | shell |
| bin/fm-secondmate-reconcile.sh | 588 | executed | later-ops | shell |
| bin/fm-secondmate-registry-lib.sh | 311 | sourced | library | shell |
| bin/fm-secondmate-report.sh | 105 | executed | later-ops | shell |
| bin/fm-secondmate-restart-lib.sh | 105 | sourced | library | shell |
| bin/fm-secondmate-restart.sh | 396 | executed | later-ops | shell |
| bin/fm-send.sh | 1460 | executed | core-lifecycle | shell |
| bin/fm-session-lock-lib.sh | 980 | sourced | library | shell |
| bin/fm-session-start.sh | 1134 | executed | later-ops | shell |
| bin/fm-sessionstart-agy.sh | 48 | executed | later-ops | shell |
| bin/fm-sessionstart-cursor.sh | 40 | executed | later-ops | shell |
| bin/fm-sessionstart-nudge.sh | 57 | executed | later-ops | shell |
| bin/fm-sessionstart-run.sh | 155 | executed | later-ops | shell |
| bin/fm-slot-claim-lib.sh | 170 | sourced | library | shell |
| bin/fm-spawn.sh | 8457 | executed | core-lifecycle | shell |
| bin/fm-startup-growth-check.sh | 417 | executed | helper | shell |
| bin/fm-startup-memory-budget-lib.sh | 224 | sourced | library | shell |
| bin/fm-startup-memory-budget.sh | 94 | executed | helper | shell |
| bin/fm-startup-network.sh | 759 | executed | helper | shell |
| bin/fm-storage-policy.sh | 88 | executed | helper | ported (full parity) |
| bin/fm-stow-cascade.sh | 251 | executed | helper | shell |
| bin/fm-stow-guard.sh | 238 | executed | helper | shell |
| bin/fm-subagent-pretool-check.sh | 221 | executed | helper | shell |
| bin/fm-supervise-daemon.sh | 2330 | executed | later-ops | shell |
| bin/fm-supervision-engine-lib.sh | 460 | sourced | library | shell |
| bin/fm-supervision-handoff.sh | 205 | executed | later-ops | shell |
| bin/fm-supervision-host.sh | 1389 | executed | later-ops | shell |
| bin/fm-supervision-instructions.sh | 349 | executed | later-ops | shell |
| bin/fm-supervision-lib.sh | 113 | sourced | library | shell |
| bin/fm-supervisor-target-lib.sh | 148 | sourced | library | shell |
| bin/fm-t3-answer.sh | 50 | executed | helper | shell |
| bin/fm-t3code-codex-env.sh | 161 | executed | later-ops | shell |
| bin/fm-tangle-lib.sh | 53 | sourced | library | pilot-only (sourced lib, not routed) |
| bin/fm-task-inbox-lib.sh | 584 | sourced | library | shell |
| bin/fm-task-inbox-state-lib.sh | 33 | sourced | library | shell |
| bin/fm-tasks-axi-lib.sh | 262 | sourced | library | shell |
| bin/fm-tasks-axi.sh | 154 | executed | helper | shell |
| bin/fm-teardown.sh | 4300 | executed | core-lifecycle | shell |
| bin/fm-test-isolation-proof.sh | 599 | executed | helper | shell |
| bin/fm-test-linux.sh | 121 | executed | helper | shell |
| bin/fm-test-run.sh | 2985 | executed | helper | shell |
| bin/fm-test-tap-verify.sh | 130 | executed | helper | ported (full parity) |
| bin/fm-timeout-lib.sh | 411 | sourced | library | shell |
| bin/fm-timing-lib.sh | 179 | sourced | library | shell |
| bin/fm-tmux-lib.sh | 391 | sourced | library | shell |
| bin/fm-tool-update-check.sh | 1025 | executed | helper | shell |
| bin/fm-trace-context-lib.sh | 227 | sourced | library | shell |
| bin/fm-transition-lib.sh | 171 | sourced | library | shell |
| bin/fm-turnend-guard-agy.sh | 224 | executed | later-ops | shell |
| bin/fm-turnend-guard-cursor.sh | 441 | executed | later-ops | shell |
| bin/fm-turnend-guard-grok.sh | 90 | executed | later-ops | shell |
| bin/fm-turnend-guard.sh | 584 | executed | later-ops | shell |
| bin/fm-update-go-check.sh | 114 | executed | helper | shell |
| bin/fm-update.sh | 380 | executed | helper | shell |
| bin/fm-usage-warner.sh | 519 | executed | helper | shell |
| bin/fm-vendor-auth-probe.sh | 189 | executed | helper | shell |
| bin/fm-wake-drain.sh | 1103 | executed | core-lifecycle | shell |
| bin/fm-wake-grant.sh | 111 | executed | core-lifecycle | shell |
| bin/fm-wake-lib.sh | 3538 | sourced | library | shell |
| bin/fm-warm-compact-lib.sh | 146 | sourced | library | shell |
| bin/fm-watch-arm.sh | 941 | executed | core-lifecycle | shell |
| bin/fm-watch-checkpoint.sh | 222 | executed | core-lifecycle | shell |
| bin/fm-watch-key-lib.sh | 32 | sourced | library | shell |
| bin/fm-watch.sh | 5026 | executed | core-lifecycle | shell |
| bin/fm-worker-account-lib.sh | 450 | sourced | library | shell |
| bin/fm-x-dismiss.sh | 122 | executed | later-ops | shell |
| bin/fm-x-followup.sh | 326 | executed | later-ops | shell |
| bin/fm-x-lib.sh | 1121 | sourced | library | shell |
| bin/fm-x-link.sh | 234 | executed | later-ops | shell |
| bin/fm-x-poll.sh | 214 | executed | later-ops | shell |
| bin/fm-x-reply.sh | 408 | executed | later-ops | shell |
