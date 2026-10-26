# Free VPS / Cloud Compute Tiers: AWS, GCP, Azure (and Oracle comparison)

## AWS Free Tier: which instances are free?

### Takeaway
AWS no longer offers a 12-month free EC2 tier to new accounts. Accounts created before July 15, 2025 retain the legacy 12-month offer (750 h/month of t2.micro or t3.micro); accounts created on/after that date get a credit-based Free Plan ($100 + up to $100 earned credits, expires in 6 months). There is no permanent always-free EC2 instance on AWS.

### Cited Findings
- Legacy (pre-July 15, 2025 accounts): 750 hours/month of `t2.micro` (or `t3.micro` where t2 is unavailable) for 12 months, Linux or Windows. — [AWS Free Tier docs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/LaunchingAndUsingInstances.html); [AWS EC2 pricing 2026](https://www.usage.ai/blogs/aws/ec2/pricing)
- `t2.micro`: 1 vCPU, 1 GiB RAM; burstable CPU credits; EBS-only storage; not EBS-optimized. — [CloudPrice t2.micro](https://cloudprice.net/aws/ec2/instances/t2.micro); [AWS T2 page](https://aws.amazon.com/ec2/instance-types/t2)
- `t3.micro`: 2 vCPUs, 1 GiB RAM; burstable; up to 5 Gbps network; EBS-optimized by default (up to ~2,085 Mbps dedicated throughput). — [CloudPrice t3.micro](https://cloudprice.net/aws/ec2/instances/t3.micro); [Vantage t3.micro](https://instances.vantage.sh/aws/ec2/t3.micro)
- New accounts (on/after July 15, 2025): credit-based Free Plan — $100 signup credit + up to $100 via onboarding activities; plan closes at 6 months or when credits depleted; credits themselves valid 12 months. Free Plan limits access to "select services." — [AWS Free Tier](https://www.aws.amazon.com/free); [AWS News Blog 2025-07-15](https://aws.amazon.com/blogs/aws/aws-free-tier-update-new-customers-can-get-started-and-explore-aws-with-up-to-200-in-credits); [AWS Free Tier Terms](https://aws.amazon.com/free/terms)
- The last account eligible for the old 12-month free tier was created 2025-07-14; its window closed 2026-07-14. — [FreeTier.co](https://freetier.co/articles/aws-free-tier-changes-july-15-2025)
- AWS has 30+ "always free" services with monthly usage limits, but EC2 is not among the permanently free ones on either plan. — [AWS Free Tier](https://www.aws.amazon.com/free)
- New Free Tier features are available in all AWS Regions except GovCloud (US) and China Regions. — [AWS News Blog](https://aws.amazon.com/blogs/aws/aws-free-tier-update-new-customers-can-get-started-and-explore-aws-with-up-to-200-in-credits)

### Inferences
- For CI/CD, a new AWS account in 2026 cannot rely on a free always-on EC2 instance; you must either spend credits (t3.micro at ~$7.59/month → ~13 months of one instance per $100) or use the legacy path only if you already have an old account.
- t3.micro's 2 vCPUs but only 1 GiB RAM is the binding constraint for Godot; t2.micro (1 vCPU / 1 GiB) is worse on CPU but identical RAM.

### Gaps
- Exact list of which EC2 instance types are billable under the new credit-based Free Plan (vs. "select services") is not precisely enumerated in fetched sources; t3.micro/t4g.micro etc. are referenced in docs but eligibility wording varies. — [AWS EC2 launch docs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/LaunchingAndUsingInstances.html)

## Google Cloud Free Tier: which instances are free?

### Takeaway
GCP is the only major hyperscaler with a permanent (always-free) VM: one non-preemptible `e2-micro` (2 shared vCPUs, 1 GiB RAM, 0.25 vCPU sustained) plus 30 GB standard persistent disk and 1 GB egress/month, in us-west1/us-central1/us-east1. Plus a 90-day $300 trial for new accounts. This is the best "always-on free VM" of the three for CI, but 1 GiB RAM and 0.25 vCPU sustained is very tight for Godot.

### Cited Findings
- Always Free: 1 non-preemptible `e2-micro` VM instance per month, in us-west1 (Oregon), us-central1 (Iowa), or us-east1 (South Carolina). — [GCP free cloud features](https://docs.cloud.google.com/free/docs/free-cloud-features)
- `e2-micro`: 2 vCPUs (shared), 1 GB RAM; sustains 2 vCPUs at 12.5% CPU time each = 25% total CPU time; can burst for ~30 seconds. — [GCP general-purpose machines](https://docs.cloud.google.com/compute/docs/general-purpose-machines)
- Free disk: 30 GB-months standard persistent disk; 1 GB outbound data transfer from North America/month. — [GCP free cloud features](https://docs.cloud.google.com/free/docs/free-cloud-features)
- Free Tier limit is by time, not by instance: all e2-micro instances share a pool of hours equal to total hours in the month (e.g., ~730 h). — [GCP free cloud features](https://docs.cloud.google.com/free/docs/free-cloud-features); [dt.in.th guide](https://dt.in.th/GoogleCloudFreeTier)
- Free Trial: $300 credit for 90 days for new customers; requires credit card/payment method (temporary $0–$1 hold, not a charge); cannot attach GPUs, use Marketplace, request quota increases, or create Windows Server VMs during trial. — [GCP free cloud features](https://docs.cloud.google.com/free/docs/free-cloud-features)
- Free Tier requires an active billing account in good standing; Google reserves the right to change limits with 30 days' notice. Unused limits do not roll over. — [GCP free cloud features](https://docs.cloud.google.com/free/docs/free-cloud-features)
- GCP also offers 2,500 Cloud Build build-minutes/month free on e2-standard-2 machines — a notable alternative for CI that avoids managing a VM. — [GCP free cloud features](https://docs.cloud.google.com/free/docs/free-cloud-features)
- GPUs/TPUs are never free and cannot be attached during Free Trial. — [GCP free cloud features](https://docs.cloud.google.com/free/docs/free-cloud-features)

### Inferences
- GCP's always-free e2-micro is the only permanent free VM among AWS/GCP/Azure, making it the closest to Oracle's Always Free for long-lived CI hosts.
- 1 GiB RAM is below Godot's documented minimum for the native editor (3–6 GB), but headless export/test runs need far less; 0.25 vCPU sustained means builds will be slow and may need to stay within burst windows.

### Gaps
- Whether e2-micro's 1 GiB is sufficient for a real Godot 4 headless export of a non-trivial project is not quantified in sources; community anecdotes vary. No benchmark data found in this research pass.

## Azure Free Tier: which instances are free?

### Takeaway
Azure offers 750 hours/month of burstable B-series VMs (B1s, and newer B2pts v2 / B2ats v2) free for 12 months for new accounts, plus $200 credit for 30 days. B1s = 1 vCPU / 1 GiB RAM. The B1s SKU is being retired in many regions and can show "NotAvailableForSubscription" on Free Trial subscriptions, so newer B2ats v2 / B2pts v2 (2 vCPU / 1 GiB, ARM/AMD) are the practical free options now.

### Cited Findings
- Azure free account: $200 credit for 30 days, then 12 months of popular services free, then 55+ always-free services. — [Azure free services docs](http://learn.microsoft.com/en-us/azure/cost-management-billing/manage/create-free-services); [Azure free account VM marketplace](https://marketplace.microsoft.com/en-us/product/azure-services/microsoft.freeaccountvirtualmachine)
- Free VM hours: 750 hours/month of B1s, B2pts v2 (ARM), and B2ats v2 (AMD) burstable VMs, Linux or Windows, valid for 12 months. — [Azure free services docs](http://learn.microsoft.com/en-us/azure/cost-management-billing/manage/create-free-services); [Sedai Azure VM guide](https://sedai.io/blog/azure-vm-sizes-series-guide)
- `Standard_B1s`: 1 vCPU, 1 GiB RAM, x64 (Intel Xeon), 4 GB local temp storage, 2 max data disks, premium storage capable; base CPU performance 10%; earns 6 CPU credits/hour, max 144 banked. — [Azure Bv1 series docs](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/general-purpose/bv1-series); [Vantage B1s](https://instances.vantage.sh/azure/vm/b1s)
- Free account also includes 2 × P6 (64 GiB) managed disks free. — [Azure free account VM marketplace](https://marketplace.microsoft.com/en-us/product/azure-services/microsoft.freeaccountvirtualmachine)
- Total free VM hours up to 1,500/month when combining Linux (750) + Windows (750) allocations. — [Azure free account VM marketplace](https://marketplace.microsoft.com/en-us/product/azure-services/microsoft.freeaccountvirtualmachine)
- B1s Windows free VM is only offered in a handful of regions: East US, West US 2, West Europe, Southeast Asia (as of mid-2026). — [Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/5911079/in-which-region-can-i-create-a-free-b1s-windows-vi)
- B1s SKU is being retired in many regions; Free Trial subscriptions cannot request quota increases, so retired/restricted SKUs like Standard_B1s cannot be enabled there. Newer B2ats v2 / B2pts v2 are the recommended free alternatives. — [Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/5778558/in-which-region-can-i-create-a-free-b1s-linux-virt); [Microsoft Q&A (NotAvailableForSubscription)](https://learn.microsoft.com/en-gb/answers/questions/5975585/b1s-b2ats-v2-vm-sizes-show-notavailableforsubscrip)
- B1s on-demand price ~$0.0104/hour (~$7.59/month at 730 h). — [azurespeed.com B1s](https://www.azurespeed.com/AzureVmPricing/Standard_B1s); [Vantage B1s](https://instances.vantage.sh/azure/vm/b1s)
- Azure free services can be created in any region where available, as long as within limits. — [Azure free services docs](http://learn.microsoft.com/en-us/azure/cost-management-billing/manage/create-free-services)

### Inferences
- Azure's free VM offer is time-limited (12 months) like AWS's legacy tier, not permanent like GCP's — but it provides 750 h/month (one always-on VM) which is enough for a single CI host.
- The B1s retirement/availability problem means a new user in 2026 may not actually be able to provision the advertised free VM in their region; B2ats v2 / B2pts v2 (2 vCPU / 1 GiB) are the safer free SKUs and arguably better for builds.

### Gaps
- Whether Azure's always-free (post-12-month) service list includes any compute VM — sources say 55+ always-free services but do not confirm a free VM among them. Likely no free VM after 12 months. — [Azure free services docs](http://learn.microsoft.com/en-us/azure/cost-management-billing/manage/create-free-services)

## Can any of these run Godot? (CPU, RAM, storage)

### Takeaway
Yes, but marginally. Godot 4's documented minimum for the native editor is 3–6 GB RAM, but headless CI export/test runs need far less (community reports ~1–2 GB). All three free VMs offer only 1 GiB RAM, which is the binding constraint; builds will be slow and may OOM on larger projects. GCP's e2-micro (0.25 vCPU sustained) and Azure's B1s (10% baseline) are CPU-credit-burstable and will throttle sustained builds. Oracle's Always Free (2 OCPU / 12 GB) is in a different league.

### Cited Findings
- Godot 4 system requirements: native editor minimum 6 GB RAM (stable docs) / 3 GB (older); web editor 8 GB; exported projects 1–2 GB RAM. Storage: 200 MB executable+cache, up to 1.5–2 GB with all export templates. — [Godot system requirements](https://docs.godotengine.org/en/stable/about/system_requirements.html); [Godot 4.3 system requirements](https://docs.godotengine.org/en/4.3/about/system_requirements.html)
- Godot 4 runs headlessly via `--headless`; no display/GPU required for export or tests. — [Godot command line tutorial](https://docs.godotengine.org/en/4.1/tutorials/editor/command_line_tutorial.html); [HelpMeTest Godot CI guide 2026](https://helpmetest.com/blog/godot-ci-cd-testing)
- GUT (Godot Unit Test) + `godot --headless` is the standard CI test invocation; `.godot/` import cache must exist. — [HelpMeTest Godot CI guide 2026](https://helpmetest.com/blog/godot-ci-cd-testing)
- Export templates: ~1.3–1.5 GB additional storage after install. — [Godot system requirements](https://docs.godotengine.org/en/stable/about/system_requirements.html)
- Cloud Build (GCP) free tier offers 2,500 build-minutes/month on e2-standard-2 (2 vCPU / 8 GB) — a more capable CI runner than the free VM, at the cost of not being a persistent host. — [GCP free cloud features](https://docs.cloud.google.com/free/docs/free-cloud-features)

### Inferences
- A 1 GiB-RAM free VM can likely run small Godot 4 headless exports/tests if the project is modest and swap is configured, but is risky for medium/large projects; export-template download (1.3+ GB) alone may exceed the 30 GB disk only if combined with OS + project, but 30 GB is sufficient.
- The 0.25 vCPU sustained on e2-micro and 10% baseline on B1s mean a Godot export (typically minutes) will take much longer and may be killed by credit exhaustion; bursting helps only for short jobs.
- For CI specifically, GCP's free Cloud Build minutes (e2-standard-2, 8 GB RAM) are a stronger fit than any free VM for Godot builds, and GitHub Actions (2,000 free minutes/month on standard runners) is the even more common path. — [HelpMeTest Godot CI guide 2026](https://helpmetest.com/blog/godot-ci-cd-testing)

### Gaps
- No published benchmark of Godot 4 headless export memory footprint on 1 GB VMs found; community experience not systematically captured in sources retrieved.

## Gotchas (credit card, region restrictions, auto-shutdown, etc.)

### Takeaway
All three require a payment method/credit card (GCP: temp $0–$1 hold; AWS/Azure: card on file). All three are time-limited except GCP's VM (permanent but tiny). Region restrictions are severe: GCP free VM only in 3 US regions; Azure B1s Windows only in 4 regions and SKU retiring; AWS new plan excludes GovCloud/China. Auto-shutdown is not automatic but idle instances still accrue charges/credits; GCP stops resources at trial end; AWS Free Plan auto-closes at 6 months.

### Cited Findings
- GCP: credit card/payment method required at signup; temporary authorization hold $0.00–$1.00; no actual charge during trial. Free Trial cannot be paused or extended. — [GCP free cloud features](https://docs.cloud.google.com/free/docs/free-cloud-features)
- GCP: Free Trial resources are stopped and marked for deletion if trial ends without upgrade; 30-day grace period to recover by upgrading. — [GCP free cloud features](https://docs.cloud.google.com/free/docs/free-cloud-features)
- AWS: Free Plan account auto-closes 6 months after signup or when credits depleted; no charges unless upgraded to Paid Plan. Legacy 12-month accounts: instance charges accrue against the 750 h/month limit; idle running instances still count. — [AWS Free Tier](https://www.aws.amazon.com/free); [AWS EC2 launch docs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/LaunchingAndUsingInstances.html)
- AWS: Free Plan EC2 access limited to "select services"; GovCloud (US) and China Regions excluded from new Free Tier features. — [AWS News Blog](https://aws.amazon.com/blogs/aws/aws-free-tier-update-new-customers-can-get-started-and-explore-aws-with-up-to-200-in-credits)
- Azure: $200 credit for 30 days; free services for 12 months; subscription disabled unless moved to pay-as-you-go after trial. — [Azure free services docs](http://learn.microsoft.com/en-us/azure/cost-management-billing/manage/create-free-services); [DataStorage 2026 guide](https://datastorage.com/articles/the-2026-guide-to-cloud-free-tiers-and-credits-compute-storage-and-gpu/)
- Azure: B1s SKU retirement in many regions; Free Trial subscriptions cannot request quota increases, so restricted SKUs cannot be enabled. — [Microsoft Q&A](https://learn.microsoft.com/en-gb/answers/questions/5975585/b1s-b2ats-v2-vm-sizes-show-notavailableforsubscrip)
- Azure: free VM must be created from the "Free services" page in the portal to qualify; wrong disk size/image disqualifies it. — [Azure free account VM marketplace](https://marketplace.microsoft.com/en-us/product/azure-services/microsoft.freeaccountvirtualmachine)
- GCP: Free Tier VM only in 3 US regions (us-west1, us-central1, us-east1); combined hours across regions. — [GCP free cloud features](https://docs.cloud.google.com/free/docs/free-cloud-features)
- Azure: B1s Windows free VM only in East US, West US 2, West Europe, Southeast Asia. — [Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/5911079/in-which-region-can-i-create-a-free-b1s-windows-vi)
- GCP: crypto mining prohibited during Free Trial; no GPUs/Marketplace/quota increases/Windows VMs during trial. — [GCP free cloud features](https://docs.cloud.google.com/free/docs/free-cloud-features)
- Oracle (for comparison): Always Free resources are in the home region only; not available in US Government Cloud regions; no SLA; one account per person. — [Oracle Always Free resources](https://docs.oracle.com/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm); [Oracle Free Tier FAQ](https://www.oracle.com/cloud/free/faq/)

### Inferences
- The "free VM" headline is misleading for AWS (new accounts) and increasingly for Azure (SKU retirement); only GCP and Oracle offer a durable free compute instance, and GCP's is 1 GiB/0.25 vCPU.
- For CI specifically, a free VM is also a poor fit vs. managed build services (GCP Cloud Build free minutes, GitHub Actions free minutes) because of CPU-credit throttling and RAM limits.

### Gaps
- Whether AWS Free Plan allows running t3.micro continuously within the $100 credit for the full 6 months (cost math: t3.micro ~$7.59/month → ~13 months per $100, so yes, one instance fits) — confirmed by cost arithmetic but not explicitly stated in AWS docs. — [CloudPrice t3.micro](https://cloudprice.net/aws/ec2/instances/t3.micro)

## Comparison to Oracle Cloud Always Free tier

### Takeaway
Oracle Cloud's Always Free tier is substantially more generous than AWS/GCP/Azure free offerings: 2 OCPU (Ampere A1 ARM) + 12 GB RAM (halved from 4 OCPU/24 GB in June 2026), plus 2 × AMD micro VMs (1/8 OCPU, 1 GB each) and 200 GB block storage pooled. For Godot CI, Oracle is the only free tier with enough RAM/CPU to be genuinely usable; AWS/GCP/Azure free VMs are 1 GiB / credit-burstable.

### Cited Findings
- Oracle Always Free: Ampere A1 Flex — up to 2 OCPUs and 12 GB RAM total, configurable as one instance or split across up to 4; (reduced from 4 OCPU/24 GB on June 15, 2026). — [Oracle Always Free resources](https://docs.oracle.com/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm); [awesome-resources free-cloud-vps](https://github.com/codebox1230/awesome-resources/blob/master/categories/free-cloud-vps.md); [Reddit r/oraclecloud](https://www.reddit.com/r/oraclecloud/comments/1u4lzkk/new_free_tier_limits_confirmed_by_oracle_support)
- Oracle Always Free: AMD E2.1.Micro — 1/8 OCPU, 1 GB RAM, up to 2 instances; 47 GB boot volume each. — [awesome-resources free-cloud-vps](https://github.com/codebox1230/awesome-resources/blob/master/categories/free-cloud-vps.md)
- Oracle Always Free: 200 GB block storage pooled across instances; 10 TB egress/month; no SLA; home region only. — [awesome-resources free-cloud-vps](https://github.com/codebox1230/awesome-resources/blob/master/categories/free-cloud-vps.md); [Oracle Free Tier FAQ](https://www.oracle.com/cloud/free/faq/)
- Oracle Free Trial: $300 credit for 30 days. — [Oracle Free Tier FAQ](https://www.oracle.com/cloud/free/faq/)
- Side-by-side (Oct 2026): Oracle 2 OCPU (ARM) / 12 GB RAM; AWS credit-based, no guaranteed free instance type, ~1 GiB reference (t2.micro); GCP 1 e2-micro 2 shared vCPUs / 1 GB RAM. — [unixgaming.org comparison](https://unixgaming.org/oracle-cloud-free-tier-vs-aws-gcp-game-servers-2026)

### Inferences
- For Godot CI, Oracle's Always Free (ARM) has enough RAM (12 GB) to run Godot comfortably and enough CPU (2 OCPU) for real builds; the catch is ARM architecture (Ampere) — Godot provides ARM Linux binaries, but export targets and some tooling may differ, and the host is ARM not x86.
- AWS/GCP/Azure free VMs are x86 (except Azure's B2pts v2 ARM) but RAM-starved (1 GiB) and CPU-credit-burstable, making them poor primary CI hosts for Godot; they suit only tiny projects or as fallback.
- Recommendation: if a free self-hosted CI runner for Godot is the goal, Oracle Always Free is the only viable always-free option among the four; otherwise use managed free CI minutes (GitHub Actions, GCP Cloud Build).

### Gaps
- Whether Godot 4's official Linux export templates run on ARM64 (Ampere) without emulation — Godot ships ARM64 Linux binaries, but not explicitly confirmed in retrieved sources. — [Godot system requirements](https://docs.godotengine.org/en/stable/about/system_requirements.html) (no ARM64 CI guidance found)