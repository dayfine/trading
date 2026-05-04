# Partial revert of #828 — restore panel-backed strategy bar reader

Closes #843. 2026-05-04.

## Context

Phase F.3.a-3 (#828, "Panel_runner CSV path builds snapshot in-process")
combined with F.3.a-4 (#829, "delete `Bar_reader.of_panels`") materially
diverged sp500-2019-2023 metrics from the pinned baseline:

|                  | Pinned baseline (5a20c1cb) | Current main (b6d1d1b7) |
|------------------|----------------------------|-------------------------|
| total_return_pct | 60.86                      | 22.2                    |
| total_trades     | 86                         | 112                     |
| win_rate         | 22.1%                      | 19.6%                   |
| max_drawdown     | 34.2%                      | 31.1%                   |

Bisect agent's findings (`dev/notes/parity-bisect-2026-05-04.md`):

- The simulator's `Market_data_adapter` switch from
  `Bar_data_source.Csv` to `Bar_data_source.Snapshot` is **not** the
  cause — restoring just the simulator to CSV mode while keeping the
  strategy on `of_snapshot_views` leaves the regression intact.
- The strategy's `Bar_reader` switch from `of_panels` to
  `of_snapshot_views` **is** the cause — restoring just the strategy to
  the panel-backed path while keeping the snapshot Market_data_adapter
  produces baseline 60.9% / 86.
- The two backings test bit-equal cell-by-cell on
  `weekly_view_for ~n:52` and `daily_bars_for` over all 132066
  (symbol, weekday) cells in 2019. So the divergence is path-dependent
  or stateful — likely LRU eviction order, Hashtbl ordering, or a
  closure capture. Forward-fix requires deeper investigation.

Maintainer authorized **Option 1 partial revert**: route the strategy's
bar_reader back through `Bar_reader.of_panels` while keeping the
snapshot-mode `Market_data_adapter` for the simulator's per-tick price
reads. Bisect agent verified empirically.

## Approach

Three changes:

### 1. Restore `Bar_reader.of_panels` constructor

Re-introduce the constructor + 4 panel-backed read closures
(`_panel_daily_bars_for`, `_panel_weekly_bars_for`,
`_panel_weekly_view_for`, `_panel_daily_view_for`) that #829 deleted.
Code is unchanged from the pre-#829 form; same LOC.

The new `of_in_memory_bars` constructor (#825) stays — it's used by 6
strategy / simulator test files and is the cleanest construct for those
sites.

`bar_reader.{ml,mli}` net: ~+70 LOC restoration.

### 2. Hybrid setup in `panel_runner.ml`

The runner enters `_setup_snapshot` in both legacy CSV and pre-built
snapshot modes. Two changes:

- For both modes, load OHLCV panels from CSV via
  `Ohlcv_panels.load_from_csv_calendar` (legacy CSV mode's loader),
  build a `Bar_panels.t`, and pass `Bar_reader.of_panels bar_panels`
  as the strategy's `bar_reader`.
- Keep `Csv_snapshot_builder.build` (CSV mode) and the caller-provided
  snapshot dir (Snapshot mode) for the simulator's Market_data_adapter.
- `_final_close_prices` reads from the snapshot's Daily_panels — no
  change.

Net effect:
- **Strategy bar reads**: panel-backed (legacy, restores baseline).
- **Simulator price reads**: snapshot-backed (preserves F.2 RAM bound).
- **Final close prices**: snapshot-backed (already there).

`panel_runner.ml` net: ~+50 LOC (restored panel-build helpers).

### 3. Regression test — `dev/scripts/check_sp500_baseline.sh`

The goldens-sp500 fixture requires per-symbol CSV bar data
(`data/<symbol>/.../data.csv`), which is local-only (per the
tier-4-release-gate-is-local-only pattern: data is gitignored, GHA
runners don't carry it). A standalone shell script is the right shape:

- Inputs: a snapshot data_dir (defaults to `data/`).
- Runs `scenario_runner.exe` against
  `goldens-sp500/sp500-2019-2023.sexp`.
- Extracts the metrics from `summary.sexp`.
- Asserts each metric is within tolerance of the baseline:
  - total_return_pct within ±1.0pp of 60.86
  - total_trades exactly 86
  - sharpe_ratio within ±0.05 of 0.55
  - max_drawdown_pct within ±1.0pp of 34.15
  - win_rate within ±2.0pp of 22.35
- Exits 0 on PASS, 1 on FAIL with the offending metric.

Patterned after `dev/scripts/check_snapshot_freshness.sh` (a similar
local-only verification script).

The fixture's existing `(expected ...)` ranges are wider than these
tolerances — the fixture must absorb the ±2w start-date fuzz IQR for
CI smoke. The script's tolerances are tighter to catch the specific
60.9 → 22.2 regression that triggered this PR.

### Out of scope

- Forward-fix of the path-dependent divergence in `of_snapshot_views`.
  Filed as a follow-up issue.
- Re-deletion of `of_panels`. The constructor stays alive until the
  forward fix lands, when the runner can flip back to the snapshot path.
- Changing the goldens-sp500 fixture's pinned ranges. They already
  encompass 60.86; restoration moves the run back inside the fixture's
  bounds without any fixture edit.

## Files to change

- `trading/trading/weinstein/strategy/lib/bar_reader.ml` — restore
  `of_panels` + 4 `_panel_*` helpers
- `trading/trading/weinstein/strategy/lib/bar_reader.mli` — restore
  `val of_panels`
- `trading/trading/backtest/lib/panel_runner.ml` — hybrid setup:
  `Bar_panels.t` for strategy, snapshot for simulator
- `trading/trading/backtest/lib/panel_runner.mli` — doc-comment update
- `trading/trading/backtest/lib/dune` — add `trading.data_panel`
  dependency (was scrubbed in #828)
- `dev/scripts/check_sp500_baseline.sh` — new regression script
- `dev/status/data-foundations.md` — note partial revert applied; F.3.a
  status moves to "partial revert; forward-fix pending"
- `dev/plans/parity-revert-pr828-strategy-bar-reader-2026-05-04.md` —
  this plan file

## Risks / unknowns

- **RAM bump on tier-3 runs**: panel build is back. For sp500 5y this
  is tens of MB — acceptable per `dev/plans/perf-scenario-catalog-...`
  (release-gate scaffolding plan). Tier-4 (broad universe) has not
  been re-run under this hybrid; a follow-up release-gate run is
  prudent before the next tag.
- **Test churn**: any callers / tests that depend on the post-#829
  pure-snapshot read path are unaffected — the public surface gains
  back `of_panels` but does not lose anything.
- **Forward-fix becomes lower priority**: with the partial revert,
  the original F.3.a-3 unification goal is no longer met. A follow-up
  issue tracks it explicitly.

## Acceptance criteria

- [ ] `dune build && dune runtest` green on the branch's worktree.
- [ ] `dune build @fmt` clean for files touched.
- [ ] `dev/scripts/check_sp500_baseline.sh` PASSes locally (verified
      against the canonical universe in `data/`).
- [ ] LOC delta < 500 (excluding the plan + status edits).
- [ ] Files listed match the "Files to change" list — no scope drift
      per `.claude/rules/worktree-isolation.md`.
- [ ] Pre-push branch ancestry shows only this PR's commits, not
      sibling agents'.
- [ ] PR body filled in via `gh pr edit` (jst submit doesn't populate
      body).
