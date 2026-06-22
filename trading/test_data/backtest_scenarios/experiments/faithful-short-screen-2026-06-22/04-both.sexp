;; Faithful-short screen (Build 3) — ARM: BOTH faithful flags ON.
;;
;; neutral_blocks_shorts=true AND enable_slow_grind_short_gate=true: the full
;; Build-3 faithful short — shorts admitted only on a Bearish tape AND only
;; when the index decline is a slow grind (no Neutral-tape shorts, no fast-V
;; shorts). The most restrictive arm. Overlay identical to baseline.
((name "faithful-short-04-both")
 (description
   "Faithful-short screen: BOTH faithful flags ON (Bearish + slow-grind only shorts). SP500 2010-2026.")
 (period ((start_date 2010-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2010-01-01.sexp")
 (universe_size 510)
 (config_overrides
  (((enable_short_side true))
   ((neutral_blocks_shorts true))
   ((enable_slow_grind_short_gate true))
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
