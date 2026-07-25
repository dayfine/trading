; leverage-dawn surface (2026-07-24) — regime-conditional long leverage on the
; lagging weekly-MA-flip-age "dawn" label. The designed default-off surface the
; P1b memo green-lit (dev/notes/regime-dependency-evaluation-2026-07-24.md §1/§3;
; dev/notes/margin-m4-validation-2026-07-23.md §Addendum). Run POST-MERGE only —
; this file ships with the mechanism PR as the deliverable; the surface run and
; its confirmation grid (promotion-confirmation.md) are a separate scheduled step.
;
; Axes: dawn_initial_long_margin_req {0.90, 0.85, 0.75}
;       x dawn_max_ma_flip_age_weeks {52, 78} = 6 cells, all dawn-armed
;       (dawn_leverage_enabled true), shorts off. The milder rungs {0.90, 0.85}
;       exist because the always-on 1.33x (=0.75) carries >=50% intra-era DD in
;       the M4 table — a DD price above any promotable bar — so the surface must
;       be able to find a gentler levered value that clears the frontier.
;
; NAMED FALSIFIER: fold-012 (2024-25/26) is the melt-up-lag dawn FALSE POSITIVE —
; the strategy's known lag regime is exactly where a lagging dawn label mis-fires
; (the MA flipped up in 2023, so 2024 reads "young dawn" while the tape melts up
; and the strategy lags). A promotable dawn value must NOT be carried by fold-012;
; the gate + DSR must survive its exclusion.
;
; Fixed honest-cost margin dials on EVERY cell (mirror margin-m4-leverage): dawn
; leverage runs margin-armed by convention (Leverage_dawn.validate enforces it),
; so the borrowed long debit is priced (8%/yr), long maintenance 0.30 is armed
; (M2 force-reduce), and the short-side margin model is on with the FINRA/HTB tier
; tables. With margin_config.enabled short proceeds are locked (150% collateral).
;
; PERMISSIVE FUNDING / GATED SIZING (B1 fix, 2026-07-24). The simulator funds
; fills at the BASE initial_long_margin_req (Panel_runner -> Simulator.create_deps,
; fixed for the whole run), NOT the dawn-week value; the dawn signal only gates
; the ENTRY WALK's sizing requirement. So the base is fixed here at 0.75 — the
; most-permissive rung the dawn axis sweeps — so the simulator can fund a levered
; dawn-week fill into long_margin_debit (priced 8%/yr + maintenance 0.30) for ANY
; dawn rung in {0.90, 0.85, 0.75}. Off-dawn the entry walk raises its requirement
; to a cash account, so no NEW borrowing starts even though the sim funds at 0.75
; (a cash-fitting order takes the base apply path, no new debit). Leverage_dawn.
; validate enforces base (0.75) <= dawn rung on every cell.
;
; Bar (promotion): a dawn cell must clear the UNLEVERED frontier on risk-adjusted
; fold terms (Sharpe gate + DSR), continuously scored across fold boundaries (the
; fold-reset forgiveness of the M4 read is the biggest flattering bias), NOT MTM —
; and survive fold-012 exclusion. Promotion also needs the confirmation grid
; (>=1 macro-regime-diverse deep cell covering 2000-02 + 2008).
;
; Run (post-merge): walk_forward_runner --spec <this>
;   --out-dir /tmp/sweeps/leverage-dawn-surface
;   --fixtures-root test_data/backtest_scenarios
;   --snapshot-dir /tmp/snap_top3000_dedup_v5thin --parallel 2
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
    (((flag dawn_leverage_enabled) (values (true)))
     ((key (initial_long_margin_req)) (values (0.75)))
     ((key (dawn_initial_long_margin_req)) (values (0.90 0.85 0.75)))
     ((key (dawn_max_ma_flip_age_weeks)) (values (52 78)))
     ((flag enable_short_side) (values (false)))
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
