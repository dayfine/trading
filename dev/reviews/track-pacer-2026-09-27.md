# Track Pacer Report — 2026-09-27

## Summary
- Tracks audited: 50 index rows (26 IN_PROGRESS + 1 PENDING = 27 non-MERGED; 23 MERGED exempt). Cadence run on the 27 non-MERGED rows.
- Active (≥1 PR last 7d): 9
- Slowing (7–30d since last PR): 4
- Stalled (>30d): 14 (13 IN_PROGRESS + 1 PENDING parked)
- `[info]` items needing decision: 0
- Capability gaps flagged: 9 (3 new, 6 carried; 2 of last week's resolved)

**Headline: the program's stop behaviour has been measured on a defective
system, and every stop-width / stop-raise / exit-stack verdict on record
inherits the defect.** `dev/notes/next-session-priorities-2026-09-26.md`
records P0 issue **#2982**: the trailing-stop raise candidate is
`min(raw correction low, ADJUSTED 30-wk MA)` (`weinstein_stops.ml:276`), so on
any name whose later splits/dividends shrink its adjusted history the ratchet
cannot fire — "0/73 trades held ≥ 13 wk raised at close/adj ≥ 1.5, vs 50 % at
< 1.02", reproduced by a 724-trade replay (704/724 with the adjusted MA vs
592/724 with a consistent one). The note is careful that the fix "is not an
obvious win" and must be measured. That is the right posture; the pacer's
point is scope: this is a **G14-class split/adjustment bug**, the exact class
M6.4 (split/dividend verification harness) was specified to catch, and it is
the third consecutive cycle this report has flagged M6.4 as unstarted. It is
also a **sixth re-base of the record-of-record in ~5 weeks** (see P5).

**Second: the fix wave exists only as five unbuilt, un-PR'd branches.** The
same handoff lists `feat/stop-decision-audit`, `feat/split-corpus`,
`fix/stop-raise-count`, `feat/suspend-tickets-bearish` and
`feat/stop-basis-flags` — "all pushed to origin with no PR yet", "written
**without compiling**" while a backtest held the container. The handoff flags
expected rebase conflicts across `stops_runner.ml`, `trade_audit.ml{,i}` and
`audit_recorder.ml{,i}`, `weinstein_stops.ml` at 492/500 lines and
`trade_audit.ml` at exactly 300. None of this is visible in
`dev/status/_index.md` (every Open-PR cell reads `—`) or to the orchestrator.
This is a deliberate, documented choice (container-capacity discipline) and
the handoff carries a clear build order — flagged here only because five
concurrent unbuilt branches touching the same files is the largest
single-point integration risk in the program right now.

