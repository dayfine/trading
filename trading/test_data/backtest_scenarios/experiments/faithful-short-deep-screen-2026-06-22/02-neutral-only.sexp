;; Faithful-short DEEP screen (Build 3) — ARM: neutral_blocks_shorts ONLY.
;;
;; neutral_blocks_shorts=true: only a Bearish tape admits shorts (Neutral no
;; longer does). Tightens the short side to Weinstein's confirmed-bear rule.
;; Isolates the macro-gate leg of the faithful short. Overlay identical to
;; baseline; the slow-grind gate stays OFF here.
((name "faithful-short-deep-02-neutral-only")
 (description
   "Faithful-short DEEP screen: neutral_blocks_shorts=true only (Bearish-tape-only shorts). SP500 2000-2010.")
 (period ((start_date 2000-01-01) (end_date 2010-12-31)))
 (universe_path "universes/sp500-historical/sp500-2000-01-01.sexp")
 (universe_size 515)
 (config_overrides
  (((enable_short_side true))
   ((neutral_blocks_shorts true))
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
   (total_trades            ((min   1)    (max 5000)))
   (win_rate                ((min   0.0)  (max 100.0)))
   (sharpe_ratio            ((min  -3.0)  (max   5.0)))
   (max_drawdown_pct        ((min   0.0)  (max  90.0)))
   (avg_holding_days        ((min   0.0)  (max 800.0)))
   (sortino_ratio_annualized ((min -3.0)  (max  10.0)))
   (calmar_ratio            ((min  -3.0)  (max   5.0)))
   (ulcer_index             ((min   0.0)  (max  60.0)))
   (open_positions_value    ((min -1.0e12) (max 1.0e12))))))
