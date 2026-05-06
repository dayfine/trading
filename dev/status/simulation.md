# Status: simulation

## Last updated: 2026-05-06

## Status
IN_PROGRESS

Split-day broker-model redesign + regression follow-ups fully wrapped
(PRs #658 / #662 / #664 / #667 broker-model; #678 strategy-side-position-map
fix; #680 stop-state rescaling; #682 short-side flag for sp500 mitigation;
all merged 2026-04-28..29). Slice 1+3 verdicts remain APPROVED. Track
stays IN_PROGRESS for the M5 walk-forward + tuner catch-all items and the
local sp500-2019-2023 baseline rerun (deferred — needs full 491-symbol
universe data not present in GHA).

P0 CI RED (`split_day_stop_exit:1:post_split_exit_no_orphan_equity`, $400 drift)
was resolved by PR #752 (2026-05-02); CI green on `main` since.

## QC
overall_qc: APPROVED (Slice 1 + Slice 3)
structural_qc: APPROVED (Slice 1: 2026-04-07, Slice 3: 2026-04-10)
behavioral_qc: APPROVED (Slice 1: 2026-04-07, Slice 3: 2026-04-10)
See dev/reviews/simulation.md.

## Interface stable
YES

## Blocked on
- None

## Existing infrastructure — DO NOT reimplement
`trading/trading/simulation/` is a **generic** framework shared across all strategies (not Weinstein-specific). Phases 1–3 are complete and tested:
- **Phase 1** (core types): `config`, `step_result`, `step_outcome`, `run_result` in `lib/types/simulator_types.ml`
- **Phase 2** (OHLC price path): intraday path generation, order fill detection for all order types
- **Phase 3** (daily loop): `step` and `run` implemented; engine + order manager + portfolio wired up
- The simulator already takes a `(module STRATEGY)` in its `dependencies` record

The Weinstein work in eng-design-4 adds Weinstein-specific components **on top** without breaking general use.

## Completed

