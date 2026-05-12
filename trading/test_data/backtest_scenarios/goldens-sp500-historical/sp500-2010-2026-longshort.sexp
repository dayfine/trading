;; perf-tier: 3-historical
;; perf-tier-rationale: 16y sp500 historical LONG-SHORT backtest. Twin of
;; goldens-sp500-historical/sp500-2010-2026.sexp (long-only) with
;; enable_short_side = true. First long-window golden that exercises the
;; short-side primitives merged in 2026-04-30 (G1–G9, see
;; dev/status/short-side-strategy.md). Phase A of the short-integration plan
;; at dev/notes/plan-short-integration-2026-05-12.md.
;;
;; **STATUS**: BASELINE pinned 2026-05-12. Ranges = ±15% around the first
;; measured run (see "Measured 2026-05-12" below).
;;
;; **Universe + sizing parity with long-only twin.** Same 510-symbol
;; survivorship-aware universe; Cell E position sizing (0.14/0.70/0.30) +
;; stage3-force-exit (h=1) + laggard rotation (h=2). Only diff vs long-only:
;; enable_short_side = true (and the consequent short-stop / short-notional
;; defaults from weinstein_strategy.config).
;;
;; **Acceptance criteria** (per plan-short-integration-2026-05-12.md
;; Phase A) — RESULTS on first run:
;;   1. Positive Sharpe — PASS (0.66 > 0).
;;   2. Clean force-liquidation audit (zero force-liqs) —
;;      FAIL: **307 force-liquidations** measured. Open follow-up: trace
;;      whether shorts trigger the cash-floor / loss-cap paths the long-only
;;      twin doesn't hit on the same window.
;;   3. Max drawdown lower than the long-only twin's [15.6, 21.2] band —
;;      FAIL: 21.35 sits 0.15pp ABOVE the long-only ceiling. Shorts did
;;      NOT reduce drawdown on the 2020 + 2022 down legs as hypothesised.
;;
;; **Measured 2026-05-12** (long-short, 16.3y window, 510-symbol universe):
;;   total_return_pct  267.08   total_trades 1125   win_rate 42.93
;;   sharpe_ratio       0.66    max_drawdown 21.35  avg_holding_days 33.64
;;   open_positions_value 2,374,035  unrealized_pnl 494,744
;;   force_liquidations_count 307
;;
;; Comparison to long-only twin (sp500-2010-2026.sexp, measured 2026-05-11):
;;   return 344.9 → 267.1  (-22.6%, shorts compete for capital)
;;   trades 1099  → 1125   (+2.4%, broadly comparable)
;;   sharpe 0.78  → 0.66   (lower at higher DD)
;;   MaxDD  18.4  → 21.35  (regression — shorts ADD risk, no DD relief)
;;   open_positions_value 3.09M → 2.37M (less long exposure)
;;
;; New M5.2c/d metrics (informational, NOT pinned in the expected block —
;; the goldens harness only pins the seven below):
;;   sortino_annualized 1.02   calmar 0.39   mar 0.37   omega 1.14
;;   profit_factor 1.45   cagr 8.29%
;;   ulcer_index 9.71   pain_index 7.29
;;   skewness 0.18   kurtosis 14.96   cvar95 -1.86   cvar99 -3.08
;; Benchmark-relative metrics (alpha/beta/TE/IR) = 0.0 — no benchmark series
;; is wired here yet (#1021 still in flight on a feature branch).
;;
;; Tolerances ±15% for the seven harness-pinned metrics.
((name "sp500-2010-2026-longshort-historical")
 (description
   "16y sp500 historical long-short backtest — survivorship-aware universe (510 symbols), enable_short_side=true. Twin of sp500-2010-2026.sexp (long-only). Phase A of dev/notes/plan-short-integration-2026-05-12.md.")
 (period ((start_date 2010-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2010-01-01.sexp")
 (universe_size 510)
 (config_overrides
  (((enable_short_side true))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (expected
  ((total_return_pct   ((min 227.0)         (max 307.0)))
   (total_trades       ((min 956)           (max 1294)))
   (win_rate           ((min  36.5)         (max  49.4)))
   (sharpe_ratio       ((min   0.56)        (max   0.76)))
   (max_drawdown_pct   ((min  18.1)         (max  24.6)))
   (avg_holding_days   ((min  28.6)         (max  38.7)))
   (open_positions_value ((min 2017000.0)   (max 2730000.0))))))
