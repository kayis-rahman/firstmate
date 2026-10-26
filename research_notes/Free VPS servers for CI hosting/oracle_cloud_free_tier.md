# Oracle Cloud "Always Free" Tier for VPS/CI Hosting (2026)

## What are the Always Free tier specs? (CPU, RAM, storage, bandwidth)

### Takeaway
Oracle's Always Free compute offers two AMD micro instances (1/8 OCPU, 1 GB RAM each) plus a shared pool of 2 OCPUs / 12 GB RAM on Ampere A1 ARM (halved from 4/24 in June 2026), backed by 200 GB block storage, 20 GB object storage, and 10 TB/month egress — the most generous permanent free compute among hyperscalers, but with important idle-reclamation and capacity caveats.

### Cited Findings
- All tenancies get up to two Always Free VM instances using `VM.Standard.E2.1.Micro` (AMD): 1/8th OCPU with burst to 1 full OCPU, 1 GB RAM. — [Oracle Always Free Resources docs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- All tenancies get 1,500 OCPU-hours and 9,000 GB-hours/month on `VM.Standard.A1.Flex` (Ampere A1 ARM), equivalent to 2 OCPUs and 12 GB memory total (as of June 15, 2026). — [Oracle Always Free Resources docs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm); [askgpu.com](https://askgpu.com/updates/oracle-cloud-halves-always-free-arm-compute/)
- Block volume: 200 GB total Always Free, used for boot volumes; minimum boot volume 47 GB per instance regardless of shape. — [Oracle Always Free Resources docs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- Object/Archive storage: 20 GB combined (Standard + Infrequent Access + Archive) for expired-trial/Always-Free-only accounts; 10 GB each tier otherwise; 50,000 Object Storage API requests/month. — [Oracle Always Free Resources docs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- Outbound data transfer: 10 TB/month free across all services. — [Oracle Cloud Free Tier](https://www.oracle.com/cloud/free/)
- E2.1.Micro networking: one VNIC, one public IP, up to 50 Mbps internet bandwidth; up to 480 Mbps to private IPs / same-region endpoints. — [Oracle Always Free Resources docs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- A1.Flex networking: bandwidth and VNIC count scale proportionately with OCPU count. — [Oracle Always Free Resources docs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- Virtual Cloud Networks: max 2 VCNs per tenancy; Flexible Load Balancer (1 instance, 10 Mbps) included. — [Oracle Cloud Free Tier](https://www.oracle.com/cloud/free/)
- Idle reclamation: instances deemed idle if over a 7-day period CPU 95th percentile <20%, network <20%, and (A1 only) memory <20%. — [Oracle Always Free Resources docs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)

### Inferences
- A 2-OCPU/12 GB A1 instance likely gets roughly 2 Gbps network throughput (community-reported ~1 Gbps per OCPU), but Oracle publishes no fixed number for the free tier.
- The 200 GB block storage cap means you cannot max out both compute shapes and large boot volumes simultaneously; e.g., two AMD micros (2×47 GB) + one 2-OCPU A1 (47 GB) ≈ 141 GB, leaving ~59 GB.

### Gaps
- Exact A1 per-OCPU network bandwidth is not stated in the cited docs; treat community figures as unverified.

## What instance types are available? (Ampere A1 ARM, AMD E2.1.Micro)

### Takeaway
Only two Always Free shapes exist: `VM.Standard.E2.1.Micro` (AMD, burstable, x86_64) and `VM.Standard.A1.Flex` (Ampere Altra, ARM64/aarch64, flexible OCPU/RAM). A1 is the CI workhorse; E2.1.Micro is only suitable for light agents.

### Cited Findings
- `VM.Standard.E2.1.Micro`: AMD processor, 1/8 OCPU baseline (bursts to 1 OCPU), 1 GB RAM; images: Oracle Linux Cloud Developer 8, Oracle Linux, Ubuntu, CentOS. — [Oracle Always Free Resources docs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- `VM.Standard.A1.Flex`: Arm (Ampere Altra) processor, flexible 1–2 OCPUs and up to 12 GB RAM total; images: Oracle Linux Cloud Developer, Oracle Linux, Ubuntu. Oracle Linux Cloud Developer image requires ≥8 GB RAM. — [Oracle Always Free Resources docs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- E2.1.Micro can only be created in one availability domain; A1 can be created in any AD except South Korea North (Chuncheon). — [Oracle Always Free Resources docs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- E2.1.Micro is available only in the home region; A1.Flex is available in any subscribed region. — [cmos486/oraclecloud-vmfree-terraform](https://github.com/cmos486/oraclecloud-vmfree-terraform)

### Inferences
- For Godot CI, the A1 (ARM64) is the only viable shape; the E2.1.Micro's 1 GB RAM and 1/8 OCPU baseline cannot run Godot editor/export or builds.

### Gaps
- None significant.

## What are the limits? (max instances, regions, etc.)

### Takeaway
You can run at most 2 OCPUs total on A1 (one 2-OCPU instance or two 1-OCPU instances) plus up to two E2.1.Micro instances, all compute must live in the home region (AMD) or any subscribed region (A1), and A1 is unavailable in Chuncheon.

### Cited Findings
- A1: up to 2 instances of 1 OCPU each (2 OCPUs total) OR one instance with 2 OCPUs, subject to 200 GB block storage. — [Oracle Always Free Resources docs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- AMD micro: up to two instances, only in one availability domain. — [Oracle Always Free Resources docs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- A1 is not available in South Korea North (Chuncheon). — [Oracle Cloud Customer Connect](https://community.oracle.com/customerconnect/discussion/970310/oci-always-free-updated-ampere-a1-compute-allocation)
- A1 exceeding the limit (e.g., leftover from trial) causes all A1 instances to be disabled and deleted after 30 days unless upgraded to paid. — [Oracle Free Tier docs](https://docs.oracle.com/iaas/Content/FreeTier/freetier.htm)
- Compute instances must be created in the home region (for Always Free resources). — [Oracle Always Free Resources docs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- Home region cannot be changed after signup. — [Oracle signup docs](https://docs.oracle.com/en-us/iaas/Content/GSG/Tasks/signingup_topic-Sign_Up_for_Free_Oracle_Cloud_Promotion.htm)
- One account per person; multiple free accounts prohibited. — [Oracle Cloud Free Tier FAQ](https://www.oracle.com/cloud/free/faq/)
- Accounts idle 30+ days may be suspended/terminated. — [Oracle Cloud Free Tier FAQ](https://www.oracle.com/cloud/free/faq/)
- Free Tier not available in US Government Cloud regions. — [Oracle Free Tier docs](https://docs.oracle.com/iaas/Content/FreeTier/freetier.htm)

### Inferences
- For CI, a single 2-OCPU/12 GB A1 instance is the right shape; splitting into two 1-OCPU instances halves RAM each and complicates a single runner.

### Gaps
- Whether AMD micro is offered in every commercial region is not explicitly confirmed; community reports some regions lack it (e.g., Montreal). — [Oracle Customer Connect](https://community.oracle.com/CustomerConnect/discussion/577099/standard-e2-1-micro-missing)

## Can you run Godot on ARM Ampere A1? What are the setup steps?

### Takeaway
Yes — Godot runs on aarch64 Linux, and Oracle's Ampere A1 is a supported target. You can either run the official Godot Linux ARM64 binary/export templates or build from source with SCons; for CI, use GitHub Actions self-hosted runners on an A1 VM (Oracle even publishes an official blog + quickstart for this).

### Cited Findings
- Godot supports 7 Linux architectures including arm64; ARM64 export templates are part of official builds since Godot 4.1+. — [Godot docs: Exporting for Linux](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_linux.html); [reddit r/godot](https://www.reddit.com/r/godot/comments/17kx7ty/precompiled_arm64_export_templates_for_godot_4/)
- Compiling Godot on Linux requires GCC 9+/Clang 6+, Python 3.9+, SCons 4.4+, plus X11/Wayland/Mesa/ALSA/PulseAudio dev libs. — [Godot docs: Compiling for Linux](https://docs.godotengine.org/en/latest/engine_details/development/compiling/compiling_for_linuxbsd.html)
- Oracle published an official blog: "Announcing GitHub Actions Arm runners for the Arm compute platform on Oracle Cloud Infrastructure," and a quickstart repo `oracle-quickstart/oci-github-actions-runner`. — [Oracle blog](https://blogs.oracle.com/cloud-infrastructure/announcing-github-actions-arm-runners-for-the-arm-compute-platform-on-oracle-cloud-infrastructure); [GitHub](https://github.com/oracle-quickstart/oci-github-actions-runner)
- Oracle Linux Cloud Developer image (requires ≥8 GB RAM on A1) ships GCC, Python, Podman, etc. — [Oracle Linux blog](https://blogs.oracle.com/linux/develop-arm-applications-quickly-using-oracle-linux-cloud-developer-image)
- Godot's own build-containers use Fedora and ship an aarch64 SDK (`aarch64-godot-linux-gnu_sdk-buildroot`). — [godotengine/build-containers](https://github.com/godotengine/build-containers/blob/main/Dockerfile.linux)
- Community guide: self-hosted aarch64 runner on Oracle Cloud for building R packages. — [gaborcsardi.org](https://gaborcsardi.org/2024/gha-runner-oracle-cloud/)

### Inferences
- Setup steps for a Godot CI runner on A1: (1) create a 2-OCPU/12 GB A1 instance with Ubuntu or Oracle Linux; (2) install Godot (download official Linux ARM64 binary + export templates, or build via SCons); (3) install the GitHub Actions runner (`actions/runner` aarch64 release); (4) register as a self-hosted runner; (5) keep CPU utilization above 20% 95th-percentile to avoid idle reclamation (e.g., a cron keep-alive or scheduled builds).
- Because Godot export templates for ARM64 are official, an A1 runner can produce Linux/ARM64 game builds natively; cross-compiling to x86_64/Windows/Web/Android needs the respective toolchains (MinGW, Emscripten, Android NDK) which run fine on ARM64 hosts.

### Gaps
- No official Godot-on-Oracle step-by-step doc was found; the steps above are synthesized from Godot + OCI docs and community guides.

## What are the known issues/caveats?

### Takeaway
The big gotchas: credit-card verification with a $1 hold (no prepaid/virtual cards), home region is permanent, capacity errors ("out of host capacity") are common, AMD micro availability varies by region, idle reclamation after 7 days, 30-day idle account suspension, and the June 2026 halving of A1 (old tutorials still say 4/24).

### Cited Findings
- Credit/debit card required for identity verification; $1 authorization hold at signup (released in days); no prepaid/virtual/single-use/PIN debit cards accepted. — [Oracle Cloud Free Tier FAQ](https://www.oracle.com/cloud/free/faq/); [cheaploy.com](https://cheaploy.com/oracle-cloud/does-it-require-credit-card)
- $100 authorization hold when upgrading to paid. — [Oracle billing docs](https://docs.oracle.com/en-us/iaas/Content/Billing/Tasks/changingpaymentmethod.htm)
- "Out of host capacity" errors are common; workaround: different AD, wait, or upgrade to Pay-As-You-Go (Always Free resources still free after upgrade). — [Oracle Always Free Resources docs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- AMD E2.1.Micro unavailable in some regions (e.g., Montreal reported); `standard-e2-micro-core-count` can be 0. — [Oracle Customer Connect](https://community.oracle.com/CustomerConnect/discussion/577099/standard-e2-1-micro-missing)
- Tokyo/Osaka have only one availability domain, limiting retry options. — [issoh.co.jp](https://www.issoh.co.jp/tech/details/17531/)
- Idle reclamation after 7 days below 20% thresholds (CPU, network, and memory for A1). — [Oracle Always Free Resources docs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- Accounts idle 30+ days may be suspended/terminated. — [Oracle Cloud Free Tier FAQ](https://www.oracle.com/cloud/free/faq/)
- A1 halved June 15, 2026 (from 4 OCPUs/24 GB to 2/12) with no announcement; old tutorials still cite 4/24. Exceeding new limits disables/deletes all A1 instances after 30 days. — [askgpu.com](https://askgpu.com/updates/oracle-cloud-halves-always-free-arm-compute/); [Oracle Free Tier docs](https://docs.oracle.com/iaas/Content/FreeTier/freetier.htm)
- Free Trial: $300 credits for 30 days; A1 disabled/deleted 30 days after trial end if over Always Free limits. — [Oracle Free Tier docs](https://docs.oracle.com/iaas/Content/FreeTier/freetier.htm)
- No SLA and no Oracle Support for Always Free-only accounts; community forums only. — [Oracle Cloud Free Tier FAQ](https://www.oracle.com/cloud/free/faq/)
- One account per person; multiple accounts prohibited. — [Oracle Cloud Free Tier FAQ](https://www.oracle.com/cloud/free/faq/)
- Signup failures reported in some countries (e.g., Pakistan) even after card verification. — [Oracle Customer Connect](https://community.oracle.com/CustomerConnect/discussion/978149/oracle-cloud-always-free-signup-failed-after-successful-debit-card-verification)

### Inferences
- For a CI runner, idle reclamation is the biggest operational risk; schedule periodic builds or a keep-alive daemon to keep 95th-percentile CPU ≥20%.

### Gaps
- No official Oracle statement on the June 2026 A1 reduction was found (reported by community/press, not Oracle announcement).

## How does Oracle Cloud compare to other free VPS providers?

### Takeaway
Oracle's Always Free is uniquely generous in permanent compute (2 ARM OCPUs/12 GB + 2 AMD micros, 200 GB storage, 10 TB egress) versus AWS/GCP/Azure free tiers that are mostly 12-month trials or tiny always-free (e2-micro 0.25 vCPU/1 GB on GCP), but it trades reliability/capacity certainty for that generosity.

### Cited Findings
- AWS free tier: 12 months of t2.micro/t3.micro (1 vCPU, 1 GB), 30 GB EBS, 15 GB egress/month; always-free layer is mostly utilities (Lambda, DynamoDB). — [hashirahmad/Best-always-free-tier-cloud-platforms](https://github.com/hashirahmad/Best-always-free-tier-cloud-platforms)
- GCP free tier: e2-micro (0.25 vCPU, 1 GB) always free in specific US regions, 30 GB standard disk, 1 GB egress/month (excluding China/Australia). — [freevps.edu.pl](https://freevps.edu.pl/blog/oracle-vs-google-cloud-free-tier-2026/)
- Oracle: up to 10 TB egress/month vs ~100 GB on competitors. — [Oracle Cloud Free Tier](https://www.oracle.com/cloud/free/); [rackdog.com](https://rackdog.com/blog/egress-fees-index)
- Oracle block storage 200 GB vs AWS 30 GB. — [medium.com illuminations-mirror](https://medium.com/illuminations-mirror/a-beginners-guide-to-comparing-oracle-vs-aws-free-tier-cloud-offerings-4a137b1107e7)
- OCI standard compute ~57% cheaper than equivalent AWS EC2; block storage ~78% cheaper; egress 13x cheaper. — [Oracle OCI vs AWS](https://www.oracle.com/cloud/oci-vs-aws/)
- Community sentiment: "nothing compares to Oracle cloud free tier" for raw resources; complaints about capacity availability and reclamation. — [Hacker News](https://news.ycombinator.com/item?id=32153172); [lowendtalk](https://lowendtalk.com/discussion/184161/oracle-may-reclaim-your-idle-vps)

### Inferences
- For CI/CD with Godot (CPU/RAM hungry builds), Oracle's 2 OCPU/12 GB A1 is the best free option; competitors' free tiers cannot run Godot builds meaningfully.

### Gaps
- No quantitative benchmark comparing build times across providers was found.

## Is there a "trial" vs "always free" distinction?

### Takeaway
Yes — Oracle Cloud Free Tier bundles a 30-day $300 credit "Free Trial" (access to nearly all services) with permanent "Always Free" services. After the trial expires (or credits exhausted), only Always Free resources remain; A1 usage above Always Free limits is disabled/deleted after 30 days unless you upgrade to Pay-As-You-Go.

### Cited Findings
- Free Tier = Free Trial ($300 credits, 30 days, all eligible services) + Always Free services (unlimited time). — [Oracle Cloud Free Tier](https://www.oracle.com/cloud/free/)
- Free Trial credits expire after 30 days if unused; Always Free services continue. — [Oracle Cloud Free Tier FAQ](https://www.oracle.com/cloud/free/faq/)
- During trial, OCI Ampere A1 instances are disabled and deleted after 30 days if over Always Free limits; upgrade to paid keeps them. — [Oracle Free Tier docs](https://docs.oracle.com/iaas/Content/FreeTier/freetier.htm)
- Grace period of 30 days after trial expiry to upgrade; resources deleted if not upgraded. — [Oracle Cloud Free Tier FAQ](https://www.oracle.com/cloud/free/faq/)
- Upgrading to Pay-As-You-Go keeps Always Free resources free and only charges for usage above free limits; unlocks support and higher capacity limits. — [Oracle Cloud Free Tier FAQ](https://www.oracle.com/cloud/free/faq/)
- Always Free resources are available in home region only for compute; home region chosen at signup and cannot change. — [Oracle signup docs](https://docs.oracle.com/en-us/iaas/Content/GSG/Tasks/signingup_topic-Sign_Up_for_Free_Oracle_Cloud_Promotion.htm)

### Inferences
- For a CI host, staying strictly within Always Free limits (2 OCPUs/12 GB A1 total) avoids any charges; upgrading to Pay-As-You-Go is the safe escape hatch if capacity is needed and is low-risk since Always Free usage remains free.

### Gaps
- Whether the $300 trial can be used to temporarily exceed Always Free A1 limits and then downsize without data loss is not explicitly documented beyond the 30-day disable/delete window.
