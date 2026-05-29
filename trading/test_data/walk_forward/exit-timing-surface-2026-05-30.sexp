;; Exit-timing SURFACE sweep — first real use of the experiment platform.
;;
;; Re-attacks the trade-autopsy missed gain (modes 1+2: late_reentry +
;; stage3_false_positive, ~2734% over 27y x 12 sym) as a SURFACE, not a point.
;; The single point (hysteresis_weeks=2, stage3_exit_margin_pct=0.02) was already
;; REJECTED on 31-fold WF-CV (dev/notes/stage3-hysteresis-walkforward-cv-2026-05-29.md;
;; ledger dev/experiments/_ledger/2026-05-29-stage3-hysteresis-wf-cv.sexp). This
;; sweep tests whether ANY cell of the exit-timing knob surface survives the fold
;; distribution — or whether the whole surface is a dead end (a stronger negative
;; than one rejected point).
;;
;; Axes (Cartesian = 9 cells + auto-baseline):
;;   stage3_force_exit_config.hysteresis_weeks in {1, 2, 3}
;;   stage3_exit_margin_pct                    in {0.0, 0.02, 0.05}
;; The (h=1, m=0.0) cell reproduces the panel baseline (base scenario already pins
;; hysteresis_weeks=1, margin defaults 0.0) — a within-run sanity anchor.
;;
;; Geometry: identical to the rejected hysteresis spec — Rolling 2010-2026,
;; test_days=365 step_days=182 => 31 OOS folds (fold-000..fold-030); gate.n=31.
;; Gate is a validity placeholder (n matches fold count); the DECISION is the
;; cross-variant ranking (Walk_forward.Variant_ranking Pareto + Backtest_stats
;; .Deflated_sharpe best-of-N deflation), harvested post-run.

((base_scenario "goldens-sp500-historical/sp500-2010-2026.sexp")
 (window_spec
  (Rolling
   ((start_date 2010-01-01)
    (end_date 2026-04-30)
    (train_days 0)
    (test_days 365)
    (step_days 182))))
 (baseline_label "baseline")
 (gate ((metric Sharpe) (m 16) (n 31) (worst_delta 0.20)))
 (axes
  ((axes
    (((key (stage3_force_exit_config hysteresis_weeks)) (values (1 2 3)))
     ((key (stage3_exit_margin_pct)) (values (0.0 0.02 0.05)))))
   (expansion Cartesian))))
