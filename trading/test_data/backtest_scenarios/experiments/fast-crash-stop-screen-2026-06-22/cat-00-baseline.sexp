;; Fast-crash-stop screen — BASELINE (catastrophic_stop_pct = 0.0 = off).
;;
;; 2019-2021 spans the 2020 fast-V crash with a 2019 bull warmup and a 2021
;; bull recovery. Default config except the universe. The catastrophic stop is
;; off (default), so this reproduces the "structural stop exits at the bottom"
;; behavior the screen is testing against.
((name "cat-00-baseline-2019-2021")
 (description
   "Fast-crash-stop screen baseline: catastrophic_stop_pct=0.0 (off), 2019-2021.")
 (period ((start_date 2019-01-01) (end_date 2021-12-31)))
 (universe_path "universes/fast-crash-screen.sexp")
 (config_overrides
  (((stops_config ((catastrophic_stop_pct 0.0))))))
 (expected
  ((total_return_pct        ((min -90.0)  (max 1000.0)))
   (total_trades            ((min   1)    (max 2000)))
   (win_rate                ((min   0.0)  (max 100.0)))
   (sharpe_ratio            ((min  -3.0)  (max   5.0)))
   (max_drawdown_pct        ((min   0.0)  (max  90.0)))
   (avg_holding_days        ((min   0.0)  (max 800.0)))
   (sortino_ratio_annualized ((min -3.0)  (max  10.0)))
   (calmar_ratio            ((min  -3.0)  (max   5.0)))
   (ulcer_index             ((min   0.0)  (max  60.0)))
   (open_positions_value    ((min -1.0e12) (max 1.0e12))))))
