;; entry_extension_max_pct WF-CV — the TIGHT end, which no surface has tested.
;;
;; WHY THIS EXISTS. Two values are in the tree and neither was derived:
;;   - live (dev/weekly-picks/live-config-overrides.sexp) uses 15.0, eyeballed
;;     off ONE day's picks ("3 of that day's 20 were past it: CRNX +43.7%,
;;     MBX +34.5%, SAFT +26.0%").
;;   - 81 of the 89 committed sexp occurrences use 2.0, which propagated by
;;     spec-copying. (Corrected 2026-08-19: this line said "all 82 specs" and
;;     both halves were wrong. The other 8: live at 15.0 x2, the
;;     staging-record-convention cap15 / estop15 / trigonly specs at
;;     15.0/15.0/1000.0, and the 2026-08-04 ledger surface's own axis values
;;     10.0/15.0/20.0.)
;; The 2026-08-04 ledger surface tested {10, 15, 20} and found them near
;; identical and all worse than uncapped Market fills. 2.0 was never in it, so
;; "cap-insensitivity" is established between 10 and 20 and says NOTHING about
;; the tight end where every committed spec actually sits. Issue #2404.
;;
;; WHAT THE FIELD MEANS (verified against entry_reconciliation.mli, not
;; inferred from the config comments): it is the limit price on a
;; StopLimit(E, cap) -- the SAME rule in live and in the sim, differing only in
;; this value. Price <= E rests; between E and cap the trigger is already
;; breached so it fills at market within the limit (re-anchored and RE-SIZED,
;; which is what fixed #2103's 14x-understated risk); above cap the limit sits
;; below market so there is no fill.
;;
;; A TIGHTER CAP DOES NOT MEAN "BUY CHEAPER" -- it means MORE NO-FILLS.
;;
;; !! RESULT 2026-08-19: the prediction that once stood here -- fewer trades and
;; LOWER return -- was WRONG IN DIRECTION. The axis found TIGHTER IS BETTER on
;; every metric: 1.0 beat baseline(=2.0) on return, Sharpe, MaxDD and Calmar,
;; winning Calmar 13/16 and MaxDD 15/16, while 5/10/15 all trailed 2.0.
;;
;; (This block used to end "Live's 15.0 was the WORST value tested." That is
;; FALSE and is corrected here rather than deleted. On this 1-year surface 5.0
;; is worse than 15.0 on every mean -- return 6.4359 vs 6.6796, Sharpe 0.5142 vs
;; 0.5505, MaxDD 9.7751 vs 9.6305, Calmar 1.0365 vs 1.2542 -- and 15.0 is worst
;; only on the Calmar WIN-COUNT, where it ties 10.0 at 3/16. The claim was
;; uncheckable when written because #2411 merged this spec without its outputs;
;; dev/experiments/entry-cap-horizon-2026-08-19/aggregate_1y.sexp now carries
;; them, which is how it was caught. 5.0 is the worst value on BOTH horizons.)
;;
;; !! BUT THIS DESIGN IS BIASED TOWARD THAT ANSWER. test_days=365 gives ONE-YEAR
;; folds. A tighter cap's failure mode is a NO-FILL, which forgoes the stock's
;; ENTIRE subsequent run -- and a 1-year fold TRUNCATES that run at the
;; boundary. So the cost of a miss is systematically understated while the
;; benefit of dodging a bad chase is fully counted inside the year. That the
;; strongest signal is MaxDD (15/16) fits "takes fewer positions" rather than
;; "picks better".
;;
;; DO NOT promote a value off this spec as written. Re-run at test_days 1095+,
;; record per-arm trade COUNT and max single-trade P&L, then the confirmation
;; grid. See #2404.
;;
;; !! HORIZON CONTROL RAN 2026-08-19 (entry-extension-cap-3y-folds-2010-2026.sexp,
;; 5 disjoint 3-year folds, same base, wall 1543s): THE TIGHT-CAP RESULT DOES NOT
;; SURVIVE. At 3-year folds 1.0 falls BELOW baseline on return (43.76 vs 45.49),
;; Sharpe (0.961 vs 0.998) and Calmar (1.002 vs 1.033); every variant FAILS the
;; 3-of-5 Calmar gate; and the MaxDD advantage inverts -- the lowest mean
;; drawdown now belongs to the LOOSE caps 10.0/15.0 (12.60 vs baseline 14.42).
;; The bias this header predicted is the whole effect. Full writeup:
;; dev/experiments/entry-cap-horizon-2026-08-19/README.md.
;;
;; The trade-count question (fewer positions vs better picks) is STILL open and
;; is a harness gap, not a measurement to re-run: fold_actual carries no trade
;; count. Filed as #2412.
;;
;; This surface is run for FIDELITY, not to find a return winner. The user
;; directive (2026-08-19) is that the backtest should model what live does; the
;; open question is which single value both should use. (The "expect tighter to
;; cost more" line that stood here is superseded by the RESULT block above.)
;;
;; Book authority for a SMALL cap, quoted in entry_reconciliation.mli:
;; weinstein-book-reference.md §1 "Stage 2 detail (Ch. 2)" -- the buy is AT the
;; breakout, or on a pullback back CLOSE TO it. A name far above its breakout is
;; at neither. Note that .mli's own caveat: the "Late Stage 2 warning" is NOT
;; the applicable clause (it is conditioned on the stock sagging toward a
;; flattening MA, a different predicate from distance past the breakout).
;;
;; PREREQUISITE: entry_extension_max_pct only binds when
;; enable_sim_entry_stoplimit is armed -- the base scenario below arms it
;; (verified: 3 references). Without that every arm collapses to Market fills
;; and the surface measures nothing. Put a duplicate cell in the sweep before
;; trusting any ranking (project_ladder_v4_null_278pp).
((base_scenario
  "test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023-armed-stoplimit.sexp")
 (window_spec
  (Rolling
   ((start_date 2010-01-01) (end_date 2026-04-30) (train_days 0)
    (test_days 365) (step_days 365))))
 (baseline_label baseline)
 (gate ((metric Calmar) (m 9) (n 16) (worst_delta 0.0)))
 (axes
  ((axes (((flag entry_extension_max_pct) (values (1.0 2.0 5.0 10.0 15.0)))))
   (expansion Cartesian))))
