# Value VPS Hosting $5-20/month: Provider Comparison

## DigitalOcean Droplets: pricing tiers, specs, recent 2026 price changes

### Takeaway
DigitalOcean Basic (shared CPU) Bundled Plans are the only DO tiers inside $5-20: 512MiB/$4, 1GB/$6, 2GB-1vCPU/$12, 2GB-2vCPU/$18. No 2026 price hike; only a switch to per-second billing effective Jan 1 2026. DO is among the lowest spec-per-dollar in this band and its Premium variants mostly overshoot $20.

### Cited Findings
- Basic entry tiers: 512MiB/1vCPU/10GB/500GiB=$4; 1GiB/1vCPU/25GB/1TB=$6; 2GiB/1vCPU/50GB/2TB=$12; 2GiB/2vCPU/60GB/3TB=$18 - [DigitalOcean pricing](https://www.digitalocean.com/pricing/droplets)
- Premium (Intel/AMD) variants NVMe, $6-$12 at 1 vCPU / 1-2 GB - [DigitalOcean pricing](https://www.digitalocean.com/pricing/droplets)
- Per-second billing effective Jan 1 2026 (min 60s or $0.01); Bundled Plans keep monthly cap - [DigitalOcean pricing](https://www.digitalocean.com/pricing/droplets)
- Global regions incl. India, Singapore, Bangalore - [VPS comparison e.g. tech-insider.org](https://tech-insider.org/digitalocean-vs-vultr-vs-aws-lightsail-2026)
- Prices steady to Sep 2026; $4/512MB among few sub-$5, CPU older Intel Xeon, SSD not NVMe - [ServaRica compare](https://servarica.com/compare/); [StackFreeks DO 2026](https://stackfreeks.com/digitalocean-review-2026/)

### Inferences
- DO gives fewest resources per dollar (1GB/$6/25GB vs Hostinger 4GB/$6.49), so its value rests on availability, docs and ecosystem, not specs.
- Per-second billing helps short-lived/batch but does not change nominal prices.

### Gaps
- No first-hand DO benchmarks extracted at plan level from snippets.

## Vultr: pricing, specs, global coverage

### Takeaway
Vultr Regular Performance matches DO Basic in $5-$20 ($5-$20), but High Performance (1vCPU $6, 2vCPU $18) with newer AMD/Intel + NVMe is the better buy at 2-5TB bandwidth and 32-34 global regions - widest footprint in this set.

### Cited Findings
- Regular (older Intel+SSD): 1/1GB/25GB/1TB=$5; 1/2GB/55GB/2TB=$10; 2/2GB/65GB/3TB=$15; 2/4GB/80GB/3TB=$20; IPv6-only 0.5GB/$2.50; IPv4 0.5GB/$3.50 - [Vultr pricing](https://www.vultr.com/pricing)
- High Performance (newer+NVMe): 1/1GB/25GB/2TB=$6; 1/2GB/50GB/3TB=$12; 2/2GB/60GB/4TB=$18; 2/4GB/100GB/5TB=$24 - [Vultr pricing](https://www.vultr.com/pricing)
- 32-34 global DC regions - [Vultr review 2026](https://stackfreeks.com/vultr-review-2026/); [vpscomparehub](https://vpscomparehub.com/)
- HF NVMe jump $1-$4/mo "worth it" for DBs/WordPress - [Vultr review 2026](https://stackfreeks.com/vultr-review-2026/)
- 2vCPU@$20 "dramatically more powerful than DO at same price" - [Vultr vs DO 2026](https://vpschart.com/en/compare/vultr-vs-digitalocean/)
- Egress $0.01/GB overage - [Vultr pricing](https://www.vultr.com/pricing)

### Inferences
- Vultr leads on region breadth and clock speed, but regular $10-$20 tiers give only 1 vCPU for 2GB RAM; $5 plan only 1GB. Strength is geographic elasticity, not raw specs.

### Gaps
- No primary benchmark numbers; only third-party "~2.2x IOPS lead over DO" (directional).

## Linode (Akamai): pricing, specs, recent changes

### Takeaway
Linode is the priciest entry (Nanode 1GB $5, 2GB $12, 4GB $24-above ceiling) with non-pooled transfer and dedicated CPU from $36; fits $5-$20 only at Nanode/2GB. Strengths are Akamai edge (33 regions), low overage $0.005/GB, not cost.

### Cited Findings
- Nanode 1GB: 1/1GB/25GB/1TB=$5; 2GB: 1/2GB/50GB/2TB=$12; 4GB: 2/4GB/80GB/4TB=$24 - [SoftwareSift 2026](https://softwaresift.com/cloud-vps-pricing-comparison); [Pikkly 2026](https://pikkly.dev/vps/linode)
- Dedicated CPU from $36 (4GB/2vCPU), High Memory $60 - [Linode docs](https://techdocs.akamai.com/cloud-computing/docs/compute-instance-plan-types)
- 31-33 regions; Jakarta +20%, Sao Paulo +40% - [StackRates Oct 2026](https://stackrates.ai/hosting/akamai-linode/)
- Egress: 1TB then $0.005/GB (lowest overage), not pooled, no renewal split - [SoftwareSift](https://softwaresift.com/cloud-vps-pricing-comparison)
- ~$5 higher-tier hike at 2022 Akamai transition; 2026 steady - [Pikkly](https://pikkly.dev/vps/linode)

### Inferences
- Only competes via $5 Nanode and $12 Linode 2GB; weakest per-dollar among named six; appeal is low overage and Akamai CDN.

### Gaps
- No 2026 price events in sources; no benchmark specifics beyond "shared CPU".

## Hetzner Cloud mid-tier: CX33, CAX21, CCX series

### Takeaway
Hetzner was best price/performance in EU (CX33: 4vCPU/8GB/80GB NVMe/20TB ~EUR8.49/$10) until 2026 hikes (+30-40% Apr+Jun) and Oct-2026 unavailability of Cost-Optimized plans. CAX21 (4vCPU ARM/8GB) ~EUR10.49; CCX dedicated ~EUR8.60-15.99 and roughly doubled. Currently not reliably purchasable.

### Cited Findings
- Post Jun-15-2026: CX33 EUR8.49 (was 6.49); CAX21 EUR10.49; CX43 EUR16.49 - [Hetzner docs](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment); [agentdeals 2026](https://agentdeals.dev/hetzner-pricing-2026)
- CCX13 ~EUR8.60-15.99 location-dependent; CX +30-38%; CPX/CCX +113-175% - [agentdeals 2026](https://agentdeals.dev/hetzner-pricing-2026)
- Raised twice in 2026 (Apr 1 all, Jun 15 new); Singapore +20-40% - [Hetzner docs](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment); [costgoat](https://costgoat.com/pricing/hetzner)
- Cost-Optimized SKUs (CX23/33/43, CAX11/21/31/41) "not available" Oct 2026 - [agentdeals](https://agentdeals.dev/hetzner-pricing-2026); [Hetzner price page](https://www.hetzner.com/cloud/cost-optimized/)
- EU (Falkenstein/Nuremberg/Helsinki) cheapest; capacity past 20TB = EUR1/TB - [usehcm.com](https://usehcm.com/hetzner-pricing)
- Backups +20%; IPv6-only save EUR0.50-0.60; block storage ~$0.057-0.06/GB-mo - [usehcm CX33](https://usehcm.com/hetzner-pricing/cx33)

### Inferences
- Best per-dollar CPU/RAM on paper in EU, historically fastest, but late-2026 adoptability uncertain due to sold-out SKUs and 30-40% jumps; treat as threshold reference; verify availability.

### Gaps
- Exact post-doubling CCX13 monthly unclear (EUR8.60-15.99). No reliable mid-tier benchmark; VPSBenchmarks historically ranks Hetzner (CX22 ~$3.29 best-value historically) - [bestvpsmatch.com](https://bestvpsmatch.com/cheapest-vps-hosting).

## Contabo mid-tier: VPS M, L, XL

### Takeaway
Contabo has the best raw specs/dollar: VPS M (6vCPU/16GB/100GB NVMe/32TB/400Mbps $8.99), VPS L ($14.99: 8/30GB/200GB/600Mbps), VPS XL ($26.99: 10/60GB/400GB/1Gbps, above $20). Trade-offs: 32TB "unlimited" is fair-use capped at 200-1000 Mbps; 9 regions; slow support; over-sold nodes.

### Cited Findings
- VPS S: 4/8GB/50GB NVMe or 200GB SSD/$4.99 (200Mbps)
- VPS M: 6/16GB/100GB NVMe or 400GB SSD/$8.99 (400Mbps)
- VPS L: 8/30GB/200 NVMe or 800GB SSD/$14.99 (600Mbps)
- VPS XL: 10/60GB/400 NVMe or 1.6TB/$26.99 (1Gbps)
- Cloud VPS 4/6/8: $6.16-$15.67/mo; VPS Plus +NVMe/EPYC ~$10-$15/mo
- Held steady through Sep 2026 (ServaRica raised) - [ServaRica compare](https://servarica.com/compare/)
- 9 regions globally - [getdeploying.com](https://getdeploying.com/contabo-vs-gpuhub)
- VDS line: dedicated EPYC at $39-$94+ - [Contabo VDS](https://contabo.com/en-us/vds/vds-l)

### Inferences
- Obvious pick for RAM/CPU-heavy but network-tolerant workloads (background, DB, cache). Caveats: slow support, shared nodes, port caps 200-600 Mbps despite "unlimited".

### Gaps
- No measured IOPS/Geekbench figures; review cites oversell risk with no hard benchmark.

## Hostinger KVM VPS: pricing and specs

### Takeaway
Hostinger has the strongest headline budget offer - KVM 1 (1vCPU/4GB/50GB NVMe/4TB ~$6.49/mo) and KVM 2 (2/8GB/100GB/8TB ~$8.79/mo), AMD EPYC, 4TB+ bandwidth, 8-9 country locations. But prices are promotional 24-month; renewals roughly double ($11.99/$14.99/$28.99/$49.99 for KVM 1/2/4/8), the decisive variable.

### Cited Findings
- KVM 1 1/4/50/4TB=$6.49 promo, renews $11.99
- KVM 2 2/8/100/8TB=$8.79, renews $14.99
- KVM 4 4/16/200/16TB=$12.99, renews $28.99
- KVM 8 8/32/400/32TB=$25.99, renews $49.99
- AMD EPYC, DDR4 ECC, NVMe, weekly backups, 8+ locations
- Bandwidth 4-32TB (per [AWS vs Hostinger 2026](https://getdeploying.com/aws-vs-hostinger))
- VPSBenchmarks: KVM2=69, KVM1=44, KVM4=44/39, KVM8=60 - [VPSBenchmarks Hostinger](https://www.vpsbenchmarks.com/hosters/hostinger)
- Some promos as low as $4.99/$8.99 - [desking 2026 review](https://desking.app/review/hostinger-vps)

### Inferences
- Best value only if committing to 24-month promo (~$156-$211 upfront) and accepting doubled renewal; over 4 years ~1.5x headline. 3-month trials still competitive. Renewal sticker shock is hidden cost.
- Value sweet spot KVM 1/2 (KVM 4 grade drops to 39-44).

### Gaps
- Per-region bandwidth varies (some markets historically 1TB); verify at checkout. KVM4 renewal uplift ~2.2x-largest in this cohort.

## Which providers offer the best vCPU/RAM/storage per dollar?

### Takeaway
By raw spec density, Contabo (VPS M 6/16GB/$8.99) and Hostinger (KVM 2 2/8GB/$8.79) dominate equal-priced DO/Vultr/Linode; Hetzner CX33 close on 4/8GB/~$10 (if available); OVH VPS-1 (4/8GB/~$6.46 unmetered) anchors low end; RackNerd annuals break per-unit floor ($1.83/mo, 1/1/20GB) but require 12-month prepay.

### Cited Findings
- Contabo VPS S $4.99 (4/8/50-200), M $8.99 (6/16/100-400NVMe), L $14.99 (8/30/200) - [hostingpromax 2026](https://hostingpromax.com/contabo-review-2026)
- Hetzner CX33 4/8/80/~$10 - [Hetzner cloud](https://www.hetzner.com/european-cloud/)
- Vultr Regular $10 (1/2/55/2TB) vs High Perf $12 (1/2/50/3TB) - [Vultr pricing](https://www.vultr.com/pricing)
- DO Basic $6 (1/1/25), $12 (1/2/50), $18 (2/2/60) - [DO pricing](https://www.digitalocean.com/pricing/droplets)
- Linode $5 (1/1/25/1TB), $12 (1/2/50/2TB) - [SoftwareSift](https://softwaresift.com/cloud-vps-pricing-comparison)
- OVH VPS-1 4/8/75/unlimited EU ~$6.46, raised ~30% in Mar-2026 - [learnwithhasan 2026](https://learnwithhasan.com/vps-providers/ovh-vps)
- RackNerd 1GB: 1/1/20/3TB for $21.99/yr (~$1.83/mo) - [RackNerd specials](https://www.racknerd.com/specials/)
- Scaleway DEV1-S 2/2/200 ~EUR6.55 - [Scaleway pricing](https://www.scaleway.com/en/pricing/virtual-instances-pricing)

### Inferences
- Ranking of named six: 1) Contabo VPS M ($8.99-$14.99), 2) Hostinger KVM 2 ($8.79), 3) OVH VPS-1 (~$6), 4) Hetzner CX33 (~$10), 5) Vultr High Perf ($12), trailing DO/Linode. Density comes with port-cap and renewal caveats respectively.

### Gaps
- No standardized cross-provider per-dollar metric; Pikkly normalizes $/GB RAM & $/vCPU across 8 providers only.

## Performance benchmarks (CPU, disk I/O, network) per dollar

### Takeaway
VPSBenchmarks names cheap/lesser hosts as top measured performers (quicksrv "Best VPS 2026 under $8", Alwyzon under $15, TakeHost.Biz DE 8GB under $25) - not the named mainstream six. Among mainstream, Hostinger KVM2 best referenced (69); Vultr HF ~2.2x IOPS claim over DO; Hetzner fastest in EU; Contabo underrepresented. Raw specs != benchmarks.

### Cited Findings
- VPSBenchmarks "Best VPS 2026 under $8": 1st quicksrv (66), 2nd Bluehost, 3rd ARPHost; under $15: 1st Alwyzon (68), 2nd Evolution Host, 3rd Bluehost; under $25: 1st TakeHost DE 8GB (80), 2nd Alwyzon, 3rd Hostinger KVM8 - [VPSBenchmarks 2026](https://www.vpsbenchmarks.com/best_vps/2026)
- Best Value (price-weighted): Aug/Sep 2026 covers 22-29 providers incl DO/Vultr/Contabo/Hostinger/Hetzner - [VPSBenchmarks Best Value Aug 2026](https://www.vpsbenchmarks.com/best_vps/august_2026/value)
- Vultr HF NVMe ~2.2x IOPS over DO at 2 vCPU/4GB - [tech-insider 2026](https://tech-insider.org/digitalocean-vs-vultr-vs-aws-lightsail-2026)
- Hostinger: KVM2=69, KVM1=44, KVM4=44/39, KVM8=60 - [VPSBenchmarks Hostinger](https://www.vpsbenchmarks.com/hosters/hostinger)
- Vultr HP described "dramatically more powerful than DO" at $20 tier - [StackFreeks 2026](https://stackfreeks.com/vultr-review-2026/); [Vultr vs DO](https://vpschart.com/en/compare/vultr-vs-digitalocean/)
- Hetzner CX/CAX historically fastest single-vCPU-per-dollar in EU; VPSBenchmarks trials high CPU - [VPSBenchmarks compare Hetzner vs Scaleway](https://www.vpsbenchmarks.com/compare/hetzner_vs_scaleway)

### Inferences
- Among six named mainstream providers, Hostinger KVM 2 (69) is best measured value; Vultr claim directional. Pocket-budget buyers should consider quicksrv/Alwyzon/TakeHost below mainstream radars.

### Gaps
- No complete multi-provider benchmark-per-dollar chart; value-weighted grades exist but exact CPU/disk/net K-per-$ not extractable from snippets.

## Unmetered bandwidth providers in this range

### Takeaway
Yes, distinct cases. "Real" unmetered (port-capped): OVH VPS (~$6.46, unlimited EU, 1Gbps), Contabo (32TB fair-use, 200Mbps-1Gbps), Virtarix ($4.40-$19.60/mo), Ultahost ($5.50-$15 managed), DreamHost ($10/mo), ewighost/ServerOptima. Hetzner 20TB (effectively unmetered). DO/Vultr/Linode metered ($0.01-$0.005/GB overage).

### Cited Findings
- OVH VPS-1: 4/8/75/unlimited EU, up to 400Mbps, ~$6.46/mo - [learnwithhasan 2026](https://learnwithhasan.com/vps-providers/ovh-vps)
- Contabo: "Unlimited Traffic*" 200Mbps-1Gbps ports, 32TB typical - [Contabo pricing](https://contabo.com/en-us/pricing/) (via HostingPromax)
- Virtarix: unmetered from $4.40/mo to $19.60/mo - [Virtarix](https://virtarix.com/vps/offshore-vps)
- Ultahost: unmetered $5.50-$20.69/mo managed - [Ultahost](https://ultahost.com/vps-hosting/)
- DreamHost: unmetered from $10/mo; 10TB=$0 vs $90 (DO)/$810 (AWS) - [DreamHost](https://www.dreamhost.com/hosting/vps/)
- Server Optima: 256Mbps-2Gbps, $25-$55/mo - [ServerOptima](https://www.serveroptima.com/vps)
- ewighost Singapore: $19/mo (2/2/14GB) - [ewighost](https://ewighost.com/unmetered-vps/singapore)
- Hetzner: 20TB then EUR1/TB - [usehcm CX33](https://usehcm.com/hetzner-pricing/cx33)
- Scaleway: "No egress" within fair use, 100-500 Mbps capped - [whichdevtool](https://whichdevtool.com/tools/scaleway-instances/)
- Metered overages: DO $0.01, Vultr $0.01, Linode $0.005/GB; entries 0.5-5TB
- Unmetered is rate-capped: 1Gbps ~330TB/mo theoretical, 256Mbps ~83TB - [vps.us](https://vps.us/blog/unmetered-vps-servers-a-bandwidth-ready-solution/)

### Inferences
- OVH VPS-1 (~$6.46) and Contabo (32TB) best $/TB; Hetzner (20TB) best perf/$ in EU. Vultr/DO/Linode costly past 2TB/mo. Port speeds determine true unmetered capacity, not labels.

### Gaps
- Contabo fair-use enforcement not quantified; only Hetzner publishes EUR1/TB overage; Virtarix/Ultahost/DreamHost "unmetered" claims unverified beyond marketing.

## Other notable providers (Scaleway, OVH, RackNerd)

### Takeaway
Three others matter: Scaleway (STARDUST1-S ~EUR0.43 and DEV1-S ~EUR6.55 but +IPv4/storage, only 3 regions), OVH VPS-1 (~$6.46 unmetered EU, Mar-2026 +30% hike), RackNerd (annual prepay, lowest $/mo with no SLA).

### Cited Findings
- Scaleway: STARDUST 1/1/100 ~EUR0.10-0.43; DEV1-S 2/2/200 ~EUR6.42-6.55; DEV1-M 3/4/300 ~EUR14.45; PAR-1/AMS-1/WAW-1 only; IPv4 +EUR0.004/hr (~EUR2.90/mo), storage extra - [Scaleway pricing](https://www.scaleway.com/en/pricing/virtual-instances-pricing); [whichdevtool 2026](https://whichdevtool.com/tools/scaleway-instances/)
- OVH VPS-1 4/8/75 ~400Mbps unlimited EU at $4.54-$6.46 (Aug 2026); Mar 2026 base hike +30% from ~$4.90; 14-day EU cooling-off; anti-DDoS - [learnwithhasan 2026](https://learnwithhasan.com/vps-providers/ovh-vps); [getdeploying](https://getdeploying.com/ovh-vs-zeabur)
- VPS-2/3/4: 4/8GB/$10 and 8/24GB/$19.97 (US) - [learnwithhasan 2026](https://learnwithhasan.com/vps-providers/ovh-vps)
- RackNerd: 1GB 1/1/20/3TB/1Gbps $21.99/yr; 2GB $35.99/yr; 8GB $119.99/yr - [RackNerd specials](https://www.racknerd.com/specials/)
- OVH footprint 15+ countries (US/EU/AU/Asia/LATAM) second only to Vultr - [OVH vs Zeabur](https://getdeploying.com/ovh-vs-zeabur)

### Inferences
- Scaleway cheapest ARM/x86 entry but storage+IPv4 push totals above $9-$12. OVH VPS-1 still sub-$7 with unmetered EU after hikes. RackNerd cheapest $/mo but forfeits performance guarantees/SLA.

### Gaps
- Scaleway STARDUST ranges EUR0.10-0.43 by source (regional/variant unresolved). OVH pricing drifted $6.46->$4.54 over Aug-Sep 2026 (verify live).

---

Sources (primary pages consulted):
- https://www.digitalocean.com/pricing/droplets
- https://www.vultr.com/pricing
- https://www.hetzner.com/european-cloud/; https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment
- https://www.akamai.com/cloud/pricing; https://techdocs.akamai.com/cloud-computing/docs/compute-instance-plan-types
- https://contabo.com/en-us/pricing/
- https://www.hostinger.com/vps-hosting
- https://www.scaleway.com/en/pricing/virtual-instances-pricing
- https://learnwithhasan.com/vps-providers/ovh-vps; https://getdeploying.com/ovh-vs-zeabur
- https://www.vpsbenchmarks.com/best_vps/2026; https://www.vpsbenchmarks.com/hosters/hostinger
- https://servarica.com/compare/
- https://stackfreeks.com/{digitalocean,vultr}-review-2026
- https://softwaresift.com/cloud-vps-pricing-comparison
- https://agentdeals.dev/hetzner-pricing-2026; https://comparethestack.com/providers/vultr
- https://getdeploying.com/ comparisons
- https://pikkly.dev/vps/; https://bestvpsmatch.com/cheapest-vps-hosting
