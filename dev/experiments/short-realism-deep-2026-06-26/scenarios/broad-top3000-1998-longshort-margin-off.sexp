;; Short-realism deep acceptance — BROAD top-3000 (PIT-1998) LONG-SHORT, 1998-2026.
;; This is the MARGIN-OFF twin (free-leverage baseline: short proceeds add to
;; deployable cash with no Reg-T collateral lock). Compare bottom-line + trade
;; records against the -margin-on twin to measure whether the merged margin model
;; (issue #859 Phase 1+2) deflates the inflated long-short absolute return and
;; keeps NAV non-negative AT BREADTH. See
;; dev/notes/short-realism-reconcile-2026-06-26.md (sp500 half) +
;; dev/notes/short-realism-deep-broad-2026-06-26.md (this broad half).
;;
;; Config = Cell-E long-short (mirrors cell-e-top3000-1998-longshort.sexp) with
;; enable_short_side + short_min_price 17 + max_position_pct_long 0.14; the ONLY
;; diff vs the -on twin is ((margin_config ((enabled false)))).
;; Universe top-3000 PIT-1998 composition snapshot (3000 symbols). N=3000 requires
;; snapshot mode (CSV mode OOMs the 7.75 GB container); run via
;; scenario_runner --snapshot-dir <warehouse>.
((name "sr-broad-top3000-1998-longshort-margin-off")
 (description "top-3000 PIT-1998 long-short, 1998-2026, Cell-E + short_min_price 17, margin OFF (free-leverage baseline).")
 (period ((start_date 1998-01-01) (end_date 2026-04-30)))
 (universe_path "../goldens-custom-universe/composition/top-3000-1998.sexp")
 (universe_size 3000)
 (config_overrides
  (((enable_short_side true))
   ((short_min_price 17.0))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((margin_config ((enabled false))))))
 (cost_model ((per_trade_commission 0.0)(per_share_commission 0.01)(bid_ask_spread_bps 0.0)(market_impact_bps_per_pct_adv 0.0)))
 (expected
  ((total_return_pct ((min -100.0)(max 1000000.0)))
   (total_trades     ((min 0)(max 1000000)))
   (win_rate         ((min 0.0)(max 100.0)))
   (sharpe_ratio      ((min -100.0)(max 100.0)))
   (max_drawdown_pct ((min 0.0)(max 100.0)))
   (avg_holding_days ((min 0.0)(max 100000.0))))))
