;; ARC BUNDLE (2026-08-20) -- the book-faithful entry path, end to end.
;;
;; Built on staging-record-convention/...-fullbook-graded.sexp, which already
;; carries the ENTRY TICKET half:
;;   sim_entry_trigger_at_suggested  the trigger RESTS at the screener
;;                                   breakout level E, not the current close
;;   enable_sim_entry_stoplimit      + entry_extension_max_pct 2.0 = the band
;;   stop_anchor_at_entry_base       the stop half of the same ticket
;;
;; This spec adds the SCREENING half plus the fill-time volume test:
;;   entry_anchor_local_range_weeks 4         REQUIRED BY the basis below: rt
;;                                              measures freshness from
;;                                              local_range_top, which this knob
;;                                              defines. At its 0 default the
;;                                              anchor is unset and the "close
;;                                              within 5% below anchor" test has
;;                                              nothing to bind against. Every
;;                                              ladder-v4 rt arm sets 4.
;;   entry_freshness_basis Range_top_breakout   screen while still UNDER the
;;                                              range top (book 4.7 mechanics),
;;                                              not after the MA cross
;;   volume_confirm_at_fill true                4.7: the GTC ticket is written
;;                                              before the breakout, so 4.2
;;                                              volume confirmation applies to
;;                                              the week it FILLS
;;
;; The 2pp band is the BOOK number, not a tuned one: 4 "Buying Within Limits"
;; specifies a buy-stop at the breakout with a limit 1/4 point above it, which
;; on his own 12-1/8 example is 2.06%. (1/2 point ~ 4.1% for thinly traded
;; names is his liquidity-conditional variant -- not implemented here.)
;; He rejects both neighbours explicitly: no limit means "you are now the proud
;; owner of XYZ at 15" instead of 12-1/8; limit==trigger means "one out of
;; four, the stock will break out without your ever buying it".
;;
;; BASIS = faithfulness, NOT performance (user directive 2026-08-20: "we will
;; get faithful right first and then later chase down the performance gap").
;; Do NOT read a verdict off this run against the record arm: the 26y return
;; null on this base is 132.51pp, so nothing short of that is interpretable.
;;
;; Run with the split-safe warehouse (/tmp/snap_top3000_dedup_v5thin_adj),
;; SNAPSHOT_CACHE_MB=1024, --no-emit-all-eligible, --parallel 1.
;; NOT a golden -- staging scenario, sentinel bands.
((name "g00-fix")
 (description "ARC BUNDLE — book-faithful entry end to end: screen UNDER the range top (Range_top_breakout), rest an E-anchored StopLimit band 2pp, judge volume AT the fill. fullbook-graded + entry_freshness_basis + volume_confirm_at_fill.")
 (period ((start_date 2000-01-03) (end_date 2004-12-31)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2000.sexp")
 (universe_size 3000)
 ;; entry_order_max_rest_weeks pinned at its pre-promotion value 0
 ;; (unbounded) so this recorded arm stays reproducible after the default
 ;; moved 0 -> 26 on 2026-08-18 (PR #2384). Do not drop this pin.
 (config_overrides
  (((enable_sim_entry_stoplimit true)) ((entry_order_max_rest_weeks 0))
   ((sim_entry_trigger_at_suggested true))
   ((entry_anchor_local_range_weeks 4))
   ((entry_freshness_basis Range_top_breakout))
   ((volume_confirm_at_fill true))
   ;; D1 + D2 fixes (2026-09-02 agent wave), both default-off flags armed
   ((sim_exit_fill_next_open true))
   ((stops_config ((stop_skip_entry_bar true))))
   ((stop_anchor_at_entry_base true))
   ((entry_extension_max_pct 2.0))
   ;; Book §5.3 flat stop when no structural floor qualifies: reference =
   ;; entry (buffer 1.0) -> stop 4.0% below entry, the band low. The 1.02
   ;; default puts the support stand-in ABOVE a long's entry and halves the
   ;; stop to 2.08% (dev/notes/inspect-6mo-trade-dissection-2026-08-21.md,
   ;; verified by the inspect-6mo-bookstop arm: modal stop 0.0208 -> 0.0400).
   ((initial_stop_buffer 1.0))
   ((extension_stop_config ((trigger_ratio 2.0) (trail_pct 0.25))))
   ((reject_declining_ma_long_entry true))
   ((enable_short_side false))
   ((stops_config ((catastrophic_stop_pct 0.10))))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))
   ((liquidity_config ((min_entry_dollar_adv 1000000.0))))
   ((liquidity_config ((min_hold_dollar_adv 500000.0))))
   ((stale_exit_after_days (5)))))
 (expected ((total_return_pct ((min -90.0) (max 90000.0))) (total_trades ((min 1) (max 90000)))
   (win_rate ((min 0.0) (max 100.0))) (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0))) (avg_holding_days ((min 0.0) (max 800.0)))
   (sortino_ratio_annualized ((min -3.0) (max 10.0))) (calmar_ratio ((min -3.0) (max 5.0)))
   (ulcer_index ((min 0.0) (max 60.0))) (open_positions_value ((min -1.0e12) (max 1.0e12))))))