- `strategy_cadence` added to simulator config — Weekly/Daily gate (#195)
- `Weinstein_strategy` — full `STRATEGY` impl, daily stop cadence, Friday-gated screening (#196, merged 2026-04-07)
  - Stop updates: daily (adjusts trailing stops as MA moves)
  - Macro analysis + screening: Fridays only (Weinstein weekly review cadence)
  - `_update_stops`, `_screen_universe`, `_make_entry_transition` wired to all analysis modules
- `Synthetic_source` — deterministic `DATA_SOURCE` impl for testing; 4 bar patterns: Trending/Basing/Breakout/Declining; 8 tests (feat/simulation branch)
- End-to-end smoke test — `Simulator.run` with `Weinstein_strategy` on CSV data in temp dir; 3 tests covering smoke + date range + weekly cadence

### Slice 2 (2026-04-09)

- **`Portfolio_view.t` on STRATEGY interface** — replaced `~positions:Position.t String.Map.t` with `~portfolio:Portfolio_view.t` containing `{ cash; positions }`. Simulator constructs it from `Portfolio.current_cash` + position map. Weinstein strategy derives portfolio value via `Portfolio_view.portfolio_value` for position sizing. 3 tests for the utility module.
- **Bar accumulation** — per-symbol daily bar buffer (`Hashtbl<string, Daily_price.t list>`) in `make` closure. Accumulated idempotently on each `on_market_close` call. Converted to weekly via `Time_period.Conversion.daily_to_weekly` for stage/macro/screening analysis. Replaces `_collect_bars` placeholder.
- **MA direction** — computed from `Stage.classify` on the weekly bar buffer instead of hardcoded `Flat`. Falls back to `Flat` when insufficient bars (< ma_period).
- **Simulation date** — `_make_entry_transition` uses current bar's date instead of `Date.today`.
- **Smoke test extended** — `hist_start` moved to 2022-01-01 (100+ weekly bars warmup). Added `portfolio_value > 0` assertion.

### Slice 3 (2026-04-10) — merged (#246)

- **Prior stage accumulation** — per-symbol `prior_stages` Hashtbl in the `make` closure. `Stage.classify` and `Stock_analysis.analyze` now receive accumulated prior stage instead of `None`. Enables accurate Stage1→Stage2 transition detection in `is_breakout_candidate`.
- **Index prior stage** — `Macro.analyze` receives accumulated index prior stage instead of `None`.
- **Breakout smoke test** — new test using `Breakout` synthetic pattern (40 weeks basing, 8x breakout volume, 1-year sim from data start). Asserts: orders submitted, trades executed, positive portfolio value. Full screener→order→trade pipeline verified end-to-end.

All slices merged: Slice 1 (#196), Slice 2 (#237, #240, #241, #242), Slice 3 (#246).

### Split-day OHLC redesign — broker-model approach (2026-04-29)

Plan: `dev/plans/split-day-ohlc-redesign-2026-04-28.md`. Closes the open
PR #641 band-aid trail; supersedes its `_split_adjust_bar` rescale in
favour of a discrete event on the position ledger. Four PRs landed:

- **PR-1 — Split_detector primitive** (#658, MERGED 2026-04-28).
  `trading/analysis/data/types/lib/split_detector.{ml,mli}`. Pure
  function `detect_split ~prev ~curr` that compares raw vs adjusted
  close ratios, snaps to small rationals, distinguishes splits from
  dividends via a 5% threshold. Configurable tolerances. 5 fixtures
  (AAPL 4:1, reverse 1:5, dividend, quiet, 3:2 boundary).
- **PR-2 — Split_event ledger primitive** (#662, MERGED 2026-04-28).
  `trading/trading/portfolio/lib/split_event.{ml,mli}` — built
  alongside `Portfolio` per CLAUDE.md. `apply_to_position` quadruples
  quantity / quarters cost-basis-per-share on 4:1; total cost basis
  preserved. `apply_to_portfolio` no-ops when symbol not held. 4
  fixtures (forward 4:1, reverse 1:5, no-op, 3:2 fractional).
- **PR-3 — wire detector + ledger into `Simulator.step`** (#664, MERGED
  2026-04-29). Adds `Price_cache.get_previous_bar` /
  `Market_data_adapter.get_previous_bar`, a `splits_applied :
  Split_event.t list` field on `step_result`, and a
  `_detect_splits_for_held_positions` step in `Simulator.step` that
  fires before strategy invocation. `_to_price_bar`,
  `_compute_portfolio_value`, `_make_get_price` are unchanged — raw
  OHLC flows everywhere, only the position ledger is adjusted on
  splits. New `test_split_day_mtm.ml` (3/3 PASS): 4:1 continuity,
  no-split window unchanged, split-day with no held position.
- **PR-4 — verification + decisions promotion** (this PR, 2026-04-29).
  `dune build && dune runtest` exit 0; `dune build @fmt` clean. Smoke
  parity goldens bit-identical to pre-#641 main (`panel-golden-2019-full`
  7 round-trips / 33.3% win, `tiered-loader-parity` 5 round-trips /
  60.0% win). Decision promoted to `dev/decisions.md`. sp500-2019-2023
  canonical baseline rerun deferred to local — GHA's 22-symbol fixture
  cannot satisfy the 491-symbol universe (same data-availability
  blocker that scoped the tier-4 release-gate to local). When a
  maintainer runs the local sp500 baseline, MaxDD is expected to drop
  from 97.69% to ~5% (the strategy's actual non-bug Stage-4 floor)
  with trade count, return, and win rate roughly unchanged. Tracked
  in `dev/notes/split-day-broker-model-verification-2026-04-29.md`
  and the §Follow-up below.

  Verify: `dev/lib/run-in-env.sh dune runtest trading/simulation/test/`
  (3/3 split_day_mtm PASS) + `dev/lib/run-in-env.sh
  _build/default/trading/backtest/scenarios/scenario_runner.exe --dir
  test_data/backtest_scenarios/smoke --fixtures-root
  test_data/backtest_scenarios` (5/5 PASS).

## In Progress

- **Split-day broker-model redesign + regression (WRAPPED 2026-04-29)**.
  PRs #658 (Split_detector) + #662 (Split_event ledger) + #664 (Simulator
  wire-in) + #667 (verification + decisions promotion) + #678
  (`fix/split-day-broker-model-debug`, strategy-side `Position.t`
  cross-side sync) + #680 (`feat/weinstein-split-day-stop-adjustment`,
  `Stop_split_adjust.scale` rescaling stop_states on split events) +
  #682 (`feat/weinstein-short-side-flag` + sp500 long-only override)
  all merged. The 97.69% phantom MaxDD on `goldens-sp500/sp500-2019-2023`
  is structurally resolved. See `dev/decisions.md` §"2026-04-29 —
  Split-day broker model: regression" + §"2026-04-29 — Split-day OHLC:
  broker model".

- M5 (walk-forward backtest, parameter tuner) is next.

## Blocking Refactors
- None

## Follow-up

- **Local sp500 baseline rerun (deferred from PR-4 of split-day redesign)** —
  capture post-PR-3 metrics on `goldens-sp500/sp500-2019-2023` against
  the full 491-symbol universe. Cannot run in GHA (22-symbol fixture
  insufficient). Reproduction shape:
  ```sh
  docker exec trading-1-dev bash -c '
    cd /workspaces/trading-1/trading && eval $(opam env) &&
    dune build trading/backtest/scenarios/scenario_runner.exe &&
    _build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir trading/test_data/backtest_scenarios/goldens-sp500 \
      --fixtures-root trading/test_data/backtest_scenarios'
  ```
  Expected: trade count ≈ 134 (per
  `dev/notes/sp500-2019-2023-baseline-canonical-2026-04-28.md`),
  total return ≈ +71%, win rate ≈ 38%, MaxDD ~5% (down from 97.69%
  phantom). Once captured, supersede the canonical baseline note and
  re-pin `goldens-sp500/sp500-2019-2023.sexp` `expected` ranges
  against the corrected MaxDD. Plan reference:
  `dev/plans/split-day-ohlc-redesign-2026-04-28.md` §PR-4.
- Volume dilution in weekly aggregation: a single high-volume daily breakout bar gets averaged with 4 normal-volume bars in the weekly sum, requiring unrealistically high `breakout_volume_mult` (8x daily) to achieve 2x weekly ratio. Consider enhancing `Synthetic_source.Breakout` to apply volume spike across multiple days of the breakout week.
- Test does not yet assert on specific position symbols (AAPL open position) or PnL direction — trades are confirmed but position-level assertions deferred.
- `TODO(simulation/price-cache-data-source)` — Remove tmpdir round-trip in strategy smoke tests once `Price_cache` accepts an injected `DATA_SOURCE` (follow-up to #218/#219). See `trading/weinstein/strategy/test/test_weinstein_strategy_smoke.ml`.
- `TODO(simulation/stoplimit-orders)` — `order_generator` uses Market orders; should be StopLimit orders with entry/exit prices from transitions. See `simulation/lib/order_generator.ml` and `.mli`.
- `TODO(simulation/monthly-cadence)` — Monthly cadence conversion not implemented in `time_series.ml` — currently returns empty. See `simulation/lib/data/time_series.ml`.
- `TODO(simulation/bar-granularity)` — Engine `price_bar` type lacks configurable bar granularity (daily/hourly/minute) and volume data. See `engine/lib/types.mli`.
- ~~**Macro.analyze cadence mismatch**~~ — RESOLVED. `Ad_bars_aggregation.daily_to_weekly` is now called at `make` time (see `weinstein_strategy.ml:254`), so `Macro.analyze` receives weekly-cadence `ad_bars` matching the weekly `index_bars`.
- **Simulation loop performance** — current 6-year / 1654-stock backtest takes
  ~40 min and ~7 GB RAM (see `dev/status/backtest-infra.md` §Performance).
  Bottlenecks worth profiling before attempting optimization:
  - `Stage.classify` is O(n) per weekly step (recomputes full MA series).
    The `classify_step` incremental pattern tracked in
    `dev/status/screener.md` §Followup / "Stage classifier: incremental
    `classify_step` for simulation" is the direct fix.
  - Hashtbl iteration ordering still partially non-deterministic (see #298,
    #274) — fixing may close reruns rather than speed up.
  - Weinstein strategy's `_screen_universe` runs the full cascade every
    Friday — cache per-symbol stage between weeks where possible.
  - Per-scenario parallelism already exists via `scenario_runner
    --parallel N` (from #316); intra-simulation parallelism would require
    design work.
  Not yet profiled — start with `perf` / `ocaml-landmarks` / `bolt` on a
  single golden scenario to find the actual hot path before optimising.

## Known gaps

- `T2-B` performance gate test deferred to M5
- Trade assertions deferred to Slice 3 (see Follow-up)

## Next Steps

### Future slices

- Position-level assertions: verify AAPL open position, PnL direction
- Walk-forward backtest (M5): parameter tuner with validation period
- Performance gate test (T2-B)

