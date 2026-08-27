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
;; {1 Measurement (2026-05-17, $1,000,000 initial cash, via Backtest.Runner)}
;;
;; Verified through {!Backtest.Runner.run_backtest} with [strategy_choice =
;; Bah_benchmark { symbol = "SPY" }]. Entry sizing happens at day-1 close
;; with a 1% gap-buffer headroom (see [_entry_gap_buffer_pct] in
;; [bah_benchmark_strategy.ml]), trade fills at the StopLimit trigger
;; since #2569 (pre-flip: next-day open — orders placed in
;; [on_market_close] execute against the next bar; the fill-model default
;; flip routes even BAH through the entry cap). The simulator stops one
;; bar before [end_date] (the [is_complete] check fires when
;; [current_date >= end_date]), so the final mark-to-market uses
;; [end_date - 1 trading day]'s close.
;;
;;   sizing close 2019-01-02:  $250.18
;;   gap-buffered sizing px:   $252.6818  (= 250.18 * 1.01)
;;   shares bought:            3957 (= floor(1,000,000 / 252.6818))
;;   fill (StopLimit trigger): ~$250.24  (was next-day open $248.23
;;     pre-#2569: the fill-model default flip routes even BAH sleeves
;;     through the StopLimit entry cap -- see the brk-b twin + the
;;     arc-readiness follow-up; closed form here is APPROXIMATE, the
;;     runner-actual is the pin)
;;   entry commission:         $39.57 ($0.01/share * 3957)
;;   leftover cash:            ~$9,800  (closed-form approximation)
;;     (~= 1,000,000 - 3957 * 250.24 - 39.57)
;;   final close 2023-12-28:   $476.69
;;     (last bar processed; end_date 2023-12-29 is not stepped)
;;   final equity:             $1,896,010.32  (runner-actual, post-#2569;
;;     was $1,903,976.65 pre-flip -- matches test_bah_runner_e2e's pin)
;;   total_return_pct:         +89.60%  (was +90.40% pre-#2569)
;;   SPY raw return (sizing 2019-01-02 close to MtM 2023-12-28 close):
;;                             +90.5%  (= 476.69 / 250.18 - 1)
;;
;; POST-#2569 the runner-actual is $1,896,010.32 and the approximate
;; closed form above lands within ~$13 of it (fill-price rounding).
;; Pre-flip record: closed-form $1,904,115.65 vs runner $1,903,976.65
;; (~$140 residual). In both eras the runner output is the
;; authoritative pin.
;;
;; The 1% gap buffer was introduced in PR #1172 to fix the weekly-start
;; sweep's ~45% zero-trade rate: without it, next-day-open gap-ups busted
;; the cash budget on a tight floor(cash/close) share count, the simulator
;; silently dropped the rejected fill, and the position stuck in [Entering]
;; with 0 fills forever. Sweep zero-trade cells dropped from 70/157 to 4/157
;; after the fix.
;;
;; {1 Accounting findings}
;;
;; Day-1 commission (~$40) is deterministic against the pinned SPY data.
;; HISTORY NOTE (2026-08-26): the original text here claimed a fill-
;; semantics change "would surface" in [total_return_pct] -- PR #2569
;; (fill-model default flip) is the counterexample: the fill moved from
;; next-day open to the StopLimit trigger (-0.80pp return) and the cell
;; PASSED silently inside its 89.00..93.00 band. Band-width regression
;; detection has a floor; the closed-form comments above are the record
;; that catches sub-band drifts.
;;
;; Adjusted close 2019-01-02 = $224.38 -> 2023-12-29 = $462.57 = +106.16%
;; is the dividend-reinvested return; we do NOT pin against this number
;; since BAH uses raw close throughout.
;;
;; {1 Pinned ranges}
;;
;; total_return_pct: 89.0..93.0 -- centred on the PRE-flip runner-actual
;; +91.31% and DELIBERATELY not re-centred for #2569: the post-flip
;; actual +89.60% sits inside, and the +-2pp determinism scheme is the
;; contract; re-centre only if a future change pushes it out.
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
;; open_positions_value: 3957 shares * $476.69 = $1,886,361.33 marked to
;; market on 2023-12-28 (last bar processed). The current pinned band
;; [1.87M..1.94M] absorbs the post-fix value; no re-anchor needed.
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
