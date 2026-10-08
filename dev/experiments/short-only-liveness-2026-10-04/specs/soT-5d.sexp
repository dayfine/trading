;; short-only-liveness-2026-10-04 (Phase A of the short-only design): trader shorts, buffer stop
;; Staging scenario, NOT a golden. Base = ../../shorts-liveness-2026-10-03/specs/shB-5d.sexp; changes marked SO.
((name "soT-5d")
 (description "short-only trader shorts, buffer stop, 5d")
 (period ((start_date 2007-06-01) (end_date 2012-06-29)))
 (universe_path "pit-v11/composition/top-3000-2006.sexp")
 (universe_schedule (
  (2006-05-31 "pit-v11/composition/top-3000-2006.sexp")
  (2007-05-31 "pit-v11/composition/top-3000-2007.sexp")
  (2008-05-31 "pit-v11/composition/top-3000-2008.sexp")
  (2009-05-31 "pit-v11/composition/top-3000-2009.sexp")
  (2010-05-31 "pit-v11/composition/top-3000-2010.sexp")
  (2011-05-31 "pit-v11/composition/top-3000-2011.sexp")
  ))
 (universe_size 3000)
 (config_overrides
  (
   ((enable_sim_entry_stoplimit true))
   ((sim_entry_trigger_at_suggested false))   ; SO: ticket at the current close (trader: full size on the breakdown)
   ((sim_entry_stoplimit_fresh_bar_only true))
   ((sim_stop_exit_fill_on_trigger_bar true))
   ((stop_anchor_at_entry_base true))
   ((entry_extension_max_pct 2.0))
   ((reject_declining_ma_long_entry true))
   ((enable_short_side true))
   ((neutral_blocks_shorts true))
   ((enable_slow_grind_short_gate false))     ; SO: not a book rule; ledger 2026-06-22-slow-grind-adlive-wfcv Reject
   ((short_min_price 17.0))
   ((short_borrow_min_dollar_adv 1000000.0))
   ((margin_config ((enabled true))))
   ((margin_config ((maintenance_margin_pct 0.30))))
   ((margin_config
     ((short_borrow_rate_tiers
       (((price_below 5.0) (value 1.00)) ((price_below 17.0) (value 0.25)))))))
   ;; #3148: this step applies the $5/share floor at its $6 value (0.83) across $5-17, which
   ;; overstates FINRA 4210(c) max($5/p, 30 %) everywhere above $6.02 (0.50 at $10, 0.30 from
   ;; $16.67) and margin-called winning shorts (UBSI 2009-02-18). Kept as run; a rerun should use
   ;; ((margin_config ((short_maintenance_finra true)))) instead.
   ((margin_config
     ((short_maintenance_tiers
       (((price_below 5.0) (value 1.00)) ((price_below 17.0) (value 0.83)))))))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((liquidity_config ((min_entry_dollar_adv 1000000.0))))
   ((liquidity_config ((min_hold_dollar_adv 500000.0))))
   ((stale_exit_after_days (5)))
   ((macro_config ((breadth_direction ((enabled true))))))
   ((require_structural_stop false))          ; SO: ~4-6 % buffer stop above the breakdown (book trader stop, Ch. 7)
   ((max_one_share_class_per_issuer true))
   ((screening_config ((max_buy_candidates 0))))     ; SO: longs off
   ((screening_config ((max_short_candidates 20))))  ; SO: was 10
   ((portfolio_config ((max_short_exposure_pct 0.60))))
   ((portfolio_config ((max_short_notional_fraction 0.60))))
   ((portfolio_config ((max_position_pct_short 0.10))))
  ))
 (expected ((total_return_pct ((min -90.0) (max 90000.0))) (total_trades ((min 1) (max 90000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
