# #888 score-threshold quick-look — 2026-05-06

## Context

Issue #888 asks to (1) expose the cascade score threshold as a config
parameter and (2) measure the impact of bumping it by 1-2 points on the
sp500-2019-2023 5y baseline.

This note covers part (2). Part (1) is implemented as a new
`min_score_override : int option` field in `Screener.config` (PR
feat/screener/888-threshold-param). Default `None` preserves the existing
grade-based filter bit-equally; when set to `Some n`, replaces the filter with
a strict numeric `score >= n` gate.

The flagship 15y run is intentionally NOT in scope here per the dispatch — the
goal is to validate the parameter wiring against the well-pinned 5y baseline
before designing the full sweep. Per #871, the cascade is at the no-look-ahead
ceiling; the dispatch (and #871's verdict) recommend deferring the actual
threshold sweep until capital-recycling work (#872 / #887) lands, so a tighter
threshold can compound with freed-up cash rather than just reducing entries.

## Setup

- Universe: `universes/sp500.sexp` (500 symbols, post-#851 share-class dedup).
- Period: 2019-01-02 → 2023-12-29 (5y, COVID + 2022 bear cycle).
- Strategy: Weinstein, default config.
- Baseline pin (sp500-2019-2023.sexp): **+58.34% / 81 trades / Sharpe 0.54 / MaxDD 33.60%**.
- Three cells:
  - **A (default)** — `min_score_override = None`. Bit-equal to the
    pinned baseline.
  - **B (+1)** — `min_score_override = Some 41`. Cuts grade-C (40-pt) admissions.
  - **C (+2)** — `min_score_override = Some 42`. Cuts grade-C through 41.

The default `grade_thresholds.c = 40` so `min_score_override = Some 40` would
be a no-op relative to grade-based filtering. `Some 41` is the smallest delta
that actually changes admissions.

## Results

Wall time: 6m53s for the 3-cell sweep at `--parallel 3`.

| Cell | Threshold | Total return | Trades | Win rate | Sharpe | MaxDD | AvgHold (d) |
|---|---|---:|---:|---:|---:|---:|---:|
| A (default) | grade ≥ C (≥40 pts) | **+58.34%** | **81** | 19.75% | 0.537 | 33.60% | 84.1 |
| B (+1)      | score ≥ 41          | +54.57%     | 93     | 19.35% | 0.545 | 28.69% | 104.5 |
| C (+2)      | score ≥ 42          | +54.57%     | 93     | 19.35% | 0.545 | 28.69% | 104.5 |

**Cell A is bit-equal to the pinned baseline (58.34% / 81 / Sharpe 0.54 / MaxDD
33.60% / AvgHold 84).** Confirms the default `min_score_override = None` is a
no-op relative to the existing grade-based filter — required by acceptance.

**Cells B and C are byte-identical**: the actual.sexp values match across
total_return_pct (54.57149502), total_trades (93), win_rate (19.355), sharpe
(0.54497), MaxDD (28.694), AvgHold (104.484), open_positions_value
(1,515,890.08). At default scoring weights (10/15/20/30 per signal) no candidate
scores exactly 41, so the 42-floor admits the same set as the 41-floor.

## Observations

1. **Counter-intuitive: tighter threshold INCREASED trade count** (81 → 93,
   +14.8%). Mechanism (hypothesis, not yet verified):
   - Lower-grade candidates that the score-41 floor excludes were typically
     the marginal entries that locked cash in losers. Removing them frees
     cash for OTHER candidates that show up later in the period.
   - Avg holding days expanded from 84 → 104.5 (+24%), consistent with
     fewer-but-stickier picks displacing more-but-shorter-cycle picks.
2. **Return DROPPED** (58.34% → 54.57%, −3.8 pp). MaxDD also dropped
   (33.60% → 28.69%, −4.9 pp) and Sharpe is unchanged. Risk-adjusted return
   is essentially flat at the threshold + 1 setting; absolute return is
   slightly worse. **Tighter threshold in isolation does not improve
   selectivity outcomes** on this 5y window.
3. **Step size of 1-vs-2 is invisible** at default weights. Real grid sweeps
   should test threshold values that fall on actual cumulative-score
   boundaries. From `Screener.default_scoring_weights`, achievable cumulative
   scores are sums of subsets of {10, 15, 20, 30, ±10}, so meaningful
   boundaries are at {25, 30, 35, 40, 45, 50, 55, 60, 70, 75, 85, ...}.
   Sweep cells should bracket these (e.g. {40, 45, 50, 55}) rather than
   single integers.
4. Consistent with #871 §"Do NOT prioritize: cascade score re-weighting" —
   tightening the score floor doesn't beat the no-look-ahead ceiling because
   the bottleneck is capital recycling (cash locked in long-runners), not
   candidate quality.

## Recommendation for next session

Per #871 §Recommendation and the cells-B/C result above, do NOT prioritize
a full multi-period sweep of this knob in isolation. Direct evidence from the
3 cells: tightening from 40 → 41/42 reduces return by 3.8pp AND trades go up
by 12 — the marginal candidates dropped weren't the losing ones, and the cash
those losers tied up isn't getting recycled productively. The leverage of
tightening the threshold should compound with capital recycling (#872 /
Stage-3 force exits / lower `max_position_pct_long`).

The right design for the next session is:

1. Land #872 / #887 (capital-recycling).
2. Then run a sweep with cells that fall on score-boundary discontinuities,
   not 1-pt increments: `min_score_override ∈ {40, 45, 50, 55, 60}` on
   sp500-2019-2023 + sp500-2010-2026 (2 periods × 5 cells = 10 cells,
   ~10h on tier-3 budget).
3. Pin the optimum if return improves AND trade-count stays sane. Otherwise
   leave the default as the canonical setting.

Until then, this PR provides:

- The config parameter (bit-equal default).
- The grid-search dimension example in `Tuner.Grid_search.param_spec`.
- Override-path test pinning the deep-merge at
  `screening_config.min_score_override = Some 41`.
- This quick-look as the placeholder for the eventual sweep.

## Verify locally

The 3 scenario sexps live at `trading/test_data/888-quicklook/cell-*.sexp`.
Re-run via:

```bash
dev/lib/run-in-env.sh dune exec trading/backtest/scenarios/scenario_runner.exe -- \
  --dir test_data/888-quicklook \
  --parallel 3 \
  --fixtures-root test_data/backtest_scenarios
```

Output goes to `dev/backtest/scenarios-<timestamp>/888-cell-*/actual.sexp`.

Note: the scenario runner resolves `_repo_root` via `Data_path.default_data_dir`
which climbs to the repo root, so when run from a worktree the output lands in
the **parent repo**'s `dev/backtest/`, not the worktree's. Look there if the
worktree's `dev/backtest/` shows no recent run.

The unit test `test_override_screening_min_score_override` in
`trading/trading/backtest/test/test_runner_hypothesis_overrides.ml` pins the
deep-merge path so a CI failure there is the canonical signal that the override
wiring has regressed.
