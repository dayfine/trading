# Track Pacer Report — 2026-06-07

## Summary
- Tracks audited: 33 (index rows); 13 non-MERGED (IN_PROGRESS / READY_FOR_REVIEW / PENDING)
- Active (≥1 PR last 7d): 4
- Slowing (7–30d since last PR): 7
- Stalled (>30d): 2
- [info] items needing decision: 0 (no open `[info]` carried in the live index header)
- Capability gaps flagged: 4

## Active tracks (≥1 PR last 7d)
- **stage-accuracy** — 3 feat/experiment PRs (#1464 macro-bearish held-exposure trim, #1458 late-Stage2-dial confirmation grid, #1446 late-Stage2 stop-tighten dial) + #1441 stage_chart lifecycle CSV; theme: held-exposure drawdown levers off the stage-lifecycle diagnosis — all default-off, all REJECTED on the confirmation grid (#1458, #1466).
- **backtest-perf** — 4 feat PRs (#1468 snapshot LRU cache + counters, #1454 warmup-windowed snapshot warehouse, #1453 build-snapshots date windowing, #1450 `--snapshot-dir`) plus golden migrations #1455/#1449; theme: snapshot-warehouse infra for large-N backtests (breadth/top-3000 enablement).
- **spy-only-reference** — 1 feat PR (#1438 sector-rotation scenario-universe opt-in + per-sector cap dials, merged 2026-06-03); theme: multi-symbol carrier comparison on the sector-rotation testbed.
- **experiment-platform** — last directly-attributed feat PRs #1409 (write_ledger_entry CLI) + #1407 (`--lifetime-trials`), both 2026-06-01 (6d); theme: population-search apparatus. Note: the substantive experiment activity has migrated to stage-accuracy; the platform's two remaining levers are data-gated (lever #1) or FRAGILE (lever #2).

## Slowing tracks (7–30d since last PR)
- **tuning** — last PR #1333 was 11 days ago (2026-05-27); theme: research-driven program v2 M1 complete (T1.1–T1.5 all merged). Recommendation: KEEP_AS_INFO — M2 (qNEHVI) awaits a maintainer GHA-enablement commit (precedent #1327); not orchestrator-dispatchable until then.
- **orchestrator-automation** — last PR #1336 was 10 days ago (2026-05-28); Phase 1 stable, Phase 2 deferred, "no outstanding work surface." Recommendation: KEEP_AS_INFO (winding down — consider closing, see P6).
- **sweep-perf** — last PR #1323 (Win #3) was 12 days ago (2026-05-26); theme: sweep perf wins. Recommendation: KEEP_AS_INFO — all 3 orchestrator-eligible wins merged; remaining follow-ups (manual ghcr.io flambda-image rebuild + Win #4 production wiring) are maintainer-local / feat-backtest.
- **tuning-methods** — last PR #1283 (plan) ~14 days ago (2026-05-24); explicitly DEMOTED per the v6 random-baseline verdict ("surface is the bind, not the surrogate"). Recommendation: KEEP_AS_INFO (PENDING, not priority).
- **short-side-strategy** — last PR #1274 was 15 days ago (2026-05-23); Phase 3 verdict locked (margin edge negligible in 3 of 4 bear windows; keep `margin_config.enabled=false`). Recommendation: KEEP_AS_INFO (steady state, no next action by design).
- **data-foundations** — last clearly on-scope feat-data work mid-to-late May (CSV-manifest stack + asset-type/snapshot decomposition through ~2026-05-22; PIT-universe snapshots #1390 on 2026-05-31); has sat at READY_FOR_REVIEW for ~3 weeks. Recommendation: ESCALATE_TO_MAINTAINER — decide whether to action the remaining bars-retention-recovery gap (synthesize vs accept loss) or close the track.
- **harness** — last track-scoped PR #1011 was ~29 days ago (2026-05-09); index notes "no eligible T1/T3 item (unchanged since 2026-05-22)." Recommendation: KEEP_AS_INFO (Tier 1 done, Tier 2 milestone-gated, Tier 3 drained — effectively at steady state; borderline-stalled).

## Stalled tracks (>30d since last PR)
- **simulation** — last PRs #916/#920 at 2026-05-08 (~30 days); reason: remaining items are local-only baseline reruns + M5 walk-forward/tuner catch-all with no GHA-dispatchable surface. Recommendation: KEEP_AS_INFO (no clean autonomous surface; revisit when walk-forward work is scoped).
- **cleanup** — last backlog PR #578 (>40 days); reason: standing reactive janitor track, backlog empty, fires only on weekly-deep-scan or post-run findings. Recommendation: KEEP_AS_INFO (exempt — reactive by design, not genuinely stalled).

## Next Steps staleness (P2)
- **weekly-snapshot** — status file `## Last updated: 2026-05-04` (34 days stale); `## Status` still reads `PENDING` while the index row reads MERGED; `## Next Steps` item 1 is "Wait for M5.1 hardening to land (CI green)" but M5.1 was RESOLVED by #752 (the file's own `## Blocked on` section says so). Recommend refreshing the status file to reflect M6.1–M6.5 MERGED + M6.6 DEFERRED. Recommendation: KEEP_AS_INFO.
- **backtest-perf** — index explicitly notes the status file `§Open work` block is stale ("refresh deferred until next dispatched-on-this-track run"); the file header was bumped 2026-06-04 but the open-work body lags. Recommendation: KEEP_AS_INFO.

## [info] items needing decision (P3)
- None. The live index header (2026-06-06 reconcile) carries no open `[info]`. The historically recurring `[info]`s (qc-structural review-file persistence gap; H3 advisory-linter false-positive) were resolved — review-file dual-write dropped via PR-D'c #1332 (2026-05-27); the H3 item has not recurred since ~2026-05-12.

## Tracks without owner (P4)
- None. All non-MERGED tracks have owners. The two tracks created within the last 14 days (stage-accuracy ~2026-06-04, spy-only-reference ~2026-05-31) both carry Owner = feat-weinstein.

## Recurring discussion topics (P5)
- None unresolved in `dev/decisions.md`. The only entries inside the 30-day window are the two 2026-05-16 vendor-pivot entries, both closed with an explicit Decision (Option B — IWV scrape primary; Norgate retired). Note: the load-bearing strategic discussion now lives in `dev/notes/next-session-priorities-*.md`, not `decisions.md`.

## Diminishing returns (P6)
- No track trips the maintenance heuristic (≥3 of last 5 PRs being chore/fmt/golden/repin) — the active tracks are shipping genuine feat/experiment PRs, not janitorial churn.
- **Strategic-fit signal (not the maintenance heuristic):** **stage-accuracy** and **experiment-platform** are in a sustained build-mechanism → land-default-off → REJECT loop. Recent rejected/fragile levers: late-Stage2 stop-tighten (REJECT, #1458), macro-bearish held-exposure trim (REJECT, #1466), early-admission deep-27y (REJECT, #1387), exit-timing surface (REJECT, #1391/#1394), stage3 hysteresis (REJECT, #1366), neutral_blocks_longs (FRAGILE, #1412). The recurring conclusion across these is "**breadth is the lever, not these dials**." Recommendation: ESCALATE_TO_MAINTAINER — consider pausing single-dial mechanism exploration until the breadth/broad-universe lever (P7) is actually tested.
- **orchestrator-automation** is at "no outstanding work surface" with Phase 2 deferred; candidate to formally close (KEEP_AS_INFO).

## Capability gaps (P7)
- **Broad-universe / breadth test (lever #1)** — mentioned across experiment-platform AND spy-only-reference ("top-1000 bankability gate"); DATA-GATED >30 days (no `EODHD_API_KEY` in GHA; deep PIT OHLCV absent from the container). This is the single highest-value unblock — the strategy program's repeated conclusion is that breadth, not dial-tuning, is the edge, yet the test that would confirm it cannot run autonomously. Recommendation: ESCALATE_TO_MAINTAINER (run the broad-universe fetch + test locally).
- **M6.6 True live cycle** — live `DATA_SOURCE` + cron + alert dispatch + trading-state durability; status: not started (DEFERRED per weekly-snapshot plan). On the critical path to M6 completion / actually trading; M6.1–M6.5 verification harness already shipped. Recommendation: ESCALATE_TO_MAINTAINER (decide when to schedule the live-cycle wiring).
- **M7.1 Train/test ML** — walk-forward leakage-safe ML tuning (oracle = optimal-strategy counterfactual); status: not started (tuning track covers M5.5/Bayesian only). Recommendation: KEEP_AS_INFO.
- **M7.2 Synthetic stress** — reject tuned configs that fail stress on Synth-v3 80yr histories; Synth v1/v2/v3 generators already built (data-foundations), but the config-rejection gate is not started. Recommendation: KEEP_AS_INFO.

## Recommendations
1. **Decide the breadth/broad-universe test (lever #1).** It is data-gated >30 days, blocks the program's central thesis, and is referenced by two tracks. Run the EODHD broad-3000 fetch + 2020-2026 test locally, or explicitly defer with a date. (ESCALATE)
2. **Pause single-dial strategy-mechanism exploration.** Six consecutive levers have landed default-off and been REJECTED/FRAGILE; the recurring finding is "breadth is the lever." Redirect stage-accuracy/experiment-platform effort behind the lever-#1 result. (ESCALATE)
3. **Resolve data-foundations (READY_FOR_REVIEW ~3 weeks).** Decide bars-retention recovery (synthesize vs accept SCTY/MNK/LB loss) or close the track. (ESCALATE)
4. **Refresh stale status files:** weekly-snapshot.md (Status PENDING vs index MERGED; Next-Step #1 waits on already-landed M5.1) and backtest-perf.md §Open work. (KEEP_AS_INFO)
5. **Close winding-down tracks:** orchestrator-automation (Phase 1 stable / Phase 2 deferred / no work surface) and consider flipping harness to a steady-state/closed marker. (KEEP_AS_INFO)
6. **Schedule M6.6 live-cycle planning** — the verification harness (M6.1–M6.5) is done; live wiring is the next capability milestone and is currently unowned/unscheduled. (ESCALATE)

## Stats
- 84 commits merged on main in last 7d (2026-05-31 → 2026-06-07, all tracks incl. ops/docs/chore)
- 493 commits merged on main in last 30d (2026-05-08 → 2026-06-07, all tracks)
- 4 tracks active / 7 slowing / 2 stalled (of 13 non-MERGED tracks)
- 0 `[info]` items carried ≥3 reconciles (review-file gap resolved via #1332)
- 4 capability gaps flagged (broad-universe/breadth test, M6.6 live cycle, M7.1 ML, M7.2 synthetic stress)
