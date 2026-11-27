# Firstmate portable test shards

`bin/fm-test-run.sh` owns portable lane composition and execution.
`bin/fm-test-isolation-proof.sh` owns the proven-isolated candidate set.
`tests/fm-test-ci-timings.tsv` holds the committed per-script CI duration hints the packer reads.

## Verification inputs

Balance hints come from successful Ubuntu CI samples, not from local runs.
The concurrent isolation proof in [fm-test-isolation-proof.md](fm-test-isolation-proof.md) establishes concurrency safety, not serial CI duration.
Local timings are not interchangeable with CI timings: platform and machine load can affect each script differently and change their relative weights.

The committed table records the slowest successful `duration_ms` per `tests/*.test.sh` across green main CI runs [43359484992](https://github.com/kunchenguid/firstmate/actions/runs/43359484992), [43331691300](https://github.com/kunchenguid/firstmate/actions/runs/43331691300), and [43209319634](https://github.com/kunchenguid/firstmate/actions/runs/43209319634), refreshed 2026-11-13.
Failed or cancelled scripts are ignored, so a timeout does not become a packing weight.
Observed maxima provide conservative packing weights, not an upper bound on future durations.
The serial hint table was refreshed again on 2026-11-22 from the slowest successful `duration_ms` per script across the uploaded timing artifacts of [main run 44065789899](https://github.com/kayis-rahman/firstmate/actions/runs/44065789899) and [pull request run 45009925142](https://github.com/kayis-rahman/firstmate/actions/runs/45009925142), and the serial lane moved from eleven to fifteen shards.
At eleven shards those hints modeled a 22.8-minute largest shard, which is why main's shards ran 22-27 minutes against the 30-minute cap; at fifteen the largest modeled shard is the single 17-minute watch-triage script.
The lint partitions moved from two to three for the same reason, with Lint 1 and Lint 2 at 21-24 minutes on main.
A passing coverage guard does not establish a healthy job duration; refresh the table from uploaded timing artifacts when a member grows or the lane gains scripts.

The native-Windows-only `tests/fm-pi-windows-shell-invocation.test.sh` retains a separate measurement and is skipped by the portable CI shards.
Measure that script through the focused Git Bash runner rather than a portable skip.

The supervision-host suite is four serial members so no one file occupies a whole CI shard: `tests/fm-supervision-host-drain.test.sh` (report, dispatch, BRANCH OUTCOMES; 17 tests, local 19978 ms, hint 45950 ms), `tests/fm-supervision-host-hook.test.sh` (Claude Stop-hook re-arm and hand-back; 24 tests, local 175562 ms, hint 403793 ms), `tests/fm-supervision-host.test.sh` (host loop wakes, closes, mirror, return; 29 tests, local 189383 ms, hint 435581 ms), and `tests/fm-supervision-host-park.test.sh` (latch, park boundary, compaction, lock ownership; 20 tests, local 143185 ms, hint 329326 ms). Packing weights are local `duration_ms` scaled by ~2.3 for CI, replacing the 1192918 ms single-file sample from run [39642852135](https://github.com/kunchenguid/firstmate/actions/runs/39642852135) that sat alone in a serial shard and still overran: run 39765114423 cancelled that script at the 30-minute job cap. Refresh these four from Ubuntu timing artifacts on the next green run.
The native-Windows-only `tests/fm-pi-windows-shell-invocation.test.sh` retains its separate 5121 ms measurement from 2026-09-06T21:02Z instead of a portable capability skip.
The 2026-10-07 polytoken adapter tests carry provisional local measurements instead - 21090 ms for `tests/fm-polytoken-harness.test.sh` and the 103 ms live-guard skip for `tests/fm-polytoken-signals-live-e2e.test.sh`, both measured on the adapter-verification macOS host - until the next CI refresh replaces them with Ubuntu measurements, because they postdate the 2026-09-30 baseline.
The 2026-10-23 `tests/fm-approval-failover.test.sh` serial hint is a provisional local measurement of 5410 ms, the slowest of five local `bin/fm-test-run.sh` samples (4991-5410 ms), until the next CI refresh replaces it with an Ubuntu timing-artifact maximum.
The 2026-11-08 `tests/fm-capacity-auto.test.sh` (36243 ms), `tests/fm-lane-capacity-integration.test.sh` (48000 ms), and `tests/fm-lane-vitals.test.sh` (5077 ms) serial hints are provisional local measurements from one `bin/fm-test-run.sh` run on a loaded macOS host, until the next CI refresh replaces them with Ubuntu timing-artifact maxima.
The 2026-11-09 `tests/fm-stow-guard.test.sh` serial hint is a provisional local measurement of 30000 ms, above a 27436 ms `bin/fm-test-run.sh` sample on this macOS host, until the next CI refresh replaces it with an Ubuntu timing-artifact maximum.
The 2026-10-23 Kimi folder-prompt live guard, `tests/fm-kimi-trust-prompt-live-e2e.test.sh`, carries a provisional 60 ms skip measured on the Linux host that recorded its captures, until the next CI refresh replaces it with an Ubuntu measurement.
The 2026-11-03 `tests/fm-herdr-projected-cd-live-e2e.test.sh` serial hint is provisionally 28000 ms, above a successful 27692 ms local runner sample exercising Herdr 0.9.5 on macOS arm64, until the next CI refresh replaces it with an Ubuntu timing-artifact maximum.
The 2026-10-27 `tests/fm-claude-account-quota.test.sh` serial hint is a provisional local measurement of 2492 ms, the slowest of five local `bin/fm-test-run.sh` samples (1930-2492 ms) on a Linux host, until the next CI refresh replaces it with an Ubuntu timing-artifact maximum.
The 2026-11-04 `tests/fm-install-herdr.test.sh` serial hint is a provisional local measurement of 1000 ms, above the slowest of five `bin/fm-test-run.sh` samples (155-223 ms) on a Linux host, until the next CI refresh replaces it with an Ubuntu timing-artifact maximum.
The 2026-10-26 `tests/fm-test-tap-verify.test.sh` serial hint is a provisional local measurement of 1000 ms, above a 238 ms `bin/fm-test-run.sh` sample on this Linux host, until the next CI refresh replaces it with an Ubuntu timing-artifact maximum.
The 2026-11-08 `tests/fm-lavish-url.test.sh` serial hint is a provisional local measurement of 30000 ms, above the slowest of three `bin/fm-test-run.sh` samples (25148-26650 ms) on a Linux host, until the next CI refresh replaces it with an Ubuntu timing-artifact maximum.
The 2026-10-27 read-repetition suites carry provisional Linux x86_64 local runner maxima: 602 ms for `tests/fm-read-repetition.test.sh` (six successful samples, 528-602 ms) and 1110 ms for `tests/fm-read-repetition-live.test.sh` (five successful samples, 949-1110 ms).
`tests/fm-park.test.sh` is now a portable parallel member; its 70085 ms parallel hint is its completed passing Ubuntu `FM_TEST_END` sample from CI run [42730709201](https://github.com/kunchenguid/firstmate/actions/runs/42730709201), and `tests/fm-arm-pretool-check.test.sh` moved to parallel lane 2 to keep the lanes within 5%.
The live samples exercised installed Pi 1.4.0 RPC without capability skips; they are not CI timing evidence or timings for unavailable harnesses.
Both suites retain serial placement and full coverage; replace these provisional hints with Ubuntu timing-artifact maxima at the next CI refresh.
The 2026-10-29 `tests/fm-live-lab-isolation.test.sh` serial hint is a provisional local measurement of 6459 ms, the slowest of six `bin/fm-test-run.sh` samples (4308-6459 ms) taken inside a private `unshare -Urm` /tmp on this Linux host, until the next CI refresh replaces it with an Ubuntu timing-artifact maximum.
The 2026-10-27 `tests/fm-codex-stop-park.test.sh` serial hint is a provisional local measurement of 35000 ms, above the slowest of the `bin/fm-test-run.sh` samples (20170-34700 ms) on a macOS arm64 host, until the next CI refresh replaces it with an Ubuntu timing-artifact maximum.
The 2026-10-28 Antigravity primary tests carry provisional serial hints - 45000 ms for `tests/fm-agy-primary.test.sh` and the 75 ms live-guard skip for `tests/fm-agy-primary-live-e2e.test.sh` - until the next CI refresh replaces them with Ubuntu timing-artifact maxima.
The wedge-cap suite carries the Ubuntu measurements from CI run [39597689178](https://github.com/kunchenguid/firstmate/actions/runs/39597689178) - 374225 ms for `tests/fm-watch-wedge-cap.test.sh` and the 74 ms live-guard skip for `tests/fm-watch-wedge-cap-live.test.sh` - in place of the provisional local measurements the suite first carried (1003000 ms and the 155 ms skip), which overstated the CI cost of both.
They are not a formality: without a hint the suite is packed on the 45000 ms default, which puts it beside a shard already holding about 17 minutes of measured work, so that shard would really have run for about 23 minutes - past the 20-minute target the guard reserves - while the coverage guard still passed.
The same run measured the wedge-cap parity suite at 27763 ms, which `bin/fm-test-run.sh` packs in place of the provisional 209000 ms local measurement.
`test_portable_serial_packing_budget_boundary` now pins every other fixture script to 1 ms, so packing exactly at the 1200000 ms budget is accepted and one millisecond above it is refused even when real serial members have no hint.
The coverage-guard test owns modeled real-hint headroom under that budget.
The session-start hint retains its pre-optimization maximum until CI measures the shorter fixture-only home-summary bound; do not discount a local speedup from CI packing weights.
The T3 Code backend suites carry the slowest successful Ubuntu samples from CI runs [39463576576](https://github.com/kunchenguid/firstmate/actions/runs/39463576576), [39814995718](https://github.com/kunchenguid/firstmate/actions/runs/39814995718), and [39883948163](https://github.com/kunchenguid/firstmate/actions/runs/39883948163) - 239245 ms for `tests/fm-backend-t3code.test.sh`, 57613 ms for `tests/fm-t3-mcp.test.sh`, 283 ms for `tests/fm-watch-inbox-meta.test.sh`, and the 51 ms and 52 ms live-guard skips for `tests/fm-backend-t3code-live-e2e.test.sh` and `tests/fm-backend-t3code-pr-tools-live-e2e.test.sh`.
`tests/fm-backend-t3code.test.sh` and `tests/fm-t3-mcp.test.sh` run in the portable parallel lanes, so those two values sit in `portable_parallel_weight_hints`: every case id the backend suite spawns carries a per-run suffix and its cleanup removes only the `/tmp/fm-<id>` directories that run created, and both suites passed running concurrently with each other and beside another parallel suite (see [`fm-test-isolation-proof.md`](fm-test-isolation-proof.md)).
A timed-out shard may upload no artifact, so a complete green run is what keeps the slowest scripts measured in the shard that needs them most.

The 2026-11-13 `tests/fm-pi-bash-timeout.test.sh` serial hint is a provisional local measurement of 1486 ms, the slowest of five successful `bin/fm-test-run.sh tests/fm-pi-bash-timeout.test.sh` samples (1288-1486 ms) on a macOS arm64 host, collected separately from coverage and lint checks.
Replace it with an Ubuntu timing-artifact maximum at the next CI refresh; this is not whole-shard CI timing evidence.

The new `tests/fm-remote-herdr-identity.test.sh` serial hint is provisionally 6158 ms, from a successful local macOS arm64 `bin/fm-test-run.sh` sample on 2026-11-08. Replace it with an Ubuntu timing-artifact maximum at the next CI refresh; this is not whole-shard CI timing evidence.

Sixty serial members carried no hint on 2026-11-16, past the coverage guard's 15% bound.
Fifty-two of them take the slowest successful `FM_TEST_END` sample from Ubuntu run [43618424032](https://github.com/kayis-rahman/firstmate/actions/runs/43618424032), a partial run whose other scripts failed.
The other eight failed in that run, so they carry provisional maxima of three `bin/fm-test-run.sh` samples in a local Ubuntu 24.04 container: `tests/fm-backend-hc-appdetect-smoke.test.sh` (144 ms, a capability skip without herdr-core), `tests/fm-env-cause.test.sh` (773 ms), `tests/fm-hygiene.test.sh` (325 ms), `tests/fm-lavish-tools.test.sh` (92 ms), `tests/fm-model-preflight.test.sh` (7903 ms), `tests/fm-slot-claim.test.sh` (4873 ms), and `tests/fm-spawn-chrome-idle-timeout.test.sh` (13725 ms).
`tests/fm-go-pilot.test.sh` is provisionally 30000 ms, above its 48 ms stub-tool sample, because a runner with a Go toolchain also builds the tool.
Replace all of these with Ubuntu timing-artifact maxima at the next green CI refresh.

## Parallel lanes

The two parallel lanes use longest-processing-time assignment over the committed hints.
CI runs each lane with `--jobs 2`, so wall time tracks the longest member rather than the sequential sum.
[`tests/fm-pi-primary-types.test.sh`](../tests/fm-pi-primary-types.test.sh) owns its typecheck dependencies independently of the lane's installed Pi runtime; both parallel jobs install the Pi package and fail on that gate skip so a packed move cannot silently skip it.
Read the derived packing estimates with `bin/fm-test-run.sh --check-coverage`; its header and `--help` own the output fields and the selection-specific `--list-scheduled` weight rules.
The largest individual hint sets a lower bound on the estimated duration of any split, regardless of how evenly the remaining work is assigned.
The CI cap follows the three-tier timeout policy in [Timeouts](#timeouts) below.

[`tests/fm-test-run.test.sh`](../tests/fm-test-run.test.sh), in `test_portable_parallel_lanes_stay_duration_balanced`, requires every parallel member to have a hint and the lane sums to differ by no more than five percent of the larger sum.
Its scheduling regressions also check stored parallel lane order and preserve committed-weight scheduling for other selections.
These checks do not detect a script outgrowing an existing hint or establish measured job headroom.
Refresh `tests/fm-test-ci-timings.tsv` whenever the parallel set gains scripts or a member grows materially.

The remote-secondmate lifecycle hint is 1005249 ms, its completed, passing `FM_TEST_END` sample from Ubuntu run [41289019354](https://github.com/kunchenguid/firstmate/actions/runs/41289019354). Rex lifecycle coverage outgrew the previous 345655 ms hint; serial shard 9 then reached the 30-minute job cap while running later tests. Eleven serial shards then accommodated the refreshed weight within the unchanged modeled budget and timeout policy. This is a completed-script measurement from a partial run, not a successful whole-shard timing or a guarantee of future headroom.

## Portable serial remainder

`portable-serial` includes every `tests/*.test.sh` that is neither proven-isolated nor `real-herdr-gated`.
It keeps watcher, lock, AFK, real tmux, daemon, secondmate lifecycle, bootstrap, the `live-harness-optin` family, GUI-backend, and other unproven work serial.
Membership is derived rather than enumerated, so a newly added test lands here by default.

## Portable serial CI shards

`portable-serial-<k>of<n>` splits the remainder across `n` separate CI runners.
Each shard is still strictly serial in itself, and separate runners mean no two of these stateful scripts ever share a machine, so the split needs no concurrency isolation proof.

`bin/fm-test-run.sh` owns `n` (currently 19) and refuses any lane whose `of<n>` disagrees with it.
`.github/workflows/ci.yml` derives the same `n` from `strategy.job-total` rather than a literal, so changing the shard count in either file without the other fails the lane loudly instead of leaving part of the required suite unrun.

Assignment is longest-processing-time bin packing over the committed duration hints.
A script with no hint gets the conservative `PORTABLE_SERIAL_DEFAULT_WEIGHT_MS` default.
Hints only affect balance: the coverage guard keeps the partition complete and disjoint whatever they say, so a stale hint costs a slower shard rather than lost coverage.
The packing target is 15 minutes (`serial_budget_ms=900000`).
`--check-coverage` refuses a modeled multi-script shard above that target; an indivisible suite may occupy a shard alone when its own hint is already above 15 minutes.
`bin/fm-test-run.sh --check-coverage` reports the unmeasured share as `serial_unhinted=` and refuses past `PORTABLE_SERIAL_MAX_UNHINTED_PERCENT`.

`bin/fm-test-run.sh` owns the per-shard packing, so its `--check-coverage` output is the current account of lane size and coverage rather than a copied inventory.
[`tests/fm-test-run.test.sh`](../tests/fm-test-run.test.sh), in `test_portable_serial_packing_budget_boundary`, verifies acceptance exactly at the budget, a singleton overflow, and refusal of a multi-script overflow through the executable runner.
`tests/fm-ci-workflow.test.sh` compares the parsed CI matrix to the executable runner lanes, and the runner rejects parallel `--jobs` on a serial lane even when that shard has only one member.

## Coverage guard

`bin/fm-test-run.sh --check-coverage` verifies that both parallel lanes partition the proven-isolated set.
It also verifies that the parallel lanes, portable serial lane, and real-Herdr family are disjoint and cover every `tests/*.test.sh` script.
It separately verifies that the portable serial CI shards are non-empty, disjoint, and together equal the portable serial lane.
Its hint-coverage and modeled-budget checks are described in [Portable serial CI shards](#portable-serial-ci-shards); neither replaces inspection of actual CI timing artifacts.

## Timing artifacts

Portable shards, each portable serial shard, and the Herdr lane upload runner-generated timing JSON.
`bin/fm-test-run.sh --aggregate-json` creates the combined summary artifact.
The timing-aggregate job then runs `bin/fm-ci-budget-warn.sh`, which emits a GitHub warning annotation (never a failure) when any lane or lint partition's measured command time is at or above 20 minutes.
`.github/workflows/ci.yml` owns the exact artifact names and aggregation wiring.

## Lint partitions and end-to-end latency

`bin/fm-lint.sh` owns four canonical CI partitions.
Each partition attempts full source-aware ShellCheck analysis and runs workflow validation and backend-purity checks.
Pull requests pass `--changed` so only the canonical-set files changed since the merge-base are analyzed, still with `--external-sources` and full dataflow.
A change to lint definition files (`bin/fm-lint.sh`, `bin/fm-lint-workflows.sh`, the pinned installers, or `bin/fm-timeout-lib.sh`), including a delete or rename of any of those paths, upgrades that PR to the full canonical set.
A change to a file that another canonical script sources, found from `# shellcheck source=` directives rather than a hand list, also upgrades to the full set so an unchanged consumer cannot hide a new ShellCheck finding from the PR and then fail the full gate on main.
A delete or rename of that helper counts, including the old path of a rename.
Main pushes keep the full canonical gate.
CI caches the pinned ShellCheck and actionlint binaries and skips the download when the pin is already present.
`FM_LINT_JOBS=1` stays in force because a second concurrent ShellCheck process does not fit the hosted runner's memory envelope.

CI requires its per-root bounds, so an unenforceable deadline or address-space limit refuses lint rather than running uncapped; the script header owns the envelope, per-root execution contract, and memory fallback.
Its `--list-files` interface exposes partition membership; `tests/fm-lint.test.sh` verifies complete/disjoint executed roots, `--changed` source-aware analysis, definition-file upgrades, and fallback reporting.
The workflow uploads each partition's quiet telemetry plus its per-root lifecycle sidecar to distinguish analysis cost, memory use, and host contention.

The packing target is a complete green run under fifteen minutes including start delay.
One indivisible serial suite (`tests/fm-remote-secondmate-lifecycle-e2e.test.sh`) currently measures above that target on its own; it occupies a singleton shard rather than raising the job timeout. It is one sequential fixture lifecycle, not independently invocable cases, so splitting it would re-run provision/seed/launch per file and change how the lifecycle is asserted.
Job timeouts remain hang tripwires under the policy in [Timeouts](#timeouts) below; they are not the desired healthy duration.
The layout uses twenty-one serial jobs, two parallel jobs with `--jobs 2`, four lint partitions, Herdr, herdr-core, plus short checks and macOS.
The workflow retains per-PR supersession and keeps only the newest of close main pushes' runs, without changing the compliance workflow's event semantics.

## Local entry points

[CONTRIBUTING.md](../CONTRIBUTING.md) owns the local test policy and common entry points.
`bin/fm-test-run.sh --help` owns exact lane names, selection flags, and bounded `--jobs` mechanics.

## Timeouts

CI job timeouts follow one three-tier policy, so the workflow reads as a policy rather than as a collection of per-job numbers.
Every tier is a hang tripwire with headroom above the healthy duration, never a packing estimate or a runtime target.
A lane that reaches its tier bound needs investigation and a distribution or runtime fix, not a larger timeout to fit the same work.

| Tier | Jobs | Bound | Rationale |
|---|---|---|---|
| Fast | coverage guard, repo invariants, timing aggregate, Full suite verdict | 5 minutes | Seconds-long local work, so the tripwire only catches a hung runner. |
| Normal | lint partitions, portable parallel shards, portable serial shards, macOS stock Bash | 30 minutes, one value shared by every job in the tier | One shared hang tripwire keeps every ordinary test and lint lane on the same policy instead of allowing per-lane packing estimates or one-off caps to set the bound. |
| Heavy | Herdr | family-run step 20 minutes under a 75-minute job-level last-resort backstop | Healthy runs finish in about 7-10 minutes, so the step tripwire fails a wedged suite while the `always()` cleanup and timing upload still run, and the job cap only catches a hang outside that step. |

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) holds the executable values and names each job's tier beside its `timeout-minutes`.
[`tests/fm-ci-workflow.test.sh`](../tests/fm-ci-workflow.test.sh) holds the policy against the parsed workflow: every job belongs to exactly one tier, the workflow carries exactly three distinct job-level values, the fast tier stays within 5-10 minutes, the normal jobs share one 30-minute budget, and the Herdr family-run step is the 20-minute tripwire below its job backstop with an `always()` teardown after it.
A passing coverage guard does not establish a healthy job duration; refresh the healthy figures above from the lanes' uploaded timing artifacts.
