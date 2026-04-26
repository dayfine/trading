;; Panel-mode golden parity scenario — second fixture for the
;; [test_panel_round_trips_golden] gate.
;;
;; Differs from [tiered-loader-parity.sexp] only in the time window:
;; covers (almost) the full range of committed synthetic ETF/index data
;; (2018-10-01 to 2020-01-03), so we exercise the panel runner across a
;; longer stretch than the 6-month parity window. Same 7-symbol universe
;; (universes/parity-7sym.sexp) keeps the run cheap.
;;
;; Per [dev/plans/data-panels-stage3-2026-04-25.md] §PR 3.1, the gate
;; uses a sexp golden bit-equality check on the full round_trips list.
;; Pinned metric ranges are intentionally broad — the round_trips
;; bit-equality is the load-bearing check; the [expected] block only
;; catches gross regressions.
((name "panel-golden-2019-full")
 (description "Panel-mode golden parity (full ETF data window)")
 (period ((start_date 2019-05-01) (end_date 2020-01-03)))
 (universe_path "universes/parity-7sym.sexp")
 (universe_size 7)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min -20.0)  (max 40.0)))
   (total_trades       ((min 0)      (max 20)))
   (win_rate           ((min 0.0)    (max 100.0)))
   (sharpe_ratio       ((min -5.0)   (max 10.0)))
   (max_drawdown_pct   ((min 0.0)    (max 40.0)))
   (avg_holding_days   ((min 0.0)    (max 200.0))))))
