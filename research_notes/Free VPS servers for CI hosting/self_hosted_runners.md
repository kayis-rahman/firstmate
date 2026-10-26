# Self-Hosted GitHub Actions Runners for Godot CI/CD

## How to register a self-hosted runner with GitHub Actions?

### Takeaway
A self-hosted runner is registered by creating a runner entry in GitHub's UI, then running the downloaded `config.sh` on the target machine with a one-hour registration token; the runner connects back to GitHub over outbound HTTPS and needs no inbound ports.

### Cited Findings
- Registration requires repository admin/owner access: navigate to repo Settings → Actions → Runners → New self-hosted runner, select OS and architecture, then run the printed shell commands on the machine. — [GitHub Docs: Adding self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/adding-self-hosted-runners)
- The `config` script requires the destination URL and an automatically-generated time-limited token; the token expires after one hour. — [GitHub Docs: Adding self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/adding-self-hosted-runners)
- Example registration command: `./config.sh --url https://github.com/YOUR-ORG/YOUR-REPO --token <RUNNER_TOKEN> --labels self-hosted,macOS,macrun-unit-01 --unattended` — [macrun.dev docs](https://macrun.dev/docs/setup)
- Runners can be scoped to a single repository, an organization, or an enterprise; organization owners can restrict which repos may create repository-level runners. — [GitHub Docs: Self-hosted runners overview](https://docs.github.com/en/actions/hosting-your-own-runners)
- Machine requirements: can install/run the runner app; can communicate with GitHub Actions; enough hardware for planned workflows; Docker only needed for container actions (Linux only). — [GitHub Docs: Self-hosted runners reference](https://docs.github.com/en/actions/reference/runners/self-hosted-runners)
- Supported OS: macOS 11.0 (Big Sur) or later; supported architectures x64 and ARM64 (ARM64 currently in public preview). — [GitHub Docs: Self-hosted runners reference](https://docs.github.com/en/actions/reference/runners/self-hosted-runners)
- Communication needs: at least 70 kbps upload/download, outbound HTTPS on port 443, and the runner application must be running. — [GitHub Docs: Self-hosted runners reference](https://docs.github.com/en/actions/reference/runners/self-hosted-runners)
- Registration token can also be generated via REST API: `POST /repos/{owner}/{repo}/actions/runners/registration-token`. — [GitHub REST API: Self-hosted runners](https://docs.github.com/en/rest/actions/self-hosted-runners)
- Ephemeral runners are registered with `--ephemeral` and are deregistered after one job; JIT (just-in-time) configs via `POST .../generate-jitconfig` + `./run.sh --jitconfig` avoid storing any registration credential on the box. — [GitHub Docs: Self-hosted runners reference (Ephemeral)](https://docs.github.com/en/actions/reference/runners/self-hosted-runners); [PrivateDevOps: Ephemeral CI runners](https://privatedevops.com/articles/ephemeral-ci-runners-on-your-own-hardware)
- For org-level registration, a GitHub App with "Organization: Self-hosted runners (Read and write)" permissions is used for automation (Tartelet approach). — [Joseph Duffy: Self-hosting macOS GitHub Runners](https://josephduffy.co.uk/posts/self-hosting-macos-github-runners)

### Inferences
- For a solo developer with a Mac Mini, repository-level registration is simplest; org/enterprise scoping only matters for multi-repo sharing.
- JIT/ephemeral registration is the better security posture for production fleets but adds automation complexity; for a single Mac Mini, persistent registration with `config.sh` is the pragmatic starting point.

### Gaps
- I did not find a single authoritative "quickstart" for ARM64 Mac Mini specifically; the generic macOS flow applies but ARM64 runner support is still labeled public preview in GitHub's docs.

## What are the security considerations? (runner isolation, fork PR attacks)

### Takeaway
Self-hosted runners are strongly discouraged for public repositories: any user can open a PR that runs arbitrary code on the machine, and because runners are stateful processes (not ephemeral VMs) secrets and the GITHUB_TOKEN can be harvested; mitigation is private repos, same-repo-only guards, ephemeral runners, and strict secret hygiene.

### Cited Findings
- GitHub's explicit warning: "We recommend that you only use self-hosted runners with private repositories. This is because forks of your public repository can potentially run dangerous code on your self-hosted runner machine by creating a pull request that executes the code in a workflow." — [GitHub Docs: Adding self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/adding-self-hosted-runners)
- Self-hosted runners "do not have guarantees around running in ephemeral clean virtual machines, and can be persistently compromised by untrusted code in a workflow." — [GitHub Docs: Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)
- Attack path: an adversary creates a PR with a new workflow whose `runs-on` targets the self-hosted label; it runs immediately on `pull_request`, giving lateral movement in the enterprise environment, persistence, and secret theft. — [StepSecurity: Defend Your GitHub Actions CI/CD Environment](https://www.stepsecurity.io/blog/defend-your-github-actions-ci-cd-environment-in-public-repositories)
- Self-hosted runners are regular OS processes with no virtualization/isolation; filesystem side-effects persist across jobs and across runners on the same OS. — [Stack Overflow: multiple runners on same machine](https://stackoverflow.com/questions/65071861/where-does-self-hosted-github-runner-executes-the-code-is-having-multiple-runne)
- Fork PRs triggered by `pull_request` have read-only permissions and no secret access, but other triggers (`issue_comment`, `push`, branch PRs) can steal secrets; secrets used in expressions are stored on-disk in shell scripts. — [GitHub Docs: Compromised runners](https://docs.github.com/en/actions/concepts/security/compromised-runners)
- Secrets passed on command lines can be seen by other jobs via `ps x -w`; environment variables and stdin are safer. — [GitHub Docs: Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use); [GitHub Docs: Using secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets)
- `pull_request_target` workflows run privileged (secrets, write token) in base context; checking out PR head code in that context is a critical vulnerability (TOCTOU, cache poisoning). — [GitHub Security Lab](https://securitylab.github.com/resources/github-actions-new-patterns-and-mitigations/)
- Mitigations: restrict to same-repo PRs with `if: github.event.pull_request.head.repo.full_name == github.repository`; require approval for external contributors; split privileged/unprivileged workflows via `workflow_run`; use ephemeral runners; keep sensitive data off the runner host. — [GitHub Security Lab](https://securitylab.github.com/resources/github-actions-new-patterns-and-mitigations/); [StepSecurity](https://www.stepsecurity.io/blog/defend-your-github-actions-ci-cd-environment-in-public-repositories)
- Organization/enterprise runners can be scoped with runner groups to limit which repos can use them. — [GitHub Docs: Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)

### Inferences
- For a solo developer's private game repo, the main practical risks are leaked Apple signing certs/keystores and long-lived cloud credentials sitting on the Mac Mini; running the runner as a dedicated low-privilege user with no secrets in its home mitigates most of this.
- Ephemeral runners are the only approach GitHub says can guarantee no cross-job secret leakage; persistent runners always carry that risk.

### Gaps
- I found no Godot-specific security guidance; the general GitHub Actions self-hosted runner guidance applies directly.

## How to run Godot on macOS/Linux as a self-hosted runner?

### Takeaway
On a self-hosted macOS runner, install Godot (and export templates) once on the machine, then invoke the headless editor binary directly (`Godot.app/Contents/MacOS/Godot --headless --export-release ...`); the `chickensoft-games/setup-godot` action also works on self-hosted runners and caches installation.

### Cited Findings
- macOS terminal invocation: `cd` to the folder containing the `.app` bundle, then `Godot.app/Contents/MacOS/Godot` with arguments. — [Godot Docs: Command line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- Headless export command: `godot --headless --export-release "Linux/X11" /var/builds/project` (preset name must match `export_presets.cfg`; use `--export-debug` for debug builds; `--export-pack` for PCK only). — [Godot Docs: Command line tutorial (Exporting)](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- On platforms without GPU (CI), `--headless` is required; it sets `--display-driver headless --audio-driver Dummy`. — [Godot Docs: Command line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- Import resources first: `./Godot.app/Contents/MacOS/Godot --headless -v --import` (often with `continue-on-error: true`). — [Pixelorama workflow example](https://github.com/jamad/Pixelorama/blob/master/.github/workflows/dev-desktop-builds.yml)
- Export templates must be installed to `~/Library/Application Support/Godot/export_templates/<version>.stable` on macOS; download from godotengine/godot-builds releases as `.tpz` and unzip into that path. — [Pixelorama workflow example](https://github.com/jamad/Pixelorama/blob/master/.github/workflows/dev-desktop-builds.yml)
- `chickensoft-games/setup-godot@v2` supports macOS/Windows/Ubuntu self-hosted runners, installs Godot 4.x, optionally templates, sets `GODOT`/`GODOT4` env vars, and caches. — [chickensoft-games/setup-godot](https://github.com/chickensoft-games/setup-godot)
- macOS-specific post-export steps seen in practice: `chmod +x` the exported binary, ad-hoc `codesign -s - --force --deep`, and `hdiutil create` for DMG. — [Pixelorama workflow example](https://github.com/jamad/Pixelorama/blob/master/.github/workflows/dev-desktop-builds.yml)
- On Linux self-hosted runners, the Docker image `barichello/godot-ci` (with Godot + templates preinstalled) is commonly used via `container:` in the workflow. — [abarichello/godot-ci](https://github.com/abarichello/godot-ci)
- Example self-hosted Godot workflow pattern: `runs-on: self-hosted` with `container: image: barichello/godot-ci:4.2.1`, then `godot --headless --export-release ...`. — [halkeye gist build.yaml](https://gist.github.com/halkeye/4facd3262d77e011bd5950092590f0c4)
- `mlm-games/godot-build-action` automates multi-platform exports including macOS, Android, caching, and itch.io upload using official Godot binaries. — [mlm-games/godot-build-action](https://github.com/mlm-games/godot-build-action)

### Inferences
- For a Mac Mini, pre-installing Godot + templates directly on the machine and calling the binary in workflow steps is more reliable than re-downloading each run; `setup-godot` is the better choice if you want version pinning and caching without manual installs.
- Linux self-hosted runners can use either direct install or the `barichello/godot-ci` container; macOS runners cannot use Linux containers, so direct install is required on Mac.

### Gaps
- I found no authoritative doc on running Godot on Raspberry Pi as a self-hosted runner; Godot's system requirements list Raspberry Pi 4/5 as supported for the editor, but CI export on ARM Linux would need an ARM Godot binary and ARM export templates, which is not well-documented in CI guides.

## What are the resource requirements for Godot builds? (CPU, RAM, storage)

### Takeaway
Godot's own minimum is modest (4 GB RAM, 200 MB storage for editor; 8 GB recommended), but real CI builds need roughly 8-16 GB RAM, multiple cores, and several GB of storage once export templates (~1.3 GB) and build artifacts are included; compiling Godot from source needs 12+ GB RAM for LTO.

### Cited Findings
- Godot editor minimum: 4 GB RAM, 200 MB storage (executable/project/cache); export templates add ~1.3 GB. Recommended: 8 GB RAM, 1.5 GB storage (all templates + cache), 4+ physical cores. — [Godot Docs: System requirements](https://docs.godotengine.org/en/stable/about/system_requirements.html)
- Raspberry Pi 4 listed as minimum-class Linux CPU; Raspberry Pi 5 with overclocking listed as recommended-class. — [Godot Docs: System requirements](https://docs.godotengine.org/en/stable/about/system_requirements.html)
- Compiling Godot from source with full LTO needs at least 12 GB system RAM (8 GB available at link time); LTO linking is single-threaded and can take 20-60 minutes. — [Godot issue #93914](https://github.com/godotengine/godot/issues/93914)
- Exported project minimum: 2 GB RAM, 150 MB storage; varies heavily with project scope. — [Godot Docs: System requirements](https://docs.godotengine.org/en/stable/about/system_requirements.html)
- Godot macOS export templates are a "Universal 2" binary bundle; macOS container image for Godot builds is ~14.6 GB (Xcode included) per godot-build-containers. — [godotengine/build-containers README](https://github.com/godotengine/build-containers/blob/main/README.md)
- GitHub's generic guidance: self-hosted runner app needs minimal resources; "the machine has enough hardware resources for the type of workflows you plan to run." — [GitHub Docs: Self-hosted runners reference](https://docs.github.com/en/actions/reference/runners/self-hosted-runners)
- Practical data point: a Mac Mini M2 running multiple self-hosted runners reduced build time from ~26 min to ~7 min for an Android app project. — [buildingcash/multi-self-hosted-runners](https://github.com/buildingcash/multi-self-hosted-runners)
- GitHub Actions runner needs ~70 kbps network and outbound HTTPS 443; jobs queued >24 hours fail. — [GitHub Docs: Self-hosted runners reference](https://docs.github.com/en/actions/reference/runners/self-hosted-runners)

### Inferences
- A base Mac Mini (8 GB RAM) is adequate for exporting typical Godot 4 projects headlessly; 16 GB is safer if running multiple runners or large 3D projects.
- Storage planning should budget: Godot editor binary (~200 MB) + export templates (~1.3 GB) + Xcode (if macOS export, several GB) + `_work` directories per runner + build artifacts.

### Gaps
- No published benchmark of Godot export times on Mac Mini hardware specifically; the 26→7 min figure is for an Android app, not Godot.

## How to configure the runner as a service (auto-start)?

### Takeaway
On macOS, `./svc.sh install && ./svc.sh start` creates a LaunchAgent, but because launchd won't load user agents without a GUI login, the reliable fix for headless Mac Minis is to move the plist to `/Library/LaunchDaemons/` (or enable auto-login); on Linux, `svc.sh` uses systemd.

### Cited Findings
- Service install (macOS): `./svc.sh install` then `./svc.sh start`; status via `./svc.sh status`; uses launchd. — [GitHub Docs: Configuring self-hosted runner as a service](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/configuring-the-self-hosted-runner-application-as-a-service)
- macOS LaunchAgent path: `~/Library/LaunchAgents/actions.runner.<org>-<repo>.<name>.plist`; for system-domain (boot-time) use `/Library/LaunchDaemons/`. — [GitHub Docs: Monitoring and troubleshooting](https://docs.github.com/en/actions/how-tos/managing-self-hosted-runners/monitor-and-troubleshoot)
- Known issue: launchd can't load user services until GUI login; workaround is automatic login or moving plist to LaunchDaemons. — [actions/runner issue #1959](https://github.com/actions/runner/issues/1959)
- Workaround (flacroix897): install service, `sudo cp ...plist /Library/LaunchDaemons/`, `sudo chown root:wheel`, uninstall user service to avoid double-start. — [actions/runner issue #1959](https://github.com/actions/runner/issues/1959)
- Matthieu Napoli's Mac Mini method: create dedicated `actions-runner` user, install runner into N directories, then `sudo mv ...plist /Library/LaunchDaemons/` + `sudo launchctl bootstrap system ...`. — [Matthieu Napoli: Self-hosting macOS GitHub Runners](https://stitcher.io/feed/posts/74513)
- Linux: `sudo ./svc.sh install` uses systemd; service file at `/etc/systemd/system/actions.runner.-..service`; customize via `actions-runner/bin/actions.runner.service.template` and always invoke via `runsvc.sh`. — [GitHub Docs: Configuring as a service](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/configuring-the-self-hosted-runner-application-as-a-service)
- Automated one-shot installer script: `create-latest-svc.sh` resolves latest runner, downloads/extracts, registers, installs as service; requires `RUNNER_CFG_PAT`. — [actions/runner: create-latest-svc.sh](https://github.com/actions/runner/blob/main/scripts/create-latest-svc.sh); [docs/automate.md](https://github.com/actions/runner/blob/main/docs/automate.md)
- Scaleway Mac mini guide: also set up `_work/.env` with `ImageOS=macos13` and Xcode developer dir. — [Scaleway: Configuring a GitHub Actions Runner on a Mac mini](https://www.scaleway.com/en/docs/tutorials/install-github-actions-runner-mac/)
- `.env` in runner directory sets PATH/env vars for the runner process (LaunchAgent doesn't inherit shell PATH); edit then restart via launchctl. — [Gist: Setup macOS as GitHub Actions self-hosted runner](https://gist.github.com/random1st/97a8ad1f8644fb4612c79e7dbc45106f)

### Inferences
- For a headless Mac Mini that reboots, the LaunchDaemons move is effectively mandatory; the LaunchAgent-only default will silently fail to start after reboot.
- Running the service as a dedicated `actions-runner` user (not your personal account) limits blast radius if a workflow is compromised.

### Gaps
- I found no official GitHub documentation acknowledging the LaunchAgent/GUI-login limitation; it surfaces only in community issues.

## What are the limitations of self-hosted runners? (concurrency, maintenance, etc.)

### Takeaway
A single self-hosted runner handles only one job at a time regardless of core count; runners are stateful (no clean VM per job), require manual OS/software maintenance, and jobs queue up to 24 hours before failing.

### Cited Findings
- One runner = one job at a time, independent of CPU cores; additional jobs queue until a runner is idle. — [Stack Overflow: parallel self-hosted runners](https://stackoverflow.com/questions/61124368/github-actions-parallel-self-hosted-runners-on-the-same-machine)
- GitHub-hosted runners are "clean isolated virtual machines destroyed at end of job"; self-hosted runners are "regular processes with no virtualization or isolation" and state persists across jobs. — [Stack Overflow: where does self-hosted runner execute](https://stackoverflow.com/questions/65071861/where-does-self-hosted-github-runner-executes-the-code-is-having-multiple-runne)
- Routing: job stays queued until a matching idle runner comes online; fails after 24 hours queued. If a runner doesn't pick up an assigned job within 60 seconds, it's re-queued. — [GitHub Docs: Self-hosted runners reference](https://docs.github.com/en/actions/reference/runners/self-hosted-runners)
- Maintenance burden: "you are responsible for updating the operating system and all other software"; runner app auto-updates only itself. — [GitHub Docs: Self-hosted runners overview](https://docs.github.com/en/actions/hosting-your-own-runners)
- Autoscaling: GitHub recommends ephemeral runners for autoscaling; persistent runners are not recommended for autoscaling because jobs may be assigned while shutting down. — [GitHub Docs: Self-hosted runners reference](https://docs.github.com/en/actions/reference/runners/self-hosted-runners)
- No concurrency limits for self-hosted runners at the account level, but each runner is single-job. — [Stack Overflow: parallel self-hosted runners](https://stackoverflow.com/questions/61124368/github-actions-parallel-self-hosted-runners-on-the-same-machine)
- Cost: runner is free to use with GitHub Actions, but you bear hardware/maintenance cost. — [GitHub Docs: Self-hosted runners overview](https://docs.github.com/en/actions/hosting-your-own-runners)

### Inferences
- For a solo dev, the main practical limitation is serial execution: a push + PR + nightly build can't run concurrently unless you add more runners.
- Statefulness means a failed/interrupted build can leave `_work` dirty; periodic cleanup or ephemeral runners help.

### Gaps
- I found no data on typical maintenance time/cost for a single Mac Mini runner.

## Can you run multiple runners on one machine?

### Takeaway
Yes — install each runner into its own directory with a unique name; each is a separate process and can run concurrently, but they share the OS so port conflicts, shared caches, and state leakage between jobs are real risks.

### Cited Findings
- Each runner handles one job at a time; running multiple runners in separate directories achieves parallelism. — [Stack Overflow: parallel self-hosted runners](https://stackoverflow.com/questions/61124368/github-actions-parallel-self-hosted-runners-on-the-same-machine)
- Setup pattern (Matthieu Napoli): download tarball once, extract into `runner-1..N` directories, configure each with `./config.sh`, install each as a separate service. — [Matthieu Napoli: Self-hosting macOS GitHub Runners](https://stitcher.io/feed/posts/74513)
- Each runner gets its own `_work` workspace; "completely different workspaces." — [Stack Overflow: parallel self-hosted runners](https://stackoverflow.com/questions/61124368/github-actions-parallel-self-hosted-runners-on-the-same-machine)
- systemd: create a separate unit file per runner with unique service name and matching `WorkingDirectory=`. — [Stack Overflow: parallel self-hosted runners](https://stackoverflow.com/questions/61124368/github-actions-parallel-self-hosted-runners-on-the-same-machine)
- Practical example: Mac Mini M2 with multiple runners cut build time ~26→7 min; repo `buildingcash/multi-self-hosted-runners` automates multi-runner setup via Nix on macOS. — [buildingcash/multi-self-hosted-runners](https://github.com/buildingcash/multi-self-hosted-runners)
- Caveat: side-effects from one runner (e.g., a test server on a fixed port, shared build caches) can break concurrent runs on another runner on the same OS. — [Stack Overflow: where does self-hosted runner execute](https://stackoverflow.com/questions/65071861/where-does-self-hosted-github-runner-executes-the-code-is-having-multiple-runne)

### Inferences
- For Godot, running 2 runners on an 8-core Mac Mini is reasonable (one export per runner); running more than cores allows risks CPU thrashing and slower exports.
- Shared Godot export templates in `~/Library/Application Support/Godot` are read-only-ish and safe to share; shared `_work` is not.

### Gaps
- No published guidance on optimal runner count per Mac Mini model; depends on project size and core count.

## How to handle secrets and environment variables?

### Takeaway
Secrets are configured in GitHub (repo/org/environment) and injected via `${{ secrets.* }}`; on self-hosted runners they arrive in the job environment, and runner-level PATH/env vars are set via the `.env` file in the runner directory; avoid command-line secret passing.

### Cited Findings
- Secrets are set in GitHub repo Settings → Secrets and variables → Actions; accessed in workflows via `${{ secrets.NAME }}` as inputs or env vars. — [GitHub Docs: Using secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets)
- Secrets are not passed to workflows triggered from forked repositories (except GITHUB_TOKEN); not available to Dependabot-triggered workflows. — [GitHub Docs: Using secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets)
- Security guidance: pass secrets via environment variables/STDIN, not command lines (visible via `ps`); quote properly. — [GitHub Docs: Using secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets)
- Runner-level environment variables (PATH, etc.) are configured via `.env` file in the runner application directory; the runner reads it at startup. — [GitHub Docs: Using a proxy server with self-hosted runners](https://docs.github.com/en/actions/how-tos/managing-self-hosted-runners/using-a-proxy-server-with-self-hosted-runners)
- On macOS, LaunchAgent doesn't inherit shell PATH, so `.env` must explicitly set PATH (e.g., `/opt/homebrew/bin:...`) or tools won't be found. — [Gist: Setup macOS as GitHub Actions self-hosted runner](https://gist.github.com/random1st/97a8ad1f8644fb4612c79e7dbc45106f)
- Scaleway guide: create `_work/.env` with `ImageOS=macos13` and `XCODE_15_DEVELOPER_DIR=...` for Xcode-based builds. — [Scaleway: Configuring a GitHub Actions Runner on a Mac mini](https://www.scaleway.com/en/docs/tutorials/install-github-actions-runner-mac/)
- Environment variables can be scoped at workflow/job/step level via `env:` key; `vars` context for configuration variables. — [GitHub Docs: Store information in variables](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-variables)
- For Apple notarization on a self-hosted Mac runner, secrets (APPLE_ID, APPLE_PASSWORD, APPLE_TEAM_ID) live in GitHub Secrets; signing certs live in the runner's Keychain. — [Gist: Setup macOS as GitHub Actions self-hosted runner](https://gist.github.com/random1st/97a8ad1f8644fb4612c79e7dbc45106f)
- GitHub auto-redacts secret values from logs, but redaction isn't guaranteed across transformations; runner can only redact secrets used in the current job. — [GitHub Docs: Secrets](https://docs.github.com/en/actions/concepts/security/secrets)
- On self-hosted runners, avoid storing secrets in the runner's home directory; use GitHub Secrets + OIDC for cloud providers where possible. — [GitHub Docs: Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)

### Inferences
- For Godot builds, the typical secrets are itch.io Butler API keys, Apple signing/notarization credentials, and Android keystores; these should all live in GitHub Secrets, never in the runner's filesystem or repo.
- The `.env` file is the right place for non-secret runner config (PATH, Xcode dir); secrets should never go there.

### Gaps
- I found no Godot-specific secret-handling guidance; standard GitHub Actions practices apply.