;; perf-tier: 3
;; perf-tier-rationale: ~500-symbol universe over 5y (2019-2023, full Weinstein
;; cycle incl. COVID + recovery + 2022 bear). Weekly cadence (≤2 h budget).
;; Matches goldens-sp500/sp500-2019-2023.sexp's window so the two scenarios
;; are directly comparable.
;;
;; **P0b-followup** (next-session-priorities-2026-05-19.md). First scenario
;; that consumes a [Universe.Snapshot.t] golden via the [Universe_file.load]
;; auto-fallback bridge added in PR #1174.
;;
;; Universe: top-500-by-marketcap composition snapshot as of 2019-05-31
;; (mid-window). Built from EODHD market-cap inventory by
;; [analysis/data/universe/bin/build_composition_universes_runner.ml]. Sectors
;; carried per-entry from the snapshot — runner uses these and ignores
;; data/sectors.csv for this cell.
;;
;; **Comparison point**: goldens-sp500/sp500-2019-2023.sexp uses the
;; current SP500 (491 symbols, snapshot taken 2026-04-26 — i.e. survivor-
;; biased). This cell uses a 2019-05-31 top-500-by-marketcap snapshot —
;; less survivor-biased (closer to a point-in-time selection) but still
;; not fully survivorship-clean (the snapshot was built today from today's
;; EODHD inventory; truly-delisted-by-2019 symbols are absent). Returns
;; SHOULD be in the same ballpark as sp500-2019-2023 within 1-2 SE.
;;
;; **First-measurement comparison** (2026-05-17, post #1172/#1174/#1175/#1177):
;;
;; | Metric            | sp500-2019-2023 | top-500-2019 (this) | Delta            |
;; |-------------------|-----------------|---------------------|------------------|
;; | total_return_pct  |   50.66         |  174.69             | +124 pp (3.4×)   |
;; | total_trades      |  264            |  248                | -16              |
;; | win_rate          |   37.5          |   30.65             | -7 pp            |
;; | sharpe_ratio      |    0.56         |    0.62             | +0.06            |
;; | max_drawdown_pct  |   21.56         |   59.06             | +38 pp (2.7×)    |
;; | sortino_ratio_ann |    0.75         |    0.73             | flat             |
;; | calmar_ratio      |    0.40         |    0.38             | flat             |
;; | ulcer_index       |    8.41         |   26.89             | 3.2×             |
;;
;; The composition universe is HIGHER-CAGR, MUCH-WIDER-DRAWDOWN. Composition
;; entries at 2019-05-31 are concentrated in mega-cap growth names that
;; massively outperformed in 2019-2023 (AMZN, NVDA, TSLA, NFLX, BKNG, AVGO,
;; SHOP, ANET top of cap-ranked list). Current-SP500 snapshot (sp500.sexp)
;; mixes growth + mature/value names and so produces tamer return + DD.
;; Calmar parity (~0.38 vs ~0.40) confirms the risk-adjusted edge is
;; preserved — extra return mostly comes with proportionally extra DD.
;;
;; **NOT a like-for-like alpha test**: the two universes differ in
;; composition (top-500-by-marketcap vs current-SP500 membership) AND in
;; survivorship characteristics. This cell exists primarily to prove the
;; Universe_file ↔ Universe_snapshot bridge works end-to-end and to
;; smoke-test that strategy + screener consume composition goldens
;; without crashing. For true cross-universe alpha comparison we'd need
;; the same selection rule applied to both (P1 follow-up).
;;
;; Universe path uses ".." traversal because composition goldens live
;; outside fixtures_root (test_data/goldens-custom-universe/) — they're
;; owned by analysis/data/universe/, not the scenarios layer.
((name "weinstein-2019-top-500-composition")
 (description
   "Weinstein over the top-500-by-marketcap composition universe (snapshot 2019-05-31), 2019-01-02 → 2023-12-29. P0b-followup proof that the universe-snapshot → Universe_file bridge unlocks composition substrates.")
 (period ((start_date 2019-01-02) (end_date 2023-12-29)))
 (universe_path "../goldens-custom-universe/composition/top-500-2019.sexp")
 (universe_size 500)
 ;; Cell E config — same as goldens-sp500/sp500-2019-2023.sexp so the two
 ;; cells are directly comparable. Drift between the two reflects universe
 ;; difference (composition snapshot vs current-SP500 membership), not
 ;; config difference.
 (config_overrides
  (((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 ;; Measured 2026-05-17 (post #1172/#1174/#1175/#1177):
 ;;   total_return_pct  174.69  total_trades 248   win_rate 30.65
 ;;   sharpe_ratio      0.62   max_drawdown 59.06 avg_holding_days 40.85
 ;;   open_positions_value 2,263,365  sortino 0.73  calmar 0.38
 ;;   ulcer 26.89   wall 186.5s
 ;; Tolerances ±20% across the board, EXCEPT max_drawdown_pct at ±15%
 ;; (DD bands kept tight on purpose — a single-symbol blow-up shifts DD
 ;; more violently than the other metrics in a concentrated universe, so
 ;; we want CI to catch a regression there sooner than the rest). Wider
 ;; than sp500's ±15% otherwise — single-measurement baseline; tighten
 ;; the others after a second run confirms bounded drift.
 (expected
  ((total_return_pct   ((min 139.0)         (max 210.0)))
   (total_trades       ((min 198)           (max 298)))
   (win_rate           ((min  24.5)         (max  36.8)))
   (sharpe_ratio       ((min   0.49)        (max   0.74)))
   (max_drawdown_pct   ((min  50.2)         (max  68.0)))
   (avg_holding_days   ((min  32.7)         (max  49.0)))
   (open_positions_value ((min 1810000.0)   (max 2720000.0)))
   (sortino_ratio_annualized ((min  0.58)   (max   0.88)))
   (calmar_ratio       ((min   0.30)        (max   0.46)))
   (ulcer_index        ((min  21.5)         (max  32.3)))
   ;; wall_seconds wide (CI ~5x local, local ~190s) — catches only
   ;; catastrophic 2x slowdowns per design intent.
   (wall_seconds       ((min 100.0)         (max 1800.0))))))
