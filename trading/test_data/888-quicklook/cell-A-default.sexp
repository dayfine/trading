;; #888 quick-look — Cell A: default (min_score_override = None)
;; Expected to reproduce sp500-2019-2023 baseline: 58.34% / 81 trades.
;; Universe / period identical to goldens-sp500/sp500-2019-2023.sexp.
((name "888-cell-A-default")
 (description "#888 quick-look Cell A: default min_score_override (None) — baseline reproduction")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 500)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min  -100.0)     (max 1000.0)))
   (total_trades       ((min 0)           (max 10000)))
   (win_rate           ((min 0.0)         (max 100.0)))
   (sharpe_ratio       ((min -10.0)       (max  10.0)))
   (max_drawdown_pct   ((min 0.0)         (max 100.0)))
   (avg_holding_days   ((min 0.0)         (max 1000.0)))
   (open_positions_value ((min -10000000.0) (max 10000000.0))))))
