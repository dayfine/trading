;; perf-tier: 3
;; perf-tier-rationale: ~500-symbol S&P 500 universe over 5 years (2019-2023, includes COVID + recovery + 2022 bear). Weekly cadence (≤2 h budget). See dev/plans/perf-scenario-catalog-2026-04-25.md tier 3.
;;
;; S&P 500 golden — regression-pinned trading + performance benchmark.
;; Universe is a 491-symbol S&P 500 snapshot (universes/sp500.sexp,
;; generated 2026-04-26). Period covers a full Weinstein cycle:
;;   * 2019: late-cycle advance.
;;   * 2020 H1: COVID crash (Stage 4 trigger).
;;   * 2020 H2 - 2021: V-shaped recovery (Stage 1 → Stage 2 transitions).
;;   * 2022: bear (Stage 4 across most names).
;;   * 2023: recovery, leadership rotation.
;;
;; This is the foundation benchmark for downstream feature work — short-side
;; strategy, segmentation-based stage classifier, stop-buffer tuning, etc.
;; Once metrics here are pinned, follow-on PRs measure against this baseline.
;;
;; Expected ranges are pinned around the canonical run with cushion sized to
;; absorb the start-date IQR observed in the PR #788 fuzz (5 variants at
;; ±2w around 2019-01-02). Re-pin with each deliberate strategy behaviour
;; change; don't bump these to absorb regressions.
;;
;; Measured baseline (2026-05-02, post-#744+#745+#746+#771):
;;   total_return_pct  +60.86  total_trades 86   win_rate ~22.35
;;   sharpe_ratio       0.55   max_drawdown 34.15
;;
;; Verified via PR #788 fuzz: 5 variants ±2w start_date all returned
;; +37.92% to +60.86% / Sharpe 0.41-0.56 / MaxDD 31.28-35.99 / 82-99 trades
;; (see dev/experiments/fuzz-startdate-canonical-full/fuzz_distribution.md).
;; The pin shift from the prior 2026-04-30 baseline (-0.01% / 32 trades /
;; 5.81% MaxDD) reflects the structural changes in #744 (sizing fix), #745
;; (cash-deployment fix), #746 (long/short cap split), and #771 (stop
;; tuning). Bands are sized to absorb the fuzz IQR plus cushion so future
;; small drift (start-date sensitivity, calendar rolls) does not flap CI.
;;
;; (Pre-rename: this metric was named [unrealized_pnl] but its semantics
;; matched the renamed [Metric_types.OpenPositionsValue] — signed mtm value
;; of open positions, NOT true paper P&L. The rename in PR
;; feat/metrics-unrealized-pnl-rename clarifies the distinction; the
;; corrected [UnrealizedPnl] metric (= OpenPositionsValue minus position
;; cost basis) is now also emitted but not yet pinned here.)
;;
;; The S&P 500 is a moving target; the universe sexp is a fixed snapshot
;; so reruns are reproducible. Refresh the universe via the build script
;; (TODO: dev/scripts/build_sp500_universe.sh) when re-baselining.
((name "sp500-2019-2023")
 (description "S&P 500 over 2019-2023 — full Weinstein cycle benchmark — Cell E config")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "universes/sp500.sexp")
 (universe_size 500)
 ;; Cell E rollout 2026-05-11: applies the new standard strategy config
 ;; (max_position_pct_long=0.14, max_long_exposure_pct=0.70, min_cash_pct=0.30,
 ;; stage3 force-exit h=1, laggard rotation h=2). Replaces prior 0.30/0.90/0.10
 ;; default-sized baseline (58.34% / 81 trades / 33.6% DD).
 ;; Measured 2026-05-12 (Cell E, post-#1052 force-liq fix + #1053 metric schema):
 ;;   total_return_pct   50.66  total_trades 264   win_rate 37.5
 ;;   sharpe_ratio       0.56   max_drawdown 21.56 avg_holding_days  40.78
 ;;   open_positions_value 1,221,041
 ;;   sortino_ratio_annualized 0.75   calmar_ratio 0.40   ulcer_index 8.41
 ;; MaxDD cut 12pp (34 → 22), trade count 3.3x. Tolerances ±15%.
 (config_overrides
  (((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 ;; Cost-model overlay (PR #1260 wiring). See goldens-small/bull-crash-2015-2020.sexp
 ;; for the full rationale. [retail_default] with per_trade=0 is byte-equal
 ;; to [None] under current wiring (only [apply_per_trade_commission] is
 ;; hooked); spread / per_share will activate once
 ;; [Cost_model.to_engine_costs] is wired into [Panel_runner] — Open work
 ;; item in `dev/status/cost-model.md`. Pinning the overlay declaratively now
 ;; means future wiring lands without touching every golden again.
 (cost_model
  ((per_trade_commission 0.0)
   (per_share_commission 0.0)
   (bid_ask_spread_bps 5.0)
   (market_impact_bps_per_pct_adv 0.0)))
 (expected
  ;; Re-pinned 2026-06-23 for the A-D-live default flip (synthetic breadth tail).
  ;; A-D-live's conservative COVID gate raised risk metrics here (MaxDD 21.6→31.3,
  ;; Calmar 0.46→0.26); return held (in band). Longshort still beats its long-only twin.
  ;; Re-pinned 2026-07-08 for the warmup 210→364 fix (RS present from the first
  ;; screen; dev/notes/warmup-364-repin-2026-07-08.md), ±15% around 364 actuals:
  ;;   ret 45.73  trades 274  win 36.50  sharpe 0.56  maxDD 24.90  hold 38.67
  ;;   OPV 1,180,589  sortino 0.69  calmar 0.31  ulcer 9.67
  ;; Risk metrics IMPROVED here (DD 31.3→24.9) — the RS-honest early-window
  ;; cohort holds a less crash-exposed 2019 book into COVID on this window.
  ((total_return_pct   ((min  38.9)        (max  52.6)))
   (total_trades       ((min 233)          (max 315)))
   (win_rate           ((min  31.0)        (max  42.0)))
   (sharpe_ratio       ((min   0.47)       (max   0.64)))
   (max_drawdown_pct   ((min  21.2)        (max  28.6)))
   (avg_holding_days   ((min  32.9)        (max  44.5)))
   (open_positions_value ((min 1003500.0)  (max 1357700.0)))
   (sortino_ratio_annualized ((min 0.59)   (max 0.80)))
   (calmar_ratio       ((min   0.27)       (max   0.36)))
   (ulcer_index        ((min   8.2)        (max  11.1)))
   ;; wall_seconds pin sized wide (CI ~920s, local parallel ~200s) —
   ;; catches only catastrophic 2x slowdowns per design intent.
   (wall_seconds       ((min 100.0)        (max 1500.0))))))
