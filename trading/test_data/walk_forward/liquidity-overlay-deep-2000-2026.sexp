;; Liquidity-overlay WF-CV — DEEP top-3000 2000-2026 (364 basis).
;; Fold-proofs the 2026-07-10 honest-tradeable single-path finding
;; (dev/notes/honest-tradeable-baseline-2026-07-10.md): arming the overlay
;; (entry gate 1e6 + hold-degradation exit 5e5 dollar-ADV) improved the deep
;; path ~3.2x with a GRADUAL sign-stable ratio — hypothesis: the overlay is a
;; QUALITY filter (junk-drag removal), which should survive fold shuffling.
;; 2x2 Cartesian decomposes the bundle: which sub-knob (entry gate vs hold
;; exit) carries the effect; the (0,0) cell must be ~identical to baseline
;; (parity check of the nested key-path overrides). N=3000 snapshot mode,
;; parallel 1 (memory); 13 biennial folds per the cash-reserve-surface
;; precedent. RESULT (2026-07-10, ledger liquidity-overlay-wfcv): parity
;; bit-identical 13/13; hold-exit alone dominates baseline; entry gate costs
;; Sharpe/Calmar; bundle < hold-only; gate FAIL all (fold-008 tail-tax).
((base_scenario "test_data/backtest_scenarios/goldens-sp500-historical/top3000-2000-2026-catstop.sexp")
 (window_spec
  (Rolling ((start_date 2000-01-01) (end_date 2026-04-30) (train_days 0) (test_days 730) (step_days 730))))
 (baseline_label baseline)
 (gate ((metric Sharpe) (m 7) (n 13) (worst_delta 0.0)))
 (axes ((axes (((key (liquidity_config min_entry_dollar_adv)) (values (0.0 1000000.0)))
               ((key (liquidity_config min_hold_dollar_adv)) (values (0.0 500000.0)))))
        (expansion Cartesian))))
