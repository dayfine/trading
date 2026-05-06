;; perf-tier: 3
;; perf-tier-rationale: Buy-and-Hold-SPY benchmark over the canonical
;; 2019-2023 window. Single-symbol, single-trade — fastest possible run on
;; the SP500 surface. Wired through [Backtest.Runner.run_backtest] via the
;; [strategy] field added in #882; the runner dispatches on
;; [Strategy_choice.Bah_benchmark] and constructs
;; [Trading_strategy.Bah_benchmark_strategy.make] in place of Weinstein.
;; Tagged [perf-tier: 3] so [golden_sp500_postsubmit.sh] picks it up
;; alongside [sp500-2019-2023.sexp] — running both per postsubmit makes the
;; alpha gap visible at every PR.
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
;;      +91.31% via Backtest.Runner, so the active strategy is currently
;;      ~33 pp behind passive SPY over this window — a finding the BAH-SPY
;;      pin makes visible at every postsubmit run).
;;
;; {1 Strategy}
;;
;; [Trading_strategy.Bah_benchmark_strategy] (added in PR #874): on day 1,
;; buys [floor(initial_cash / SPY_close)] shares of SPY with all available
;; cash; holds indefinitely; never sells, rebalances, or adjusts. Single
;; CreateEntering transition followed by a stationary position.
;;
;; {1 Measurement (2026-05-06, $1,000,000 initial cash, via Backtest.Runner)}
;;
;; Verified through {!Backtest.Runner.run_backtest} with [strategy_choice =
;; Bah_benchmark { symbol = "SPY" }]. Entry sizing happens at day-1 close,
;; trade fills at next-day open (the simulator's standard order-routing
;; semantics — orders placed in [on_market_close] execute against the
;; next bar). The simulator stops one bar before [end_date] (the
;; [is_complete] check fires when [current_date >= end_date]), so the final
;; mark-to-market uses [end_date - 1 trading day]'s close.
;;
;;   sizing close 2019-01-02:  $250.18
;;   shares bought:            3997 (= floor(1,000,000 / 250.18))
;;   fill open  2019-01-03:    $248.23
;;   entry commission:         $39.97 ($0.01/share * 3997)
;;   leftover cash:            $7,784.72
;;     (= 1,000,000 - 3997 * 248.23 - 39.97)
;;   final close 2023-12-28:   $476.69
;;     (last bar processed; end_date 2023-12-29 is not stepped)
;;   final equity:             $1,913,114.65
;;     (= 7,784.72 + 3997 * 476.69)
;;   total_return_pct:         +91.3115%
;;   SPY raw return (sizing 2019-01-02 close to MtM 2023-12-28 close):
;;                             +90.5%  (= 476.69 / 250.18 - 1)
;;
;; The +$1.5k delta vs the closed-form using same-day fill is the day-2
;; open ($248.23) being lower than the day-1 close ($250.18), giving the
;; strategy a slightly cheaper effective entry with leftover cash carried
;; through to end-of-window MtM. The +0.7% delta vs SPY raw return reflects
;; the leftover cash sitting idle (no money-market interest modeled) plus
;; the commission drag.
;;
;; Day-2 fill semantics also explain why a closed-form spreadsheet using
;; "buy at sizing-day close" arithmetic ($1,899,804.64) underestimates the
;; runner output by ~$13k; the runner is not buggy, the spreadsheet just
;; doesn't model the next-day-open fill the simulator actually performs.
;;
;; {1 Accounting findings}
;;
;; None. Day-1 commission (~$40) and next-day-open fill behavior are both
;; deterministic against the pinned SPY data. Both are pinned into
;; [total_return_pct] so a regression that drops commission or changes
;; fill semantics would surface here.
;;
;; Adjusted close 2019-01-02 = $224.38 -> 2023-12-29 = $462.57 = +106.16%
;; is the dividend-reinvested return; we do NOT pin against this number
;; since BAH uses raw close throughout.
;;
;; {1 Pinned ranges}
;;
;; total_return_pct: +/- 2 pp around the runner-actual +91.31% (89.0..93.0).
;; Tighter than the Weinstein scenario's +/- 13 pp because BAH is mechanical
;; — no parameter sensitivity, no stop slippage, no cash-deployment timing.
;; The only sources of drift are SPY's day-1 close (deterministic against
;; pinned data files) and commission tier changes (a config-level decision
;; that should re-pin this file).
;;
;; total_round_trips = 0: BAH never sells, so 0 closed round-trips on the
;; total_trades field (which counts ROUND-TRIPS, not fills). Note that the
;; simulator records exactly 1 ENTRY trade in trades.csv that does not
;; produce a closed round-trip. Pinned via a tight [(min 0) (max 0.5)]
;; band; the existing ranges in [scenario_runner._actual_of_result]
;; populate this from [List.length r.round_trips], not from raw fill count.
;;
;; sharpe_ratio / max_drawdown_pct / avg_holding_days: tracked but loosely
;; pinned. The bands below reflect SPY's 2019-2023 reality (peak drawdown
;; ~34% during the COVID crash; ~25% during the 2022 bear) and will be
;; tightened in a follow-up once the postsubmit run reports actuals.
;; avg_holding_days defaults to 0 when there are no closed round-trips
;; (BAH's case), so it's pinned tight at [(min 0) (max 1)] to catch any
;; regression that flips it to a non-zero value via a phantom round-trip.
;;
;; open_positions_value: 3997 shares * $476.69 = $1,905,330.93 marked to
;; market on 2023-12-28 (last bar processed). +/- 2% band = 1.87M..1.94M.
;;
;; {1 Universe}
;;
;; [universes/spy-only.sexp] is a one-symbol pinned universe (SPY).
;; The runner's [Csv_snapshot_builder.build] tolerates missing CSVs for the
;; sector ETFs / global indices the runner pulls in alongside the universe,
;; so SPY's bars are loaded and other symbols stay NaN — the BAH strategy
;; only ever calls [get_price "SPY"] anyway.
;;
;; {1 Wiring (#882)}
;;
;; The [strategy] field below selects {!Strategy_choice.Bah_benchmark} —
;; the runner dispatches in [Panel_runner._build_strategy] and constructs
;; {!Trading_strategy.Bah_benchmark_strategy.make { symbol = "SPY" }} in
;; place of {!Weinstein_strategy.make}. End-to-end coverage lives in
;; [trading/trading/backtest/test/test_bah_runner_e2e.ml] (skips when SPY
;; data is unavailable in [test_data/]; runs locally with the full [data/]
;; mount).
((name "sp500-2019-2023-bah-spy")
 (description "Buy-and-Hold SPY 2019-2023 — accounting sanity + alpha bar")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/spy-only.sexp")
 (universe_size 1)
 (config_overrides ())
 (strategy (Bah_benchmark (symbol SPY)))
 (expected
  ((total_return_pct       ((min  89.00)      (max   93.00)))
   (total_trades           ((min   0.0)       (max    0.5)))
   (win_rate               ((min   0.0)       (max  100.0)))
   (sharpe_ratio           ((min   0.40)      (max    0.85)))
   (max_drawdown_pct       ((min  23.0)       (max   36.0)))
   (avg_holding_days       ((min   0.0)       (max    1.0)))
   (open_positions_value   ((min 1870000.0)   (max  1940000.0))))))
