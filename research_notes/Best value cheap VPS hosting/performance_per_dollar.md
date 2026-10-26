# VPS Performance Per Dollar - Research Notes (2026)

Scope: current 2026 pricing/benchmarks for mainstream VPS providers. Sources are benchmark labs (AIMultiple 2026, VPSBenchmarks monthly trials, VPSMetrics, Raff), provider docs, and community comparison tables (LowEndTalk, provider blogs). Where prices are in EUR, USD conversions are approximate at ~1.08-1.10 USD/EUR; verify before acting.

## vCPU / RAM / storage / bandwidth per dollar for top providers

### Takeaway
Hetzner and Contabo deliver roughly 2-3x the raw CPU/RAM/storage/bandwidth per dollar of DigitalOcean/Linode/Vultr at equivalent tiers, but with trade-offs in consistency (Contabo) and region/latency (Hetzner). VPSBenchmarks' price-weighted rankings consistently put unknown/low-cost providers (Nobull, TakeHost.Biz, 0ping, ServerOptima) above mainstream names.

### Cited Findings
- AIMultiple Aug 2026 benchmark (4 vCPU / 8 GB / Ubuntu 24.04 / US East): Hetzner $18.59/mo, DigitalOcean $48.00/mo, Linode $48.00/mo, Liquid Web $45.00/mo, IONOS $15.00/mo, GoDaddy $65.99/mo. — [AIMultiple VPS Benchmark](https://aimultiple.com/vps-benchmark)
- Derived resource-per-dollar at that tier: Hetzner 4 vCPU/$18.59 = 0.215 vCPU/$ and 0.43 GB RAM/$; DigitalOcean 4/$48 = 0.083 vCPU/$ and 0.167 GB RAM/$ (≈2.6x gap). — [AIMultiple](https://aimultiple.com/vps-benchmark)
- Low-tier ratios: Hetzner CX23 ~$6.55/mo (2 vCPU, 4 GB, 40 GB NVMe, 20 TB transfer) = 0.305 vCPU/$, 0.61 GB RAM/$, 6.1 GB storage/$, ~3 TB transfer/$. — [SpinUp / FlexiCloud / Medium VPS deal comparisons](https://medium.com/@fimber6/best-vps-deals-of-2025-1baeddb08e3d)
- Contabo Cloud VPS 1 ~€4.50/mo (~$4.91): 4 vCPU, 6 GB RAM, 100 GB NVMe, 32 TB traffic = 0.814 vCPU/$, 1.22 GB RAM/$, 20.4 GB storage/$. Contabo VPS 8: 24 GB RAM at ~€13.33/mo (~$14.56) = 1.65 GB RAM/$. — [Contabo blog 2026](https://contabo.com/blog/best-vps-hosting-providers), [Hetzner vs Contabo video transcript](https://www.youtube.com/watch?v=-Rz5aVAKC0I)
- OVHcloud VPS-1 ~$4.54/mo: 2 vCore, 4 GB RAM, 40 GB NVMe, "unlimited" traffic at 500 Mbps = 0.44 vCPU/$, 0.88 GB RAM/$, 8.8 GB/$. — [OVHcloud](https://us.ovhcloud.com/vps)
- IONOS VPS S+ ~$2/mo (intro, regular $5): 2 vCore, 2 GB RAM, 90 GB NVMe; entry VPS often $4.54-5.00/mo. — [LiquidWeb cheapest VPS post 2026](https://www.liquidweb.com/blog/cheapest-vps-hosting), [10 Cheapest VPS Providers 2026](https://zoomnod.com/blog/cheapest-vps-providers)
- Fourplex Telecom (annual): 1 vCore/2 GB/30 GB NVMe ≈$2.07/mo; 2 vCore/4 GB/60 GB ≈$3.74/mo; 1 vCore/1 GB/1 TB SATA HDD = $5/mo. — [Chinese-language VPS roundup 2026](https://blog.naibabiji.com/bestvps)
- Hostinger KVM 2: 2 vCPU, 8 GB RAM, 100 GB NVMe at ~$6.49/mo (intro) = 0.308 vCPU/$, 1.23 GB/$. — [Hostinger VPS pricing](https://www.hostinger.com/vps-hosting)
- Entry-plan transfer allowances: DigitalOcean 512 MB/$4 plan includes 500 GB; Linode and Vultr 1 GB/$5 plans include ~1-2 TB; DO 16 GB Droplet includes 6 TB, Vultr 16 GB includes 5 TB, Linode 16 GB includes 8 TB. — [LiberationTek VPS comparison](https://liberationtek.com/compare/vps-hosting-providers), [VPSBenchmarks DO vs Linode vs Vultr](https://www.vpsbenchmarks.com/compare/digitalocean_vs_linode_vs_vultr)
- Hetzner includes 20 TB transfer on CX/CPX plans (EU) with no overage up to that. — [Medium VPS deals post](https://medium.com/@fimber6/best-vps-deals-of-2025-1baeddb08e3d)

### Inferences
- In raw specs-per-dollar, Contabo and IONOS-era budget providers dominate by 3-5x over the developer clouds (DO/Vultr/Linode) at entry tiers; Hetzner sits in between with better consistency than Contabo.
- VPSBenchmarks monthly trials show low-cost providers (Nobull, TakeHost.Biz, 0ping, ServerOptima, Alwyzon) topping price-weighted lists in every price band under $8/$15/$25/$40/$70/$120. — [VPSBenchmarks Best VPS rankings](https://www.vpsbenchmarks.com)

### Gaps
- Contabo's headline RAM-per-euro figures (24 GB/€13.33) mix SSD base line and NVMe Plus line; the exact storage class per plan varies and should be verified on the pricing page before quoting.
- IONOS introductory pricing ($2-4.54/mo) renews higher ($5-12/mo); "per dollar" figures split dramatically between intro and renewal. Sources note renewal hikes but rarely quantify exact renewal multipliers.

## CPU performance benchmarks (PassMark, Geekbench, sysbench) per dollar

### Takeaway
On a normalized CPU-events-per-dollar basis, IONOS (833 events/$/mo) and Hetzner (780) are ~11x ahead of DigitalOcean (71) in AIMultiple's 2026 4 vCPU/8 GB test — but Hetzner combines that with the lowest CPU variance, while IONOS caps disk. CPU performance per dollar is dominated by low-cost predictable (non-oversold) providers, not the developer clouds.

### Cited Findings
- AIMultiple 2026 (sysbench CPU, 4 vCPU/8 GB, US): CPU events/sec: Liquid Web 16,072 (±326), Hetzner 14,493 (±35), IONOS 12,501 (±22), GoDaddy 6,133 (±76), Linode 6,133 (±150), DigitalOcean 3,408 (±174). Price-performance: IONOS 833 events/$, Hetzner 780, Liquid Web 357, Linode 128, GoDaddy 93, DigitalOcean 71. — [AIMultiple VPS Benchmark](https://aimultiple.com/vps-benchmark)
- CPU variance (std dev across 50 runs): IONOS 21.8, Hetzner 35.2, DigitalOcean 174.1; low variance attributed to isolation approaching dedicated cores despite shared pricing. — [AIMultiple](https://aimultiple.com/vps-benchmark)
- Raff (4 GB/2 vCPU, AlmaLinux 9.6): Raff $17.99 score 60.5 PPD 3.36; Vultr Regular $24 score 66.0 PPD 2.75; Vultr High Frequency $45 score 72.8 PPD 1.62; DigitalOcean Premium AMD $28 score 56.5 PPD 2.02; DigitalOcean CPU-Optimized $42 score 56.3 PPD 1.34; AWS c7a.large $74 score 50.9 PPD 0.69; DigitalOcean Regular $24 score 48.9 PPD 2.04. — [Raff 2026 VPS Performance Benchmarks](https://rafftechnologies.com/performance), [DEV Community PPD writeup](https://dev.to/sst21/vps-performance-reality-check-2025-whos-actually-fast-and-worth-the-money-1g6g)
- VPSMetrics sample Geekbench 6 single/multi: AMD EPYC (Cloudzy) SC 765/MC 1,387 at $28.95/mo; AMD Ryzen 9 (Tihost) SC 1,323/MC 3,861 at $12.30/mo; AMD EPYC (Cloudblast) SC 1,228/MC 3,092 at $8.24/mo. (Geekbench-based, per-provider test lab; non-sysbench, not directly comparable to AIMultiple.) — [VPSMetrics benchmarks](https://vpsmetrics.com/benchmarks)
- Hetzner hardware benchmarks (VPSRated 2026): CCX23 (AMD EPYC dedicated, 2 vCPU? listed 2C/8GB-ish) Geekbench 6 single 2,340 / multi 8,450; DigitalOcean Premium Intel/AMD single 2,150 / multi 7,620. Disk 4K random read 420K vs 310K IOPS. — [VPSRated enterprise guide 2026](https://www.vpsrated.com/enterprise-high-performance-vps-benchmarks-2026)
- Hetzner ARM CAX31 vs x86 CPX31 (4 vCPU/8 GB): ARM Geekbench 6 single ~1,070 at €11.99/mo vs x86 ~1,650 at €16.49/mo; WordPress throughput ~7-10% slower on ARM. — [bitdoze ARM vs x86 VPS benchmark](https://www.bitdoze.com/arm-vs-x86-vps-server-benchmarks)
- Community yabs benchmark (Wappler/Hetzner): Ampere Altra 2-core achieved highest CPU and file I/O vs Intel/AMD 2-core on Hetzner; Intel weakest. — [Wappler community](https://community.wappler.io/t/the-new-arm64-servers-from-hetzner-are-so-powerful/50439)

### Inferences
- Cheapest is not always fastest but can be close: IONOS $15/mo lands 12,501 sysbench events/sec vs Hetzner $18.59/mo at 14,493 — IONOS is 86% of Hetzner's throughput at 81% of the price, with the tightest variance in the test.
- Developer clouds (DO/Linode) are 5-11x worse on CPU per dollar and 3-10x more variable, consistent with heavier oversubscription of shared CPU pools.
- Dedicated-CPU tiers (Hetzner CCX, Linode Dedicated, Vultr CPU-Optimized) cost more but remove noisy-neighbor variance; benchmarking shows they are worth the premium for latency-sensitive workloads.

### Gaps
- No independent 2026 PassMark aggregate across all eight mainstream VPS providers was found; PassMark figures are mostly hardware-level (CPU family) rather than per-VPS. Geekbench per-VPS community submissions (VPSMetrics) use inconsistent plan tiers and cannot be normalized into a single price-performance ratio.
- AWS in Raff test uses c7a.large (a general-purpose instance) at $74/mo but is not directly comparable to the 4 GB/2 vCPU baseline (c7a.large is 2 vCPU/4 GB, same baseline). Fine; but AWS pricing fluctuates with region and reserved instances.

## Disk I/O performance per dollar (IOPS, throughput)

### Takeaway
Disk performance per dollar is bimodal: IONOS and Liquid Web/Hetzner deliver high throughput cheaply, but IONOS hard-caps IOPS/MBps at the hypervisor (highly predictable but low ceiling), while premium tiers (Liquid Web, Linode) lead raw IOPS. Contabo Basic uses cheaper storage and shows poor I/O consistency versus its NVMe Plus line.

### Cited Findings
- AIMultiple 2026 (fio, libaio, qd64, direct I/O; 4 vCPU/8 GB): Random read IOPS: Liquid Web 72,149; Linode 71,068; GoDaddy 63,017; Hetzner 59,558; DigitalOcean 54,295; IONOS 20,066 (capped). Sequential read/write MB/s: Liquid Web 12,709/10,212; Linode 8,187/4,983; Hetzner 3,728/3,013; DigitalOcean 2,298/350 (weak write); GoDaddy 721/1,088; IONOS 478/478 (capped). — [AIMultiple VPS Benchmark](https://aimultiple.com/vps-benchmark)
- MyUnix (fio 3.36, 4K random read/write, 4 GB file): Vultr 87,400 random-read IOPS, Linode 51,200, DigitalOcean 44,800 on comparable plans. — [Shattered.io cheapest VPS 2026](https://shattered.io/cheapest-cloud-vps-2026-provider-comparison)
- VPSRated 2026: Hetzner CCX23 (dedicated AMD EPYC) 420,000 4K random read IOPS; DigitalOcean Premium 310,000 IOPS. — [VPSRated](https://www.vpsrated.com/enterprise-high-performance-vps-benchmarks-2026)
- Raff 2026: Raff disk 487 MB/s vs AWS EBS 125 MB/s on 4 GB/2 vCPU; Raff file operations 1000 files in 2.3s vs AWS t2 12.4s. — [Raff performance](https://rafftechnologies.com/performance)
- Hetzner: NVMe (local) by default on CX/CPX; additional volumes $0.05/GB/mo for block storage. — [Hetzner pricing per onboarding](https://aimultiple.com/vps-benchmark)
- DigitalOcean: Premium/NVMe Droplets from $7/mo (1 GB/1 vCPU/25 GB NVMe/1 TB transfer); block storage $0.10/GB/mo. — [DigitalOcean VPS hosting](https://www.digitalocean.com/solutions/vps-hosting)
- OVHcloud: NVMe claimed up to 6x standard SSD; VPS-3 6 vCore/12 GB/100 GB @ $12.32/mo includes NVMe. — [OVHcloud VPS](https://us.ovhcloud.com/vps)
- Contabo: older lines ship SSD (Base) at cheap RAM-per-euro prices; Plus line upgrades to NVMe at higher price. IONOS-style hypervisor caps noted on IONOS. — [Contabo vs Hetzner 2026](https://www.youtube.com/watch?v=-Rz5aVAKC0I)

### Inferences
- Per-dollar disk efficiency: Liquid Web (72,149 IOPS / $45 = 1,603 IOPS/$) leads, but Hetzner (59,558 / $18.59 = 3,204 IOPS/$) beats it despite lower absolute IOPS, and IONOS (20,066 / $15 = 1,338 IOPS/$) trails but with zero variance (hard cap).
- DigitalOcean's weak write throughput (350 MB/s seq write vs Hetzner 3,013 MB/s) is a serious per-dollar liability for write-heavy/DB workloads at $48/mo.
- NVMe vs underlying device matters less than whether the plan uses local NVMe vs block-storage hypervisor caps; IONOS proves cheap plans can be provisioned with hard hypervisor caps that make results identical run-to-run.

### Gaps
- No independent per-GB-per-dollar full pricing table (with IOPS tier) across providers; existing numbers (Vultr 87,400 vs DO 44,800) come from MyUnix, a single methodology, and VPSMetrics figures are WordPress-composite, not raw fio. Cannot rank all providers on identical disk workloads.
- Contabo's "SSD vs NVMe" line performance split has no published sysbench/fio comparison with methodology.

## Network bandwidth and transfer limits per dollar

### Takeaway
Transfer inclusion per dollar varies by an order of magnitude: Hetzner's 20 TB and Contabo/OVH's 32 TB/unlimited beat the developer clouds' 1-8 TB, and Linode has the cheapest overage ($0.005/GB) among metered providers. For high traffic, Hetzner/OVH/Linode beat DO/Vultr; for low latency globally, Vultr's region count wins.

### Cited Findings
- Included transfer at common tiers: DigitalOcean Basic $4 plan = 500 GB; Hetzner CX23 = 20 TB; Contabo Cloud VPS 1 = 32 TB; OVHcloud = unlimited (port 500 Mbps-3 Gbps) on VPS-1..VPS-4; Vultr entry = 1-2 TB; Linode 4 GB plan = 4 TB. — [Medium VPS deals](https://medium.com/@fimber6/best-vps-deals-of-2025-1baeddb08e3d), [OVHcloud](https://us.ovhcloud.com/vps), [LowEndTalk discussions](https://lowendtalk.com/discussion/195477/hetzner-vs-netcup-vs-contabo-vps-for-webserver-cyberpanel)
- Overages: DigitalOcean $0.01/GiB; Vultr $0.01/GB; Akamai/Linode $0.005/GB; Hetzner ~€1/extra TB beyond included (typical); LiberationTek includes 6-32 TB with no egress fees. — [LiberationTek VPS comparison](https://liberationtek.com/compare/vps-hosting-providers)
- Bandwidth per dollar derivations: Hetzner CX23 20 TB / $6.55 = 3.05 TB/$; Contabo 32 TB / $4.91 = 6.52 TB/$; OVHcloud unlimited (capped port). DO $4 500 GB/$4 = 125 GB/$. (DO overage at $0.01/GiB means 1 TB of egress beyond allowance = $10.) — derived from cited prices/allowances.
- AIMultiple 2026 network (4 vCPU/8 GB, US): download/upload median Mbps: Hetzner 1,811/1,689; DigitalOcean 1,673/1,172; Linode 1,603/1,145; IONOS 1,176/963; Liquid Web 962/417 (min 213); GoDaddy 319 min 58. — [AIMultiple](https://aimultiple.com/vps-benchmark)
- Latency/region: DigitalOcean most consistent across regions; Hetzner strong in EU, decent US; Vultr widest region choice (32+ global DCs, hourly billing). — [Pivotlar 2026 comparison](https://pivotlar.com/blog/digitalocean-vs-vultr-vs-hetzner-for-wordpress-hosting-which-vps-is-actually-worth-it-in-2026), [FlexiCloud](https://flexicloud.co/blogs/digitalocean-vs-vultr-vs-linode-vs-hetzner-which-cloud-is-best-for-your-needs)
- OVHcloud APAC regions (Mumbai, Singapore, Sydney): bandwidth capped at 10 Mbps after 1-4 TB quota; non-APAC regions unlimited traffic. — [OVHcloud VPS](https://us.ovhcloud.com/vps)

### Inferences
- For bandwidth-heavy workloads (CDN origin, media, scraping), Hetzner/Contabo/OVH have a structural 10-50x transfer advantage; a DO bill for 20 TB of egress beyond allowance would be ~$200 vs included on Hetzner.
- Network raw speed per dollar: Hetzner 1,811 Mbps at $18.59 = 97.4 Mbps/$ vs DigitalOcean 1,673/$48 = 34.9 Mbps/$ and IONOS 1,176/$15 = 78.4 Mbps/$ — Hetzner leads, IONOS close second.

### Gaps
- No single source tests all providers' network from identical source/destination; AIMultiple US-East only, community results uncontrolled. Latency to specific regions (APAC, Middle East) not benchmarked in any cited independent source.

## Which providers oversell? Which are fairly provisioned?

### Takeaway
Shared-CPU tiers split into two camps: Hetzner and IONOS behave like dedicated (very low CPU variance, near-zero steal), while DigitalOcean Regular shows high variance (oversubscribed pools). Contabo reliably advertises more RAM/storage per dollar but suffers noisy-neighbor CPU steal on base lines; its NVMe/Plus and VDS tiers improve. Dedicated-CPU tiers (Hetzner CCX, Linode Dedicated, Vultr CPU-Optimized, DO CPU-Optimized) buy consistency. Naming on plan pages does not match provisioning reality.

### Cited Findings
- AIMultiple 2026 states the VPS/VDS distinction plainly: DO CPU scores varied 174 points vs IONOS 22 across 50 runs at identical load; a VDS (dedicated cores) gives zero steal time. "The name on the plan page does not always match reality." IONOS and Hetzner shared plans performed like dedicated in that test. — [AIMultiple VPS Benchmark](https://aimultiple.com/vps-benchmark)
- VPSBenchmarks: "price weighted" grades penalize high price, used to separate genuinely cheap good plans from expensive good ones; Contabo "noisy" reliability rating on base line vs "Very good" on Hetzner. — [VPSBenchmarks Contabo vs Hetzner](https://www.vpsbenchmarks.com/compare/contabo_vs_hetzner), [VPSBenchmarks FAQ](https://www.vpsbenchmarks.com/faq)
- DanubeData/Contabo-alternatives analysis 2026: Contabo "Mixed (noisy)" with shared disk pools; Hetzner "Very good"; DanubeData (built on Hetzner dedicated) "Predictable" with per-VM LVM NVMe. — [DanubeData reliability 2026](https://danubedata.ro/blog/contabo-alternatives-reliability-2026)
- Hetzner splits into shared "Cost-Optimized/Regular" and dedicated "General Purpose (CCX)" tiers; CPU-optimized/High Frequency at Vultr; DO Premium AMD/Intel NVMe variants. — [provider pricing docs and comparisons](https://helpwithweb.com/help/digitalocean-vs-linode-vs-vultr)
- MassiveGRID notes Hetzner's modern AMD EPYC + local NVMe gives highest raw IOPS in their test group; Vultr HF "worth the premium" for CPU-bound workloads; Linode NVMe standard and consistent. — [MassiveGRID best VPS 2026](https://massivegrid.com/blog/best-vps-hosting-providers-2026)
- Hostwinds: charges bandwidth overage and SSL extra; only 72-hour refund; throttling at peak reported. — [LiquidWeb cheapest VPS 2026](https://www.liquidweb.com/blog/cheapest-vps-hosting)

### Inferences
- Strong proxies of overselling: (1) CPU score variance across time-of-day runs > ~100 sysbench points at 4 vCPU = heavily shared; (2) CPU steal time in `top`/`htop` > 2-3%; (3) identical IOPS/MBps across runs to 3 decimal places = hard hypervisor cap (not necessarily bad; predictable, just low).
- "Fairly provisioned" high-volume shared hosts: Hetzner Cost-Optimized, IONOS, Linode Shared, Vultr Regular/High Frequency, OVHcloud.
- Likely oversold / throttled shared hosts: DigitalOcean Basic/Regular shared pools (high variance), Contabo Base SSD line (CPU steal on multi-tenant nodes), GoDaddy (lowest CPU/unit by far, mandatory agent).

### Gaps
- No provider publishes a committed vCPU-to-physical-core or VM-per-host ratio; "overselling" claims rely on benchmark variance, not disclosed policy. Provider docs on resource allocation policies were mostly marketing copy without ratio commitments.

## Hetzner vs DigitalOcean vs Vultr vs Linode performance per dollar

### Takeaway
On the 2026 AIMultiple 4 vCPU/8 GB test, Hetzner is the only provider that combines low price ($18.59), top-tier CPU (14,493 events/sec, 780 events/$), high memory bandwidth (5,423 MiB/s, best in test), strong sequential disk (3,728 MB/s), and fastest low-variance network (1,811/1,689 Mbps). DigitalOcean and Linode charge 2.6x more and score lowest on CPU; Vultr sits mid-tier by price but leads disk IOPS and I/O throughput in some third-party tests.

### Cited Findings
- AIMultiple 2026 head-to-head table (4 vCPU/8 GB/US) as above. — [AIMultiple](https://aimultiple.com/vps-benchmark)
- VPSBenchmarks comparison page shows Voxety of plans and price-weighted grades for DO/Linode/Vultr/Hetzner; VPSBenchmarks own aggregate places Vultr High Performance at strong IOPS and Vultr VX1 tier at 2 vCPU/8 GB/$48.80 with 5,000 GB transfer. — [VPSBenchmarks DO vs Linode vs Vultr](https://www.vpsbenchmarks.com/compare/digitalocean_vs_linode_vs_vultr)
- Cloudprice comparison: Vultr vc2-2c-4gb $20.00/mo vs Linode g6-standard-2 $24.00/mo at 2 vCPU/4 GB; Vultr cheaper at every comparable tier (4 vCPU/8 GB: $40 vs $48). — [cloudprice.app](https://cloudprice.app/compare/vultr-vs-linode)
- Shattered.io (MyUnix): Vultr 87,400 4K random-read IOPS vs Linode 51,200 and DO 44,800 on comparable plans; Vultr internal network 9.4 Gbit/s vs DO 8.7 Gbit/s. — [Shattered.io](https://shattered.io/cheapest-cloud-vps-2026-provider-comparison)
- SpinUpWP: Hetzner 8 GB/2 vCPU €12.49/mo vs Vultr 4 GB/2 vCPU $40/mo vs Akamai 4 GB/2 $36 vs DO 4 GB/2 $42; Hetzner far cheaper at similar-plus-better specs. — [SpinUpWP](https://spinupwp.com/blog/digitalocean-vs-google-cloud-vs-aws)
- Cloudblast/Tihost/VPSMetrics: Tihost 4 vCPU/4 GB with AMD Ryzen 9 3.4 GHz $12.30/mo, SC 1,323/MC 3,861. — [VPSMetrics](https://vpsmetrics.com/benchmarks)
- MassiveGRID: Hetzner "best price-to-performance EU"; Vultr HF "worth premium" for CPU-bound; Linode NVMe standard consistent. — [MassiveGRID 2026](https://massivegrid.com/blog/best-vps-hosting-providers-2026)
- HelpWithWeb comparison: entries: DO $4 (0.5 GB), Linode $5 (1 GB), Vultr $3.50 (0.5 GB), Hetzner €4.59 (4 GB). DO $6 1 GB. — [HelpWithWeb](https://helpwithweb.com/help/digitalocean-vs-linode-vs-vultr)
- Pivotlar (WordPress focus): Hetzner unbeatable EU; Vultr good balance global; DO safest polish-but-priciest. — [Pivotlar](https://pivotlar.com/blog/digitalocean-vs-vultr-vs-hetzner-for-wordpress-hosting-which-vps-is-actually-worth-it-in-2026)

### Inferences
- Price ordering at comparable capability: Hetzner (lowest) < Vultr < Linode < DigitalOcean (highest), in roughly that order across 1-8 GB tiers, with the gap widening at higher tiers (Vultr 8 GB $48 vs DO 8 GB $96 at dedicated CPU).
- Capability ordering: Hetzner leads CPU-per-dollar and memory bandwidth; Vultr leads disk IOPS/I/O per third-party tests and global region count; Linode leads included transfer (8 TB at 16 GB) and support inclusion; DO leads tooling/docs/ecosystem and Premium NVMe tiers (420k-ish IOPS at premium) at highest price.
- DO-vs-Linode at same price ($48/mo, 4 vCPU/8 GB): Linode has 2x CPU events/sec, 3.6x seq write MB/s, faster network; DO weaker in every raw metric. DO's premium pays for platform, not hardware.

### Gaps
- Direct DO-vs-Vultr dedicated-CPU comparison at identical tiers was not found in an independent benchmark. Most sources compare shared tiers only. VPSBenchmarks has plan pages but no single normalized ratio table.

## ARM vs x86 price-performance comparison

### Takeaway
ARM (Hetzner Ampere Altra) is 30-40% cheaper per vCPU/RAM than equivalent Hetzner AMD x86 and delivers comparable multi-thread performance at lower cost; x86 retains single-thread advantage (Geekbench 6 ~1,650 vs ~1,070) and broader software compatibility. For parallel/cloud-native workloads ARM wins per dollar; for high single-thread/burst workloads x86 wins. Vultr dropped all ARM plans as of 2026; ARM availability is concentrated at Hetzner/Oracle/Netcup/Oracle Cloud.

### Cited Findings
- Hetzner ARM CAX31 (4 vCPU Ampere Altra, 8 GB, 80 GB) €11.99/mo → rises to €15.99/mo from April 2026 vs CPX31 (4 vCPU AMD EPYC Genoa, 8 GB, 80 GB) €16.49 → €21.49 from April 2026. ARM is 27-35% cheaper at equivalent RAM/storage. — [bitdoze ARM vs x86 benchmark](https://www.bitdoze.com/arm-vs-x86-vps-server-benchmarks)
- Geekbench 6 single-thread: ARM ~1,070 vs x86 ~1,650 (Hetzner CPX31 AMD Genoa); WordPress throughput ARM ~7-10% slower, single-thread-bound. — [bitdoze](https://www.bitdoze.com/arm-vs-x86-vps-server-benchmarks)
- Hetzner ARM 2-core yabs: highest CPU and file I/O vs Intel/AMD 2-core on same host. Ampere Altra Max single-core ~2,050 (Geekbench-class) vs AMD EPYC 9654 ~2,650 vs Intel Granite Rapids ~3,100. — [Wappler community](https://community.wappler.io/t/the-new-arm64-servers-from-hetzner-are-so-powerful/50439), [Colobird ARM vs x86 2026](https://www.colobird.com/blogs/arm-vs-x86-dedicated-servers-2026)
- Colobird: ARM up to 40% better cost-per-core on cloud-native/parallel workloads; x86 leads single-thread legacy apps, memory-intensive, compatibility. AWS Graviton4 single-core ~2,380. — [Colobird 2026](https://www.colobird.com/blogs/arm-vs-x86-dedicated-servers-2026)
- Onidel: ARM 15-40% cost savings vs equivalent x86 VPS; hybrid approach recommended. — [Onidel benchmarks](https://onidel.com/blog/arm-vs-x86-vps-2025-benchmarks)
- VPSDEX ARM VPS guide 2026: Vultr's public pricing page no longer lists any ARM/Ampere plans as of Sept 2026; Cloud Compute is AMD/Intel only. — [VPSDEX ARM comparison](https://vpsdex.com/en/activity/arm-vps-comparison-guide-2026)
- Ampere Altra Max 80-128 cores per socket vs x86; density drives lower per-instance cost. — [VPSDEX](https://vpsdex.com/en/activity/arm-vps-comparison-guide-2026)
- LowEndTalk: "ARM systems perform just as well if not better... comparable to x86"; package-repo minor friction. — [LowEndTalk ARM vs x86](https://lowendtalk.com/discussion/194381/arm-vs-x86)

### Inferences
- ARM performance per dollar is strongest at Hetzner (CAX line); spread is limited: Oracle Cloud free ARM instances (4 vCPU/24 GB free tier) are an exceptional but region-limited value.
- Cost-per-core efficiency ~1.3-1.4x ARM; single-thread penalty ~20-40%. Decision rule: choose ARM for steady parallel/container workloads; x86 for burst/single-thread/db heavy.
- AWS Graviton (not cheap VPS) remains the ARM benchmark leader; Hetzner CAX line is the cheap-VPS ARM leader.

### Gaps
- No independent sysbench/fio comparison of Hetzner ARM vs x86 at 4 vCPU/8 GB with variance; bitdoze's test is single-run WordPress-oriented. Whether ARM enjoys the same low-variance isolation as Hetzner x86 shared plans is untested in cited sources.
- Oracle Cloud ARM free tier quota availability (capacity) issues are widely reported but not quantified with numbers here.

## Storage pricing: NVMe vs SSD vs HDD per GB per dollar

### Takeaway
On included/bandwidth-style storage, Contabo HDD lines and storage VPS lines (Fourplex/RackNerd annuals) reach ~50-200 GB per dollar/mo, ~10x NVMe developer-cloud block storage. NVMe (~$0.05-0.10/GB/mo extra) costs roughly 2x SSD block storage; HDD archives are ~10-20x cheaper per GB than NVMe. The right metric is IOPS-per-dollar, where NVMe with high cue depth wins (3728 MB/s seq on Hetzner NVMe vs IONOS 478 capped).

### Cited Findings
- Block storage monthly per-GB add-on pricing: Hetzner $0.05/GB/mo ($5/100 GB); DigitalOcean $0.10/GB/mo ($10/100 GB); Vultr $0.10/GB/mo; Linode $0.10/GB/mo; AWS EBS gp3 ~$0.08/GB/mo plus IOPS; Liquid Web cloud block storage $0.11/100 GB? ($11/100 GB/mo). — [AIMultiple onboarding section](https://aimultiple.com/vps-benchmark), [OVHcloud](https://us.ovhcloud.com/vps)
- Budget annual storage per dollar: Fourplex 1 vCore/1 GB/1 TB SATA HDD $5/mo = ~204.8 GB/$/mo; Storage Wars 1 vCore/1 GB/256 GB storage $12.88/yr ≈ $1.07/mo = 239 GB/$/mo. HostDare SSD0 1 vCPU/768 MB+768 MB/10 GB NVMe ~$1.62/mo. — [Chinese VPS roundup 2026](https://blog.naibabiji.com/bestvps)
- Contabo Cloud VPS 1 €4.50/mo: 100 GB NVMe = 22.2 GB/$ (incl 4 vCPU, 6 GB RAM). Contabo Storage VPS line: 400 GB+ SSD at similar price. Hetzner: 40 GB included NVMe at ~$6.55 = 6.1 GB/$. — [Contabo 2026 comparison](https://www.youtube.com/watch?v=-Rz5aVAKC0I), [LowEndTalk](https://lowendtalk.com/discussion/195477/hetzner-vs-netcup-vs-contabo-vps-for-webserver-cyberpanel)
- DigitalOcean: NVMe Premium Droplets from $7/mo (1 GB/1 vCPU/25 GB NVMe) = 3.57 GB/$; Storage-Optimized 16 GB/300 GB at $131/mo = 2.29 GB/$ (includes 4 TB transfer). — [DigitalOcean VPS hosting](https://www.digitalocean.com/solutions/vps-hosting)
- Capacity/$: Hetzner volumes $0.05/GB/mo => $0.60/GB/yr vs DO $1.20/GB/yr. NVMe add-on premium vs SSD block from budget providers ~2-3x per GB; HDD archive ≈1/10 of NVMe per GB. — derived.
- OVHcloud NVMe "up to 6x faster than standard SSD"; Local Zone VPS uses different storage. — [OVHcloud VPS](https://us.ovhcloud.com/vps)

### Inferences
- For pure capacity (backups, cold storage, media), HDD-based VPS (Fourplex/RackNerd/Contabo Storage) at ~$0.005/GB/mo is unbeatable; NVMe premium is justified only for IOPS-bound workloads (DBs, build caches).
- Contabo leads raw included storage per dollar among the "all-rounder" providers (100-400 GB base); Hetzner sells cheap additional NVMe volume if you outgrow the small 40 GB base.
- Block-storage pricing is more uniform ($0.05-$0.11/GB/mo) than included capacities, so capacity is determined largely by plan choice rather than vendor add-ons.

### Gaps
- No cited independent random-IOPS-per-dollar comparison for HDD vs SATA vs NVMe at matched price points; bitdoze's WordPress benchmarks are higher-level.

## Bandwidth overage costs - which provider is cheapest for high traffic?

### Takeaway
High-traffic cost winner order: OVHcloud (unlimited, capped port) ≈ Hetzner (20 TB included, cheap overage) > Contabo (32 TB/unlimited) > Linode ($0.005/GB) > DigitalOcean/Vultr ($0.01/GB). At egress above ~20 TB, DO/Vultr cost ~$100-200/extra-TB vs included on Hetzner/OVH — a 100x cost delta.

### Cited Findings
- Overages (per GB): DigitalOcean $0.01/GiB; Vultr $0.01/GB; Akamai/Linode $0.005/GB; Hetzner ~€1/TB beyond included; OVHcloud no overage (port cap instead: 500 Mbps-3 Gbps). — [LiberationTek](https://liberationtek.com/compare/vps-hosting-providers), [OVHcloud](https://us.ovhcloud.com/vps)
- Cost of 1 TB excess egress: DO $10.24; Vultr $10.00; Linode $5.00; Hetzner ~$1.09 (€1); OVHcloud $0. — derived from cited rates.
- Included transfer: Hetzner 20 TB (EU), Contabo 32 TB, OVHcloud unlimited, DO 1-6 TB by size, Vultr 1-5 TB, Linode 4-8 TB. — sources as above.
- Medium cited VPS deals: Hetzner 20 TB EU inclusion "saves $50-100/mo vs DigitalOcean/Vultr at similar tiers" for bandwidth-heavy apps. — [Medium VPS deals 2025/2026](https://medium.com/@fimber6/best-vps-deals-of-2025-1baeddb08e3d)
- OVHcloud APAC regions impose 1-4 TB quotas then 10 Mbps throttle; other regions unlimited with port caps. — [OVHcloud](https://us.ovhcloud.com/vps)
- LiberationTek includes 6-32 TB VPS with zero egress fees — useful as a niche alternative for static-heavy workloads. — [LiberationTek](https://liberationtek.com/compare/vps-hosting-providers)

### Inferences
- Break-even overage comparison: at Linode $0.005/GB, crossing Hetzner's 20 TB threshold costs ~$102.50 (20,480 GB × $0.005) — so Linode only wins vs Hetzner if you need under ~20 TB and prefer Linode's plan economics anyway. Above 20 TB, Hetzner/OVH are strictly cheaper.
- At DO/Vultr $0.01/GB, 20 TB of egress = ~$205 — 100x the per-TB cost of Hetzner overage. DO/Vultr are effectively only competitive for low-traffic (<1-5 TB) workloads.
- For very high egress (PB scale), OVHcloud's port-cap model (1-3 Gbps sustained, no metering) is the only cost-stable option among mainstream VPS.

### Gaps
- None of the cited benchmarks measure actual sustained throughput to end users per region; port speed (1 Gbps/10 Gbps) advertised differs from delivered throughput under peering/network congestion.

## Benchmark methodology differences (important caveats)

### Takeaway
Cross-provider PPD comparisons are not interchangeable: Raff's 2 vCPU/4 GB AlmaLinux with custom composite score, AIMultiple's 4 vCPU/8 GB sysbench/fio across 5 times of day with direct I/O, VPSBenchmarks' monthly trials with price-weighted grades, VPSMetrics' WordPress Geekbench composite, and VPSRated's enterprise single-instance tests all measure different things. Treat any single PPD number as methodology-bound, not universal.

### Cited Findings
- AIMultiple 2026 methodology: 4 vCPU/8 GB, Ubuntu 24.04, US East (when selectable), fresh provision, 5 benchmark sessions at different times of day (early morning through evening), medians reported, sysbench + fio (libaio, qd64, direct I/O bypassing page cache) + speedtest-cli; CPU std dev reported for variance; price-performance = CPU events/sec ÷ monthly price. — [AIMultiple methodology](https://aimultiple.com/vps-benchmark)
- Raff 2026: 4 GB RAM/2 vCPU/AlmaLinux 9.6; PPD = Overall Performance Score ÷ Monthly Price; includes Raff's own composite (CPU + memory + disk + network). — [Raff performance](https://rafftechnologies.com/performance)
- VPSBenchmarks: buys VPS as a customer, runs Geekbench + Fio + Iperf3 + web-server tests (response time, max req rate, stability/endurance) across several days; price-weighted grade bonus proportional to difference between $30 and monthly price; monthly rankings in 6 price bands; grades not price-adjusted unless "price weighted" toggled. — [VPSBenchmarks](https://www.vpsbenchmarks.com), [VPSBenchmarks FAQ](https://www.vpsbenchmarks.com/faq)
- VPSMetrics: WordPress benchmark (WPBench 0-10) + Geekbench single/multi + 4K mixed IOPS + combined IOPS + network download/upload/latency; composite "value" rating 0-10; units and test sizes vary (non-comparable across rows explicitly labeled). — [VPSMetrics](https://vpsmetrics.com/benchmarks)
- IVPSRated 2026 (AIMultiple-style enterprise framing): Geekbench 6 single/multi, 4K IOPS, network down/up at specific tiers (CCX23 etc.), per-provider. — [VPSRated](https://www.vpsrated.com/enterprise-high-performance-vps-benchmarks-2026)
- LowEndTalk / community: sysbench + yabs.sh informal scripts, often single-run, region-specific; frequently used for ARM-vs-x86 comparisons but no controlled baseline. — [LowEndTalk ARM vs x86](https://lowendtalk.com/discussion/194381/arm-vs-x86)

### Inferences
- Comparisons are valid only within the same benchmark: AIMultiple's 4 vCPU/8 GB sysbench comparisons are internally consistent (5 runs, median, time-of-day variation); cross-lab PPD numbers (Raff 3.36 vs AIMultiple-derived ratios) cannot be numerically compared.
- The most actionable cross-cutting metric is CPU variance (std dev) reported by AIMultiple — a strong (though indirect) signal of shared-vs-isolated provisioning that no other source quantifies as cleanly.
- Whenever quoting a PPD number, name the methodology and tier; avoid citing "IONOS 833 CPU events/$" without noting it is a shared 4 vCPU/8 GB US plan with 478 MB/s capped disk and ~963 Mbps capped upload.

### Gaps
- No independent (non-provider-vendor-affiliated) benchmark covers all eight named providers at matched tiers with a unified 2026 methodology; VPSBenchmarks comes closest but its price bands and single-plan-per-trial schedule produce fragmented data. Providers' self-published benches (Raff) are advocacy and should be treated as provider-attributed.
- Missing data: controlled ARM-vs-x86 at identical tier, Contabo disk IOPS with published fio methodology, Hetzner US-vs-EU cost differential (quoted EUR not converted), and real-world application-level (WordPress TTFB) per-dollar rankings at higher tiers.
