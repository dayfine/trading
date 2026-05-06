;; perf-tier: SKIP
;; perf-tier-rationale: Scenario fixture defines a Buy-and-Hold-SPY benchmark
;; over the same 2019-2023 window as [sp500-2019-2023.sexp]. Currently NOT
;; runnable via [scenario_runner] because [Backtest.Runner.run_backtest] is
;; hardcoded to [Weinstein_strategy.make] (see runner.ml § "Configuration
;; constants" and panel_runner.ml § "_build_strategy"). Promote to
;; [perf-tier: 3] once a strategy-selector field is plumbed through the
;; scenario format and the runner — see "Wiring follow-up" below.
;;
;; Buy-and-Hold-SPY benchmark — pinned for the canonical 2019-2023 window.
;;
;; Dual purpose:
;;
;;   1. Accounting sanity check. BAH-SPY's final equity should track SPY's
;;      raw-close price-only return very tightly. Sub-basis-point drift
;;      indicates the simulator's broker / MtM / cash-accounting path is
;;      working; meaningful drift surfaces a regression.
;;
;;   2. Performance benchmark / alpha bar. Any active-trading strategy run on
;;      the same window must beat this number to claim alpha. The pinned
;;      [total_return_pct] here is the bar [sp500-2019-2023.sexp] is measured
;;      against (sp500-2019-2023 currently pins +58.34%; SPY BAH posts
;;      +89.99%, so the active strategy is currently ~32 pp behind passive
;;      SPY over this window — a finding the BAH-SPY pin makes visible).
;;
;; {1 Strategy}
;;
;; [Trading_strategy.Bah_benchmark_strategy] (added in PR #874): on day 1,
;; buys [floor(initial_cash / SPY_close)] shares of SPY with all available
;; cash; holds indefinitely; never sells, rebalances, or adjusts. Single
;; CreateEntering transition followed by a stationary position.
;;
;; {1 Measurement (2026-05-06, $1,000,000 initial cash)}
;;
;; Verified two ways:
;;
;;   a. Closed-form (raw price arithmetic):
;;        entry close 2019-01-02:  $250.18
;;        final close 2023-12-29:  $475.31
;;        shares bought:           3997 (= floor(1,000,000 / 250.18))
;;        leftover cash:           $30.54
;;        entry commission:        $39.97 ($0.01/sh * 3997)
;;        expected final equity:   $1,899,804.64
;;        total_return_pct:        +89.9805%
;;        SPY price-only return:   +89.9872% (= 475.31/250.18 - 1)
;;        commission drag:         -0.004% (entry trade only)
;;
;;   b. Simulator-actual (BAH strategy through standard simulator, same
;;      pipeline used by Backtest.Runner — but invoked directly via
;;      Trading_simulation.Simulator.create + run, since
;;      Backtest.Runner.run_backtest is currently Weinstein-hardcoded):
;;        actual final equity:     $1,899,922.50
;;        total_return_pct:        +89.9923%
;;        drift vs closed-form:    +0.0062%
;;        (drift is sub-basis-point — accounting matches.)
;;
;; The +$117.86 simulator-vs-closed-form discrepancy reflects rounding /
;; mark-to-market timing differences across the 5-year run. Same drift
;; magnitude observed at 2024 calendar year scale in
;; [test_bah_benchmark_e2e] ($100k cash, drift -$0.88 / -0.0007%).
;;
;; {1 Accounting findings}
;;
;; None. BAH-SPY equity tracks SPY raw close-to-close arithmetic to
;; sub-basis-point fidelity over a 5-year horizon. The two drift sources
;; we accept are documented in [test_bah_benchmark_e2e.ml]:
;;
;;   - Day-1 entry commission (~$40 here, 0.004% of initial cash). Pinned
;;     into [total_return_pct] so a regression that drops the commission
;;     would be caught.
;;   - Raw close vs adjusted close. SPY's adjusted_close back-rolls
;;     dividends — the strategy uses raw close, and the comparison above
;;     uses raw close on both sides, so dividend-treatment is not a drift
;;     source. (Adjusted close 2019-01-02 = $224.38 -> 2023-12-29 = $462.57
;;     = +106.16%, the dividend-reinvested return; we do NOT pin against
;;     this number.)
;;
;; {1 Pinned ranges}
;;
;; total_return_pct: +/- 2 pp around the simulator-actual +89.99% (i.e.
;; 88.0..92.0). Tighter than the Weinstein scenario's +/- 13 pp because BAH
;; is mechanical — there is no parameter sensitivity, no stop slippage, no
;; cash-deployment timing. The only sources of drift are the day-1 close
;; price (deterministic against pinned data files) and commission tier
;; changes (a config-level decision that should re-pin this file).
;;
;; total_trades = 1: one Buy on day 1, zero exits. Pinned exactly via a
;; tight [(min 0.5) (max 1.5)] band — [total_trades] is float-typed.
;;
;; sharpe_ratio / max_drawdown_pct / avg_holding_days: tracked but loosely
;; pinned — these are only computed when the scenario actually runs through
;; [Backtest.Runner], which is gated by the wiring follow-up. The bands
;; below reflect SPY's 2019-2023 reality (peak drawdown ~34% during the
;; COVID crash; ~25% during the 2022 bear) and will be tightened once the
;; runner produces actual numbers.
;;
;; open_positions_value: 3997 shares * $475.31 = $1,899,814.07 marked to
;; market on 2023-12-29. +/- 2% band = 1.86M..1.94M.
;;
;; {1 Universe}
;;
;; The [universe_path] field below is a placeholder — BAH-SPY is
;; single-symbol and doesn't need a multi-symbol universe. The runner-side
;; wiring follow-up should either (a) add a one-symbol [spy-only.sexp]
;; universe file, or (b) lift the universe-path requirement for
;; single-symbol strategies. Leaving the placeholder in lets [Scenario.load]
;; parse the file today.
;;
;; {1 Wiring follow-up (required to make this file runnable)}
;;
;; To promote [perf-tier: SKIP] -> [perf-tier: 3] and let
;; [golden_sp500_postsubmit.sh] pick this file up:
;;
;;   1. Add an optional [strategy] field to [Scenario.t] (default
;;      [Weinstein] for back-compat) with a [BahBenchmark { symbol }]
;;      variant.
;;   2. Plumb through [Backtest.Runner.run_backtest] to dispatch on the
;;      strategy choice — likely a separate [Bah_runner.run] entry point
;;      since the Weinstein runner's ad_bars / sector_etfs / panel_runner
;;      machinery is not needed for BAH (single-symbol, no indicators).
;;   3. Wire [scenario_runner.ml] § [_run_scenario_in_child] to dispatch.
;;   4. Add a [universes/spy-only.sexp] one-symbol fixture and switch
;;      [universe_path] below from [universes/parity-7sym.sexp] to it.
;;
;; Estimated surface: ~200-400 LOC across Scenario.t + a new Bah_runner +
;; the dispatch site, plus a parity test confirming BAH-SPY 2019-2023 via
;; the runner matches the closed-form expectation pinned here.
;;
;; Until then, this file documents the pinned target. The
;; [test_bah_benchmark_e2e] suite (under
;; trading/trading/simulation/test/) provides the live sanity check at
;; the simulator level — temporarily editing its dates to (2019-01-02 ..
;; 2023-12-29) and initial_cash to $1,000,000 reproduces the
;; simulator-actual numbers above (verified 2026-05-06).
((name "sp500-2019-2023-bah-spy")
 (description "Buy-and-Hold SPY 2019-2023 — accounting sanity + alpha bar")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/parity-7sym.sexp")
 (universe_size 1)
 (config_overrides ())
 (expected
  ((total_return_pct       ((min  88.00)      (max   92.00)))
   (total_trades           ((min   0.5)       (max    1.5)))
   (win_rate               ((min   0.0)       (max  100.0)))
   (sharpe_ratio           ((min   0.40)      (max    0.85)))
   (max_drawdown_pct       ((min  23.0)       (max   36.0)))
   (avg_holding_days       ((min 1100.0)      (max  1300.0)))
   (open_positions_value   ((min 1860000.0)   (max  1940000.0))))))
