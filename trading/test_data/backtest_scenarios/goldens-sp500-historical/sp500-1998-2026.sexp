;; perf-tier: research
;; perf-tier-rationale: M4 T4.1 SCAFFOLDING ONLY — base scenario for the
;; 1998-2026 28-fold walk-forward fixture
;; (`trading/test_data/walk_forward/cell_e_full_history_28fold_2026_05_25.sexp`).
;; NOT itself a regression cell — research-tier, runs are M4 T4.4+
;; sanity-backtest / T4.5 BO sweep work (multi-hour wall, not in CI).
;;
;; Why the wide 1998-2026 window: per
;; `dev/plans/tuning-research-driven-program-v2-2026-05-25.md` §M4, the
;; primary tuning sweep evaluates the 11-knob surface against a 28-year
;; delisted-aware top-3000 universe to validate findings across multiple
;; market regimes (1998-2000 tech boom / bust, 2008 GFC, 2020 COVID,
;; 2022 bear). 2010-2026 alone is one bull cycle plus tail noise.
;;
;; **Universe pointer (T4.1 placeholder):** points at the top-3000-1998
;; composition snapshot as a static universe for fixture parsability.
;; T4.2 (per-fold universe rotation in Panel_runner) is responsible for
;; rotating through the top-3000-YYYY snapshots per fold start year.
;; T4.1 only needs the fixture sexp to load + the Window_spec to generate
;; folds; this base scenario's universe is therefore not load-bearing for
;; the T4.1 tests.
;;
;; **Cell E config**: identical to `sp500-2010-2026.sexp` and
;; `weinstein-2019-full-pool.sexp` (the canonical Cell E config across
;; all goldens since 2026-05-11 promotion). The constant we hold across
;; the walk-forward is the *config*; the window rotates per fold.
;;
;; **No expected bands** beyond catch-only sentinels — this is a
;; research scenario; per-fold metrics are evaluated downstream by the
;; walk-forward harness, not against per-scenario bands here.
((name "sp500-1998-2026-historical")
 (description
   "28y top-3000 historical scaffolding scenario — base for the 1998-2026 28-fold walk-forward fixture (M4 T4.1). Universe pointer is a T4.1 placeholder; T4.2 plumbs per-fold rotation.")
 (period ((start_date 1998-01-01) (end_date 2026-04-30)))
 (universe_path "../goldens-custom-universe/composition/top-3000-1998.sexp")
 (universe_size 3000)
 ;; Cell E config — identical to sp500-2010-2026.sexp.
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.30))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 ;; Cost-model overlay mirroring sp500-2010-2026.sexp.
 (cost_model
  ((per_trade_commission 0.0)
   (per_share_commission 0.0)
   (bid_ask_spread_bps 5.0)
   (market_impact_bps_per_pct_adv 0.0)))
 ;; Research bands — intentionally WIDE, catch only catastrophic
 ;; crashes / NaN sentinels. Tightening per-fold bands is downstream of
 ;; T4.4 (sanity backtest) and T4.5 (sweep harvest).
 (expected
  ;; Concentration=0.30 promotion 2026-06-25 (max_position_pct_long 0.14 -> 0.30, the
  ;; production default; ledger 2026-06-25-capacity-concentration-broad). Catch-only
  ;; sentinel bands; 0.30 measured ret 227.5% / 673 trades / 40.6% win / 28.5% DD (PASS).
  ((total_return_pct  ((min -90.0)  (max 5000.0)))
   (total_trades      ((min   0.0)  (max 100000.0)))
   (win_rate          ((min   0.0)  (max 100.0)))
   (sharpe_ratio      ((min  -2.0)  (max   5.0)))
   (max_drawdown_pct  ((min   0.0)  (max  95.0)))
   (avg_holding_days  ((min   0.0)  (max 365.0)))
   (wall_seconds      ((min 100.0)  (max 360000.0))))))
