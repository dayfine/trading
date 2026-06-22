;; perf-tier: research
;; perf-tier-rationale: DEEP long-short base for the neutral_blocks_shorts
;; walk-forward CV (faithful-short-deep-screen-2026-06-22 → promote-track).
;; Long-short twin of the deep universe, on the point-in-time sp500-as-of-2000
;; membership (incl. delistings) over 2000-2026 (dot-com bust + GFC + bull).
;; Used ONLY as the WF base_scenario (the window_spec drives the folds); the
;; period here is a default. Reads the gitignored repo-root data/ store (deep
;; 1998-2026 bars fetched 2026-06-22). NOT a pinned golden — research-tier,
;; sentinel bands only.
((name "sp500-2000-2026-longshort-deep")
 (description
   "Deep long-short base (sp500-as-of-2000 PIT, 2000-2026, enable_short_side=true) for the neutral_blocks_shorts WF-CV. Same overlay as sp500-2010-2026-longshort.")
 (period ((start_date 2000-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2000-01-01.sexp")
 (universe_size 515)
 (config_overrides
  (((enable_short_side true))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (cost_model
  ((per_trade_commission 0.0)
   (per_share_commission 0.0)
   (bid_ask_spread_bps 5.0)
   (market_impact_bps_per_pct_adv 0.0)))
 (expected
  ((total_return_pct        ((min -90.0)  (max 5000.0)))
   (total_trades            ((min   1)    (max 9000)))
   (win_rate                ((min   0.0)  (max 100.0)))
   (sharpe_ratio            ((min  -3.0)  (max   5.0)))
   (max_drawdown_pct        ((min   0.0)  (max  90.0)))
   (avg_holding_days        ((min   0.0)  (max 800.0)))
   (sortino_ratio_annualized ((min -3.0)  (max  10.0)))
   (calmar_ratio            ((min  -3.0)  (max   5.0)))
   (ulcer_index             ((min   0.0)  (max  60.0)))
   (open_positions_value    ((min -1.0e12) (max 1.0e12))))))
