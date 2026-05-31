# Track Pacer Report — 2026-05-31

## Summary
- Tracks audited: 11 (10 IN_PROGRESS/READY_FOR_REVIEW + 1 PENDING)
- Active (≥1 PR last 7d): 6
- Slowing (7–30d since last PR): 4
- Stalled (>30d): 0
- [info] items needing decision: 0
- Capability gaps flagged: 3

## Active tracks (≥1 PR last 7d)

- **experiment-platform** — ~14 PRs; theme: program landed end-to-end (Gaps A–F via #1368/#1369/#1371/#1372/#1374), first three platform uses completed (exit-timing REJECT #1375, early-admission INCONCLUSIVE→REJECT #1379/#1383/#1387), `rank_variants` CLI #1381, promotion-grid protocol #1384, exit-timing+hysteresis re-validation on repaired data #1391. Hottest track this week.
- **data-foundations** — 2 PRs; theme: GSPC.INDX 2017-floor + 15y re-baseline (#1383, closes issue #1380) and point-in-time SP500 snapshots 2005/2015/2020 (#1390). Unblocks experiment-platform's surface sweeps.
- **tuning** — 5 PRs; theme: M1 paired-Δ tooling (#1328/#1329) + post-sweep harvest scripts #1333 + v7 BO sweep results writeup #1338 + sensitivity_sweep cell-E fix #1340. M1 OCaml deliverables (T1.1–T1.5) all merged; v7 verdict: ROBUST holdout but promote REFUSED on 16y panel.
- **sweep-perf** — 3 PRs; theme: all 3 orchestrator-eligible wins shipped (#1317 `--parallel 6` + 12 GB RAM, #1318 per-fold universe pruning, #1323/#1324 Flambda + `-O3`).
- **harness** — 3 PRs (track-attributable); theme: orchestrator hardening — GHA run-id footer #1322, one-shot per-PR lifecycle #1312, 4x daily cron #1316. Plus the cross-cutting #1336 skip-no-op-daily-PR.
- **orchestrator-automation** — 2 PRs; theme: PR-D'c (drop `dev/reviews/` file writes) MERGED maintainer-direct via #1332 (2026-05-27, after 2026-05-26 run-4 dispatch failure); skip-no-op-daily-PR #1336 (2026-05-28).

## Slowing tracks (7–30d since last PR)

- **backtest-perf** — last PR #1282 (`[main-fix]` cost-model.md, 2026-05-23) — 8 days ago; theme: cost-model overlay end-to-end wiring complete (#1151 → #1260 → #1273 → #1276 → #1277). Real next step is N≥5000 release-gate awaiting daily-snapshot streaming (local-only). Recommendation: KEEP_AS_INFO — track is in a natural rest phase between cost-model wrap and the next big perf push.
- **short-side-strategy** — last PR #1274 (`fix(margin): dedup same-tick TriggerExit`, 2026-05-23) — 8 days ago; theme: Phase 2 transition bug fixed; Phase 3 verdict locked (margin-edge negligible in 3 of 4 bear windows; only GFC 2008 has positive short-side edge). Track is in steady-state per status file. Recommendation: KEEP_AS_INFO.
- **simulation** — last PR #1177 (`fix(simulator): surface rejected fills via CancelEntry`, 2026-05-18) — 13 days ago; theme: M5 walk-forward + Bayesian Phase 3 catch-all closed; cost-model wiring landed via the `cost-model` track. Remaining work is "local-only sp500-2019-2023 baseline rerun". Recommendation: KEEP_AS_INFO — no actionable orchestrator-dispatchable work surface.
- **cleanup** — last PR #1245 (`docs(cleanup): close 4 stale [~] items`, 2026-05-22) — 9 days ago; theme: backlog drained; per status file "Backlog empty after #578". Recommendation: KEEP_AS_INFO — exempt-equivalent (no actionable findings since the 2026-05-08 cleanup batch).

## Stalled tracks (>30d since last PR)

(None at the IN_PROGRESS/READY_FOR_REVIEW level.)

## Tracks in atypical states

- **tuning-methods** — PENDING per status file. Last PR-attributable activity is the random-baseline verdict 2026-05-24 (#1288 + #1289). All non-step-0 work explicitly DEMOTED by the v6 verdict ("surface is the bind, not the surrogate"). Track stays open contingent on a component-decomposition objective; not stalled in the sense of "needs dispatch", just dormant by design. Recommendation: KEEP_AS_INFO.

## Next Steps staleness (P2)

- **orchestrator-automation** — §Open work still lists PR-D'c as `[ ]` (unticked), but the orchestrator-automation row in `_index.md` confirms PR-D'c MERGED via #1332 on 2026-05-27 (maintainer-direct after the 2026-05-26 run-4 dispatch failure). Status file `## Last updated: 2026-05-26` predates the merge. Recommend the status-file refresh: flip the `[ ]` to `[x]`, move the entry to "Completed work", and either re-wrap the track on Phase 1 stable (per 2026-05-22 track-pacer §P6 recommendation) or queue the next Phase 2 win.
- **data-foundations** — §Next Steps item 1 says "Phase 1.4 — run the actual IWV scrape (ops-data, ~3-hour wall-clock). Tooling complete; data is not." But the `_index.md` 2026-05-23 PM preamble records this as obsoleted: "PIT-universe vendor decision OBSOLETED 2026-05-17: EODHD `?delisted=1` endpoint returns ~57k delisted entries on existing tier... IWV Akamai-block surface is now moot." The Next Step item should be retired or re-scoped to the EODHD delisted ingest. Status file `## Last updated: 2026-05-23` predates the more recent Status row text.
- **tuning** — §In Progress block lists PRs #1231, #1236, #1237 as "IN REVIEW" / OPEN, but none have been touched since the 2026-05-22 status refresh. Verify whether the cross-scenario-validation work has subsumed them (V7 BO sweep #1338 + sensitivity_sweep #1340 suggest the workflow has shifted). Status file `## Last updated: 2026-05-26` is current on the M1 task list but stale on the V5/V6 section.
- **backtest-perf** — `_index.md` row body explicitly notes "Status file §Open work block remains stale — refresh deferred until next dispatched-on-this-track run." Cost-model is now MERGED end-to-end (per the `cost-model` track row), so the cost-model wiring deferred items mentioned in `## Status` are obsolete.

## [info] items needing decision (P3)

None carried across ≥3 reconciles in the last 30 days. The earlier carried `[info]`s (qc-structural H3 false-positive, review-file persistence gap, magic-numbers docstring false-positives, status_file_integrity advisory FAILs, PR-D'c dispatch failure) have all either resolved organically or been closed by PRs landed in May (#1227 promote rules, #1332 drop review file writes, #1235 schema cleanup).

## Tracks without owner (P4)

None. All 11 audited tracks carry an Owner.

## Recurring discussion topics (P5)

`dev/decisions.md` contains 2 dated entries in the last 30 days, both on 2026-05-16 and both addressing the same vendor decision (Norgate retired + Option B IWV pivot). Both reached a clean resolution the same day (Option B chosen). No recurring un-resolved topics within the 30-day window. Note: the subsequent EODHD `?delisted=1` discovery (2026-05-17) that obsoleted the IWV pursuit is recorded in `memory/project_eodhd_delisted_unlock.md` and `_index.md` reconcile preambles, but not in `decisions.md`. KEEP_AS_INFO: consider recording the EODHD-delisted decision in `decisions.md` for symmetric provenance.

## Diminishing returns (P6)

None. Each active track's last 5 PRs are feature/docs work, not maintenance (chore/fmt/golden/repin). Specifically:

- experiment-platform last 5: #1391 docs(experiments) re-validation, #1389 docs(plans) population search, #1387 docs(experiments) 27y deep test, #1383 data(golden) GSPC.INDX fix, #1381 feat(walk_forward) `rank_variants` CLI — all feature/data/decision work.
- tuning last 5: #1340 fix(tuning), #1338 docs(notes), #1333 feat(tuning), #1329 feat(tuning), #1328 feat(tuning) — feature work.
- sweep-perf last 5: #1324, #1323, #1322, #1318, #1317 — all feature/harness wins.

## Capability gaps (P7)

- **M6.6 — true live cycle** (`live` DATA_SOURCE + cron + alert dispatch + trading-state durability). Mentioned in `weekly-snapshot.md` (explicitly DEFERRED), `orchestrator-automation.md` §Phase 2 considerations, and `dev/notes/next-session-priorities-2026-05-22.md` §P2. On critical path to M6. No track started. Recommendation: ESCALATE_TO_MAINTAINER — at minimum a scoping plan PR; this is the single remaining capability needed to take the system from "verification harness" to "live cycle."
- **Cross-scenario validation as the new promote gate** (per `dev/plans/tuning-methodology-redesign-2026-05-22.md` §3 row A). Mentioned across `tuning.md` (§Next Steps item 6, §Open work), the 2026-05-22 track-pacer §Recommendations §1, and indirectly by the V7 verdict #1338 "promote REFUSED on 16y panel". `promote_config.sh` (#1234) + Calmar/Sortino primary gate (#1359) shipped. Missing: the `validation.sexp` aggregate writer + REFERENCE scenario panel. Recommendation: ESCALATE_TO_MAINTAINER — decide between (a) spawning a `cross-scenario-validation` track row or (b) folding as a multi-PR block under `tuning`. Open for 9+ days since the track-pacer raised it.
- **EODHD bars-retention recovery for delisted symbols** (e.g. SCTY/MNK/LB have 0 bars). Mentioned in `data-foundations.md` §"Next Steps". Not vendor-shaped — accept-or-synthesize decision pending. Recommendation: KEEP_AS_INFO — low-priority, but should land an explicit decision in `decisions.md` before the data-foundations track wraps.

## Recommendations

1. **Refresh `dev/status/orchestrator-automation.md`** to reflect PR-D'c MERGED via #1332 (2026-05-27). Either re-wrap the track on Phase 1 stable per the 2026-05-22 track-pacer §P6 recommendation (carrying as IN_PROGRESS without dispatch for 9+ further days is the same anti-pattern flagged then) or queue a concrete Phase 2 win.
2. **Refresh `dev/status/data-foundations.md` §Next Steps** to retire the IWV scrape item and re-state the post-EODHD-`?delisted=1` next actions. The current item-1 invites a dispatch on obsoleted work.
3. **Decide on the cross-scenario-validation surface** — either spawn its own track row or fold under `tuning` as a multi-PR block (per 2026-05-22 §Recommendations §1, now 9+ days carried). The Calmar/Sortino gate (#1359) + V7 promote-REFUSED verdict (#1338) make it operationally load-bearing today; the formal track-or-block decision is the unblock.
4. **Scope an M6.6 plan PR** — even if implementation defers, having a written plan unfreezes the M6 → M7 critical path. Same shape as the previous milestone plans under `dev/plans/`.
5. **Refresh `dev/status/backtest-perf.md` §Open work** — the cost-model wiring sub-list is now stale (the `cost-model` track row in `_index.md` records the end-to-end MERGE 2026-05-23).
6. **Consider recording the EODHD `?delisted=1` discovery in `decisions.md`** so that vendor decisions live in a single discoverable location (currently spread between `memory/` and `_index.md` reconcile preambles).

## Stats
- 101 PRs merged in last 7 days (all tracks; main commit log)
- 616 PRs merged in last 30 days
- 6 active / 4 slowing / 0 stalled (out of 10 IN_PROGRESS/READY_FOR_REVIEW; tuning-methods PENDING/dormant counted separately)
- 0 [info] items carried ≥3 reconciles
- 3 capability gaps flagged (M6.6 live cycle; cross-scenario-validation track-shape decision; EODHD bars-retention recovery)
