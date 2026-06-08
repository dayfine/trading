# Next-session priorities — 2026-06-08

**Supersedes** `next-session-priorities-2026-06-07.md`. Read this + check main CI
green (`.claude/rules/session-rampup.md`) before dispatching anything.

## TL;DR — the broad-universe verification is DONE, and it reframes the headline

The 2026-06-07 doc's #1 lever — "honest broad-universe re-baseline, +790.5% top-3000
15y" — was **verified and corrected** this session:

> **The +790.5% reproduces bit-identical and is NOT a universe-construction
> artifact — but it is MTM-inflated: ~75% is terminal unrealized mark-to-market
> on ONE open position (AXTI, $2.19→$79.22, ~36×, top-3000-only). The honest
> realized broad-universe number is +199%. Retire the +790 headline.**

But **breadth is still the real lever** — on the *robust* metrics, not the
inflated return:
- **DD-tail (the load-bearing result):** top-3000 caps peak-MaxDD at **24-33% on
  every start**; top-1000 blows out to **58-61%** on bad starts. Worst-case DD
  nearly halved. (DD-based → immune to the MTM caveat.)
- **Realized return:** +199% (top-3000) vs +68% (top-1000) = 3×, MaxDD 29 vs 58%.
- **Beats top-1000 CAGR in 8/8 matched rolling starts.**

But everything is **fat-tail + start-date driven**: even realized +199% is
top-5-winner-concentrated (remove them → net negative); top-1000 median rolling
CAGR is only **~5.6%**. Point estimates are noise; the **distribution** is the
signal.

## This session's shipped work
- **#1485** (docs) — P0 verification: +790.5% is MTM-inflated; the AXTI decomposition.
- **#1486** (docs) — P1 rolling-start dispersion: breadth caps the DD tail; ledger
  verdict audit (survivorship-robust, no flips).
- **#1484** (issue) → **#1487** (merged) — **default-off `stale_exit_after_days`**
  force-exit for stale/delisted zombie positions (was a detector-only gap inflating
  terminal NAV). Realizes the position at last close + frees cash. Axis-able.
- Honest re-baseline (top-3000, `stale_exit_after_days=5`): **450.9% / Sharpe
  0.585 / MaxDD 38.5% / Calmar 0.31 / 878 trades / only 3 open (all live — the 8
  zombies were force-exited)**. **Worse on every metric** than the zombie-carrying
  790.5% / 0.71 / 29.2%: stale-exit redeploys zombie cash into (here) worse
  positions and even *raises* MaxDD (carrying delisted names flat adds no
  volatility; redeploying into live ones does). **AXTI still dominates the
  unrealized ($4.02M)** — the single-name MTM issue is independent of zombies.
  → **default-off vindicated; stale-exit is not free; promotion needs the grid.**

## Priorities for next session

**P0 — Decide the stale-exit default + lock the honest broad-PIT baseline.**
- `stale_exit_after_days` shipped default-off (#1487). It is a **correctness**
  fix, not a strategy dial — but it changes results (frees cash, redeploys), so
  per flag-discipline it needs a confirmation grid before default-on. Run the
  grid (`.claude/rules/promotion-confirmation.md`): if it doesn't degrade across
  period×universe, **promote to default-on** so all future broad-PIT numbers are
  honest by construction. Otherwise keep default-off and **always set =5 in
  broad-PIT specs**.
- Pin the honest top-3000 15y baseline (with stale-exit) as the reference number.

**P1 — Re-check the TWO breadth-sensitive ledger verdicts on top-3000 PIT.**
Per the §4 audit in `p1-rolling-start-dispersion-pit-2026-06-08.md`: the
exit-timing / hysteresis REJECTs are mechanistic (universe-independent) and don't
need re-checking, but **laggard-rotation** (`laggard-disable-retracted`) and
**continuation-buy** (`continuation-combined-axis`) are candidate-supply-sensitive
— they may behave differently with 3000 vs 500 names. These are the only verdicts
breadth could flip.

**P2 — Extend the breadth-robustness curve on the honest basis.**
Run rolling-start dispersion (#1476) across top-{500,1000,3000} on the stale-exit
basis, matched start grids, to quantify how the DD-tail contraction scales with
breadth. The DD-tail (capital-relative-DD #1471, peak-MaxDD) is the primary lens.

**Defer:** single-dial strategy mechanics — still no broad-grounded motivating
signal beyond breadth itself (`.claude/rules/weinstein-faithful-core.md` + the 6
rejections). The fat-tail finding hints position-sizing/concentration matters, but
that is strategy-mechanic territory — needs a broad-PIT-grounded signal first.

## Key artifacts
- `dev/notes/p0-verify-broad-universe-790-2026-06-08.md` — the +790.5% decomposition.
- `dev/notes/p1-rolling-start-dispersion-pit-2026-06-08.md` — dispersion + verdict audit.
- memories: `project_broad_universe_790_mtm_inflated` (the corrected headline),
  `project_n3000_covid_oom` (OOM fix, now ⚠-flagged), `project_pit_survivorship_inflation`.
- Repro: snapshot `/tmp/snap_top3000_2011`; specs `/tmp/p1verify_t3k{,_stale}`,
  `/tmp/p1verify_t1k`; `rolling_start_eval` (#1476) for dispersion.

## Live tracks (owners)
- **stage-accuracy / spy-only-reference** (feat-weinstein).
- **experiment-platform / backtest-perf / simulation / tuning** (feat-backtest) —
  stale-exit promotion grid, breadth-robustness curve.
- **data-foundations** (feat-data).
- **harness / orchestrator / sweep-perf / cleanup** (harness-maintainer) — note:
  ~90 stale `.claude/worktrees/agent-*` accumulated (disk 13%, below sweep threshold).
