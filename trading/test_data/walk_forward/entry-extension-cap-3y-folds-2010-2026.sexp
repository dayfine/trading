;; entry_extension_max_pct WF-CV — THREE-YEAR folds, the horizon control for
;; entry-extension-cap-tight-2010-2026.sexp.
;;
;; WHY THIS EXISTS. The 1-year-fold surface (sibling spec, #2404) found tighter
;; is better on every metric: 1.0 beat baseline(=2.0) on return, Sharpe, MaxDD
;; and Calmar, winning Calmar 13/16 and MaxDD 15/16, while 5.0 was the worst
;; value tested on every mean. That measurement is real but its DESIGN is biased
;; toward the answer it produced:
;;
;;   A tighter cap's failure mode is a NO-FILL, which forgoes the stock's
;;   ENTIRE subsequent run. A 1-year fold TRUNCATES that run at the fold
;;   boundary, so the cost of a miss is systematically understated while the
;;   benefit of dodging a bad chase is fully counted inside the year.
;;
;; This spec is the same axis at test_days 1095. If tighter-is-better survives
;; a 3x longer horizon, the 1y result was not a truncation artifact. If the
;; ranking compresses or inverts, it was.
;;
;; WHAT THIS SPEC STILL CANNOT ANSWER (harness gap, do not paper over it):
;; [Walk_forward_types.fold_actual] carries no trade COUNT and no max
;; single-trade P&L — it has total_return_pct, sharpe, maxdd, calmar, cagr and
;; avg_holding_days only. The "takes fewer positions vs picks better"
;; discrimination therefore needs either a fold_actual field or a per-arm
;; trades.csv read. Do not claim the discrimination off this spec alone.
;; Filed as #2412.
;;
;; FOLD ARITHMETIC. 2010-01-01 -> 2026-04-30 is ~16.3 years; disjoint 3-year
;; folds (step = test) give 5. The gate is 3 of 5 rather than 9 of 16 for that
;; reason — with 5 folds the surface is a direction check, not a promotion
;; grid. Promotion still needs the confirmation grid
;; (.claude/rules/promotion-confirmation.md), including one macro-diverse cell.
;;
;; DUPLICATE CELL. 2.0 is the base scenario's own value, so its arm must come
;; back bit-identical to baseline on all 5 folds. That is the null tripwire
;; (project_ladder_v4_null_278pp); if it does not, the axis is not binding and
;; nothing else in the table is interpretable.
;;
;; PREREQUISITE: entry_extension_max_pct only binds when
;; enable_sim_entry_stoplimit is armed — the base scenario below arms it.
((base_scenario
  "test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023-armed-stoplimit.sexp")
 (window_spec
  (Rolling
   ((start_date 2010-01-01) (end_date 2026-04-30) (train_days 0)
    (test_days 1095) (step_days 1095))))
 (baseline_label baseline)
 (gate ((metric Calmar) (m 3) (n 5) (worst_delta 0.0)))
 (axes
  ((axes (((flag entry_extension_max_pct) (values (1.0 2.0 5.0 10.0 15.0)))))
   (expansion Cartesian))))
