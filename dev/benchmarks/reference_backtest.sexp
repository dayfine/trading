;; Reference backtest configuration — default Weinstein strategy parameters.
;; Extracted from Weinstein_strategy.default_config and sub-module defaults.
;; Used as the baseline for performance gate comparisons (T2-B).
;;
;; To reproduce: run backtest_runner with no --override flags.
;; Any --override changes only the overridden field; all others stay at these
;; defaults.

((runner
  ((initial_cash 1000000.0)
   (index_symbol GSPC.INDX)
   (commission ((per_share 0.01) (minimum 1.0)))
   (warmup_days 210)
   (strategy_cadence Daily)))

 (strategy
  ((initial_stop_buffer 1.02)
   (lookback_bars 52)))

 (stage
  ((ma_period 30)
   (ma_type Wma)
   (slope_threshold 0.005)
   (slope_lookback 4)
   (confirm_weeks 6)
   (late_stage2_decel 0.5)))

 (macro
  ((bullish_threshold 0.65)
   (bearish_threshold 0.35)
   (indicator_weights
    ((w_index_stage 3.0)
     (w_ad_line 2.0)
     (w_momentum_index 2.0)
     (w_nh_nl 1.5)
     (w_global 1.5)))
   (indicator_thresholds
    ((ad_line_lookback 26)
     (momentum_period 200)
     (nh_nl_lookback 13)
     (nh_nl_up_threshold 1.02)
     (nh_nl_down_threshold 0.98)
     (ad_min_bars 4)
     (nh_nl_min_bars 10)
     (global_consensus_threshold 0.6)))))

 (screening
  ((min_grade C)
   (max_buy_candidates 20)
   (max_short_candidates 10)
   (weights
    ((w_stage2_breakout 30)
     (w_strong_volume 20)
     (w_adequate_volume 10)
     (w_positive_rs 20)
     (w_bullish_rs_crossover 10)
     (w_clean_resistance 15)
     (w_sector_strong 10)
     (w_late_stage2_penalty -15)))
   (grade_thresholds
    ((a_plus 85) (a 70) (b 55) (c 40) (d 25)))
   (candidate_params
    ((entry_buffer_pct 0.005)
     (initial_stop_pct 0.08)
     (short_stop_pct 0.08)
     (base_low_proxy_pct 0.15)
     (breakout_fallback_pct 0.05)))))

 (portfolio_risk
  ((risk_per_trade_pct 0.01)
   (max_positions 20)
   (max_long_exposure_pct 0.90)
   (max_short_exposure_pct 0.30)
   (min_cash_pct 0.10)
   (max_sector_concentration 5)
   (max_unknown_sector_positions 2)
   (big_winner_multiplier 1.5)))

 (stops
  ((round_number_nudge 0.125)
   (min_correction_pct 0.08)
   (tighten_on_flat_ma true)
   (ma_flat_threshold 0.002)
   (trailing_stop_buffer_pct 0.01)
   (tightened_stop_buffer_pct 0.005)))

 (stock_analysis
  ((breakout_event_lookback 8)
   (base_lookback_weeks 52)
   (base_end_offset_weeks 8)))

 (rs
  ((rs_ma_period 52)
   (trend_lookback 4)
   (flat_threshold 0.98)))

 (volume
  ((lookback_bars 4)
   (strong_threshold 2.0)
   (adequate_threshold 1.5)
   (pullback_contraction 0.25)))

 (resistance
  ((chart_lookback_bars 130)
   (virgin_lookback_bars 520)
   (congestion_band_pct 0.05)
   (heavy_resistance_bars 8)
   (moderate_resistance_bars 3)))

 (sector
  ((strong_confidence 0.6)
   (weak_confidence 0.4)
   (stage_weight 0.40)
   (rs_weight 0.35)
   (constituent_weight 0.25))))
