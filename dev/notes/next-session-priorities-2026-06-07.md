# Next-session priorities — 2026-06-07

**Supersedes** all prior `next-session-priorities-*.md`. Single load-bearing
handoff. Read this + check main CI green (per `.claude/rules/session-rampup.md`)
before dispatching anything.

## TL;DR — where the project is

**The system is built.** ~20 of 30 tracks are MERGED — the entire Weinstein
pipeline + backtest/snapshot/tuning/cost infra is done and working. The frontier
is **alpha search**, and across 6+ rejected/fragile single-dial experiments the
program keeps reaching ONE conclusion:

> **Single-dial tuning is exhausted. Breadth / broad-universe is THE lever — and
> as of #1481 it can finally be run at scale on honest (survivorship-correct
> PIT) data locally.**

## ⭐ The #1 lever is now UNBLOCKED (this session's payoff)

Running the broad universe at N=3000 used to OOM-kill the 7.75 GB container.
**FIXED via #1481** (`fix(engine): lazy intraday-path generation`): `Engine.update_market`
was eagerly building a ~19 KB intraday `Price_path` for every symbol every tick
(~3000/day) when only the ~5 order-touched symbols are ever read — >99% churn
dominating the heap. New `Market_state` sub-module generates paths lazily/
memoized per tick only for order-touched symbols. Public `Engine` API unchanged;
**results bit-identical** (verified: RNG is per-call, not shared across symbols —
`price_path.ml` builds a fresh `Random.State` per path). Live-memory growth
1.39 → 0.013 MB/cycle; the 15y N=3000 run now completes with RSS ~5.8 GB flat.
Both QC gates APPROVED (behavioral q=5, A1 generalizability PASS).

**First honest full-15y top-3000 PIT Cell-E baseline (validated this session):**
**+790.5% return / Sharpe 0.712 / MaxDD 29.2% / Calmar 0.526 / Sortino 1.225 /
Ulcer 9.78 / 671 trades / 2 force-liqs.**
Contrast: survivorship-correct top-1000 15y = 29.6%; SP500-survivor 15y = 237%.
The +790.5% on the **broad** honest universe vs 29.6% on top-1000 is a striking
breadth effect — **verify it next session** (apples-to-apples: same Cell-E
config, same 2011-2026 window, both honest PIT). If it holds, it is the
strongest evidence yet for the breadth thesis.

## Priorities for next session

**P0 — Verify + extend the honest broad-universe re-baseline** (the #1 lever).
- Sanity-check the +790.5% top-3000 number (re-run, confirm vs top-1000 on the
  identical config/window — rule out a universe-construction artifact).
- Re-run Cell-E + the *accepted* mechanisms on PIT `top-{1000,3000}-<year>`
  across start years; **re-check past ACCEPT/REJECT verdicts on honest data** —
  some ACCEPTs may be survivorship artifacts, some REJECTs judged on inflated
  numbers (`project_pit_survivorship_inflation`).
- Recipe: snapshot mode (`feedback_large_n_needs_snapshot_mode`); the snapshot
  `/tmp/snap_top3000_2011` + cells `/tmp/p1cell*` may still exist in-container.
  N=3000 full-history now fits (#1481).
- Scorecard: the new capital-relative-DD (#1471) + rolling-start dispersion
  (#1472/#1476) metrics; start-date robustness primary
  (`dev/plans/evaluation-objective-and-metrics-2026-06-07.md`).

**P1 — Rolling-start dispersion on PIT** (backtest-perf). Runner #1476 merged;
run it on the PIT universes to get robustness distributions (the primary lens).
P3 eval prototypes (`time_underwater_pct` + antifragility convexity) remain —
hold skeptically per plan §2 P3.

**Defer:** further single-dial strategy mechanisms — the program has shown these
don't generalize (`.claude/rules/weinstein-faithful-core.md` + the 6 rejections).
No new dials without a broad-universe-grounded motivating signal.

## This session's shipped work (5 PRs)
- **#1468** P0 — configurable snapshot LRU cache + hit/miss counter (kills thrash).
- **#1471** P2a — `MaxUnderwaterVsInitialPct` capital-relative drawdown metric.
- **#1472** P2b-part1 — pure dispersion-stats core; **#1476** (orchestrator) part-2 `rolling_start_eval` exe.
- **#1475** process fix — feat-agent finish-step (container-visible jj workspace path + mandatory Finish Protocol). **Validated:** the #1481 agent used the fixed path + opened its PR cleanly.
- **#1481** ⭐ N=3000 OOM fix (lazy `Market_state`) — the lever unblock.

## Live tracks (owners)
- **stage-accuracy / spy-only-reference** (feat-weinstein) — breadth lever, sector-rotation testbed, long-short (dedicated human session).
- **experiment-platform / backtest-perf / simulation / tuning** (feat-backtest) — Cell-E stall, rolling-start eval, M5 catch-all, qNEHVI M2.
- **data-foundations** (feat-data) — PIT universe unlocked; bars-retention gap.
- **harness / orchestrator-automation / sweep-perf / cleanup** (harness-maintainer).

## Related
- `dev/notes/p1-pit-rebaseline-n3000-oom-2026-06-07.md` — OOM diagnosis + repro.
- `dev/plans/evaluation-objective-and-metrics-2026-06-07.md` — scorecard reframe.
- memories: `project_n3000_covid_oom` (now FIXED), `project_pit_survivorship_inflation`,
  `project_evaluation_methodology_reframe`, `project_cell_e_2020_stall_regime`,
  `feedback_large_n_needs_snapshot_mode`, `feedback_feat_agents_lose_commits`.
