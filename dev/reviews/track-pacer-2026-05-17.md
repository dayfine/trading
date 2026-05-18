# Track Pacer Report — 2026-05-17

## Summary
- Tracks audited: 9 non-MERGED (8 IN_PROGRESS + 1 READY_FOR_REVIEW); 1 orphan track file (`cost-model`) missing from index
- Active (≥1 PR last 7d): 8
- Slowing (7–30d since last PR): 1
- Stalled (>30d): 0
- [info] items needing decision: 2 (carried 7+ reconciles)
- Capability gaps flagged: 3

## Active tracks (≥1 PR last 7d)
- **tuning** — 5 PRs (#1126, #1132, #1136, #1143, #1145); theme: Bayesian Phase 3 stack PR-A → PR-E (scoring fn → knob inventory → walk-forward in-process integration → length-scale + early-stop + Option encoding → end-to-end runner + OOS validator). Maintainer cadence rapid (full 5-PR stack landed in ~24h).
- **data-foundations** — ~17 PRs (#1103/#1104 broad-3000 cohort; #1112/#1118/#1120/#1122 IWV scraper PR-A–PR-D; #1137/#1138/#1147 IWV fetcher fixes + GHA workflow_dispatch; #1140/#1141 Shiller ingest + cross-validator; #1142/#1146/#1148/#1149/#1150 CSV-manifest Phase 1/2/3 + reconcile log + Stooq drift detector; #1152 Kenneth French 5-Industry ingest; #1156/#1157/#1159/#1160 EODHD Asset_type parse + bulk asset-type enrichment + filter_equity_like + shares-outstanding Q2-A PR1); theme: IWV scraper tooling COMPLETE + multi-source data quality cross-validators + bulk inventory enrichment.
- **harness** — 7 PRs (#1117, #1121, #1130, #1131, #1138, #1153, #1158); theme: CI hardening — race-proof check, cache restore-keys removal, image rebuild for `-march=x86-64-v2`, IWV retry-with-backoff, csv-storage/csv-manifest test guards. No new harness *features* shipped — entirely fix/infra.
- **experiments** — 4 PRs (#1090, #1091, #1095, #1097); theme: targeted parameter sweeps (M5.6 slippage, continuation-buys tuning + combined-axis, PI-filter 16y survivorship validation). Single-lever tuning under Cell E exhausted per `memory/project_m5-5-tuning-exhausted.md`.
- **simulation** — 3 PRs (#1119, #1123, #1128); theme: margin Phase 2 simulator wiring + NAV silent-cash-fallback removal (fail-loud) + nesting linter fix in `portfolio_valuation.compute`.
- **short-side-strategy** — 3 PRs (#1113, #1115, #1119); theme: margin accounting Phase 1 (Reg-T collateral + borrow fee) + Phase 2 (daily borrow accrual + maintenance force-cover) + 1 file-length fix-forward extracting `portfolio_margin`.
- **orchestrator-automation** — 3 PRs (#1099, #1127, #1134); theme: daily ops summary auto-emission only. Zero feature work; Phase 2 (background execution) remains PLANNED with no active dispatch since 2026-05-04.
- **backtest-perf** — 1 PR (#1151); theme: cost-model overlay — 4 independent cost knobs. (Note: this PR is the canonical surface for the as-yet-unindexed `cost-model` track — see P4 below.)

## Slowing tracks (7–30d since last PR)
- **cleanup** — last cleanup-prefixed PR #978 at 2026-05-08 (9 days ago); status file dated 2026-05-08; 4 `[~]` in-flight items still listed (garch/snapshot_writer/split_detector nesting, pick_diff+snapshot_manifest nesting, ticker_aliases avg-nesting, simulator.step fn_length). Inferred reason: no new health-scan `[medium]`/`[high]` findings surfaced in recent reconciles (backlog absorption complete). Recommendation: KEEP_AS_INFO — track is by design demand-driven on health-scan output, but the stuck `[~]` items deserve a sweep.

## Stalled tracks (>30d since last PR)
- None.

## Next Steps staleness (P2)
- **simulation** — `dev/status/simulation.md` last updated 2026-05-06; `## Next Steps` still says "Walk-forward backtest (M5): parameter tuner with validation period" as a future item. Both walk-forward CV harness (`walk-forward-cv` track MERGED 2026-05-16 via #1100/#1111/#1116) and the M5.5/Phase-3 Bayesian tuner (`tuning` track, #1126→#1145 stack) have since shipped. Recommend refreshing status file or marking the M5 catch-all bullets RESOLVED with cross-track pointers.
- **tuning** — `dev/status/tuning.md` last updated 2026-05-16 and only reflects Bayesian Phase 3 PR-A + PR-B merged; PR-C #1136, PR-D #1143, and PR-E #1145 have since merged (within the past ~24h). The "Next: PR-C through PR-E sequenced" clause is now stale. Recommend refreshing once today's PR-D/E settle.
- **experiments** — Last updated 2026-05-13. `## Next Steps` item 5 "Stability + turnover metrics — Track wraps after this PR" refers to #1073 which merged the same day (2026-05-13). Either the file was written before #1073 landed or the wrap was never recorded. Recommend flipping the item to DONE and either wrapping the track or restating the next experiment surface (e.g. Phase 2 walk-forward CV consumer experiments).
- **backtest-perf** — Last updated 2026-05-13; does not yet reflect #1151 cost-model overlay (today). Borderline — file is 4 days old. No action urgent.
- **harness** — Last updated 2026-05-08; does not reflect recent CI fixes (#1121, #1130) or test-guard PRs (#1153, #1158). 9 days stale. Recommend refresh.

## [info] items needing decision (P3)
- **qc-structural recurring H3 false-positive on advisory linter text** — carried in reconcile preambles across 2026-05-03 (run-1), 2026-05-03 (run-2), 2026-05-04, 2026-05-05, 2026-05-07 (run-1), 2026-05-07 (run-2), 2026-05-10 (run-2) — at least 7 reconciles since 2026-05-03 with no resolution recorded; recommended action: ESCALATE_TO_MAINTAINER (either fix the qc-structural H3 detector or formally accept the false-positive pattern).
- **qc-structural review-file persistence gap** (`/w/...` vs `/__w/...` path typo on some runs) — carried in the same set of reconciles (7+) since 2026-04-30; recommended action: ESCALATE_TO_MAINTAINER. Per the 2026-05-04 reconcile note, the gap has not surfaced in the most recent runs (review-file written correctly on PR #703 and PR #805), but no explicit fix has been recorded — recommend formally marking RESOLVED in the next orchestrator run if the gap stays dormant, otherwise patch the agent.

(Lower-severity carried [info]s — `magic_numbers linter false-positives on docstring text`, `status_file_integrity 7 advisory FAILs` — are harness-backlog candidates and do not require a decision this week.)

## Tracks without owner (P4)
- None of the IN_PROGRESS / READY_FOR_REVIEW tracks in the index have an empty Owner column.
- **Index drift (adjacent finding):** `dev/status/cost-model.md` exists (Last updated 2026-05-17, Status READY_FOR_REVIEW, Interface stable YES) but has no row in `dev/status/_index.md`. The track is implicitly owned by `feat-backtest` (PR #1151 landed under that surface). Recommend adding a row in the next reconcile.

## Recurring discussion topics (P5)
- None unresolved. Both 2026-05-16 vendor-pivot decisions (Norgate retired; IWV scrape becomes primary) are resolved on the same day they were filed. The 2026-05-03 agent-scope decision (extend feat-backtest + create feat-data) is resolved. No multi-entry unresolved topic detected in the last 30 days.

## Diminishing returns (P6)
- **harness** — last 5 merged PRs (#1117, #1121, #1130, #1131, #1138) are 4 fixes + 1 ops workflow_dispatch; matches the heuristic (≥3 of last 5 are `fix(*)`/CI infra). By design, harness is the maintenance surface, but the absence of any new feature shipping since T1-S (branch-protection on `main`, 2026-05-08) is worth noting; Tier 2 items are milestone-gated, Tier 3 mostly drained, Tier 4 not auto-dispatched. Recommendation: KEEP_AS_INFO — natural state for a wrapped Tier 1.
- **orchestrator-automation** — last 5 PRs are all auto-emitted daily summaries (#1065, #1093, #1099, #1127, #1134). Status file (last updated 2026-05-04) explicitly says Phase 2 (background execution) "remains PLANNED. No active dispatch." If Phase 2 is not going to ship, recommend wrapping the track MERGED rather than leaving it IN_PROGRESS indefinitely. Recommendation: ESCALATE_TO_MAINTAINER for explicit close-or-prioritise decision.

## Capability gaps (P7)
- **M6.6 — True live cycle** (`live` DATA_SOURCE + cron + alert dispatch + trading-state durability). Mentioned in `weekly-snapshot.md` Next Steps (explicitly DEFERRED), referenced in `weinstein-trading-system-v2.md` §3 as the target operating state, and the entire point of M6. No active track owns it. Milestone: M6.6. Status: not started; deferred per plan. Recommendation: KEEP_AS_INFO — explicit deferral, not orphan work, but the maintainer should periodically reassess whether to spin a track for it (the system goal per §3 cannot ship without it).
- **M7.1 / M7.2 — ML training + synthetic stress.** Mentioned in design doc §7 (milestone refinement); not started; no status file. The tuning track's Bayesian Phase 3 (#1126→#1145) covers the M5.5 grid+Bayesian portion, but the M7.1 train/test ML and M7.2 antifragility-on-synth pipelines are not yet in flight. Recommendation: KEEP_AS_INFO — natural to defer until walk-forward CV + Bayesian Phase 3 stack settles and there is empirical evidence Phase 3 outputs converge.
- **shares-outstanding bulk run (Q2-A PR1 follow-through)** — `data-foundations.md` (today): library + binary built, but bulk run blocked on EODHD Fundamentals tier upgrade ($59.99/mo standalone or €99.99/mo bundled) or swap to alternate source (Sharadar via Nasdaq Data Link, AlphaVantage). Same blocker as the parked Phase 1.1 (`HistoricalTickerComponents` 403). Vendor-blocked but with a documented mitigation list. Recommendation: ESCALATE_TO_MAINTAINER for a tier-vs-alternate-source decision (or formally defer).

## Recommendations
1. **Refresh stale status files** — `simulation.md` (11 days stale, missing #1119/#1123/#1128); `tuning.md` (missing PR-C #1136 / PR-D #1143 / PR-E #1145); `experiments.md` (item 5 was DONE same-day via #1073). One small reconcile commit covers all three.
2. **Add `cost-model` row to `dev/status/_index.md`** — track was created 2026-05-17 (status READY_FOR_REVIEW, owner implicitly feat-backtest via PR #1151) but no index row exists.
3. **Dispatch `ops-data`** to run the IWV scrape (`fetch_iwv_history.exe --start 2006-09-29 --end 2026-05-16 --cadence auto --polite-spacing 2.0` then `build_iwv_universe.exe`). Tooling COMPLETE; only operational run remains to unblock Russell-3000 2006–2026 survivorship-aware backtests. The GHA `iwv-scrape-once workflow_dispatch` (#1138) also enables an IP-independent path.
4. **Decide on orchestrator-automation Phase 2** — track has been IN_PROGRESS with no feature dispatch since 2026-05-04. Either spin up the Phase 2 empirical tests (background execution + harvest) or mark the track MERGED on Phase 1's stable operating state.
5. **Resolve recurring [info] items** (qc-structural H3 false-positive; review-file persistence gap) — carried 7+ reconciles. Either patch the agent or record explicit acceptance.
6. **Sweep the cleanup `[~]` in-flight items** — 4 items dated 2026-05-07/08 still marked in-flight (garch/snapshot_writer/split_detector final-tail nesting, pick_diff+snapshot_manifest nesting, ticker_aliases avg-nesting, simulator.step fn_length). Either dispatch `code-health` to finish or close as superseded.
7. **Make a shares-outstanding source decision** — EODHD Fundamentals add-on ($59.99/mo) vs Sharadar/AlphaVantage swap vs formally park. Currently blocking the Q2-A PR1 bulk run.
8. **Reassess M6.6 timing** — the target operating state from §3 cannot ship without it, but it is consistently deferred. Worth a quarterly check on whether to scope a feature track (or formally accept indefinite deferral while M5 tuning matures).

## Stats
- 136 PRs merged in last 7d (all tracks)
- 730 PRs merged in last 30d (all tracks)
- 8 tracks active / 1 slowing / 0 stalled (of 9 non-MERGED tracks audited)
- 2 [info] items carried ≥3 reconciles (qc-structural H3 FP; review-file persistence gap)
- 3 capability gaps flagged (M6.6 live cycle; M7.1/M7.2 ML+synth-stress; shares-outstanding fundamentals source)
- 1 index-vs-files drift finding (cost-model.md exists but has no `_index.md` row)