**The good news is real, and two of last week's recommendations closed.**
(a) The orchestrator ran **every day** of the window — 14 funded slots, 10
`dev/daily/` summaries, no zero-cost outage (vs six dead slots last week).
(b) **#2903 fixed `prune-candidates-weekly.yml`** through the REST route
(last week's Rec 2); first post-fix cron is Monday 09-28. (c) The
**weekly-start sweep published** (#2893, BAH SPY 2026-09-21) — the first
post-#2842 datapoint, confirming that fix. (d) **`backtest-perf` came back
from 8 cycles of stall** to the most productive feature track of the week
(7 PRs, tier-2 walls −82 %, #2910). (e) **The empty-queue problem eased on its
own**: #2955 widened the file-length linter repo-wide, which put 16 concrete
`file_length` rows into `cleanup.md` — ungated, dispatchable work the
orchestrator has already started consuming (#2959, #2971).

## Active tracks (≥1 PR last 7d)
- **harness** — ~15 PRs (#2980, #2970, #2958, #2956, #2955, #2953, #2948, #2943, #2929, #2927, #2909, #2908, #2907, #2906, #2874); theme: token-usage accounting (#2922 items 1–4), the results-only QC lane (#2906), Codex budget/sampling (#2907), repo-wide file-length scope (#2955), the run-counter corruption from jj-colocation pollution (#2956), and `pr_gate_status.sh`'s zero-check-run case (#2970).
- **screener** (top-of-funnel program) — 11 PRs (#2884, #2897, #2900, #2917, #2923, #2925, #2931, #2935, #2945, #2947, #2979); theme: index-stage veto REJECT-as-default/keep-as-axis (#2884), top-N capacity ACCEPT(mechanism) not promotable (#2900), then a 3-cell top-N confirmation grid ending in "cap 40 dominated on the top-1000 schedule, not promotable" (#2945) — default stays 20. A full `promotion-confirmation.md` grid run end to end, including a broad-vs-broad breadth-tier cell. `screener.md` itself was not updated (see P2).
- **backtest-perf** — 7 PRs (#2888, #2894, #2882, #2910, #2919, #2920, #2965); theme: cache occupancy telemetry, perf tiers stop timing the all-eligible diagnostic (12× wall), mmap-handle cap as a knob, PIT-warehouse smoke cell, FAIL-row annotations, and the `perf_long_cells` runtime ledger. **Newly active after 8 stalled cycles.**
- **orchestrator-automation** — 6 PRs (#2903, #2918, #2937, #2939, #2950, #2951); theme: prune workflow via REST, fastexit prior-summary selector, `scheduled_workflow_health.sh` event filtering and crowded-page reporting, `merge_pr_when_clean` updating a behind branch, weekly-start sweep end-date guard. Landed under `fix:`/`harness:` prefixes; `orchestrator-automation.md` itself untouched since 09-05.
- **cleanup** — 4 PRs (#2971, #2959, #2949, #2889); theme: `backtest_runner.ml` under the 500 hard limit, `autopsy_runner.ml` under 300, 9 expired linter exceptions retired/re-dated, weekly opam update.
- **simulation** — 2 PRs (#2963, #2967); theme: two default-off fill-model flags (`sim_entry_stoplimit_fresh_bar_only`, `sim_stop_exit_fill_on_trigger_bar`). **Index row still reads "next: none queued"; `simulation.md` not updated.**
- **support-floor-stops** — 1 PR (#2966); theme: `require_structural_stop` (investor preset skips automatic-percentage stops, default off) plus a §5.3 book-reference write-back (#2968 follow-up).
- **post-run-validation** — 1 PR (#2875); theme: `Series_level` wired into `Build_runner` behind `-detect-series-level`, report-only default-off — last week's stated next step, done.
- **backtest-infra** — 1–2 PRs (#2951 touched `backtest-infra.md`; #2882 closed its #2839 item); theme: sweep robustness and the PIT-cell cost knob.

## Slowing tracks (7–30d since last PR)
- **rename-twin-dedup** — last PR #2870 at 2026-09-20 (7 days, just outside the window); theme: alias sidecar armed-pass correction after #2862; recommendation: KEEP_AS_INFO — next step ("arm the guards on a PIT rebuild") is gated on a rebuild that the #2982 work will likely trigger anyway.
- **trade-audit** — last PR #2827 at 2026-09-15 (12 days); theme: §5.1 R7 book write-back; recommendation: KEEP_AS_INFO — `feat/stop-decision-audit` (#2977, unbuilt branch) is this track's next surface; 9 open follow-ups unchanged.
- **arc-readiness** — last PR #2652 at 2026-09-03 (24 days); theme: D1/D2 exit-basis flip; recommendation: KEEP_AS_INFO — A2-4 (picks chart, plan #2453) now **37 days** behind its merged plan.
- **experiment-platform** — last PR #2631 at 2026-09-01 (26 days); theme: clock A-null ledger entry; recommendation: ESCALATE_TO_MAINTAINER — **3rd consecutive cycle**; crosses 30 days on 10-01. The ledger (2 new entries this week: `2026-09-21-index-stage-veto`, `2026-09-22-top-of-funnel-capacity`) is heavily used; the platform code is not, and its first Next Step is still a struck-through 2026-06-21 item.

## Stalled tracks (>30d since last PR)

No track crossed the 30-day line this week; `backtest-perf` left the bucket (now active).

- **stage-accuracy** — last PR #2450 at 2026-08-20 (38 days); reason: broad-universe WF-CV re-run data-gated; recommendation: KEEP_AS_INFO — honest park.
- **weekly-snapshot** — last PR #2453 at 2026-08-20 (38 days); reason: index cell "next: none queued"; recommendation: ESCALATE_TO_MAINTAINER — M6.4 is now demonstrably load-bearing (#2982), and `feat/split-corpus` (#2973, "7 real split windows + first cross-consumer suite") is M6.4-shaped work being done outside this track with no link back to it.
- **resistance-v2** — last PR #2145 at 2026-07-28 (61 days); reason: remaining WF-CV vs w30 data-gated/LOCAL; recommendation: ESCALATE_TO_MAINTAINER — default-on bundle (#2047) still uncertified; #2982 adds a stop-basis confound to its evidence. 7th cycle.
- **tuning** — last PR #2113 at 2026-07-27 (62 days); reason: M2 qNEHVI awaiting maintainer enable-commit since #1327 (2026-05-26, **124 days**); recommendation: ESCALATE_TO_MAINTAINER. 10th ask.
- **short-side-strategy** — last PR #2081 at 2026-07-26 (63 days); reason: next task LOCAL; recommendation: KEEP_AS_INFO.
- **margin-realism** — last PR #2077 at 2026-07-24 (65 days); reason: M4 complete, no successor, no `## Next Steps` section; recommendation: KEEP_AS_INFO — close to MERGED. 3rd ask.
- **extension-stop** — last PR #1960 at 2026-07-13 (76 days); reason: default flip human-gated (R3); recommendation: KEEP_AS_INFO — note its insurance-ACCEPT was measured on the #2982 stop system.
- **data-foundations** — last PR #1939 at 2026-07-12 (77 days); reason: EODHD-gated; recommendation: KEEP_AS_INFO.
- **floor-quality** — last PR #1913 at 2026-07-10 (79 days); reason: deep-warehouse LOCAL; recommendation: KEEP_AS_INFO.
- **rolling-start-lens** — last PR #1645/#1648 at 2026-06-18 (101 days); reason: LOCAL/data-gated; recommendation: KEEP_AS_INFO.
- **cash-floor-correctness** — last PR #1582 at 2026-06-14 (105 days); reason: NS2 human-gated, NS4 data-gated; recommendation: KEEP_AS_INFO.
- **sweep-perf** — last PR #1574 at 2026-06-13 (106 days); reason: manual ghcr.io flambda rebuild; recommendation: ESCALATE_TO_MAINTAINER. 9th ask.
- **spy-only-reference** — last PR #1438 at 2026-06-03 (116 days); reason: item 1 "(Open question, not dispatched)"; recommendation: ESCALATE_TO_MAINTAINER — decide or close.
- **tuning-methods** (PENDING) — no PR ever; file last updated 2026-05-24 (126 days); recommendation: ESCALATE_TO_MAINTAINER — close or re-scope. 3rd ask.

## Next Steps staleness (P2)

**Carried-and-improved:** `harness.md`'s `Last updated` is now 2026-09-25 (was 30 days stale last cycle) and the `harness` Open-PR cell no longer lists merged PRs — both last-cycle P2 items resolved.

New / changed drift this week:

- **screener** — `screener.md` `Last updated: 2026-09-05`, last commit 2026-09-06; **11 top-of-funnel PRs since** (#2884 … #2979), including two ledger entries and a full confirmation-grid verdict. None touched the file. recommend refreshing status file (the index row carries #2884 but not the #2931/#2945 grid verdicts).
- **simulation** — #2963 and #2967 shipped two fill-model flags on 09-25; `simulation.md` (last 2026-09-02) and the index row ("next: none queued") both unchanged. recommend refreshing status file.
- **cleanup** — `Last updated: 2026-08-30` but 5 commits this week edited the file (#2911, #2949, #2955, #2959, #2971). Content is current; header is not.
- **Index-row drift:** `backtest-infra` row "next #2839" — shipped as **#2882** on 09-20; `backtest-perf` row lists "(#2896)" as next — shipped as **#2920** on 09-22; `support-floor-stops` row "next: UNSET (09-15)" — **#2966** shipped 09-25 and the file was refreshed, the row was not.

Carried unchanged (none of these files touched this week): `cash-floor-correctness` (NS1 ✅ SHIPPED at head), `resistance-v2` (items 1–2 are completed events), `experiment-platform` (struck-through 06-21 head), `tuning` (items 1–5 struck through), `extension-stop` (item 1 DONE), `tuning-methods` ("None yet — track just opened"), `data-foundations` (recital of merged PRs), `spy-only-reference`, `weekly-snapshot`. recommend refreshing status files — 3rd cycle for all nine.

Structural, carried: 11 of 27 non-MERGED files still have no `## Next Steps` / `## Next task` section (`margin-realism`, `post-run-validation`, `rolling-start-lens`, `sweep-perf`, `trade-audit`, `support-floor-stops`, `short-side-strategy`, `harness`, `orchestrator-automation`, `cleanup`, `screener`). KEEP_AS_INFO.

## [info] items needing decision (P3)

None. `dev/status/_index.md` carries zero `[info]` / `[critical]` tags (grep). The daily summaries carry three `[info]` escalations this week (`dev/daily/2026-09-26-run2.md`: #2747 recurrence, `/tmp` ENOSPC, prune streak pending 09-28), none repeated across reconciles. PASS — 12th consecutive clean week.

## Tracks without owner (P4)

None. No track created in the last 14 days; every non-MERGED row has an owner. PASS.

## Recurring discussion topics (P5)

`dev/decisions.md` — 0 entries in 30 days, last modified 2026-05-15 (135 days); P5 unrunnable as specified. recommend: ESCALATE_TO_MAINTAINER (3rd ask). Scanning the live channel (handoffs + ledger):

- **Record-of-record re-basing — now a 6th re-base, and it reaches back into closed verdicts.** #2532 → #2657 → #2704 → #2751 → #2843 (PIT band 152/188/457 %), and now #2982 states "every stop-width / stop-raise / exit-stack verdict so far was measured on that system." `dev/backtest/DEEP_RESULTS.md` last touched 2026-07-29 (#2170, **60 days**). recommend: RECOMMEND_NEW_TRACK (`record-of-record`: owns the basis, provenance and the invalidation sweep of prior verdicts). **3rd ask.**
- **Split/adjustment correctness** — appears as #2982 (adjusted MA in the stop), #2973 (split corpus), the audit's new `adjusted_close_at_decision`, and historically G14 / the −144.5 % phantom baseline. No track owns it; M6.4 is the specified home. recommend: RECOMMEND_NEW_TRACK or explicitly re-home under `weekly-snapshot` M6.4.
- **Warehouse data-integrity split across four tracks** (`backtest-infra`, `post-run-validation`, `rename-twin-dedup`, `data-foundations`) — unchanged. recommend: KEEP_AS_INFO (2 prior asks; no new friction this week).
- **Book write-back loop** fired again (#2966 + #2968, §5.3). KEEP_AS_INFO — working as designed.

## Diminishing returns (P6)

**Mechanical heuristic: 0 flags.** Last 5 PRs per active track: `harness` (#2980, #2970, #2958, #2956, #2955) — 0 subject hits; `cleanup` (#2971, #2959, #2949, #2889, #2805) — 2 of 5 contain `chore`, below the 3-of-5 threshold (and the track is maintenance by charter). PASS.

Qualitative: last week's "harness absorbs the queue" concern softened — harness share fell to ~15 of 84 merges (from ~30 of 89), and feature tracks (`screener`, `backtest-perf`, `simulation`, `support-floor-stops`) carried a larger share. KEEP_AS_INFO.

## Capability gaps (P7)

- **[NEW] #2982 stop-basis defect invalidates the stop-verdict history.** Mentioned in: priorities 09-26, `support-floor-stops`, `extension-stop`, `resistance-v2`, `trade-audit`. Milestone: M5/M7 (any tuned stop value). Status: fix branch `feat/stop-basis-flags` written, unbuilt; `weinstein_stops.ml` at 492/500; `goldens-affected` expected to flag AFFECTS-ALL. recommend: ESCALATE_TO_MAINTAINER — decide which prior ledger verdicts to mark "measured on pre-#2982 stops" once the paired run lands.
- **[NEW] Five unbuilt write-only branches, no PRs, overlapping files.** Mentioned in: priorities 09-26 §P0. Invisible to `_index.md` and to `pr_gate_status.sh`. recommend: KEEP_AS_INFO — the handoff's one-at-a-time build order is sound; the risk is only if a session boundary drops them. Consider an index Open-PR note ("branch, no PR") so the orchestrator does not re-dispatch the same issues.
- **[NEW] #2747 recurred** — `dev/daily/2026-09-26-run2.md`: run 1 (36241340681, $3.07) exited with both dispatched agents in flight; plus a `/tmp` ENOSPC from four 13–17 GB worktrees against the standing "reclaim as each agent finishes" ceiling. Mentioned in: `orchestrator-automation`, `harness`. recommend: KEEP_AS_INFO (run 2 recovered).
- **M6.4 split/dividend verification harness** — carried, now validated by #2982. `feat/split-corpus` (#2973) is the first real step; unbooked to `weekly-snapshot`. Milestone: M6. recommend: ESCALATE_TO_MAINTAINER.
- **Weekly live-picks run — 44 days stale, 6 consecutive Fridays missed** (08-21 … 09-25). Newest record `dev/weekly-picks/f88c277d5/2026-08-14.*`. Mentioned in: `weekly-snapshot`, `arc-readiness`, `decision-audit`. Milestone: M6. recommend: ESCALATE_TO_MAINTAINER. 6th cycle.
- **Promoted bundle margin uncertified** (`DEEP_RESULTS.md` 60 days; #2047 default-on). Now additionally confounded by #2982. recommend: ESCALATE_TO_MAINTAINER. 9th cycle.
- **`tuning` M2 enable-commit (#1327) — 124 days.** Milestone: M7. ESCALATE_TO_MAINTAINER. 10th ask.
- **`sweep-perf` ghcr.io flambda rebuild — 106 days**; `-O3` a silent no-op in CI. ESCALATE_TO_MAINTAINER. 9th ask. (Note the new tier-2 baselines in #2910 are also un-optimised.)
- **`arc-readiness` A2-4** — 37 days behind plan #2453; dispatchable, not data-gated. KEEP_AS_INFO.

Resolved since last report: **prune-candidates-weekly `gh pr create`** (#2903, 09-22; verify on 09-28 cron) and **the "empty dispatchable queue"** in its acute form (16 `file_length` rows now queued via #2955).

Follow-up accumulation: **79** open `- [ ]` items repo-wide (up from 64); the rise is almost entirely `cleanup` (4 → 20) from #2955's widened linter scope — new *visible* debt, not new debt. KEEP_AS_INFO.

## Recommendations
1. **Land the #2982 stop-basis fix as a paired measurement, then decide which prior verdicts to re-label.** Build `feat/stop-basis-flags` per the handoff, run the AFFECTS-ALL paired golden, and add a "measured on pre-#2982 stops" marker to the affected ledger entries (stop-width 12 %, extension-stop insurance-ACCEPT, the resistance-v2 bundle) rather than silently leaving them as current.
2. **Build and PR the five write-only branches in the handoff's order (#2977 first), one at a time**, and record them in the index Open-PR column as they open. Until then they exist only in a handoff note.
3. **Assign M6.4 an owner and link `feat/split-corpus` (#2973) to it.** #2982 is the G14-class bug M6.4 was specified to catch; the work has started outside the track that owns it.
4. **Spawn a `record-of-record` track — or explicitly refuse to.** Sixth re-base; `DEEP_RESULTS.md` 60 days old. 3rd ask.
5. **Decide the weekly picks cadence**: automate or de-scope M6.6. 44 days, 6 Fridays missed. 6th ask.
6. **Unblock the two one-action human gates**: `tuning` #1327 (124 days) and the `sweep-perf` flambda rebuild (106 days).
7. **Refresh `screener.md` and `simulation.md`**, and fix the three drifted index rows (`backtest-infra` #2839→#2882, `backtest-perf` #2896→#2920, `support-floor-stops` UNSET→#2966).
8. **Close or re-scope the parked tracks**: `tuning-methods` (126 days, never shipped), `spy-only-reference` (116 days), `margin-realism` (no successor), `experiment-platform` (code idle since #1372; 3rd slowing cycle).
9. **Verify `prune-candidates-weekly` on the 09-28 cron**, then close #2847.
10. **Retire or revive `dev/decisions.md`** (135 days empty). 3rd ask.

## Stats
- **84 PRs merged in last 7d** (18 `docs`, 18 `ops`, 12 `harness`, 12 `fix`, 10 `exp`, 8 `feat`, 3 `cleanup`, 1 `test`, 1 `perf`, 1 `chore`) — **37 (44 %) touch code**, up from 34 %
- **319 PRs merged in last 30d** (95 `docs`, 74 `ops`, 43 `harness`, 33 `fix`, 32 `feat`, 20 `exp`/`experiments`, 6 `cleanup`, 4 `chore`, 3 `test`, other 8)
- 9 tracks active / 4 slowing / 14 stalled out of 27 non-MERGED rows (vs 7 / 5 / 15 last cycle); `backtest-perf`, `simulation`, `support-floor-stops` moved up to active
- 0 `[info]` items carried ≥3 reconciles (12th consecutive week)
- **14 orchestrator slots since 09-20, $410.86 total, 0 zero-cost slots**; 10 `dev/daily/` summaries (09-20 … 09-26-run2); lowest slots 09-24 run 1 ($3.54) and 09-26 run 1 ($3.07, #2747 recurrence)
- Weekly deep health scan ran 2026-09-21 (#2898); weekly-start sweep published 09-21 (#2893)
- Experiment ledger: 2 new entries this week (index-stage-veto 09-21, top-of-funnel-capacity 09-22); 9 in 30d
- Newest `dev/weekly-picks/` record **44 days** old; `DEEP_RESULTS.md` **60 days**; `dev/decisions.md` **135 days**
- **79** open `- [ ]` follow-ups repo-wide (up from 64; `cleanup` 4 → 20 via #2955)
- 5 write-only branches on origin with no PR (per `next-session-priorities-2026-09-26.md`); 0 open PRs in the index
- 9 capability gaps flagged (3 new: #2982 stop basis, unbuilt branch wave, #2747 recurrence); 2 resolved (prune REST #2903, empty queue)
- **Method note:** `gh` unavailable; PR facts from merge-commit subjects on `main`, open-branch facts from the 09-26 handoff. Window 2026-09-20 ~11:40 UTC → 2026-09-27.
