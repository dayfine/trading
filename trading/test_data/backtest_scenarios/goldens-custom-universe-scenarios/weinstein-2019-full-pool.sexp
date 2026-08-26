;; perf-tier: research
;; perf-tier-rationale: BASELINE RESEARCH cell — NOT a tier-3 regression
;; cell. Runs Cell-E over the full top-3000-2019 universe (no random
;; subsampling) for 2019-2023. Settles the survivor-bias / random-sample
;; methodology question raised by dev/notes/random-universe-sweep-2026-05-18.md
;; (uniform 500-of-2549 random subsets, n=5 — flawed methodology). The
;; correct control is one full-pool run on the same composition fixture
;; that top-500-2019.sexp was sliced from.
;;
;; **DO NOT add ;; perf-tier: 3** — this would route through
;; .github/workflows/golden-runs-custom-universe.yml's
;; goldens-custom-universe-scenarios subdir scan
;; (dev/scripts/golden_sp500_postsubmit.sh greps for `^;; perf-tier: 3`).
;; Expected wall time is multi-hour (3000 symbols × 5 years weekly cadence),
;; well beyond the 60-min CI timeout, and the expected bands here are
;; intentionally wide for research — not suitable as a CI regression gate.
;;
;; Comparison points (all 2019-01-02 → 2023-12-29, Cell-E):
;;   - goldens-sp500/sp500-2019-2023.sexp: ~491-symbol current-SP500 (survivor-
;;     biased snapshot taken 2026-04-26). Measured: total_return_pct 50.66.
;;   - weinstein-2019-top-500.sexp: top-500-by-marketcap composition snapshot
;;     2019-05-31 (delisted-aware rebuild via #1184-#1187). Measured 2026-05-18:
;;     total_return_pct 78.34.
;;   - THIS cell: full top-3000-by-marketcap composition snapshot 2019-05-31
;;     (same delisted-aware fixture top-500-2019 is sliced from).
;;
;; **Measured 2026-05-23 (research baseline):**
;;   total_return_pct  32.37   total_trades 278   win_rate 33.09
;;   sharpe_ratio       0.37   max_drawdown 32.48 avg_holding_days 32.22
;;   sortino           0.43   calmar       0.18   ulcer 14.71
;;   open_positions_value 1,308,524  wall_seconds 2,158 (~36 min)
;;
;; Full comparison + interpretation in
;; `dev/notes/full-2019-pool-baseline-2026-05-23.md`. Net finding:
;; full-pool dilutes the top-500's selection bias roughly 1.4× (top-500
;; +78.34% vs. full-pool +32.37%); the previous 8σ random-sample
;; framing in `random-universe-sweep-2026-05-18.md` is superseded.
;;
;; Run via:
;;   scenario_runner.exe --dir <dir containing only this scenario> \
;;     --fixtures-root trading/test_data/backtest_scenarios \
;;     --parallel 1 --no-emit-all-eligible
;;
;; Universe path uses ".." traversal because composition goldens live
;; outside fixtures_root (same convention as weinstein-2019-top-500.sexp).
((name "weinstein-2019-full-pool-composition")
 (description
   "Weinstein Cell-E over the FULL top-3000-by-marketcap composition universe (snapshot 2019-05-31, delisted-aware), 2019-01-02 → 2023-12-29. Full-pool baseline that settles the random-universe-sweep methodology question — one deterministic run on the entire pool, not n=5 uniform subsamples.")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "../goldens-custom-universe/composition/top-3000-2019.sexp")
 (universe_size 3000)
 ;; Cell-E config — identical to goldens-sp500/sp500-2019-2023.sexp and
 ;; weinstein-2019-top-500.sexp so the three cells are directly comparable.
 ;; Any drift across the three reflects universe difference only.
 (config_overrides
  (((portfolio_config ((max_position_pct_long 0.14))))
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
   (entry_extension_max_pct "live arms 2.0 (#2404 user decision 2026-08-25, measured winner); this cell runs the 0.0 default (uncapped) — report-side ticket cap, never read by on_market_close unless enable_sim_entry_stoplimit arms it")
   (sparse_tail_min_bars "live-only sparse-tail eligibility gate (#2083 fix 1); report-layer data hygiene, no backtest consumer")
   (sparse_tail_window_trading_days "live-only sparse-tail eligibility gate (#2083 fix 1); report-layer data hygiene, no backtest consumer")
   (rename_detect_min_overlap_days "live-only ticker-rename detector (#2083 fix 2); report-layer data hygiene, no backtest consumer")
   (rename_detect_match_fraction "live-only ticker-rename detector (#2083 fix 2); report-layer data hygiene, no backtest consumer")))
 ;; **Research bands** — intentionally WIDE to catch only catastrophic
 ;; crashes / NaN sentinels. This is NOT a regression cell. The point of
 ;; the cell is to MEASURE, not to pin. Per-metric rationale:
 ;;   - total_return_pct: -50 to +200 — full-pool diversification should
 ;;     drag the return well below top-500's +78% (less selection bias)
 ;;     but a catastrophic strategy bug would blow past either bound.
 ;;   - max_drawdown_pct: 0 to 95 — catch only "did the strategy keep
 ;;     anything" wipeout cases.
 ;;   - sharpe_ratio: -2 to 5 — same; NaN/inf would fail in_range too.
 ;;   - total_trades: 0 to 100000 — 3000-symbol pool over 5y can easily
 ;;     fire thousands of breakouts.
 ;;   - wall_seconds: 0 to 36000 (10 hrs; min floored at 0 per #2547 — a min guards nothing) — full-pool weekly cadence
 ;;     is multi-hour by design.
 (expected
  ((total_return_pct  ((min -50.0)         (max 200.0)))
   (total_trades      ((min   0.0)         (max 100000.0)))
   (win_rate          ((min   0.0)         (max 100.0)))
   (sharpe_ratio      ((min  -2.0)         (max   5.0)))
   (max_drawdown_pct  ((min   0.0)         (max  95.0)))
   (avg_holding_days  ((min   0.0)         (max 365.0)))
   (wall_seconds      ((min 0.0)           (max 36000.0))))))
