# Track Pacer Report — 2026-05-22

## Summary
- Tracks audited: 9 non-MERGED (7 IN_PROGRESS + 2 READY_FOR_REVIEW: `cost-model`, `data-foundations`); 5-day window since last pacer report (2026-05-17 13:00Z)
- Active (≥1 PR last 7d): 8
- Slowing (7–30d since last PR): 1 (`cleanup`)
- Stalled (>30d): 0
- [info] items needing decision: 2 (qc-structural recurring [info]s carried since 2026-04-30 / 2026-05-03 — re-flagged, NOT resolved)
- Capability gaps flagged: 4 (M6.6 live cycle; M7.1/M7.2 ML+synth; shares-outstanding source; **NEW: cross-scenario validation as load-bearing methodology gap per PR #1237**)

## Active tracks (≥1 PR last 7d)

- **tuning** — ~25 PRs since 2026-05-17 (V1→V7 Bayesian sweep stack: #1192 plan, #1196 spec.objective plumbing plan, #1210 V1 REJECT, #1214 PR-1 plumbing, #1216 PR-2 Composite + Calmar + TotalReturn + Concavity_coef, #1217 PR-3 doc, #1219 P4 per-stage hold-period decomposition, #1220 AvgHoldingDays in Composite, #1222 V2 REJECT, #1224 bo_checkpoint.sexp for resume, #1225 V3+V3-cadence specs, #1226 V3 smoke + QC writeups, #1229 soft gate penalty + V4 spec, #1232 V3 result + axis-3 gate-fitness proposal, #1234 `promote_config.sh` + tuning methodology design doc, plus open PR #1231 V5 spec, #1236 V5 partial + V6 specs, #1237 tuning-methodology-redesign-2026-05-22). Theme: aggressive iteration on Bayesian sweep methodology — V1, V2 both REJECTED; V3 promotable under one gate variant but V4/V5/V6/V7 hypotheses all produced byte-identical scores to V3. The week's discovery is that **the 4-param surface has plateaued** and the methodology itself (not bounds, not gate, not random seed) is the bottleneck. See P6 for diminishing-returns flag.
- **data-foundations** — ~19 PRs since 2026-05-17 (delisted-aware enrichment pipeline #1183/#1184/#1185/#1186/#1187/#1190; weinstein-2019-top-500 cell into postsubmit #1182; composition-bar-coverage audit #1181; random-universe sweep + selection-bias finding #1180/#1191; #1175 universe perf fix (OOM); #1177 simulator CancelEntry rejected-fill fix; #1183 delisted-roster unblocks PIT-universe; tunable-parameter inventory + private-config-repo design #1178; M1 Shiller pinned monthly fixture #1207; M2 PR-C French 49-Industry daily ingest #1209; M2 PR-D French 49-industry Weinstein rotation #1211; #1212 MA-window unit-tag fix; #1213 M2 result + M3 deferral note; #1194 sectors.csv 40 famous delistings backfill; #1235 drop cosmetic `[name]` field −4.8 MB). Theme: deep-history cross-cycle Weinstein validation (Shiller 1871, French 1926-2026, 100y Sharpe 0.81 rotation strategy) + delisted-symbol enrichment unblocking PIT-universe agenda + survivorship-bias diagnostic on composition goldens.
- **backtest-perf** — 4 PRs (#1199 `Gc.compact` between folds + `_extract_fold` scoping; #1200 `Fork_pool` library; #1202 `Fork_pool` wired into `Walk_forward_executor`; #1203 `--parallel` CLI flag on walk_forward + bayesian runners). Theme: fork-based job parallelism for walk-forward + Bayesian runners, motivated by base.Random DLS leak (#1201) requiring fresh process per fold. Genuine perf feature surface (not just maintenance) — distinct from prior weeks' "all chore/fix" cadence.
- **simulation** — 1 PR (#1177 fix(simulator): surface rejected fills via CancelEntry so strategies retry, P0a-residual). Theme: residual fix-forward from the BAH gap-buffer work.
- **harness** — 2 PRs (#1198 ops: weekly deep health scan 2026-05-18; #1227 rules: promote session-tested QC + merge + rampup norms from memory to repo). Theme: meta — the harness track's role this week was promoting agent-norms from user memory to `.claude/rules/` (an institutional-knowledge-capture PR), not feature work.
- **walk-forward-cv** — 0 net-new feature PRs; harness is COMPLETE since #1100/#1111/#1116 (2026-05-16). Consumed by tuning (Bayesian runner integration in PR #1136/#1145). Plan PR #1197 (parallelise executor) landed as design doc, implementation lives under `backtest-perf` (#1200/#1202). Recommend KEEP track row as MERGED.
- **screener** — 0 net-new PRs (MERGED, last touched via #1089/#1094 in week prior). Theme: track wrapped.
- **portfolio-stops** — 0 net-new PRs (MERGED, last touched via #1098 sector cap in week prior). Theme: track wrapped.

(`orchestrator-automation` has 5+ daily-summary PRs (#1188, #1193, #1199 [no — #1199 is backtest], #1204, #1205, #1218, #1221, #1230, #1233) but **all are auto-emitted by Phase 1 cron** — zero feature work. Counted under §P6 Diminishing Returns, not Active.)

## Slowing tracks (7–30d since last PR)

- **cleanup** — last non-stale activity at PR #978 (2026-05-08, 14 days ago); 4 in-flight `[~]` items dated 2026-05-07/08 still listed in status file Backlog (garch/snapshot_writer/split_detector final-tail nesting; pick_diff+snapshot_manifest nesting; ticker_aliases avg-nesting; simulator.step fn_length). #1198 weekly deep health scan landed 2026-05-18; if it surfaced new findings, none have been triaged into the cleanup backlog yet. Recommendation: KEEP_AS_INFO + sweep — flagged identically in 2026-05-17 pacer; no movement in 5 days.

## Stalled tracks (>30d since last PR)

- None.

## Next Steps staleness (P2)

- **simulation** — `dev/status/simulation.md` last updated 2026-05-06 (16 days stale); `## Next Steps` still says "Walk-forward backtest (M5): parameter tuner with validation period" as a future item. Walk-forward CV harness MERGED via #1100/#1111/#1116 (2026-05-16); Bayesian Phase 3 stack MERGED via #1126→#1145 (2026-05-17); V1→V3 production sweeps run (#1210/#1222/#1232). Flagged in 2026-05-17 pacer; **still not refreshed**. Recommend: refresh on next dispatch.
- **experiments** — `dev/status/experiments.md` last updated 2026-05-13; `## Next Steps` item 5 "Stability + turnover metrics — Track wraps after this PR" refers to #1073 which merged 2026-05-13. Flagged in 2026-05-17 pacer; **still not refreshed**. The track also doesn't reflect P4 hold-period analysis (#1219) or random-universe selection-bias sweep (#1180/#1191) which are arguably "experiments" surface. Recommend: refresh or formally wrap.
- **tuning** — `dev/status/tuning.md` last updated 2026-05-16. `## In Progress` block claims PR-A "IN REVIEW" and PR-B MERGED; reality is PR-A through PR-E all MERGED 2026-05-17, and the V1→V7 production sweep stack has run on top. The 9-line "Next Steps" section refers to "rerun the 81-cell flagship sweep" which is no longer the active work surface — the active surface is V3-promote vs cross-scenario validation per `dev/plans/tuning-methodology-redesign-2026-05-22.md` (PR #1237). Flagged in 2026-05-17 pacer; **still not refreshed**. Recommend: full status-file rewrite to reflect Bayesian Phase 3 COMPLETE + V1-V3 result narrative + methodology-redesign pivot.
- **harness** — `dev/status/harness.md` last updated 2026-05-08 (14 days stale); doesn't reflect #1198 weekly deep health scan, #1227 rules promotion. Flagged in 2026-05-17 pacer; **still not refreshed**.
- **backtest-perf** — `dev/status/backtest-perf.md` last updated 2026-05-13; doesn't reflect #1151 cost-model overlay nor the #1199/#1200/#1202/#1203 fork-pool parallelism stack. Flagged in 2026-05-17 pacer; **still not refreshed**.

5 of 9 active/READY tracks have stale Next Steps that were flagged a week ago and still are not refreshed. **This is the dominant pacer signal this week** — agent reconciles aren't running on the rapid maintainer-driven session output.

## [info] items needing decision (P3)

- **qc-structural recurring H3 false-positive on advisory linter text** — carried in reconcile preambles since 2026-05-03; still listed in 2026-05-17 `_index.md` preamble as carried; flagged in 2026-05-17 pacer P3; **NOT resolved** as of 2026-05-22. Recommended action: ESCALATE_TO_MAINTAINER (either patch the agent's H3 detector or formally record acceptance of the false-positive pattern).
- **qc-structural review-file persistence gap** (`/w/...` vs `/__w/...` path typo on some runs) — carried since 2026-04-30. The 2026-05-17 pacer noted that the gap had not surfaced in the most recent runs (review-file written correctly on PR #703/#805) but no explicit fix or RESOLVED marker was recorded; **same situation** today. Recommended action: formally mark RESOLVED in next orchestrator run, OR patch the agent if intermittent. Either way, take action — carrying for 7+ weeks without decision is the failure mode.

(Lower-severity carried `[info]`s — magic_numbers docstring false-positives, status_file_integrity advisory FAILs — remain harness backlog candidates; no decision needed this week.)

## Tracks without owner (P4)

- None. Of 9 non-MERGED tracks, every row in `dev/status/_index.md` has an Owner column populated (`feat-backtest`, `feat-data`, `feat-weinstein`, `harness-maintainer`, `code-health`, `harness-adjacent`). The `cost-model` row added 2026-05-17 per the prior pacer recommendation is now in the index with owner `feat-backtest`.

## Recurring discussion topics (P5)

- **Cross-scenario / cross-universe generalization as the load-bearing missing methodology** — appears in `dev/notes/next-session-priorities-2026-05-21-pm.md` §"V2 result", `dev/plans/tuning-methodology-redesign-2026-05-22.md` (entire doc), `dev/plans/private-tuned-configs-repo-2026-05-18.md`, and #1180 + #1191 random-universe sweep findings. **Multiple decision items**: (a) cross-scenario validation as promote-gate vs as BO training input (PR #1237 §2.5); (b) optimal-strategy quality refresh as prerequisite (#1237 §2.6); (c) feature flags as 0/1 BO knobs (#1237 §2.7); (d) component-decomposition objective (#1237 §2.8). Recommended action: RECOMMEND_NEW_TRACK candidate — `cross-scenario-validation` is a natural track since it has its own plan, distinct surface (`promote_config.sh` + `validation.sexp` aggregate writer + reference scenario panel), and is the gate for any further tuning work per #1237 §9 explicit deferral.
- **V3-V7 sweep methodology debate** — appears in #1226 V3 smoke writeup + #1229 V4 soft penalty + #1232 V3 result + axis-3 gate-fitness proposal + open #1231 V5 spec + #1236 V5 partial + #1237 methodology redesign. The convergence is now resolved per #1237 (V3-V7 stack is sufficient; further 4-param sweeps explicitly deferred). KEEP_AS_INFO — internal evolution, resolved on file.

## Diminishing returns (P6)

- **tuning** — last 25 PRs are dominated by `feat(tuner)` + `feat(scoring)` + `tuning:` spec sexps + `docs(notes): VN result REJECT` writeups + plan docs. The week's 5 sweep iterations (V3, V4, V5, V6, V7) **converged on byte-identical trajectories** by V5 per #1237 §1. This pattern (incremental hypothesis-tweaks producing identical results) is the classical diminishing-returns signal — **though differently from prior weeks**: this is not maintenance fatigue, it's optimisation-surface plateau. The maintainer's own diagnosis in #1237 explicitly names this and explicitly defers further 4-param sweeps until cross-scenario validation lands. Recommendation: KEEP_AS_INFO — the diminishing-returns signal is acknowledged + acted on in PR #1237; track will shift to cross-scenario validation work next. **Was this productive?** Yes for methodology evolution (Composite scorer shipped, soft-gate landed, checkpointing landed, promote-gate scaffolding landed); No for parameter-discovery (V3 winner still the only candidate, gate ambiguous). Net: useful diagnostic week, but the work pace if continued on 4-param surface would burn budget for zero new alpha.
- **orchestrator-automation** — 5+ daily-summary PRs and nothing else since 2026-05-04. Same situation as flagged in 2026-05-17 pacer; **no movement on Phase 2** in 5 days. Recommendation: ESCALATE_TO_MAINTAINER (same recommendation as 2026-05-17) — either dispatch Phase 2 experiments or wrap track MERGED on Phase 1's stable state. Carrying as IN_PROGRESS without dispatch for 18+ days is the same problem we flag for stale Next Steps.
- **harness** — 2 PRs in 5d, both non-feature (#1198 = ops, #1227 = rules promotion). Consistent with 2026-05-17 pacer's "natural state for a wrapped Tier 1" finding. KEEP_AS_INFO.

## Capability gaps (P7)

- **Cross-scenario validation as the promote gate** (NEW THIS WEEK; load-bearing per PR #1237). Mentioned in `dev/plans/tuning-methodology-redesign-2026-05-22.md` §2.5 + §3 row A + §5 P1 + §8. No existing track owns it — proposed `promote_config.sh` infrastructure landed via #1234 but the actual cross-scenario panel + structured `validation.sexp` writer + REFERENCE scenario list (sp500-2010-2026, sp500-2019-2023, broad-2019, French 49-industry 1926-2026, Shiller 1871-2025) is unshipped. **#1237 explicitly defers all further tuning work until this lands** (§9). Recommendation: ESCALATE_TO_MAINTAINER for explicit track-spawn decision — either add `cross-scenario-validation` row to `_index.md` (P1 work per #1237) or fold into the existing `tuning` track with a re-scoped `## Next Steps` block. The capability gap is the most actionable item in this week's audit.
- **Optimal-strategy quality refresh** (NEW THIS WEEK per PR #1237 §2.6 + §8 P0). The `optimal-strategy` track is MERGED but PR #1237 flags it as a prerequisite for the `efficiency = candidate_sharpe / optimal_sharpe` Composite term that would let the Bayesian objective target alpha-capture. Concern surfaced in #856 diagnostic note (2026-05-06) but never addressed. Recommendation: KEEP_AS_INFO — gates §2.6/§2.8 of #1237; not blocking P1, but a load-bearing follow-up if BO is going to keep being used.
- **M6.6 — True live cycle** (`live` DATA_SOURCE + cron + alert dispatch + trading-state durability). Same gap flagged in 2026-05-17 pacer. PR #1237 §7 explicitly raises the question of timing now that "V3-V7 plateau suggests M5 tuning IS mature." Recommendation: ESCALATE_TO_MAINTAINER — quarterly reassessment per #1237 §10 open question; the system goal per `weinstein-trading-system-v2.md` §3 cannot ship without it, and the V3 plateau is a natural inflection point.
- **M7.1 / M7.2 — ML training + synthetic stress.** Same gap as 2026-05-17 pacer. PR #1237 §7 maps M7.2 to the §2.1 "missing randomness" gap and recommends opening a track post-cross-scenario validation. KEEP_AS_INFO.
- **Shares-outstanding bulk run** — still vendor-blocked on EODHD Fundamentals tier upgrade ($59.99/mo) per `data-foundations.md`. Same gap as 2026-05-17 pacer; **the dollar-volume pivot (#1169) is a workaround, not a resolution**. Recommendation: ESCALATE_TO_MAINTAINER — tier-vs-alternate-source decision overdue.

## Recommendations

1. **Decide on cross-scenario validation as a track** (NEW, top of queue). Either spawn `dev/status/cross-scenario-validation.md` per `dev/plans/tuning-methodology-redesign-2026-05-22.md` §3 row A, or formally add the work as a multi-PR block under `tuning`. PR #1237 explicitly defers further tuning work until this lands (§9) — this is the bottleneck for the entire `tuning` track's next session.
2. **Refresh 5 stale status files** in one reconcile commit: `simulation.md` (last updated 16d ago, missing PR-A→PR-E + V1-V3 results), `tuning.md` (last updated 6d ago, Next Steps + In Progress all stale post-PR-E), `experiments.md` (Next Steps item 5 was DONE 9 days ago), `harness.md` (14d stale, missing #1198 / #1227), `backtest-perf.md` (9d stale, missing fork-pool parallelism stack + cost-model). **All 5 were flagged in 2026-05-17 pacer and none refreshed** — this is the dominant operational debt.
3. **Decide on `optimal-strategy` quality refresh** — gates the §2.6 Composite efficiency term per #1237. Low-cost (~2-3h) but prerequisite for the next sweep dimension.
4. **Make the `orchestrator-automation` track-state decision** — Phase 2 IN_PROGRESS with no dispatch for 18+ days. Same recommendation as 2026-05-17 pacer; still unactioned.
5. **Resolve the two recurring qc-structural `[info]` items** — carried for 7+ weeks. Either patch the agent or record explicit acceptance in `dev/decisions.md`.
6. **Make the shares-outstanding source decision** — tier upgrade ($59.99/mo) vs Sharadar/AlphaVantage swap vs formally park. Q2-A is on the dollar-volume pivot, but #1169 is acknowledged as a workaround.
7. **Reassess M6.6 timing** — PR #1237 §7 + §10 explicitly raises this as an open question. V3-V7 plateau is a natural inflection point.
8. **Sweep the cleanup `[~]` items** — 4 items 14 days stale. Either dispatch `code-health` or close as superseded.

## Stats

- **76 PRs merged in last 5 days** (since 2026-05-17 13:00Z, when last pacer report wrote); ~133 PRs merged in last 7 days
- ~191 PRs merged in last 30 days
- 8 tracks active / 1 slowing / 0 stalled (of 9 non-MERGED tracks audited)
- 5 of 9 active/READY tracks have stale Next Steps flagged in 2026-05-17 pacer + still not refreshed
- 2 [info] items carried ≥3 reconciles (qc-structural H3 FP; review-file persistence gap) — flagged in prior pacer, **still not resolved**
- 4 capability gaps flagged (NEW: cross-scenario validation as promote-gate per #1237; carried: M6.6 live cycle; M7.1/M7.2; shares-outstanding)
- Tuning track ran 5 production-sweep iterations (V3, V4, V5, V6, V7) which converged on byte-identical trajectories per `dev/plans/tuning-methodology-redesign-2026-05-22.md` §1 — diminishing-returns signal acknowledged + acted on by maintainer in same plan (§9 explicit deferral of further 4-param sweeps)
