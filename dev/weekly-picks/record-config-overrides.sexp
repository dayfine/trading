; Record weekly-review config (2026-11 backfill) — passed to
; generate_weekly_snapshot via --config-overrides for the 13 backfilled Fridays
; 2026-08-21 .. 2026-11-13 (README "2026-11 backfill").
;
; Part 1, verbatim: the config_overrides of the record arm
;   dev/experiments/record-kseed-2026-10-27/specs/rk-k0.sexp (record N,
;   Seeded tie order, tiebreak_seed 0), in the same order. candidate_ranking is
;   left at main's default (Seeded, #3425), as the record leaves it.
((enable_sim_entry_stoplimit true))
((sim_entry_trigger_at_suggested true))
((sim_entry_stoplimit_fresh_bar_only true))
((sim_stop_exit_fill_on_trigger_bar true))
((stop_anchor_at_entry_base true))
((entry_extension_max_pct 2.0))
((reject_declining_ma_long_entry true))
((enable_short_side false))
((portfolio_config ((max_position_pct_long 0.14))))
((portfolio_config ((max_long_exposure_pct 0.70))))
((portfolio_config ((min_cash_pct 0.30))))
((enable_laggard_rotation true))
((laggard_rotation_config ((hysteresis_weeks 2))))
((liquidity_config ((min_entry_dollar_adv 1000000.0))))
((liquidity_config ((min_hold_dollar_adv 500000.0))))
((stale_exit_after_days (5)))
((macro_config ((breadth_direction ((enabled true))))))
((require_structural_stop true))
((max_one_share_class_per_issuer true))
((split_dividend_guard true))
((cash_yield (Series "macro/tbill_3m_dtb3.csv")))
((cash_yield_fee_bp 10.0))
((dividend_crediting true))
((screening_config ((tiebreak_seed 0))))
;
; Part 2: live-only data-hygiene fields from live-config-overrides.sexp that
;   the record does not set. Report-layer only (read by
;   Weekly_snapshot_generator.generate, never by on_market_close), so they
;   cannot move a backtest number.
; sparse-tail eligibility gate, issue #2083 fix 1 (SNSE->FTH zombie ticker).
((sparse_tail_min_bars 10) (sparse_tail_window_trading_days 15))
; live rename detection, issue #2083 fix 2 (returns-basis succession detector).
((rename_detect_min_overlap_days 5) (rename_detect_match_fraction 0.95))
