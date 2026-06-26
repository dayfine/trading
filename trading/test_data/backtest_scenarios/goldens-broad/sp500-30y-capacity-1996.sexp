;; perf-tier: capacity-only
;; perf-tier-rationale: NOT a release-gate cell — survivorship-biased; capacity validation only.
;;
;; CAPACITY VALIDATION ONLY — NOT A STRATEGY VALIDATION
;;
;; This scenario exists to measure peak RSS, wall, and engine stability
;; over a 30-year horizon at N=1000. The universe
;; (`universes/broad-1000-30y.sexp`) is intrinsically survivorship-
;; biased: every symbol was selected because it survived from <=1996 to
;; 2026. Returns and drawdowns over a 30y backtest on this cohort do NOT
;; reflect what the strategy would have produced live. See
;; `dev/notes/historical-universe-membership-2026-04-30.md` for the
;; bias caveat (issue #696) and
;; `dev/notes/n1000-30y-capacity-2026-04-30.md` for the run output.
;;
;; Do NOT add this cell to tier-3 or tier-4 perf workflows. Do NOT
;; compare its return/drawdown to "expected" values. The expected
;; ranges below are intentionally wide because they are not a baseline
;; — they exist solely to gate "did the run complete without crashing,
;; OOMing, or producing nonsense like NaN drawdown".
;;
;; enable_short_side = false (mirror of #682's mitigation): the
;; short-side gaps documented in `dev/notes/short-side-gaps-2026-04-29.md`
;; (G1-G4) produce broken metrics on any scenario crossing a Bearish-
;; macro window. G4 not yet merged at scenario-creation time, so long-
;; only is the safe default for any new long-horizon cell.
;;
;; Cost-model projection (post-engine-pool):
;;   RSS ≈ 67 + 3.94·N + 0.19·N·(T−1)
;;        = 67 + 3940 + 0.19·1000·29
;;        = ~9,517 MB (~9.3 GB).
;; Measured-vs-projected gap on N=1000×10y was 52 % (2,945 MB measured
;; vs 5,700 MB projected; see dev/notes/n1000-decade-rss-2026-04-29.md).
;; If the same factor holds, expect ~5 GB peak. Won't fit GHA 8 GB
;; ceiling under the cost-model worst case — runs locally on
;; trading-1-dev (32 GB host) only.
((name "sp500-30y-capacity-1996")
 (description "30-year capacity validation — survivorship-biased N=1000 cohort, long-only")
 (period ((start_date 1996-01-02) (end_date 2025-12-31)))
 (universe_path "universes/broad-1000-30y.sexp")
 (universe_size 1000)
 ;; Cell E rollout 2026-05-11: applies the standard Cell E strategy config
 ;; (max_position_pct_long=0.30, max_long_exposure_pct=0.70, min_cash_pct=0.30,
 ;; stage3 force-exit h=1, laggard rotation h=2) for consistency with the
 ;; rest of the goldens. Capacity testing isn't affected by the config knobs
 ;; — pin ranges are intentionally wide and tolerate the new shape.
 (config_overrides
  (((universe_cap (1000)))
   ((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.30))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 ;; Expected ranges intentionally permissive — this is a smoke gate,
 ;; not a baseline. PASS = run completes without OOM/crash and produces
 ;; non-degenerate metrics. Specific values are recorded in
 ;; dev/notes/n1000-30y-capacity-2026-04-30.md and the ranges below
 ;; merely confirm the run finished sanely.
 (expected
  ;; Concentration=0.30 promotion 2026-06-25 (max_position_pct_long 0.14 -> 0.30, the
  ;; production default; ledger 2026-06-25-capacity-concentration-broad). Capacity-test
  ;; sentinel bands; 0.30 measured ret 951.9% / 958 trades / 40.9% win / 33.9% DD (PASS).
  ((total_return_pct   ((min -1000.0)      (max 1000000.0)))
   (total_trades       ((min 0)            (max 100000)))
   (win_rate           ((min 0.0)          (max 100.0)))
   (sharpe_ratio       ((min -10.0)        (max 10.0)))
   (max_drawdown_pct   ((min 0.0)          (max 100.0)))
   (avg_holding_days   ((min 0.0)          (max 10000.0)))
   (open_positions_value ((min -1000000000.0) (max 100000000000.0))))))
