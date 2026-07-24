; Margin M4 stage-3 leverage surface (2026-07-23) — the first PRICED-leverage
; surface, run only after M4 stage-1 parity gates passed (all bit-identical)
; and stage-2 squeeze cells passed (no false fire; ordering audited via the
; forced-engagement cell). Plan: levered-longshort-margin-realism-2026-07-14 §M4.3.
;
; Axes: initial_long_margin_req {1.0, 0.75, 0.5} x enable_short_side {false,true}
; = 6 cells. Fixed honest-cost dials on EVERY cell: long margin rate 8%/yr on
; the borrowed debit, long maintenance 0.30 (M2 force-reduce armed), short-side
; margin model ON with the FINRA/HTB tier tables from the stage-2 cells (buy-in
; stress OFF here — the confirmation grid carries the stress cell). With
; margin_config.enabled the short proceeds are LOCKED (150% collateral), so no
; entry cap is needed: equity/req is the sole long bound and every borrowed
; dollar is priced into long_margin_debit — no Run-E proceeds fiction.
; The (req 1.0, shorts false) cell is the promoted baseline modulo the armed
; margin_config (which only affects shorts) and maintenance_long_pct 0.30
; (no-op on an unlevered book) — expected ~= baseline; any drift is a finding.
;
; Bar (promotion): a levered cell must clear the UNLEVERED frontier
; (baseline + the E-capped anchor +10,589%/Sharpe .906/DD 31.1 from stage 1)
; on risk-adjusted fold terms (Sharpe gate + DSR), not MTM.
;
; Run: walk_forward_runner --spec <this> --out-dir /tmp/sweeps/margin-m4-surface
;      --fixtures-root test_data/backtest_scenarios
;      --snapshot-dir /tmp/snap_top3000_dedup_v5thin --parallel 2
; 6 variants x 13 folds + 13 baseline = 91 fold-runs, ~8-9h at parallel 2.
((base_scenario
  "test_data/backtest_scenarios/staging-record-convention/top3000-2000-2026-record-convention.sexp")
 (window_spec
  (Rolling
   ((start_date 2000-01-01) (end_date 2026-04-30) (train_days 0)
    (test_days 730) (step_days 730))))
 (baseline_label baseline)
 (gate ((metric Sharpe) (m 7) (n 13) (worst_delta 0.0)))
 (axes
  ((axes
    (((key (initial_long_margin_req)) (values (1.0 0.75 0.5)))
     ((flag enable_short_side) (values (false true)))
     ((key (long_margin_rate_annual_pct)) (values (0.08)))
     ((key (maintenance_long_pct)) (values (0.30)))
     ((key (short_borrow_min_dollar_adv)) (values (1000000.0)))
     ((key (margin_config enabled)) (values (true)))
     ((key (margin_config maintenance_margin_pct)) (values (0.30)))
     ((key (margin_config short_borrow_rate_tiers))
      (values ((((price_below 5.0) (value 1.00)) ((price_below 17.0) (value 0.25))))))
     ((key (margin_config short_maintenance_tiers))
      (values ((((price_below 5.0) (value 1.00)) ((price_below 17.0) (value 0.83))))))))
   (expansion Cartesian))))
