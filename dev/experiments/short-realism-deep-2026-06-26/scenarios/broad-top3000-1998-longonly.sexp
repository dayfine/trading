;; Short-realism deep results-of-record — BROAD top-3000 (PIT-1998) LONG-ONLY, 1998-2026.
;; The long-only sleeve companion to the long-short cells in this dir. Same Cell-E
;; sizing (max_position_pct_long 0.14, max_long_exposure_pct 0.70, min_cash_pct 0.30,
;; stage3 force-exit h=1, laggard h=2) — the ONLY difference vs the long-short cells is
;; that the short leg is absent (no enable_short_side / short_min_price / margin_config).
;; Recorded in dev/notes/deep-backtest-results-2026-06-26.md.
;; Universe top-3000 PIT-1998 composition snapshot (3000 symbols). N=3000 requires
;; snapshot mode (CSV mode OOMs the container); run via scenario_runner --snapshot-dir.
;; Experiment-only / GHA-skipped (perf-tier 4): needs the production deep data dir for
;; pre-2009 bars; reproducible locally, not part of any nightly/CI tier.
((name "sr-broad-top3000-1998-longonly")
 (description "top-3000 PIT-1998 long-only, 1998-2026, Cell-E sizing (0.14 concentration). Deep results-of-record long-only sleeve.")
 (period ((start_date 1998-01-01) (end_date 2026-04-30)))
 (universe_path "../goldens-custom-universe/composition/top-3000-1998.sexp")
 (universe_size 3000)
 (config_overrides
  (((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (cost_model ((per_trade_commission 0.0)(per_share_commission 0.01)(bid_ask_spread_bps 0.0)(market_impact_bps_per_pct_adv 0.0)))
 (expected
  ((total_return_pct ((min -100.0)(max 1000000.0)))
   (total_trades     ((min 0)(max 1000000)))
   (win_rate         ((min 0.0)(max 100.0)))
   (sharpe_ratio      ((min -100.0)(max 100.0)))
   (max_drawdown_pct ((min 0.0)(max 100.0)))
   (avg_holding_days ((min 0.0)(max 100000.0))))))
