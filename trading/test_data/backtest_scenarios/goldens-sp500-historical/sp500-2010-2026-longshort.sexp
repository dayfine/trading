;; perf-tier: 3-historical
;; perf-tier-rationale: 16y sp500 historical LONG-SHORT backtest. Twin of
;; goldens-sp500-historical/sp500-2010-2026.sexp (long-only) with
;; enable_short_side = true. First long-window golden that exercises the
;; short-side primitives merged in 2026-04-30 (G1–G9, see
;; dev/status/short-side-strategy.md). Phase A of the short-integration plan
;; at dev/notes/plan-short-integration-2026-05-12.md.
;;
;; **STATUS**: BASELINE re-pinned 2026-05-12 AFTER P1 fix
;; (Portfolio_floor death-loop). Ranges = ±15% around measured values.
;;
;; **Universe + sizing parity with long-only twin.** Same 510-symbol
;; survivorship-aware universe; Cell E position sizing (0.14/0.70/0.30) +
;; stage3-force-exit (h=1) + laggard rotation (h=2). Only diff vs long-only:
;; enable_short_side = true (and the consequent short-stop / short-notional
;; defaults from weinstein_strategy.config).
;;
;; **Acceptance criteria** (per plan-short-integration-2026-05-12.md
;; Phase A) — RESULTS after P1 fix:
;;   1. Positive Sharpe — PASS (0.66 > 0).
;;   2. Clean force-liquidation audit (zero force-liqs) —
;;      STILL FAIL: 14 force-liqs (was 307 pre-fix; -95.4%). 1 Per_position
;;      (DISCA 2014, -50.8%; legitimate) + 13 Portfolio_floor across 3
;;      cascade dates in 2025 (4/17, 5/5, 5/19). The remaining 13 are the
;;      legitimate initial breach + 2 re-breaches after macro flipped
;;      Bearish then back. Transition-only reset semantic now lets halt
;;      clear naturally on regime change rather than re-firing every Friday.
;;   3. Max drawdown lower than the long-only twin's [15.6, 21.2] band —
;;      STILL FAIL: 21.35 sits 0.15pp ABOVE the long-only ceiling. Shorts
;;      did NOT reduce drawdown on the 2020 + 2022 down legs.
;;
;; **Measured 2026-05-12 (post-P1 fix)**:
;;   total_return_pct  262.19   total_trades  832   win_rate 39.54
;;   sharpe_ratio       0.66    max_drawdown 21.35  avg_holding_days 44.40
;;   open_positions_value 2,374,035  unrealized_pnl 494,744
;;   force_liquidations_count 14
;;
;; Pre-P1-fix vs post-P1-fix delta (informational):
;;   return    267.08 → 262.19  (-1.8%, marginal)
;;   trades   1125    → 832     (-26%, fewer churn cycles after halt latches)
;;   win_rate  42.93  → 39.54   (-3.4pp, fewer short-hold whipsaws)
;;   sharpe    0.66   → 0.66    (unchanged at 2 decimals)
;;   MaxDD     21.35  → 21.35   (unchanged — halt doesn't affect drawdown
;;                                depth, only re-fire count)
;;   avg_hold  33.64  → 44.40   (+32%, positions live longer without weekly
;;                                forced exits)
;;   force-liqs 307   → 14      (-95.4%, death loop killed)
;;
;; New M5.2c/d metrics (informational, NOT pinned in expected block):
;;   sortino_annualized 1.01   calmar 0.38   mar 0.37   omega 1.14
;;   profit_factor 1.48   cagr 8.20%
;;   ulcer_index 9.86   pain_index 7.36
;;   skewness 0.18   kurtosis 15.07   cvar95 -1.86   cvar99 -3.08
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
 ;; Cost-model overlay (PR #1260 wiring). See sp500-2010-2026.sexp for the
 ;; full rationale. [retail_default] with per_trade=0 is byte-equal to
 ;; [None] under current wiring (only [apply_per_trade_commission] is
 ;; hooked); spread / per_share activate once [Cost_model.to_engine_costs]
 ;; is wired into [Panel_runner] — Open work item in
 ;; `dev/status/cost-model.md`. Long-short scenarios will absorb more
 ;; spread drag than long-only since shorts cycle faster on stops.
 (cost_model
  ((per_trade_commission 0.0)
   (per_share_commission 0.0)
   (bid_ask_spread_bps 5.0)
   (market_impact_bps_per_pct_adv 0.0)))
 ;; Re-pinned 2026-05-13 post NAV stale-price fix (#1063). Long-short
 ;; force_liq events on this 16y run: 1 (vs 300+ death-loop signature
 ;; pre-fix, per dev/notes/longshort-portfolio-floor-death-loop). The
 ;; Portfolio_view avg-cost fallback removes the phantom NAV collapse
 ;; that triggered cascading Peak_tracker breaches; the short book now
 ;; tracks Sharpe 0.70 / Calmar 0.46 / MaxDD 19.8% on the cleaned
 ;; baseline. total_return ~316% (was crashing pre-fix); open_positions
 ;; ~4.1M (was inflated by spurious-NAV-driven sizing). Wall on local
 ;; parallel-3 in trading-1-dev: 1217.2s; pin sized for GHA/local
 ;; variance.
 (expected
  ;; Re-pinned 2026-07-08 for the warmup 210→364 fix (RS present from the first
  ;; screen; dev/notes/warmup-364-repin-2026-07-08.md), ±15% around 364 actuals:
  ;;   ret 362.11  trades 782  win 35.81  sharpe 0.75  maxDD 21.35  hold 45.40
  ;;   OPV 3,760,365  sortino 1.11  calmar 0.46  ulcer 8.26
  ;; Unlike the long-only twin (floor-halted by the GME squeeze — see its pin
  ;; comment), this hedged variant rides the same window healthily.
  ;; Re-verified 2026-07-09 under the neutral_blocks_shorts default flip
  ;; (false→true, user-mandated faithfulness flip): actuals are BIT-IDENTICAL
  ;; to the 364 pin above (ret 362.11 / 782 / 35.81 / 0.75 / 21.35 / 45.40 /
  ;; OPV 3,760,365 / 1.11 / 0.46 / 8.26). This 2010-2026 window took no
  ;; Neutral-tape short the gate would block, so the flip is inert here —
  ;; bands unchanged. Confirms the ≈0-cost deep-cell attribution
  ;; (dev/notes/p1a-deep-short-screens-364-2026-07-09.md §Attribution).
  ((total_return_pct   ((min 307.8)         (max 416.4)))
   (total_trades       ((min 665)           (max  899)))
   (win_rate           ((min  30.4)         (max  41.2)))
   (sharpe_ratio       ((min   0.64)        (max   0.86)))
   (max_drawdown_pct   ((min  18.1)         (max  24.6)))
   (avg_holding_days   ((min  38.6)         (max  52.2)))
   (open_positions_value ((min 3196000.0)   (max 4324000.0)))
   (sortino_ratio_annualized ((min  0.95)   (max   1.28)))
   (calmar_ratio       ((min   0.39)        (max   0.53)))
   (ulcer_index        ((min   7.00)        (max   9.50)))
   ;; Wall floor lowered 600→100 (the 364 run measured ~391s locally).
   (wall_seconds       ((min 100.0)         (max 2400.0))))))
