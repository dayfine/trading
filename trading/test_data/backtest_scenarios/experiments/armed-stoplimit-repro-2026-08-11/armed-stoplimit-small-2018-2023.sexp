;; ARMED-STOPLIMIT REPRO — the short probe for the ladder-v4 cell-00 regression.
;;
;; WHY: ladder-v4 cell 00 does not reproduce the ladder-v3 faithful-w4 arm
;; (317.80% / 1143 trades / 36.49 DD  ->  343.90% / 1136 / 44.28) even though
;; the two specs are semantically identical — every one of the seven overrides
;; v4 adds was verified equal to its declared default, and the overlay merge is
;; a deep-merge, so v4's three `stops_config` entries do not clobber each other.
;; The drift is therefore in one of the five behaviour-touching commits merged
;; between the two runs: 7dbdf9646 (F3), 2f6f07892 (F1), e3087812c (F2),
;; f806fab14 (F5), a03f2a4e4 (PR-5 audit).
;;
;; Nothing caught it because R1 bit-identity was verified by unit tests plus the
;; default-config goldens, and **zero of the ten golden specs arm the StopLimit
;; entry family** — which is precisely the regime F2/F3/F5 are scoped to. The
;; guarantee was only ever tested where these mechanisms are inert by
;; construction. A structural hole, not a slip.
;;
;; WHAT THIS IS: the ladder-v3/v4 v2-core entry stack (resting StopLimit at the
;; local range top, E frozen at the first qualifying breakout, honest next-open
;; Market-leg fills, support-floor stop) transplanted onto the 302-symbol
;; `goldens-small` universe over six years, so it runs from the committed CSV
;; test_data in minutes instead of the 1h46m the 26y top-3000 warehouse probe
;; costs. Bisecting on the real ladder config is not affordable.
;;
;; The sizing/exit half is copied verbatim from `goldens-small/six-year-2018-2023`
;; (the Cell-E standard config) rather than from the ladder, so this spec differs
;; from that golden in the ENTRY stack alone. That makes the pair a controlled
;; comparison: any delta here is attributable to the armed entry family.
;;
;; NOT A GOLDEN — a staging probe with sentinel bands. The durable fix this
;; probe motivates is a StopLimit-ARMED golden with real pinned bands.
((name "armed-stoplimit-small-2018-2023")
 (description "Armed StopLimit entry stack (v2-core) on the 302-symbol small universe, 2018-2023. Short bisect probe for the ladder-v4 cell-00 regression.")
 (period ((start_date 2018-01-02) (end_date 2023-12-29)))
 (universe_size 302)
 (config_overrides
  (;; --- armed StopLimit entry stack (the regime no golden covers) ---
   ((enable_sim_entry_stoplimit true))
   ((sim_entry_trigger_at_suggested true))
   ((entry_anchor_local_range_weeks 4))
   ((entry_extension_max_pct 2.0))
   ((freeze_entry_at_first_breakout true))
   ((sim_entry_fill_next_open true))
   ;; --- sizing / exit half: verbatim from goldens-small/six-year-2018-2023 ---
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected
  ;; Sentinel bands only — this spec exists to be DIFFED across commits, not to
  ;; pin a value. Wide enough that the probe never fails for being a probe.
  ((total_return_pct ((min -90.0) (max 9000.0)))
   (total_trades ((min 1) (max 90000)))
   (win_rate ((min 0.0) (max 100.0)))
   (sharpe_ratio ((min -3.0) (max 5.0)))
   (max_drawdown_pct ((min 0.0) (max 90.0)))
   (avg_holding_days ((min 0.0) (max 800.0)))
   (open_positions_value ((min -1.0e12) (max 1.0e12))))))
