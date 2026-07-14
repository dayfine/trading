; Live weekly-review arming config (2026-07-14) — passed to
; generate_weekly_snapshot via --config-overrides. Code defaults stay no-op
; (experiment-flag R1); arming happens here and in the record-convention
; staged scenario only.
;
; extension_stop: insurance-ACCEPT, ledger
;   2026-07-14-extension-stop-insurance-accept (banks parabolic tops 8/8,
;   MaxDD 40.9->32.3 on the 28y dedup-v2 record pair).
((extension_stop_config ((trigger_ratio 2.0) (trail_pct 0.25))))
; reject_declining_ma: #1775 ARM-FOR-BROAD + 07-13 matrix confirming evidence
;   (drops Stage-4-bounce "Stage2" longs, AIR-2020 class; validator V8->PASS).
((reject_declining_ma_long_entry true))
