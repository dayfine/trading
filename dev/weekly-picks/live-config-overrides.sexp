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
; resistance-history feed: 520 weekly bars (~10y) for the resistance/support
;   mapper only — fixes CWST-class false-virgin live text with real data
;   (armed-run matrix Run C: the min-hist label floor is NOT armable; feeding
;   history is the fix). Generator warmup auto-widens to cover the window.
((resistance_lookback_bars 520))
; candidate_ranking=Quality: issue #1782 — orders equal-score long/short
;   candidates by a continuous Weinstein-faithful key (RS magnitude desc ->
;   earliness/weeks_advancing asc -> volume_ratio desc -> ticker) instead of the
;   pure-alphabetical tiebreak. Fixes the live-weekly artifact where the cap-20
;   selection was "the first 20 A-ticker grade-A breakouts" and consecutive
;   weeks' pick lists shared ~0 symbols (100% turnover = tiebreak artifact, not
;   signal). RS-for-selection is a Weinstein spine item (weinstein-faithful-core
;   §7). This is a LIVE-UX + faithfulness arming, NOT a return lever: the
;   2026-06-29 / 2026-06-30 breadth grids REJECT a backtest default-flip (both
;   RS-primary Quality and earliness-primary Quality_earliness marginally
;   do-no-harm-FAIL on return-adjusted metrics — no equal-score tiebreak adds
;   return, cf. project_edge_is_the_fat_tail). The backtest code default stays
;   Alphabetical; this reorders only the human-facing weekly picks.
((screening_config ((candidate_ranking Quality))))
; sparse-tail eligibility gate: issue #2083 fix 1 — the 2026-07-17 report's
;   rank-1 pick "SNSE" did not exist at the broker (Sensei Biotherapeutics had
;   renamed to Faeth Therapeutics, SNSE->FTH, on 2026-06-16). The feed kept
;   serving occasional stale bars under the dead ticker (6 bars across ~15
;   trading days, one anomalous spike) and the existing "too few bars" check
;   never fired because the series was current at the right-hand edge and
;   merely sparse in the middle. Requiring >=10 of the last 15 trading days
;   (the issue's own suggested threshold) would have dropped this pick
;   regardless of rename knowledge. Engineering data hygiene, NOT a Weinstein
;   rule or a return lever — the spine (stage/breakout/volume/macro/sector) is
;   untouched; see [Weinstein_snapshot_gen.Sparse_tail_gate].
((sparse_tail_min_bars 10) (sparse_tail_window_trading_days 15))
