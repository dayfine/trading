;; perf-tier: 3
;; perf-tier-rationale: Buy-and-Hold-BRK-B benchmark over the canonical
;; 2019-2023 window. Companion to [sp500-2019-2023-bah-spy.sexp] —
;; same window, same starting cash, different reference instrument
;; (BRK-B = Berkshire Hathaway Class B, an active-value baseline
;; alongside SPY's passive-market baseline). Single-symbol, single-trade
;; — fastest possible run on the SP500 surface. Tagged [perf-tier: 3]
;; so [golden_sp500_postsubmit.sh] picks it up alongside
;; [sp500-2019-2023-bah-spy.sexp] — running both gives the active
;; strategy two reference points (passive index + active value-style
;; reference) at every postsubmit run.
;;
;; Buy-and-Hold-BRK-B benchmark — pinned for the canonical 2019-2023 window.
;;
;; Dual purpose:
;;
;;   1. Comparison baseline. Weinstein's stage-2 trend-following targets
;;      growth/momentum stocks; BRK is the canonical
;;      buy-and-hold-quality-businesses opposite school of thought.
;;      Tracking the active strategy against BRK-B answers "is the
;;      active strategy adding alpha vs the most-cited active-passive
;;      reference?".
;;
;;   2. Accounting sanity check. BAH-BRK-B's final equity should track
;;      BRK-B's raw-close price-only return very tightly (modulo the
;;      day-2-open fill convention documented below). Sub-basis-point
;;      drift from the closed-form indicates the simulator's broker /
;;      MtM / cash-accounting path is working symmetrically across the
;;      SPY and BRK-B instances of the same strategy.
;;
;; {1 Strategy}
;;
;; [Trading_strategy.Bah_benchmark_strategy] (added in PR #874,
;; symbol-parameterized via [config.symbol]): on day 1, buys
;; [floor(initial_cash / BRK-B_close)] shares of BRK-B with all available
;; cash; holds indefinitely; never sells, rebalances, or adjusts. Single
;; CreateEntering transition followed by a stationary position.
;;
;; {1 Measurement (2026-05-17, $1,000,000 initial cash, via Backtest.Runner)}
;;
;; Closed-form sanity using the simulator's day-2-open fill convention
;; (entry sizing at day-1 close, fill at next-day open, final mark uses
;; [end_date - 1 trading day]'s close):
;;
;;   sizing close 2019-01-02:  $202.80
;;   shares bought:            4997 = floor(1,000,000 / 202.80) ... wait,
;;                             1,000,000 / 202.80 = 4930.97..., so
;;                             4931 actually.
;;   shares bought:            4931
;;   fill open  2019-01-03:    $199.97
;;   entry commission:         $49.31 ($0.01/share * 4931)
;;   leftover cash:            $13,898.62
;;     (= 1,000,000 - 4931 * 199.97 - 49.31)
;;   final close 2023-12-28:   $357.57
;;     (last bar processed; end_date 2023-12-29 is not stepped — same
;;     [current_date >= end_date] [is_complete] semantics as bah-spy)
;;   final equity:             $1,777,076.29
;;     (= 13,898.62 + 4931 * 357.57)
;;   total_return_pct:         +77.71%
;;   BRK-B raw return (sizing 2019-01-02 close to MtM 2023-12-28 close):
;;                             +76.32%  (= 357.57 / 202.80 - 1)
;;
;; The ~+1.4 pp delta vs the closed-form raw-close ratio mirrors the
;; SPY BAH dynamic — the day-2 open ($199.97) is below the day-1 close
;; ($202.80), giving the strategy a slightly cheaper effective entry
;; with leftover cash carried through to end-of-window MtM. The
;; commission drag (~$49) is structurally identical to the SPY pin.
;;
;; {1 Comparison to BAH-SPY 2019-2023}
;;
;; SPY 5y total return (pinned): +91.31%.
;; BRK-B 5y total return:       +77.71%.
;; Spread: BRK-B underperformed SPY by ~13.6 pp over 2019-2023. This is
;; the documented BRK underperformance during the post-COVID growth /
;; tech rally — value style lagged momentum style materially over this
;; window. The 15y companion (post-split start) shows a different
;; picture; see [goldens-sp500-historical/sp500-2011-2026-bah-brk-b.sexp].
;;
;; {1 Adjusted-close vs raw-close (no split in window)}
;;
;; BRK-B's only stock split was the 50-for-1 on 2010-01-21 (to enable
;; the BNSF acquisition cash-component). The 5y window 2019-2023 is
;; post-split — raw close and adjusted close move ~identically (modulo
;; dividend reinvestment, which is moot for BRK because Berkshire pays
;; no dividend). Adjusted close 2019-01-02 = $202.80 -> 2023-12-29 =
;; $356.66 = +75.87% is the SAME shape as raw close. We pin against
;; raw-close-derived numbers; no split-adjustment math required.
;;
;; {1 Pinned ranges}
;;
;; total_return_pct: ±2 pp around the closed-form +77.71% (75.7..79.7).
;; Same tolerance scheme as the SPY pin — mechanical strategy, no
;; parameter sensitivity, no stop slippage, no cash-deployment timing.
;; The only sources of drift are BRK-B's day-1 close (deterministic
;; against pinned data) and commission tier changes (a config-level
;; decision that should re-pin this file).
;;
;; total_trades = 0 round-trips: BAH never sells, so 0 closed round-
;; trips on the total_trades field (which counts ROUND-TRIPS, not
;; fills). The simulator records exactly 1 ENTRY trade in trades.csv
;; that does not produce a closed round-trip. Pinned via a tight
;; [(min 0) (max 0.5)] band identical to bah-spy's.
;;
;; sharpe_ratio / max_drawdown_pct / avg_holding_days: tracked but
;; loosely pinned. The bands reflect BRK-B's 2019-2023 reality (peak
;; drawdown ~30% during the COVID crash, similar to SPY; sharpe lower
;; than SPY due to the value-style underperformance during the period).
;; avg_holding_days defaults to 0 when there are no closed round-trips
;; (BAH's case), so it's pinned tight at [(min 0) (max 1)] to catch
;; any regression that flips it to a non-zero value via a phantom
;; round-trip.
;;
;; open_positions_value: 4931 shares * $357.57 = $1,763,178 marked to
;; market on 2023-12-28 (last bar processed). ±2% band ≈ 1.73M..1.80M.
;;
;; {1 Universe}
;;
;; [universes/brk-b-only.sexp] is a one-symbol pinned universe (BRK-B).
;; The runner's [Csv_snapshot_builder.build] tolerates missing CSVs for
;; the sector ETFs / global indices the runner pulls in alongside the
;; universe, so BRK-B's bars are loaded and other symbols stay NaN —
;; the BAH strategy only ever calls [get_price "BRK-B"] anyway.
;;
;; {1 Wiring}
;;
;; The [strategy] field below selects {!Strategy_choice.Bah_benchmark}
;; with [symbol = "BRK-B"] — the runner dispatches in
;; [Panel_runner._build_strategy] and constructs
;; {!Trading_strategy.Bah_benchmark_strategy.make { symbol = "BRK-B" }}
;; in place of {!Weinstein_strategy.make}. End-to-end coverage shares
;; the [test_bah_runner_e2e.ml] machinery with the SPY case via the
;; new BRK-B test parallel.
((name "sp500-2019-2023-bah-brk-b")
 (description "Buy-and-Hold BRK-B 2019-2023 — active-value reference baseline alongside BAH-SPY")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/brk-b-only.sexp")
 (universe_size 1)
 (config_overrides ())
 (strategy (Bah_benchmark (symbol BRK-B)))
 (expected
  ((total_return_pct       ((min  75.70)      (max   79.70)))
   (total_trades           ((min   0.0)       (max    0.5)))
   (win_rate               ((min   0.0)       (max  100.0)))
   (sharpe_ratio           ((min   0.20)      (max    0.70)))
   (max_drawdown_pct       ((min  18.0)       (max   34.0)))
   (avg_holding_days       ((min   0.0)       (max    1.0)))
   (open_positions_value   ((min 1730000.0)   (max  1800000.0))))))
