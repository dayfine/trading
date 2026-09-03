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
 ;; Deviations from the live weekly-picks config
 ;; (dev/weekly-picks/live-config-overrides.sexp), enforced by the
 ;; golden_live_drift linter (#2403). Data-only: Scenario.t is
 ;; [@@sexp.allow_extra_fields], so the runner parses and ignores this block.
 (deviates_from_live
  ((portfolio_config "record-convention concentration arming (position 0.14 / exposure 0.70 / min_cash 0.30); live runs the code defaults")
   (enable_stage3_force_exit "record-convention Stage-3 force-exit arming; live leaves it default-off")
   (stage3_force_exit_config "hysteresis_weeks 1 belongs to the arming above; the code default is 2")
   (enable_laggard_rotation "record-convention laggard-rotation arming; live leaves it default-off")
   (laggard_rotation_config "hysteresis_weeks 2 belongs to the arming above; the code default is 4")
   (extension_stop_config "live arms the extension-stop insurance (trigger 2.0 / trail 0.25, ledger 2026-07-14-extension-stop-insurance-accept); this cell pins the pre-insurance basis")
   (reject_declining_ma_long_entry "live arms the declining-MA long-entry rejection (#1775); this cell pins the pre-arming basis")
   (screening_config "live arms candidate_ranking=Quality (#1782, report ordering) and failed_breakout_tolerance_pct=0.05 (#2084); the backtest defaults stay unarmed per experiment-flag R1")
   (resistance_lookback_bars "live feeds the resistance/support mapper 520 weekly bars for the human report only")
   (entry_through_band_pct "live-only entry-reconciliation band for the printed ticket (#2103); read by Weekly_snapshot_generator, never by on_market_close")
   (sparse_tail_min_bars "live-only sparse-tail eligibility gate (#2083 fix 1); report-layer data hygiene, no backtest consumer")
   (sparse_tail_window_trading_days "live-only sparse-tail eligibility gate (#2083 fix 1); report-layer data hygiene, no backtest consumer")
   (rename_detect_min_overlap_days "live-only ticker-rename detector (#2083 fix 2); report-layer data hygiene, no backtest consumer")
   (rename_detect_match_fraction "live-only ticker-rename detector (#2083 fix 2); report-layer data hygiene, no backtest consumer")))
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
  ;; RE-PINNED 2026-08-25 to the book-faithful stops basis shipped in
  ;; #2530 (initial_stop_buffer 1.0 + reset_anchor_on_stalled_cycle on,
  ;; ledger 2026-08-24-stops-basis-book-faithful) — the #2403 historical
  ;; re-pin, measured from the #2537 diagnostic run (local, pinned
  ;; worktree at 0ebe5fd8b, committed test_data store, 5374s total /
  ;; 472s backtest proper / ~745MB GNU-time peak RSS — the harness
  ;; summary printed 1745192kB, which fuses GNU time's exit-status "1"
  ;; onto the digits on failing cells; see the postsubmit-script issue
  ;; filed off #2552's review). Single local run; the
  ;; runner's determinism was pinned 3x independently on the custom
  ;; cell at this build family. Bands ±15% around:
  ;;   ret 844.10  trades 619  win 35.70  sharpe 0.566  maxDD 60.99
  ;;   hold 58.08  OPV 4,606,165  sortino 0.781  calmar 0.242  ulcer 20.90
  ;; The LONG-SHORT cell moved far more than long-only under the new
  ;; basis: return band 307-416 -> 717-971, maxDD 18-25 -> 52-70. A
  ;; PLAUSIBLE mechanism is the short side interacting with the wider
  ;; initial stop + ratchet reset — hypothesis only; no trade-level
  ;; dissection was run (see mechanism-validation rigor).
  ;; RE-PINNED 2026-08-26 for the #2380 RS-trend fix (PR #2555: lookback_bars
  ;; 52->56 makes the trend classifier + its FOUR consumers live for the
  ;; first time; the 4 deeper bars also reach volume/breakout detection).
  ;; +-15% around actuals from the paired run at PR tip 5b6472afd (local,
  ;; pinned worktree, committed store). CORRECTNESS re-pin: per the #2380
  ;; record, NO return-improvement claim attaches to these deltas -- the
  ;; large top-line swings are tail-path reshuffling on a pin, not evidence.
  ;; This LONG-SHORT cell additionally feels rs_blocks_short going from
  ;; universally-blocking (every candidate Positive_flat, which the gate
  ;; passes) to genuinely discriminating -- the fourth consumer named in
  ;; weinstein_strategy_config.mli; the mechanism its docstring predicted
  ;; would move this cell (+205pp ret / +18pp maxDD here, still a pin).

  ;; RE-PINNED 2026-08-26 for the fill-model default flip (PR #2569:

  ;; enable_sim_entry_stoplimit + entry_extension_max_pct 2.0 as the

  ;; default pair -- USER-directed fidelity decision, #2405 precondition;

  ;; entries now rest as StopLimit tickets like live). +-15% around the

  ;; paired-sweep actuals at PR tip aa4a513e2 (local pinned worktree,

  ;; committed store). NO return claim: the swings are entry-timing

  ;; reshuffles on regression pins, not evidence about the fill model.


  ;; RE-PINNED 2026-09-03 for the D1/D2 exit-basis default flip (PR #2648: sim_exit_fill_next_open + stop_skip_entry_bar on). ±15% around the NEW-arm actual at pinned build 398f57111; paired old arm + dissection in dev/experiments/exit-basis-flip-2026-09-03/. Correctness re-pin: no return claim attaches to the delta.
  ((total_return_pct ((min 345.1137) (max 466.9185)))
   (total_trades ((min 567.8000) (max 768.2000)))
   (win_rate ((min 27.9940) (max 37.8743)))
   (sharpe_ratio ((min 0.3541) (max 0.4790)))
   (max_drawdown_pct ((min 67.2212) (max 90.9463)))
   (avg_holding_days ((min 52.9329) (max 71.6150)))
   ;; OPV re-pinned ~2.18M under the realism-defaults flip (ledger
   ;; 2026-07-10-realism-defaults-flip): $1M-ADV entry gate + stale-exit 5d
   ;; lighten the terminal book. Headline metrics stayed in-band (ret 387.5 /
   ;; 784 / Sharpe 0.777 / DD 21.35). Was ~3.76M pre-flip.
   (open_positions_value ((min 1467314.9225) (max 1985190.7775)))
   (sortino_ratio_annualized ((min 0.3587) (max 0.4853)))
   (calmar_ratio ((min 0.1122) (max 0.1518)))
   (ulcer_index ((min 28.4961) (max 38.5536)))
   ;; Wall floor lowered 600→100, then floored at 0 per #2547 (a min guards nothing; the 364 run measured ~391s locally).
   (wall_seconds       ((min 0.0)           (max 2400.0))))))
