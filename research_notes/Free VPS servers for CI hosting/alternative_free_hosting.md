# Alternative Free Hosting and CI/CD Options for Godot Builds

## Fly.io Free Tier

### Takeaway
Fly.io no longer offers a permanent free tier for new accounts as of 2026; new signups get a 7-day / 2-VM-hour trial, after which the cheapest always-on app costs roughly $2-5/month. Existing legacy free allowances were grandfathered but cannot be transferred to new accounts.

### Cited Findings
- Fly.io retired its free allowances for new accounts on October 7, 2024; new organizations start on usage-based billing with a $5/month minimum (Hobby plan) — [Fly.io Pricing 2026: What It Actually Costs | Temps](https://temps.sh/blog/fly-io-pricing-2026)
- New users receive a free trial limited to 2 VM hours OR 7 days (whichever comes first), max 10 machines, up to 4GB RAM and 2 vCPUs per machine, 20GB volume storage, no GPUs, no dedicated IPv4 — [Fly.io Free Tier 2026: What Can You Actually Host?](https://www.saaspricepulse.com/blog/flyio-free-tier-2026)
- Legacy free allowances were grandfathered but cannot be transferred to new accounts; Fly stopped selling plans/free allowances Oct 7, 2024 — [Fly.io Pricing: Free Tier & Real App Costs (2026) · Lizard](https://lizard.build/blog/fly-io-pricing)
- Fly.io uses per-second billing; smallest always-on Machine (shared-cpu-1x, 256MB RAM) costs ~$2.02/month plus $2.00/month for dedicated IPv4, $0.15/GB volume, $0.02/GB egress — [Fly.io Free Tier 2026](https://www.saaspricepulse.com/blog/flyio-free-tier-2026)
- Fly.io pricing page lists min memory 256MB, max 32GB, default timeout 60s, max 5min — [Fly.io Pricing](https://www.srvrlss.io/provider/fly)
- Fly.io community confirms no real free tier anymore; small (<$5) invoices are waived — [Fly.io community discussion](https://community.fly.io/t/concern-about-unexpected-charges-on-fly-io-free-tier-usage/24560)

### Inferences
- Fly.io is not suitable as a "free" CI host; it's a low-cost paid option. For CI/CD workloads specifically, the 2 VM-hour trial is far too short for any meaningful build. A Godot build could technically run on a Fly Machine (up to 4GB RAM / 2 vCPU in trial), but you'd be paying ~$4-7/month minimum for always-on capacity.

### Gaps
- No confirmed reports of Godot builds running on Fly.io Machines found; the trial limits (2 VM hours) make it impractical for CI regardless.

---

## Render Free Tier

### Takeaway
Render has a genuine permanent free tier: free web services (512MB RAM, 0.1 CPU, sleeps after 15 min inactivity, 750 instance hours/month), free static sites, and free PostgreSQL (256MB, expires after 30 days). It can run Godot exports via Docker containers, but the 512MB RAM / 0.1 CPU and 15-minute sleep make it marginal for Godot builds.

### Cited Findings
- Free web service instance: 512 MB RAM, 0.1 CPU, $0/month; Starter $7/month (512MB, 0.5 CPU); no credit card required to sign up — [Render Pricing](https://render.com/pricing)
- Free web services spin down after 15 minutes of inactivity, restart on next request, spin-up ~1 minute; 750 free instance hours per workspace per calendar month, suspended if exhausted — [Render: Platforms with a real free tier 2026](https://render.com/articles/platforms-with-a-real-free-tier-for-developers-in-2026)
- Free PostgreSQL: 256MB RAM, 25MB storage, 50 connections, expires 30 days after creation (14-day grace period before deletion) — [Render Pricing](https://render.com/pricing)
- Hobby workspace plan is $0/month (1 seat, 5GB bandwidth); Pro $25/month flat (unlimited seats, 25GB bandwidth); bandwidth overage $0.15/GB on all tiers — [Render pricing explained](https://livemy.app/blog/render-pricing)
- Free tier rules as of July 2026: 750 hours/month compute, 5GB bandwidth (down from 100GB), 1GB Postgres for 90 days — [Best Render Alternatives 2026 | Code Capsules](https://www.codecapsules.io/blog/best-render-alternatives-in-2026-where-to-go-when-render-falls-short)
- Render Workflows (task runs): flex plan up to 1 CPU / 4GB RAM, billed per use; Hobby workspaces can create up to 16 CPU / 64GB RAM of new compute per minute — [Render Workflows Limits](https://render.com/docs/workflows-limits)
- Render can run Docker-based workloads including Godot CI images (barichello/godot-ci) since it supports container deployments — [Godot CI image docs](https://github.com/marketplace/actions/godot-ci)

### Inferences
- Render's free web service (512MB RAM, 0.1 CPU) is likely insufficient for Godot exports, which need ~2-4GB RAM and a modern CPU; the 15-minute sleep also makes it unsuitable as a CI runner that must stay responsive. Render Workflows could run Godot builds on flex compute but that's billed per use, not free. Render is better suited to hosting deployed game builds (static sites) than running CI.

### Gaps
- No confirmed community reports of Godot builds succeeding on Render's free tier; the memory/CPU limits suggest it would struggle.

---

## Railway Free Tier

### Takeaway
Railway's free tier is a one-time $5 trial credit (30 days, no credit card) followed by a permanent Free plan with only $1/month of usage credit. Specs are 1 vCPU / 0.5GB RAM per service on Free. This is not viable for Godot builds.

### Cited Findings
- Railway Free plan: $0/month, $1/month non-rollover usage credit, 1 vCPU and 0.5 GB RAM per service, 1 project, 3 services per project, 0.5 GB volume storage, no cron jobs, community support only — [Railway Free Tier 2026 | Medium](https://medium.com/@kuberns/railway-free-tier-in-2026-what-you-get-and-when-it-runs-out-2101fdca0998)
- New accounts get a one-time Trial with $5 credit (no credit card), reverts to Free plan after 30 days or when $5 spent; Trial allows 5 services per project — [Railway Free Tier 2026 | SaaSPricePulse](https://www.saaspricepulse.com/tools/railway)
- Hobby plan: $5/month minimum (includes $5 usage credit), 8 vCPU-hours / 32 GB-hours per month included, $0.000463/vCPU-second, $0.0000018/GB-second, 100GB egress, 10-min execution timeout for one-off jobs — [Railway Pricing 2026 | Nayan Kyada](https://nayankyada.com/blog/railway-pricing-2026-free-tier-limits-usage-costs-when-to-upgrade)
- Railway usage rates: $20/vCPU/month, $10/GB RAM/month, billed per second; Pro $20/month per workspace minimum — [Railway Pricing 2026 | Temps](https://temps.sh/blog/railway-pricing-2026)
- Railway has no permanently free tier with meaningful resources; all plans have a monthly base cost — [Railway Pricing Calculator 2026 | MakerKit](https://makerkit.dev/pricing-calculator/railway)

### Inferences
- Railway's Free plan ($1/month credit, 0.5GB RAM) cannot run Godot builds. Hobby plan ($5/month) could theoretically run a Godot build within its 8 vCPU-hour / 32 GB-hour monthly allowance, but a single Godot export can consume several minutes of CPU time and would exhaust the allowance quickly. Not recommended for CI.

### Gaps
- No community reports of Godot builds on Railway found.

---

## Hetzner Cloud (Not Free, But Very Cheap)

### Takeaway
Hetzner has no free tier, but its entry-level cloud servers start at ~€5.49-5.99/month (CX23: 2 shared vCPU, 4GB RAM) — the cheapest viable option for a self-hosted CI runner that can handle Godot builds. Prices increased significantly in 2026 (up to 2-3x on some instance families), but still undercut competitors by ~60%.

### Cited Findings
- Hetzner Cloud has no free tier or trial; lowest cost is CX23 at €5.49/month (2 shared vCPU, 4GB RAM) or €0.0088/hour, hourly billing, delete anytime — [Hetzner Cloud VPS Pricing Calculator](https://costgoat.com/pricing/hetzner)
- Hetzner cloud servers: CX23 from €5.99/month (post-April 2026 price adjustment); CPX22 (2 vCPU / 4GB) rises to €7.99/month from April 2026 — [Hetzner Cloud Review 2026 | Better Stack](https://betterstack.com/community/guides/web-servers/hetzner-cloud-review)
- Hetzner price adjustment June 2026: CCX cloud server families increased 2.1x-2.73x, CPX families 2.4x-2.75x in Germany/Finland, CPX in USA up to 3.1x — [Hetzner cloud server price increases 2026 | Northflank](https://northflank.com/blog/hetzner-cloud-server-price-increases)
- Hetzner still ~60% cheaper than DigitalOcean/Vultr for equivalent specs ($24/month vs ~$9.49/month for 2 vCPU/4GB) — [Hetzner Cloud Review 2026](https://betterstack.com/community/guides/web-servers/hetzner-cloud-review)
- CX33: 4 vCPU, 8GB RAM, 80GB disk, €5.99-6.49/month; CAX11 (ARM): 2 vCPU, 4GB RAM, 40GB, €3.99-4.51/month — [Hetzner European Cloud](https://www.hetzner.com/european-cloud)
- Reddit community reports frustration with 2026 price increases but still considers Hetzner cheapest — [r/hetzner discussion](https://www.reddit.com/r/hetzner/comments/1u6bcdb/hetzner_these_prices_are_ludicrous)

### Inferences
- A Hetzner CX23 or CAX11 (4GB RAM) is the cheapest viable self-hosted CI runner for Godot builds. Godot exports need ~2-4GB RAM minimum; 4GB is workable for 2D/light 3D, 8GB (CX33) is better for heavier projects. The CAX11 ARM instance is cheapest but Godot's ARM Linux support and export templates need verification.

### Gaps
- No specific benchmarks of Godot build times on Hetzner instances found.

---

## GitHub Actions Self-Hosted Runners

### Takeaway
GitHub Actions self-hosted runners are free to use (no per-minute charge from GitHub) and run on your own hardware. Setup involves downloading the runner binary, registering it with a token, and running it as a service. This is the best free option for Godot builds if you already own hardware.

### Cited Findings
- Self-hosted runners are free to use with GitHub Actions; you are responsible for machine costs and maintenance — [GitHub Docs: Self-hosted runners](https://docs.github.com/actions/hosting-your-own-runners)
- Requirements: machine must communicate with GitHub Actions, minimum 70 Kbps upload/download, outbound HTTPS on port 443, enough hardware for workflows; Docker needed only for container actions — [GitHub Docs: Self-hosted runners reference](https://docs.github.com/en/actions/reference/runners/self-hosted-runners)
- Runner application auto-updates; supports Linux, Windows, macOS on x64 and arm64; can run multiple runners on one host in separate directories — [GitHub community discussion #26258](https://github.com/orgs/community/discussions/26258)
- As of March 2026, self-hosted runners on private repos incur a $0.002/min platform fee drawn from the included-minutes pool — [Top 5 CI/CD Platforms 2026](https://guptadeepak.com/tools/top-5-ci-cd-platforms-2026)
- GitHub-hosted runner specs for comparison: Linux 2 vCPU / 8GB RAM / 14GB SSD, 2000 free minutes/month for private repos, unlimited for public — [GitHub Docs: GitHub-hosted runners reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- AWS CodeBuild can now serve as managed self-hosted runners for GitHub Actions (ephemeral, scalable) — [AWS DevOps Blog](https://aws.amazon.com/blogs/devops/best-practices-working-with-self-hosted-github-action-runners-at-scale-on-aws)
- Self-hosted runner setup: create runner in repo/org settings, download runner package, run config.sh with URL + token, install as service with svc.sh — [DevOpsCube guide](https://devopscube.com/github-actions-self-hosted-runner)

### Inferences
- Self-hosted runners are the recommended path for Godot CI: Godot's barichello/godot-ci Docker image runs on any Linux host with Docker, and GitHub Actions workflows can target self-hosted runners with `runs-on: self-hosted`. The only cost is hardware/electricity. On a Mac Mini or existing dev machine, this is effectively free.

### Gaps
- No specific guide for running Godot builds on self-hosted runners found beyond general Godot CI guides; the Docker-based approach (barichello/godot-ci) works on any Linux host.

---

## GitLab CI Free Tier

### Takeaway
GitLab CI Free tier provides 400 compute minutes/month per group (vs GitHub's 2000), 5 users max per top-level private group, 10GB storage per project. Self-hosted runners are free on all tiers including Free. The 400-minute allowance is very tight for Godot builds.

### Cited Findings
- GitLab Free tier: 400 compute minutes/month per group, 5 users max per top-level private group, 10GB storage per project — [GitLab Pricing](https://about.gitlab.com/pricing); [Semaphore: Best GitLab Alternatives 2026](https://semaphore.io/blog/best-gitlab-alternatives-in-2026)
- New accounts after Jan 27, 2026 limited to 3 top-level groups; 5-user limit enforced on remaining Free namespaces with private visibility from Aug 15, 2026 — [GitLab Free user and group limits](https://docs.gitlab.com/user/free_user_limit); [GitLab blog: Upcoming changes](https://about.gitlab.com/blog/efficient-free-tier)
- Self-hosted runners are free on every tier including Free; hosted minutes adjusted by runner machine cost factors — [Semaphore comparison](https://semaphore.io/blog/best-gitlab-alternatives-in-2026)
- Additional compute minutes purchasable at $10 per 1000 minutes — [GitLab Forum](https://forum.gitlab.com/t/ci-cd-minutes-for-gitlab-saas-free-tier/40241)
- GitLab.com Free: 400 mins/group/month vs GitHub Actions 2000 mins/month for private repos — [CICDCalculator.com](https://cicdcalculator.com/free-ci-cd-platforms)

### Inferences
- GitLab CI's 400 free minutes/month is too tight for Godot builds (a single export can take 5-15 minutes). Self-hosted runners on GitLab (free) are the practical path, using the barichello/godot-ci Docker image or a self-hosted GitLab Runner on existing hardware.

### Gaps
- No specific Godot-on-GitLab-CI free tier benchmarks found.

---

## Other Free CI/CD Platforms

### CircleCI Free Tier
- 30,000 credits/month (~3,000 minutes on Medium Linux at 10 credits/min); 5 users, 1 concurrent job on Free; up to 30 concurrent jobs reported; self-hosted runner concurrency capped at 5 on Free; no per-build-minute fee on self-hosted runners — [CircleCI Pricing 2026](https://cicdcost.com/circleci-pricing); [CircleCI Docs: Credits](https://circleci.com/docs/guides/plans-pricing/credits)
- Open source projects on Free plan get up to 400,000 credits/month (80,000 build minutes) for Linux/Arm/Docker — [CircleCI Review 2026 | Siit](https://www.siit.io/tools/trending/circleci-review)
- Free plan users cannot purchase additional credits; must upgrade to Performance ($15/month) — [CircleCI Pricing 2026](https://cicdcost.com/circleci-pricing)

### Travis CI
- Free plan: 20 concurrent jobs, but only 10K trial credits (1K Linux build minutes) valid for 14 days, not replenished; OSS credits for public repos only — [Travis CI Billing Overview](https://docs.travis-ci.com/user/billing-overview)
- Usage-based plans start at $69/month; no meaningful permanent free tier for private repos — [Travis CI Pricing 2026 | TrustRadius](https://www.trustradius.com/products/travis-ci/pricing)
- 120-minute max build time per job — [Travis CI FAQ](https://www.travis-ci.com/faq)

### Other Notable Free CI/CD Options
- **Buildkite Personal**: Free forever, 1 active user, 3 concurrent jobs, 500-550 hosted Linux minutes/month, no free macOS — [Free CI/CD 2026 comparison | merginit](https://merginit.com/blog/20062026-free-cicd-comparison)
- **Bitbucket Pipelines Free**: 50 minutes/month private, effectively unlimited public — [CICDCalculator.com](https://cicdcalculator.com/free-ci-cd-platforms)
- **Jenkins**: Free and open source, self-hosted, no license limits; requires your own infrastructure — [JetBrains CI Tools 2026](https://blog.jetbrains.com/teamcity/2026/03/best-ci-tools)
- **Woodpecker CI / Drone CI**: Free open-source self-hosted options, $15-30/month infra — [CICDCalculator.com](https://cicdcalculator.com/free-ci-cd-platforms)
- **GitHub Actions**: 2000 free minutes/month for private repos (Linux), unlimited for public; self-hosted runners free (but $0.002/min platform fee on private repos since March 2026) — [Top 5 CI/CD Platforms 2026](https://guptadeepak.com/tools/top-5-ci-cd-platforms-2026)

### Inferences
- CircleCI's 30,000 free credits (~3,000 min on Medium Linux) is competitive with GitHub Actions' 2000 minutes and better than GitLab's 400. However, Godot builds are heavy (Docker image pulls + export), so even 3,000 minutes/month exhausts quickly. Travis CI is effectively not free for private repos. Jenkins/Woodpecker/Drone on self-hosted hardware are viable free alternatives if you already own a machine.

### Gaps
- No confirmed reports of Godot builds on CircleCI or Travis CI specifically; the barichello/godot-ci Docker image should work on any Docker-capable CI runner.

---

## Can Any of These Run Godot Builds?

### Takeaway
Yes — GitHub Actions (hosted and self-hosted), GitLab CI (hosted and self-hosted), and CircleCI can all run Godot builds using the barichello/godot-ci Docker image or GameCI's Godot support. The free tiers' minute limits are the binding constraint, not capability. Self-hosted runners on existing hardware are the most practical free path.

### Cited Findings
- barichello/godot-ci is a Docker image for exporting Godot games, used with GitHub Actions and GitLab CI; supports Godot 3.x and 4.x, including Mono/C# builds — [GitHub Marketplace: godot-ci](https://github.com/marketplace/actions/godot-ci)
- GameCI supports Godot builds out of the box against barichello/godot-ci image; works on GitHub Actions, GitLab CI, CircleCI — [GameCI FAQ](https://game.ci/docs/faq)
- Godot headless export command: `godot --headless --export-release "Preset" build/output` — [Medium: Build Your First CI/CD Pipeline for Godot](https://medium.com/the-solo-dev-journal/build-your-first-ci-cd-pipeline-for-godot-and-why-you-wanna-do-it-a5efb94796ce)
- Godot editor needs ~4GB RAM minimum (2GB may work with optimized OS); 2 cores enough for editor, 4+ for C++ module compilation — [Godot Forum: hardware specs](https://forum.godotengine.org/t/what-specs-are-good-for-a-computer-that-you-are-planning-to-use-godot-with/28101)
- Godot CI build on GitHub Actions (free tier): 2000 min/month for private repos, unlimited for public; a typical Godot export takes 5-15 minutes depending on project size and target platform — [YouTube: GitHub Actions Godot VR builds](https://www.youtube.com/watch?v=PjDDakeG4J0)
- Self-hosted CI runner needs: 2 vCPU / 4GB RAM minimum per parallel job; disk I/O is often the bottleneck for parallel builds — [Hostiserver: Self-hosted CI/CD architecture](https://www.hostiserver.com/community/articles/self-hosted-cicd-architecture-runners)
- Yockyard guide: self-hosted GitLab runner on Debian, using flatpak Godot or barichello/godot-ci Docker image, builds Windows/Linux/macOS exports — [Yockyard: Setting up a Godot CI/CD server](https://www.yockyard.com/post/setting-up-a-godot-cicd-server)

### Inferences
- GitHub Actions hosted runners (2 vCPU / 8GB RAM / 14GB SSD) have enough RAM for Godot exports but the 14GB SSD is tight for Docker images (Godot CI image is ~1-2GB). Free 2000 min/month is the main constraint — a project with daily builds would exhaust it in ~2-3 weeks.
- For free Godot CI, the best options in order are: (1) GitHub Actions on a public repo (unlimited minutes), (2) self-hosted runner on existing hardware (free, unlimited), (3) CircleCI free tier (3000 min/month, better than GitLab's 400), (4) GitLab CI free tier (400 min/month, too tight for anything but tiny projects).
- Render/Railway/Fly.io are not practical for CI builds: Render's free tier sleeps and has 0.1 CPU, Railway's free tier has 0.5GB RAM, Fly.io has no permanent free tier.

### Gaps
- No benchmark data on actual Godot export times across different CI platforms found; community reports suggest 5-15 minutes per export depending on project complexity and target platform.
- No data on whether Godot's ARM Linux builds work on ARM-based CI runners (e.g., Hetzner CAX11, GitHub Actions ARM runners).