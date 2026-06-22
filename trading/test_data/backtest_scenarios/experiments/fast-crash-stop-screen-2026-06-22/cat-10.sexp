;; Fast-crash-stop screen — catastrophic_stop_pct = 0.10.
;;
;; Identical to cat-00-baseline except the fast-crash absolute stop is enabled
;; at 0.10. When the index is in a Fast_v decline (Decline_character.classify),
;; a long's stop fires at trailing_high * (1 - 0.10). Dormant otherwise.
((name "cat-10-2019-2021")
 (description
   "Fast-crash-stop screen: catastrophic_stop_pct=0.10, 2019-2021.")
 (period ((start_date 2019-01-01) (end_date 2021-12-31)))
 (universe_path "universes/fast-crash-screen.sexp")
 (config_overrides
  (((stops_config ((catastrophic_stop_pct 0.10))))))
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
