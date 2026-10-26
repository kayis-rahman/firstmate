# Hidden Costs, Gotchas, and Fine Print of Cheap VPS Providers (2026)

## 1. Overview of the Hidden-Cost Landscape

### Takeaway
The stated monthly price of a cheap VPS is rarely the actual cost, once overage rates, backups, extra IPs, license fees, and fair-use throttling are added. Several budget providers bundle essentials that others charge extra for, and renewal pricing near-doubles some headline plans.

### Cited Findings
- DigitalOcean charges $0.01/GB bandwidth overage beyond the included allowance, while AWS Lightsail charges $0.09/GB; at 10 TB/month that is $90 vs $810 — [DreamHost comparison page](https://www.dreamhost.com/hosting/vps/).
- Linode/Akamai overage is $0.005/GB and Vultr's is $0.01/GB; Hetzner charges extra only above 20 TB included (EU) — [DreamHost comparison page](https://www.dreamhost.com/hosting/vps/); [Experte Hetzner review](https://www.experte.com/server/hetzner).
- Contabo offers unlimited traffic with no per-GB overage billing, applying only a fair-use policy — [Contabo blog](https://contabo.com/blog/a-comprehensive-guide-to-cloud-server-pricing).
- "Unmetered" plans are typically speed-capped (100 Mbps or 1 Gbps); at 100 Mbps the practical monthly transfer is well below the theoretical ~32 TB — [affordablevpsserver.com](https://affordablevpsserver.com/blog/vps-bandwidth-limits-explained-what-budget-hosts-dont-tell-you/).
- Vultr bills additional bandwidth at $10/TB beyond the shared account pool — [is*hosting comparison](https://blog.ishosting.com/en/vultr-alternative).
- ExtraVM overage is $1.50/mo per 1 TB (New Jersey is $3.00/mo per 1 TB) — [ExtraVM policy page](https://www.extravm.com/billing/knowledgebase/129/VPS-Bandwidth-Policy-and-Overages.html).
- Webdock includes free snapshots (5 slots), dedicated IPv4 and no transfer fees; a "typical budget host" charges €5-10/mo for snapshots and €3+/mo for IPv4 — [Webdock pricing page](https://webdock.io/cheap-vps-hosting).

### Inferences
- The effective cost gap between providers widens dramatically under high-bandwidth workloads; Hetzner/OVH-style generous transfer is the main value driver, not VPS spec.
- A provider advertising "unlimited bandwidth" still constrains egress via port speed since unmetered isn't infinite speed.

### Gaps
- No unified, authoritative comparison of overage rates across all cheap providers beyond the ones cited; some small-host rates are only in their ToS.

## 2. Bandwidth Overage & Transfer Caps

### Takeaway
Most metered providers charge $0.005-$0.01/GB beyond included allowances, compounding into hundreds of dollars at scale; Hetzner (~20 TB/mo included in EU), OVH (unlimited in most regions), and Contabo (fair-use, no overage) are exceptions. Cheap providers also throttle after undisclosed "fair use" thresholds.

### Cited Findings
- ExtraVM, OVH, and Contabo do not bill per-GB overage in any ordinary sense; OVH excludes Asia-Pacific from its unlimited VPS traffic — [OVHcloud Cloud VPS page](https://us.ovhcloud.com/vps/vps-cloud).
- OVHcloud VPS traffic is unlimited in all regions except Asia-Pacific — [OVHcloud](https://us.ovhcloud.com/vps/vps-cloud).
- Hostinger VPS throttles speed to 10 Mbps (or 5 Mbps per an alternate doc) for the remainder of the month after hitting the monthly cap — [Build MVP Fast](https://www.buildmvpfast.com/blog/hostinger-vps-production-gotchas-cpu-throttling-bandwidth-2026).
- RackNerd support response time is typically 12-24 hours via ticket — [VPSTier](https://vpstier.com/blog/cheap-vps-local-llm-inference-2026).

### Inferences
- Unknown caps ("fair use" without numbers) are real risk, since enforcement is at provider discretion.

### Gaps
- Specific undisclosed per-server thresholds (e.g., Hostinger's internal caps) are not published.

## 3. Backup & Snapshot Pricing

### Takeaway
Backups and snapshots are the single most common add-on that converts a cheap VPS into a costlier one: DigitalOcean, Vultr and Linode charge 20% of server price for automated backups and ~$0.05-$0.06/GB for snapshots; Hetzner automated backups are 20% of server price (CX22 ≈ €0.92/mo, refreshing simple fixed rate); Contabo auto-backup varies; cPanel-style backup licenses are separate. OVH snapshot/backup is an add-on.

### Cited Findings
- DigitalOcean snapshots $0.06/GB/mo; backups 20-30% of droplet price weekly/daily — [oss cost calc guide](https://osscostcalc.com/guides/hetzner-vs-digitalocean-vs-linode-2026).
- Hetzner snapshots €0.0119/GB/mo; automated backups 20% of server price (€4.59 CX22 ≈ €0.92/mo) — [oss cost calc guide](https://osscostcalc.com/guides/hetzner-vs-digitalocean-vs-linode-2026).
- Vultr snapshots $0.05/GB, backups +20%, DDoS protection $10/mo — [saaskly UK VPS comparison](https://saaskly.com/comparisons/best-vps-cloud-hosting-2026).
- Linode backups: flat per-plan fee (~$2/mo Nanode, ~$5/mo 4 GB plan) — [oss cost calc guide](https://osscostcalc.com/guides/hetzner-vs-digitalocean-vs-linode-2026).
- OVHcloud automated VPS backup: optional, snapshots manual and auto-deleted after restore — [OVHcloud VPS options](https://www.ovhcloud.com/en/vps/options/); [OVHcloud VPS backup](https://www.ovhcloud.com/en/vps/vps-backup/).
- Contabo Auto Backup is an add-on (daily off-server, 10-day retention), separate from bundled 3 snapshots — [Contabo Auto Backup page](https://contabo.com/en/auto-backup/).
- Webdock includes 5 free snapshot slots (typical budget host charges €5-10/mo) — [Webdock pricing](https://webdock.io/cheap-vps-hosting).

### Inferences
- Backup costs add roughly 20–30% to the effective monthly bill on any metered hyperscaler-style VPS and are not shown in the headline price.

### Gaps
- Specific retention windows and per-GB rates are plan-dependent; some small hosts' snapshot pricing is buried in billing add-ons pages.

## 4. IPv4 Address Costs

### Takeaway
IPv4 scarcity has turned IP addresses into a recurring surcharge: Hetzner charges €0.50/mo per primary IPv4 and €0.60/mo for unassigned IPv4s (IPv6 free); Scaleway adds ~€3.65/mo for IPv4; Krystal £2/mo; many cheap hosts include one IPv4 in the base price, and "IPv6 only" tiers appear below ~$0.50 in some regions to keep price minimal.

### Cited Findings
- Hetzner primary IPv4 €0.50/mo (assigned) / €0.60/mo (unassigned); IPv6 free — [oss cost calc guide](https://osscostcalc.com/guides/hetzner-vs-digitalocean-vs-linode-2026).
- Scaleway IPv4 surcharge €3.65/mo; Krystal £2/mo; others include IPv4 free — [saaskly UK VPS comparison](https://saaskly.com/comparisons/best-vps-cloud-hosting-2026).
- Akamai (Linode) cheapest plan with a public IPv4 is Nanode $5/mo; Hetzner CX11 IPv6-only saves €0.50/mo — [StackRates Linode pricing](https://stackrates.ai/hosting/akamai-linode/); [Hetzner European Cloud](https://www.hetzner.com/european-cloud/).
- Hosters no longer give IPv4 by default for the cheapest tiers in noded.cloud's and some others' offerings — noted alongside Hetzner's NVMe tiers.

### Inferences
- IP cost realism: adds roughly $0.50–$3.65/mo unless using IPv6-only (cheap) tiers, which limits use cases.

### Gaps
- Full comparison of IPv4 fees across small budget hosts (RackNerd, DediRock, VirMach, Hostens) not found in primary sources; included informally as part of "unlimited" bundles.

## 5. Uptime / SLA Realities on Cheap Tiers

### Takeaway
Most budget VPS SLAs advertise 99.9% but compensate in account credits only (capped at 100% of monthly fee), exclude scheduled maintenance, force majeure and upstream failures, and require claims within deadlines; Incognito VPS is a rare exception that auto-applies credits. The effective recovery value is a token amount (a 99.9% miss on a $5 plan might be pennies). Vultr is cited as 100% network/host-node SLA with 2× credit compensation on paper, the highest stated SLA in its comparison.

### Cited Findings
- A 99.9% SLA permits 43.8 minutes/month or 8.76 hours/year of downtime, 99.95% 21.9 min/mo, 99.99% 4.4 min/mo — [Tencent Cloud guide](https://www.tencentcloud.com/techpedia/145478); [ApexVPS uptime guide](https://apex-vps.com/blog/uptime-sla-guide.html).
- Many SLAs exclude scheduled maintenance, force majeure, upstream failures, and customer misuse; credits are capped at the monthly fee and are the sole and exclusive remedy — [OVH SLA doc](https://us.ovhcloud.com/legal/sla/vps/); [OVH contract appendix](https://storage.gra.cloud.ovh.net/v1/AUTH_325716a587c64897acbef9a4a4726e38/contracts/7824b7f-Conditions_Particulieres_VPS-WE-4.1.pdf).
- OVH VPS STARTER tier credit starts at 10% (99-99.5% availability) up to 50% below 99%; higher tiers differ — [OVH contracts](https://storage.gra.cloud.ovh.net/.../2b20f2c-Conditions_Particulieres_VPS-WE-4.0.pdf).
- VPSNET compensates 5% (VPS) / 10% (Cloud VPS) per hour of downtime, capped at 100% monthly fee, account-balance only — [VPSNET SLA](https://www.vpsnet.com/en/information/sla).
- Incognito VPS auto-applies credits without a claim (10% below 99.9%, 25% below 99.5%, 50% below 99%, 100% below 95%) — [Incognito SLA](https://www.incognitovps.com/legal/sla).
- Vultr states 100% network and host-node SLA with 2× account-credit compensation (highest on-paper SLA in tested comparison) — [vps-mart best VPS 2026](https://www.vps-mart.com/blog/best-vps-provider-2026).
- Many budget hosts publish 99.9% SLA, tested real-world: Contabo 99.996% (claimed, own hardware), Cloudzy 99.95%, VPSMart 99.9% — [vps-mart 2026](https://www.vps-mart.com/blog/best-vps-provider-2026).
- Xervera guarantees 99.982% with auto-credit — [Xervera SLA](https://xervera.net/sla).

### Inferences
- A 99.9% SLA is essentially a marketing line, since credits are token-based and exclude most post-cause scenarios; only high-tier enterprise SLAs with real remedies exist and they are not in the cheap segment.

### Gaps
- Real measured uptime of the budget hosts (RackNerd, DediRock, GreenCloud) is not in primary sources; LowEndTalk anecdotes exist but are mixed and provider-specific.

## 6. Account Suspension & ToS Risks

### Takeaway
Cheap VPS hosts broadly prohibit crypto mining and sustained high CPU load, suspend on abuse complaints without refund, and the cheapest hosts terminate whole accounts (not just the affected server) per user reports (GreenCloud dispute on LowEndTalk, 2026). Data retention windows after suspension range 14 days (FxSVPS) to 30 days; refunds on prepaid terms are rarely given.

### Cited Findings
- Vultr explicitly prohibits CPU/GPU cryptocurrency mining in its AUP, with immediate suspension or termination possible and crypto-paid funds non-refundable (only spendable on Vultr) — [Gate News on Vultr](https://www.gate.com/news/detail/vultr-prohibits-crypto-mining-on-vps-servers-21253076).
- Most general-purpose VPS hosts prohibit mining without pre-approval; HostArmada likewise prohibits it in practice — [Hostadvice crypto VPS guide 2026](https://gb.hostadvice.com/vps/mining).
- FxSVPS: mining prohibited without exception, VPS suspended (powered off, network removed) with data retained 14 days then deleted, refunds not given; trading CPU usage is counted differently (only trading platforms) — [FxSVPS AUP](https://www.fxsvps.com/acceptable-use-policy/).
- GreenCloud user report (LowEndTalk, Oct 2026): account terminated permanently despite requesting remediation, full fleet of 8 servers taken down, no ToS provision cited publicly — [LowEndTalk thread](https://lowendtalk.com/discussion/comment/4878295).
- GhostVPS and many hosts: immediate suspension without notice allowed in serious abuse/unlawful-activity cases — [GhostVPS ToS](https://ghostvps.com/terms-of-services/).
- Pakistan-hosted AUP charges for port 25 policy unclear (Ultahost), blocks "excessive" CPU on fair-use/shared plans requiring dedicated CPU plan — [Ultahost review 2026](https://vkttech.com/ultahost-vps-review-2026-worth-it-for-email-senders/); [CloudVPS.pk AUP](https://cloudvps.pk/aup).
- Cloud VPS: sustained CPU >85% (Advinservers) / 80% (Wasabi) for 2-3 consecutive hours triggers auto-cap; IOPS artificially limited 1024-10000 in shared/cheap tiers; IO throttling applies to the system disk on many — [Advinservers FUP](https://docs.advinservers.com/policies/fair-use); [Wasabi FUP](https://wasabihosting.com/legal/fair-use); [Cherry Servers FUP](https://www.cherryservers.com/legal/virtual-server-fair-usage-policy); Reddit r/VPS IO throttling thread.
- Hostinger enforces undisclosed "fair use" CPU caps even on VPS; users report VMs being shut down for 75%+ CPU usage over "a few" hours, with only a small number of manual "CPU resets" per week — [Reddit r/Hostinger](https://www.reddit.com/r/Hostinger/comments/1q8vx5j/hostinger_is_limiting_the_resources_of_my_vps_and/); [BuildMVPFast](https://www.buildmvpfast.com/blog/hostinger-vps-production-gotchas-cpu-throttling-bandwidth-2026).
- Reddit report: Hostinger hard-caps CPU at host level such that SSH/Docker daemon stop answering when throttled — [r/selfhosted](https://www.reddit.com/r/selfhosted/comments/1u35vi8/if_youre_putting_production_on_a_hostinger_vps).

### Inferences
- "Fair use" thresholds that are undisclosed or published as high percentages only after reading ToS mean cheapest hosts convert into trouble more often under sustained workloads, especially crypto, AI inference, video encoding/scraper jobs.

### Gaps
- Exact reset/fraction limits at Hostinger and other hosts; terms are inconsistent and rarely granular in public docs.

## 7. Signup Verification / KYC Requirements

### Takeaway
Mainstream cheap providers require email + real-name-ish details and a credit card (which carries its own KYC, 3DS), while crypto-only/no-KYC providers (Echelon, bithost, Privex, FlokiNET, AnubizHost, NovaVPS) allow email-only signup with crypto payment. Identity requests at higher scale or flagged accounts can still be triggered (ToS clauses reserve the right to demand ID later).

### Cited Findings
- Tier 1 (mainstream): email, full name, card/PayPal — legal identity links through payment data; no government ID required at signup at most mainstream hosts — [Servury guide](https://servury.com/blog/no-kyc-vps-what-it-is-why-it-matters-and-where-to-get-one).
- Humble providers reserve the right (in ToS) to request ID verification later; EU/GDPR requires declaring processing purposes — [VMHeaven no-KYC guide](https://vmheaven.io/blog/guides/no-kyc-vps).
- Echelon: email-only signup, 42 assets (BTC, XMR, USDT etc.), 42 cities, NVMe from €1.90/mo — [Echelon VPS](https://www.echelonvps.com/).
- bithost: email-only signup since 2014, crypto prepaid balance, no card on file — [bithost](https://bithost.io/anonymous-vps).
- No-KYC does not equal "no AUP": providers still retain abuse/close accounts if terms break — [vpscore guide](https://www.vpscore.net/articles/no-kyc-vps-anonymous-hosting).
- Privex: name and email required, crypto-only payment, no government ID; published transparency reports — [Servury profile](https://servury.com/blog/no-kyc-vps-what-it-is-why-it-matters-and-where-to-get-one).
- NovaVPS: email-only or email + 12-char password, Monero supported, token-only — [NovaVPS list 2026](https://novavps.io/best-no-kyc-vps-2026).

### Inferences
- Cheap VPS hosts often verify less at signup (Echelon, bithost) but retain zero-fraud-tolerance on later abuse; mainstream provider's 3DS/card KYC adds friction but rarely blocks legitimate signups.

### Gaps
- Exact verification thresholds (when hosts demand ID) and which hosts do so on first provisioning vs delayed request, varies and is not fully documented publicly.

## 8. Renewal Price Increases (Intro vs Renewal)

### Takeaway
Introductory pricing often applies only to the longest prepayment term, and rebuild pricing can jump 25-100%+ at renewal; the biggest offenders are Hostinger (shared; VPS terms more stable) and IONOS (intro price lasts ~3 months of a 1-year term, then 2-3× up), plus A2 Hosting (3-year $6.49 → $19) and GoDaddy (36-month $647.64). IONOS/hetzner aside: Hetzner raised prices up to 37% in April 2026 due to DRAM/NAND cost increases. SSDNodes renews +26% ($5.50 → $6.92). Contabo often shows no separate renewal rate; Hostinger VPS renews at same signed-up price (unlike shared hosting).

### Cited Findings
- SSDNodes VPS renews +26% ($5.50 → $6.92/mo) — [DohoHub SSDNodes](https://dohohub.com/providers/ssdnodes).
- Liquid Web Managed VPS 4GB doubles at renewal (+100%, $36 → $72) — [Medium VPS pricing index](https://medium.com/@vpshostingradar/a-100-price-hike-that-costs-you-72-why-intro-length-beats-the-renewal-percentage-b99d25b12adc).
- IONOS VPS: intro price applies only first 3 months of 1-year term; regular price roughly 2-3× (VPS XL+: $6 → $21/mo) — [whichdevtool guide](https://whichdevtool.com/tools/ionos-vps/) and [IONOS hostingcriteria](https://hostingcriteria.com/hosting/vps/ionos).
- A2 Hosting $6.49 → $19 (72%+); GoDaddy 36-month $647.64; Hetzner priced 20 of 24 alternatives cheaper per month at cheapest term — [dev.to hostingsift](https://dev.to/hostingsift/is-hetzner-still-the-cheapest-vps-we-priced-24-alternatives-october-2026-271g).
- Hetzner raised some plans up to 37% in April 2026 from DRAM/NAND cost increases; CX11 rose from €3.29 to €3.79? (example, current ~€3.99) — [bitdoze Hetzner review](https://www.bitdoze.com/hetzner-cloud-review).
- Hostinger VPS: promotional pricing lower than renewal (20-40% less) for plans 1/2/4-yr terms? Note contradictory: separate source says VPS renewals are stable vs shared hosting — [Smarthostfinder clarification](https://smarthostfinder.com/hostinger-vps-pricing).
- Ultahost: headline price reflects longest term; renewal typically higher — [Ultahost review 2026](https://vkttech.com/ultahost-vps-review-2026-worth-it-for-email-senders/).
- Hostinger VPS price guide says intro applies to first billing term, renewal +20-40% depending on plan — [Smarthostfinder](https://smarthostfinder.com/hostinger-vps-pricing).

### Inferences
- Most "cheap" headline rates require 1-3 year prepayment and still renew higher; even long lock-ins eventually expire into 25-100% increase.

### Gaps
- Exact per-plan renewal tables are provider-specific and live; annual fee schedules should be verified at checkout (guide).

## 9. Support Quality on Budget Tiers

### Takeaway
Budget hosts commonly provide email/ticket support with 12-24 hour first response (RackNerd ~12-24h); managed/panel support is reserved for higher-priced tiers. OVH, IONOS offer 24/7 support on cheap tiers; cheap unmanaged VPS relies on documentation. Ionos free 24/7 includes experts; Scaleway free tier 8-hour initial response, 2-hour advanced, 30-minute business — basic/free support is slow.

### Cited Findings
- RackNerd: 12-24 hour ticket response — [VPSTier](https://vpstier.com/blog/cheap-vps-local-llm-inference-2026).
- AlphaVPS: 24/7 support, <15 min response, engineers — [AlphaVPS](https://alphavps.com/cheap-vps).
- ServerPoint (admin blog): budget providers typically email-only, multi-day response, outsourced call centers — [ServerPoint article](https://www.serverpoint.com/en/articles/cheap-vps-hosting-what-you-get/).
- Scaleway support tiers: Basic 8 hour IRT free, Advanced 2 hour, Business 30 min, Enterprise 15 min — [Scaleway docs](https://www.scaleway.com/en/docs/account/reference-content/understanding-support-plans/).
- OVH: free Standard support, Premium 2-hour first response target during working hours — [OVH support levels](https://www.ovhcloud.com/en/support-levels/premium).
- IONOS: 24/7 expert support even on cheap VPS+ plans — [IONOS free 24/7 claim](https://www.ionos.com/servers/vps).
- Contabo: 24/7 human support + 99.9% uptime; testimonials praise quick support — [Contabo testimonials](https://contabo.com/en-us/).

### Inferences
- Support speed/quality strongly correlates with price tier and management level, not location.

### Gaps
- No systematic audit of support response across small hosts (RackNerd, DediRock, Hostens); trustpilot averages are weak signal.

## 10. Data Center Locations and Latency Impact

### Takeaway
Location determines latency by geography: cheapest tiers are mostly US-only (Vultr 32 regions; Host4Fun 35; Contabo 10-11; cheap Asia options are limited/rare). A opposite-coast VPS adds 50-80 ms; US-East/West difference can be 60-80ms. Low-latency niches (FX, Turkey/MENA) require regional DCs which are typically $3-$20/mo not base cheapest tiers. Hetzner US pricing is higher vs EU, and US DC rollout remains limited vs competitors.

### Cited Findings
- US East vs West latency: opposite-coast adds 50-80 ms; sample provider A 5ms (East) vs 72ms (West), provider C 3ms (West) / 45ms (Central) — [virtualserversvps.com benchmarks](https://virtualserversvps.com/blog/your-ultimate-guide-to-cheap-vps-hosting-usa/).
- Cheap Turkey VPS: $3.44/mo, sub-5ms within Turkey, ~20ms Iran, ~28ms Germany, ~38ms Gulf — [TurkVPS](https://turkvps.cloud/).
- Host4Fun: $3/mo starting, all 35+ locations at same price (unusual), NVMe + 99.99% SLA, Windows free — [Host4Fun](https://www.host4fun.com/cheap-vps).
- OVHcloud VPS-2/6 region choices affect latency tiers (NA East B, NA West C, EU West S, Asia SG C, CN Mainland C) — [CheapVPS Finder](https://cheapvps.store/en/plans/ovhcloud-vps-2025-model2).
- Vultr / Standard cloud providers have 32-40 global locations but entry tiers exclude some features; Asia latency often worse on cheap providers — [saaskly 2026 UK VPS comparison](https://saaskly.com/comparisons/best-vps-cloud-hosting-2026).
- Contabo has 9-11 global regions (France, US, DE, etc.) and EU-low-latency optimized — [Contabo VPS France](https://contabo.com/en/vps-france).
- Hetzner only 6 locations (DE, FI, US, SG) vs Vultr 32+, limiting global users — [bitdoze review](https://www.bitdoze.com/hetzner-cloud-review).
- Forex/VPS near broker matters: NVMe VPS at 32 global locations with sub-ms brokers — [bestvpsmatch.com 2026](https://bestvpsmatch.com/best-vps-for-forex-trading).

### Inferences
- Providers with many regions (Vultr 32, Host4Fun 35) charge more for entry tiers than regional-only hosts; staying near users is a second axis of "value."

### Gaps
- Real measured latency/ping tables beyond anecdotal samples; peering quality per DC is not systematically published.

## 11. Resource Throttling, CPU Steal, and Oversell Gotchas

### Takeaway
Cheap VPSes gamefully oversell: expected CPU steal 10-20% on budget plans; VPS IOPS capped 5,000-10,000 with ~200-300 MB/s throughput; Hostinger enforces undisclosed CPU caps and throttles to unusable SSH when tripped; Contabo reported disk I/O as the true bottleneck (not CPU) on cheap instances. A "fair use" cap kicks in after 2-3 hours sustained CPU.

### Cited Findings
- Sub-$5 VPS in 2026: 1-2 vCPU, 2-4 GB RAM, 30-50 GB NVMe, IOPS limited 5,000-10,000, throughput 200-300 MB/s; overselling means CPU steal 10-20% — [Valebyte blog](https://valebyte.com/en/blog/vps-under-5mo-in-2026-what-you-will-actually-get).
- Vultr $3.50: CPU steal <2% (well-managed overselling); Hostinger enforces caps that render VM unusable when exceeded, with only a few manual CPU resets per week — [abo.ng test](https://gpt.abo.ng/blog/cheap-vps-under-5-6-providers-that-don-t-oversell-comparison); [Reddit r/selfhosted](https://www.reddit.com/r/selfhosted/comments/1u35vi8/if_youre_putting_production_on_a_hostinger_vps).
- Cheap NVMe drives advertise speeds but real IOPS often <1,000 on legacy/oversold hosts — [Valebyte Namecheap comparison](https://valebyte.com/en/blog/namecheap-vps-alternatives-where-cpus-arent-oversold); [affordablevpsserver marketing tricks](https://affordablevpsserver.com/blog/cheap-vps-marketing-tricks-real-vs-advertised/).
- RAM: advertised as guaranteed but cheap providers use ballooning and overcommit; swaps to disk on IOPS-capped NVMe cause severe slowdown — [webhostmost guide to limits](https://blog.webhostmost.com/hosting-resource-allocation-cpu-ram-io-limits).
- Contabo real-world: CPU steal 0% usually but disk I/O throttling caused the slowness — [r/VPS thread](https://www.reddit.com/r/VPS/comments/1to8bwk/i_expected_cpu_steal_on_my_cheap_contabo_vps_the).
- "System drive IO throttling" is common: provider confirms system drive capped; upgrade required for faster disk — [r/VPS](https://www.reddit.com/r/VPS/comments/1tje7kk/system_drive_io_throttling).
- CPU limits: typical chip process count limits 10-30 entry processes, 1024-2048 shared IOPS on shared hosting; on VPS limits are higher but still policed — [webhostmost guide](https://blog.webhostmost.com/hosting-resource-allocation-cpu-ram-io-limits).
- CPU steal time does not always indicate overload (Cherry Servers explicitly notes) — [Cherry Servers FUP](https://www.cherryservers.com/legal/virtual-server-fair-usage-policy).

### Inferences
- Real sustained performance per dollar is the dominant hidden reduction of "cheap VPS" value, more than line-item fees.

### Gaps
- No systematic benchmark across small hosts; community reports are anecdotal and hardware-generation-dependent.

## 12. Control Panel & License Add-Ons

### Takeaway
cPanel licensing is a massive hidden line item: official Solo (1 account) is $29.99/mo, Admin $35.99 (5 accounts), Pro $53.99 (30), Premier $69.99 (100); shared third-party licenses cost $4.50/mo VPS with unlimited accounts on shared license marketplaces. Plesk is comparable; WHM $0/free (IDCloudHost includes free WHM/cPanel), and many cheap hosts bundle cPanel only on managed tiers. Other hidden extras: Imunify360, WordPress Toolkit, SSL (sometimes free, sometimes manual), Snap-on-restore images. cPanel prices rose 6-17% in 2026.

### Cited Findings
- cPanel official 2026 Store pricing: Solo $29.99/mo (1 account), Admin $35.99/mo (5), Pro $53.99/mo (30), Premier $69.99/mo (100); auto-renews — [support.cpanel.net 2026 store pricing](https://support.cpanel.net/hc/en-us/articles/30117774089879-2026-cPanel-Store-License-Pricing); [cpanel.net/pricing](https://www.cpanel.net/pricing).
- Shared cPanel license marketplace prices: Solo-equivalent $4.50/mo VPS (unlimited accounts) from SharedLicense — [SharedLicense cPanel cost 2026](https://sharedlicense.com/cpanel-license-cost/).
- Findstack: control panel costs ~7× the server it runs on (Hetzner 4GB server ~€4, cPanel Premier $69.99) — [Findstack true cost VPS](https://findstack.com/resources/vps-hosting-with-cpanel-included).
- cPanel 6-17% annual price increases historically, budget annually — [Findstack](https://findstack.com/resources/vps-hosting-with-cpanel-included).
- cPanel/WHM licenses bind to the public-facing static IP; mobility supported (no repurchase when moving) — [cpanel.net trial mobility docs](https://www.cpanel.net/products/trial/).
- Webdock and many modern hosts prefer free/open-source panels (Vesta/Hestia/CloudPanel/aaPanel) or skip panels entirely to avoid $30-70/mo license tax — [Webdock pricing](https://webdock.io/cheap-vps-hosting).
- IDCloudHost includes a free WHM/cPanel license with managed VPS WHM product — [IDCloudHost](https://idcloudhost.com/en/managed-vps/).

### Inferences
- Any VPS priced below $7/mo with cPanel "included" is dedicating half the bill to the panel; per-account pricing makes small VPSs uneconomical for typical reseller use.

### Gaps
- Plesk 2026 pricing not in primary sources beyond bundled managed plans; DirectAdmin cheaper but exact 2026 rates vary by reseller.

## 13. Cost of Getting Disrupted: SLA Credits and Refund Policies

### Takeaway
SLA credits are account credits, not cash, capped at 100% of monthly fee; refunds for suspension/termination are rarely provided; prepaid annual terms are non-refundable upon early cancellation except provider-caused failures; crypto/balance credit is non-transferable.

### Cited Findings
- VPSNET SLA: credits added to account balance, not paid in cash; maximum 100% annual; sole remedy — [VPSNET SLA](https://www.vpsnet.com/en/information/sla).
- OVH VPS: SLA credits per tier; sole remedy; 14-30 day data retention after service termination — [OVH contracts](https://storage.gra.cloud.ovh.net/...).
- FxSVPS: 14-day data retention post suspension; no refund on violations — [FxSVPS AUP](https://www.fxsvps.com/acceptable-use-policy/).
- Vultr crypto funds: non-refundable, only spendable on Vultr products — [Gate News](https://www.gate.com/news/detail/vultr-prohibits-crypto-mining-on-vps-servers-21253076).
- Many small hosts offer 7-30 day money-back guarantee only on first order (Byte etc.); signup bonuses/promos may be clawed back — [VPS VPS Coupons, VPSBenchmarks](https://www.vpsbenchmarks.com/vps_coupons).

### Inferences
- Real business cost of budget-tier downtime vastly exceeds credit compensation.

### Gaps
- Per-provider refund policy nuance (prorated vs none) is scattered in ToS and not consolidated.

## Summary: Checklist of Real Value Killers

- Overages: $0.005-$0.01/GB on DigitalOcean/Linode/Vultr vs $0.09/GB on Lightsail.
- Backups auto: +20-30% of server price; snapshots $0.05-0.06/GB; backup license adds fees.
- IPv4: €0.50-€3.65/mo or included in headline.
- Custom panel (cPanel): $29.99-$69.99/mo.
- CPU steal: 10-20% typical, drops SSH to unusable on bad hosts when tripped.
- IOPS disk caps: 5,000-10,000 (advertised NVMe) but sometimes ≤1,000 in oversold hosts.
- Renewal surges: 20-40% at Hostinger VPS, 20-80% at A2/GoDaddy/IONOS, +26% SSDNodes.
- Support: 12-24h tickets standard; engineers are premium.
- SLA credits: account credits capped at 100% monthly fee, sole remedy.
- Account termination risk under mining/sustained CPU with no refund.
