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
; failed_breakout_tolerance_pct=0.05: issue #2084 fix 1 (armed 2026-07-26) —
;   invalidates a long candidate whose current close has collapsed back below
;   breakout_price x (1 - 0.05) after the breakout week (a failed breakout per
;   the book; the FTH/SNSE 07-17 rank-1 specimen closed ~30% below its own
;   breakout level and still emitted with entry $36.94). Merged into the same
;   screening_config overlay as candidate_ranking so neither arming clobbers
;   the other. Backtest code default stays 0.0 (off) per experiment-flag R1.
((screening_config ((candidate_ranking Quality) (failed_breakout_tolerance_pct 0.05))))
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
; entry reconciliation: issue #2103 (armed 2026-07-27) — candidate.entry is the
;   breakout level from the TRANSITION week, and the <=4-week early-Stage-2
;   window admits a name for weeks afterwards, so the printed ticket can be a
;   resting buy-stop far under the market. On the 2026-07-24 list MBX printed
;   "BUY STOP 651 sh @ $46.08 ... risk $784" while MBX traded ~$62: a stop
;   under the market IS a market order, so the real fill was ~$62, the notional
;   34% larger than sized, and the risk against the $44.88 stop ~$11k — 14x the
;   displayed figure. Armed at the issue's own boundaries: a 1-point de-minimis
;   band (a stop resting a few cents under the market fills at the stop, so
;   re-anchoring inside the band buys nothing) and a 15-point fill cap.
;   Through-entry names re-anchor to a LIMIT fill at the close, capped, and are
;   RE-SIZED on the cap.
; ⚠ entry_extension_max_pct is NO LONGER A SUPPRESSION THRESHOLD (issue #2404,
;   user decision 2026-08-24). It is purely the limit leg of the
;   StopLimit(E, E x (1 + pct/100)) ticket. A pick past the cap KEEPS its row,
;   its rank and its ticket, annotated "will not fill at current price" — which
;   is exactly what the order does (limit below the market, so it rests
;   unfilled and is re-evaluated next week), and exactly what the simulator
;   does under enable_sim_entry_stoplimit. One rule, two views. The old
;   behaviour dropped the ticket and moved the row to a do-not-chase watch
;   section, so a confirmed breakout (CRNX +43.7%, MBX +34.5%, SAFT +26.0% on
;   the 2026-07-24 list) vanished from the actionable report.
;   The VALUE is still open: live arms 15.0, the committed backtest specs use
;   2.0. #2404 unified the semantics, not the number; both the 1y and 3y
;   horizon surfaces rank 15.0 below 2.0, but moving live to 2.0 is a separate
;   user decision with no confirmation grid behind it, so 15.0 stands here.
;   Execution correctness for the human artifact, NOT a return lever: the
;   fields are read only by Weekly_snapshot_generator.generate, never by
;   on_market_close, so arming them cannot move a backtest number. The cap
;   follows weinstein-book-reference.md §1 "Stage 2 detail (Ch. 2)" — the
;   breakout point (and the pullback back to it) is the buy, which is also why
;   the row stays visible: the pullback back into the band is that second
;   chance. Code defaults stay 0.0 (off) per experiment-flag R1. See
;   [Weinstein_snapshot.Entry_reconciliation].
((entry_through_band_pct 1.0) (entry_extension_max_pct 15.0))
; live rename detection: issue #2083 fix 2 (armed 2026-08-04) — returns-basis
;   succession detector (#2100, reuses the #1946 Twin_detector scorer at
;   ret_epsilon 1e-3). When a universe ticker goes sparse at the right-hand
;   edge while a younger ticker takes over with matching daily returns
;   (SNSE->FTH class), the dead predecessor is dropped from candidates and the
;   report warns naming the successor — prompting the human universe re-pin.
;   Armed values: match_fraction 0.95 (Twin_detector top-3000 calibration:
;   real twins .95-.99, controls <.06), min_overlap_days 5 (the SNSE-shaped
;   zombie-tail fixture class). Arming dry-run 2026-08-04 over the full 3,158
;   universe @ as-of 2026-07-31: ZERO detections (no false positives) and
;   candidates bit-identical to the committed c028ee864 record. Report-layer
;   data hygiene, NOT a strategy rule: consumed only by
;   Weekly_snapshot_generator.generate; on_market_close never reads these
;   fields, so arming cannot move a backtest number (same class as the
;   sparse-tail gate + entry reconciliation armings above). Code defaults stay
;   0/0.0 (off) per experiment-flag R1. See [Rename_detector] / [Rename_gate].
((rename_detect_min_overlap_days 5) (rename_detect_match_fraction 0.95))
