# Pi Fleet UI Audit (piworm.local:8765)

Audit of the static read-only Fleet dashboard served at `http://192.168.0.100:8765/`
(application title: "Firstmate Fleet"). Captured with Playwright/Chromium headless at a 1440x900
viewport. All ten sidebar views were visited. Screenshots are stored outside the worktree at
`/Users/kayisrahman/Documents/workspace/firstmate/data/pi-fleet-ui-audit-v1/screenshots/`
(one PNG per view: `board.png`, `decisions.png`, `prs.png`, `workers.png`, `fleet.png`,
`backlog.png`, `activity.png`, `reviews.png`, `health.png`, `memories.png`).

## Summary

- Page shell and navigation render on every view: no JavaScript page errors, no horizontal
  overflow, no broken images.
- Only the Board is data-backed. Every other view displays "Data unavailable" because its
  JSON endpoint returns 404 on the Pi host. The Pi build is incomplete: only
  `/data/snapshot.json` and `/data/live_status.json` exist; 13 of the 15 expected data files are
  missing (`meta.json`, `decisions.json`, `prs.json`, `stuck.json`, `backlog.json`,
  `secondmates.json`, `activity.json`, `reviews.json`, `capacity.json`, `away.json`, `quota.json`,
  `models.json`, `memories.json`, plus `task-details.json`).
- All views report `Home: unknown home` and a "stale" warning because the served snapshot is
  older than 3 minutes and no background refresher is running.
- Minor text defect: the age label is doubled - `Data as of Oct 26, 07:04 PM (11m ago ago)`.

## Per-view findings

| View | Loads | Data shown | Console errors | Network failures | Sections populated |
|---|---|---|---|---|---|
| Board | Yes | Yes (snapshot) | 0 data-related* | 0 | Yes: overview counts, working tasks, blocked/attention column |
| Decisions | Yes | No - "Data unavailable for decisions" | 5 (404s) | 10 (5 distinct) | Header only; empty list |
| Pull requests | Yes | No - "Data unavailable for pull requests" | 5 | 10 | Header only |
| Workers | Yes | Partial - stuck panel unavailable; task list renders from snapshot (10 tasks) | 4 | 8 | Task cards render; stuck-worker alert section empty (0 alerts reported) |
| Fleet | Yes | No - capacity and secondmates unavailable; away posture stuck on "Reading away posture..." | 7 | 14 | Headings only; no machine/away/secondmate data |
| Backlog | Yes | No - "Data unavailable for backlog" | 5 | 10 | Header only |
| Activity | Yes | No - "Data unavailable for activity" | 5 | 10 | Header only |
| Review boards | Yes | No - "Data unavailable for review boards" | 4 | 8 | Header only |
| Health | Yes | No - quota and free models unavailable | 6 | 12 | Headings only |
| Memories | Yes | No - "Data unavailable for memories" | 5 | 10 | Header only |

\* Board itself makes no failing `/data/*.json` requests beyond the shared shell; its data loads from `snapshot.json` (present).

Console errors on every non-Board view are the browser's `Failed to load resource: 404 (Not Found)`
for the missing JSON endpoints (network panel lists the exact URLs). No uncaught JavaScript
exceptions (`pageerror`) were observed on any view.

## Layout / visual notes

- No horizontal overflow detected at 1440x900 on any view; scroll width equals client width.
- No broken images on any view.
- "Data as of unknown" did not appear; instead the timestamp renders but is stale.
- Chrome aside: the fixed 204px sidebar plus content fit without side-scroll.
- Mobile/responsive layout not exercised in this audit (desktop viewport only).

## Root cause

The Pi instance (`192.168.0.100:8765`, host label `piworm.local`) is serving a stale/incomplete
`fm-fleet-ui` build. Only `snapshot.json` and `live_status.json` are present under `/data/`,
so every view whose loader calls `fetchJson` for its own panel (decisions, prs, backlog,
secondmates, activity, reviews, quota, models, memories, stuck, capacity, away) hits a 404 and
renders the "Data unavailable ... Run fm-fleet-ui (auto-refresh 60s), then Reload." banner.

Additionally, `meta.json` is missing, so the dashboard cannot resolve the home identity and shows
`Home: unknown home`; the snapshot's `generated` timestamp is over three minutes old, triggering
the stale-data warning.

## Suggested follow-up (for the captain / firstmate, not performed here)

1. Rebuild the dashboard on the Pi home:
   `fm-fleet-ui.sh build --out <home>/state/fleet-ui` (or re-run `serve`), ensuring
   `FM_HOME` points at the Pi firstmate home so all 15 panels generate.
2. Confirm the 60-second refresh LaunchAgent is installed and running on the Pi so data stays
   fresh (clears the "Stale: data is older than 3 minutes" warning).
3. Fix the doubled "ago" in the `Data as of ... (Nm ago ago)` label.
4. Re-run this audit after the rebuild to confirm every view now shows live data.

## Conclusion

The dashboard shell is healthy and the Board view works, but 9 of 10 views are non-functional
due to missing data files on the Pi host. No layout defects were found. The defect is operational
(missing build artifacts), not in the page markup.

## Addendum - after Pi auto-refresh (~19:27 UTC)

The Pi auto-refreshed its build between the initial audit run and capture of the updated
screenshots. State now:

- Missing data files (404): `away.json`, `models.json`, `reviews.json` only.
- Capacity panel is served but reports "Capacity is unavailable." (host metrics missing).
- Live now: Board, Decisions, Pull requests, Workers, Fleet (secondmates + quota-related
  content), Backlog, Activity, Health (quota side), Memories.
- Still unavailable: Review boards (no Lavish sessions hosted on Pi), Health free models,
  Fleet away posture ("Reading away posture..." never resolves).
- "Home: unknown home" and the doubled "Nm ago ago" label persist; generated timestamp
  advanced to 2026-10-26 07:27 PM.

Root cause of the remaining three is environmental on the Pi (missing away record,
free-model-axi, Lavish) rather than a broken build. Decision on whether to install/configure
that tooling is with the captain.
