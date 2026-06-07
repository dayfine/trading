# P1 PIT re-baseline — N=3000 OOMs at the COVID crash (container memory ceiling)

**Date:** 2026-06-07
**Session goal:** P0 (snapshot-cache fix) → P2 (eval metrics) → P1 (honest PIT re-baseline).
**Outcome:** P0 + both P2 metric cores shipped + merged. P1 honest broad
baseline **blocked by a newly-found container memory ceiling** at the COVID
crash — documented below as the load-bearing next-session item.

## Shipped this session (3 PRs merged)

| PR | What | Status |
|----|------|--------|
| **#1468** | P0 — configurable snapshot LRU cache (`SNAPSHOT_CACHE_MB`, default 1024→4096) + hit/miss/eviction counter surfaced via stderr (`misses_per_symbol`). | merged |
| **#1471** | P2a — `MaxUnderwaterVsInitialPct` (capital-relative drawdown: worst NAV shortfall below the *initial stake*, %). Demotes peak-relative MaxDD per the methodology reframe. | merged |
| **#1472** | P2b part-1 — pure dispersion-stats core (`percentile`/`median`/`iqr`/`summarize`) + `Rolling_start_types` (per_start row, report, markdown render). | merged |

Each cleared CI + qc-structural + qc-behavioral. Note: all three feat-agents
lost their commits to the jj-default-`@` worktree race and/or timed out
backgrounding their final verify; the work was recovered from the agents'
on-disk worktrees and finished by hand (registry refactor, magic-number/nesting
linter fixes, fmt). **Lesson for next session: feat-agents on this repo keep
failing the commit+push+PR finish step — recover from
`.claude/worktrees/agent-<id>/` rather than re-dispatching.**

## P0 confirmation — the cache fix WORKS (thrash solved)

The N=3000 snapshot run (top-3000-2011 PIT, Cell-E, 15y) ran at **8–9.7
Friday-cycles/min** for ~500 cycles under the 4096 MB cache — i.e. **no thrash**.
Before #1468 the same N=3000 run was non-terminating (the 1 GB LRU re-decoded
every cycle). The decisive `misses_per_symbol` counter could not be captured
because the run OOM'd before the end-of-run log line (see below), but the cycle
rate is unambiguous: the working set fit, no re-decode thrash. **P0 is confirmed
for its purpose.**

## The new finding — N=3000 + COVID-crash OOMs the 7.75 GB container

Two full-15y runs, identical except cache size, both **OOM-killed**
(`docker inspect ... State.OOMKilled = true`) at the **COVID-crash onset**:

| cache | died at cycle | last completed | trades | equity | OOM |
|-------|---------------|----------------|--------|--------|-----|
| 4096 MB | 516 / 829 | 2020-04-24 | 918 | $1,812,275 (+81%) | yes |
| 2048 MB | 508 / 829 | 2020-02-28 | 893 | $1,975,952 (+98%) | yes |

**Halving the cache barely moved the death point (516 → 508).** So the OOM is
**not cache-driven** — it is a transient memory spike when the broad-universe
(3000-symbol) COVID crash hits. Almost certainly a **force-liquidation cascade**:
the 60%-portfolio-DD circuit breaker (and/or mass weekly-close stop triggers)
fires across hundreds of positions at once, allocating a large transient of
orders / events / audit records that pushes total RSS over the 7.75 GB limit.

This is a **distinct issue from the thrash #1468 fixed**:
- #1468 fixed *steady-state* bar-decode memory/CPU (the LRU cache).
- This is a *transient allocation spike* in the cascade/liquidation path that
  scales with universe size — it appears only at a broad-N crash regime.

The pre-COVID portion (2011 → early-2020, ~500 cycles) runs clean. Equity
trajectory on the honest top-3000 universe was strong (+81–98% by early 2020,
~9y) — promising vs the survivorship-corrected top-1000 15y (29.6%), consistent
with the breadth=lever thesis — but **no clean final scorecard** (return /
Sharpe / MaxDD / the new capital-relative-DD) exists because both runs died
before writing `actual.sexp`.

## P1 is blocked on this — options for next session (in priority order)

1. **Fix the cascade memory spike (highest value — unblocks the whole
   broad-PIT agenda).** Investigate the force-liquidation / mass-stop-exit path
   in the simulator at broad N: is it materializing all liquidation events /
   orders / audit records in one allocation? Stream or batch them. This is what
   stops *every* full-history N=3000 PIT run, not just this one.
2. **Run N≤1000 PIT instead.** top-1000-2011 15y already baselined in the trim
   study (29.6% / 42.2% MaxDD) — survivorship-correct. N=1000 fit under the old
   1 GB cap, so it completes. Re-run accepted/rejected mechanisms there to
   re-check verdicts on honest data (the core P1 ask) without needing the fix.
3. **More container RAM.** Bump the Docker memory limit > 8 GB; the COVID spike
   is transient, so even ~12 GB likely clears it. Cheapest unblock if available.
4. **Pre-COVID / post-COVID partial windows** at N=3000 (e.g. 2011-2019) — give
   honest broad numbers but break path-continuity and miss the COVID regime.

## Deferred (clean follow-up, not blocked)

- **P2b part-2 — rolling-start dispersion runner.** The pure core (#1472) is
  merged; the N-backtest executor (loop start dates → `Runner.run_backtest` +
  `--snapshot-dir` → collect CAGR / capital-DD / MaxDD per start → feed
  `Dispersion_stats.summarize`) is a clean follow-up. ~150-250 LOC reusing
  `walk_forward_executor` patterns. Plumbing, not novel — lower priority than
  the cascade fix.

## Reproduction

Snapshot (reusable, covers 2010-06 → 2026-04, 3015 symbols incl. GSPC.INDX):
```
dune exec --no-build trading/backtest/snapshot_warehouse/build_scenario_snapshots.exe -- \
  -scenario <spec> -fixtures-root test_data/backtest_scenarios \
  -csv-data-dir /workspaces/trading-1/data -output-dir /tmp/snap_top3000_2011 -progress-every 500
```
Scenario spec (Cell-E config, top-3000-2011 PIT universe, 15y):
```
((name "cell-e-top3000-2011-15y")
 (description "P1 honest Cell-E baseline — top-3000-2011 PIT x 15y (snapshot-mode only)")
 (period ((start_date 2011-01-01) (end_date 2026-04-30)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2011.sexp")
 (universe_size 3000)
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected (...wide SCAFFOLDING-ONLY ranges...)))
```
Run (snapshot mode; output → `dev/backtest/scenarios-<ts>/`, gitignored):
```
SNAPSHOT_CACHE_MB=4096 dune exec --no-build trading/backtest/scenarios/scenario_runner.exe -- \
  --dir <dir-with-only-this-spec> --snapshot-dir /tmp/snap_top3000_2011 \
  --fixtures-root test_data/backtest_scenarios --no-emit-all-eligible --parallel 1
```
→ OOM at cycle ~510 (2020-02/04). Confirm with `docker inspect trading-1-dev --format '{{.State.OOMKilled}}'`.

## Related
- `dev/notes/macro-bearish-trim-grid-2026-06-07.md` (§5 survivorship, §7 cache),
  `dev/plans/evaluation-objective-and-metrics-2026-06-07.md` (P2 metrics).
- memories: `project_pit_survivorship_inflation`, `project_evaluation_methodology_reframe`,
  `feedback_large_n_needs_snapshot_mode`, `project_cell_e_2020_stall_regime`.
