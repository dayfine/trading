;; P0 barbell-on-stocks — the ENGINE curve.
;; Full Cell E production Weinstein strategy on the clean point-in-time S&P 500
;; (survivor-bias-free Wikipedia membership-replay), deep window
;; 2000-01-01 → 2026-04-30. This is the return-engine leg of the barbell blend
;; against the SPY-only floor (p0-barbell-spy/spy-only-deep.sexp).
;;
;; Config = canonical Cell E (identical to goldens-sp500-historical/
;; sp500-1998-2026.sexp and sp500-2010-2026.sexp): 0.14/0.70/0.30 sizing +
;; stage3-force-exit h=1 + laggard-rotation h=2; macro gate on by default in
;; the full Weinstein strategy. Cost-model overlay mirrors the goldens.
;;
;; Universe: PIT S&P 500 as-of 2000-01-01 (~515 symbols). Wide research bands —
;; this reproduces the doc's 918%/37%/0.25 deep result to recover the equity
;; curve for the blend. Not a pinned golden. See
;; next-session-priorities-2026-06-03.md P0.
((name "production-deep")
 (description "Cell E production strategy on PIT S&P 500 (2000-01-01 snapshot) 2000-2026 — barbell ENGINE curve.")
 (period ((start_date 2000-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2000-01-01.sexp")
 (universe_size 515)
 (config_overrides
  (((enable_short_side false))
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
  ((total_return_pct  ((min -90.0)  (max 100000.0)))
   (total_trades      ((min   0.0)  (max 100000.0)))
   (win_rate          ((min   0.0)  (max  100.0)))
   (sharpe_ratio      ((min  -2.0)  (max    5.0)))
   (max_drawdown_pct  ((min   0.0)  (max   95.0)))
   (avg_holding_days  ((min   0.0)  (max 5000.0)))
   (wall_seconds      ((min   1.0)  (max 360000.0))))))
