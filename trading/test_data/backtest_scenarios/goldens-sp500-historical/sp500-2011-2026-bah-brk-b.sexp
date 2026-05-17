;; perf-tier: 3-historical
;; perf-tier-rationale: 15y Buy-and-Hold-BRK-B benchmark — companion to
;; [sp500-2010-2026.sexp] (the 15y active-Weinstein cell) and to
;; [sp500-2019-2023-bah-brk-b.sexp] (the 5y BAH-BRK-B cell). Tagged
;; [perf-tier: 3-historical] alongside the active 15y golden so the
;; historical postsubmit gate picks up both — running the active and
;; passive cells on the same window makes the BRK-B alpha gap visible
;; at every postsubmit on the 15y horizon, mirroring the
;; [sp500-2019-2023-bah-spy.sexp]/[sp500-2019-2023.sexp] pairing on
;; the 5y horizon.
;;
;; {1 Window choice — 2011-01-03 start, NOT 2010-01-01}
;;
;; BRK-B's only stock split was a 50-for-1 on 2010-01-21 (to enable the
;; BNSF acquisition cash-component): raw close jumped from $3,476 on
;; 2010-01-20 to $72.72 on 2010-01-21. Because the BAH strategy reads
;; the [close] field directly and the simulator marks-to-market against
;; raw closes (not adjusted closes; see the explicit choice documented
;; in [sp500-2019-2023-bah-spy.sexp] §"Adjusted close"), a window that
;; spans the split would produce a catastrophic phantom 98% drawdown on
;; 2010-01-21 that does NOT reflect investor experience. Starting the
;; window 2011-01-03 — eleven months after the split — avoids the
;; raw-close discontinuity entirely. The trade-off is ~1y less window;
;; net window is 2011-01-03 → 2026-04-30 = 15y 4m of post-split history,
;; which is the longest split-clean BRK-B window we can pin against
;; without a runner change.
;;
;; The companion active-Weinstein 15y golden
;; [sp500-2010-2026.sexp] starts 2010-01-01 — but that golden runs an
;; SP500 universe in which BRK-B is just one of ~510 names; even if a
;; BRK-B position were opened pre-split, the split's effect would be a
;; single-name drawdown swamped by the broader portfolio. The BAH cell
;; can't dilute the single-symbol effect, so it needs its own start
;; date.
;;
;; {1 Strategy}
;;
;; Identical to the 5y cell: [Trading_strategy.Bah_benchmark_strategy]
;; with [symbol = "BRK-B"]. Single CreateEntering transition on day 1,
;; held to end_date.
;;
;; {1 Measurement (2026-05-17, $1,000,000 initial cash, closed-form)}
;;
;;   sizing close 2011-01-03:  $80.41
;;   shares bought:            12436 = floor(1,000,000 / 80.41)
;;   fill open  2011-01-04:    $80.33
;;   entry commission:         $124.36 ($0.01/share * 12436)
;;   leftover cash:            $891.76
;;     (= 1,000,000 - 12436 * 80.33 - 124.36)
;;   final close 2026-04-29:   $475.38
;;     (last bar processed; end_date 2026-04-30 not stepped — same
;;     [current_date >= end_date] [is_complete] semantics as bah-spy)
;;   final equity:             $5,912,717
;;     (= 891.76 + 12436 * 475.38)
;;   total_return_pct:         +491.27%
;;   BRK-B raw return (sizing 2011-01-03 close to MtM 2026-04-29 close):
;;                             +491.20%  (= 475.38 / 80.41 - 1)
;;   CAGR over 15.32y:         ~12.3%/yr (consistent with BRK's
;;                             long-term ~10-13% returns)
;;
;; The trivial delta between final-equity total return and raw-close
;; ratio reflects the day-2-open fill ($80.33 < $80.41 day-1 close)
;; almost exactly offsetting the leftover-cash carry — over 15y the
;; effect is rounding noise.
;;
;; {1 Comparison points}
;;
;; SP500 active strategy (2010-2026, Cell E): +341.7% total return,
;; Sharpe 0.78, max DD 18.4% (per [sp500-2010-2026.sexp] pin 2026-05-13).
;; BRK-B BAH 5y (2019-2023): +77.7% total return.
;; BRK-B BAH 15y (2011-2026): +491.3% total return.
;;
;; BRK-B has OUT-performed the active Weinstein strategy on the 15y
;; window (491 vs 342) while UNDER-performing SPY on the 5y window
;; (78 vs 91). This bidirectional spread is exactly why having both
;; SPY and BRK-B benchmarks at multiple horizons is useful — the
;; story differs by window and by horizon. The 15y alpha gap is the
;; load-bearing finding that justifies the BRK-B golden investment.
;;
;; {1 Pinned ranges}
;;
;; total_return_pct: ±10 pp around the closed-form +491.3% (481..501).
;; Tighter than other 15y cells because BAH is mechanical — no
;; strategy-parameter sensitivity. The only drift sources are BRK-B's
;; day-1 close (deterministic against pinned data) and commission
;; tier changes.
;;
;; sharpe_ratio: BRK-B 15y Sharpe is harder to pin tightly without a
;; first runner-actual measurement; band [(min 0.5) (max 1.1)]
;; absorbs the ~0.8-1.0 long-term BRK Sharpe regime plus the
;; non-rebalanced single-position concentration risk.
;;
;; max_drawdown_pct: spans the 2011 European-debt scare (~17%), the
;; 2015-16 China scare (~14%), the COVID crash (~30% on BRK-B), and
;; the 2022 bear (~20%). Pinned [(min 22) (max 38)] to cover the
;; COVID-anchored worst-case.
;;
;; open_positions_value: 12436 * $475.38 ≈ $5,911,825 marked at
;; 2026-04-29. ±3% band ≈ 5.74M..6.08M.
;;
;; total_trades = 0 round-trips, same accounting as the 5y cell.
;;
;; {1 Universe + wiring}
;;
;; [universes/brk-b-only.sexp] — same one-symbol universe as the 5y
;; cell, sector="Financial Services" (informational only; BAH
;; ignores sectors).
;;
;; The [strategy] field below selects {!Strategy_choice.Bah_benchmark}
;; with [symbol = "BRK-B"] — runner dispatch path identical to the
;; 5y cell.
((name "sp500-2011-2026-bah-brk-b")
 (description
   "Buy-and-Hold BRK-B 2011-2026 — 15y post-split active-value reference baseline. Start date 2011-01-03 chosen to avoid the 2010-01-21 50-for-1 BRK-B split.")
 (period ((start_date 2011-01-03) (end_date 2026-04-30)))
 (universe_path "universes/brk-b-only.sexp")
 (universe_size 1)
 (config_overrides ())
 (strategy (Bah_benchmark (symbol BRK-B)))
 (expected
  ((total_return_pct       ((min 481.00)      (max  501.00)))
   (total_trades           ((min   0.0)       (max    0.5)))
   (win_rate               ((min   0.0)       (max  100.0)))
   (sharpe_ratio           ((min   0.50)      (max    1.10)))
   (max_drawdown_pct       ((min  22.0)       (max   38.0)))
   (avg_holding_days       ((min   0.0)       (max    1.0)))
   (open_positions_value   ((min 5740000.0)   (max  6080000.0))))))
