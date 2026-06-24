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
;; **WARNING — this is a BRIDGE SMOKE TEST, NOT a strategy alpha
;; benchmark.** Random-universe sweep on 2026-05-18 (see
;; dev/notes/random-universe-sweep-2026-05-18.md) showed the +174.69%
;; return here is ~8 σ above the random-500-sample mean of +12.66%
;; drawn from the same 2019 cap-ranked pool. The composition golden
;; is forward-looking: it's "what survived to 2026 AND was big in
;; 2019" — pure survivor + winner bias. Concentration in AMZN / NVDA /
;; TSLA / NFLX / BKNG / AVGO / SHOP / ANET — all monster 2019-2023
;; runners — drives the headline number, not Weinstein alpha. Win
;; rate (30.65) is statistically identical to the 5 random samples
;; (mean 28.99, range 26.5-31.5) — strategy mechanics are universe-
;; invariant; only the universe's intrinsic up-side changes.
;;
;; The cell still earns its keep: it pins the
;; Universe_file → Universe_snapshot.load_path_as_pairs bridge wiring
;; (added in PR #1174), pins the runner's universe-sized sector-map
;; handling for composition goldens, and pins per-symbol fill +
;; commission + stop accounting against a 500-symbol cell. A strategy
;; bug that breaks any of those will move trade count / win rate / DD
;; out of the pinned bands. A strategy bug that changes alpha discovery
;; on a *fair* (point-in-time) universe will NOT be caught here —
;; selection bias dominates the return number.
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
 ;; **Re-pinned 2026-05-18 after the delisted-aware composition rebuild
 ;; (P1 #1184 + P2 #1185 + P3 #1186 + ergonomics #1187 + post-P2 pipeline
 ;; run). The new top-500-2019 universe now includes ~101 names that
 ;; delisted between 2019-05-31 and 2026 (AABA, CELG, ANTM, AGN, ATVI,
 ;; CBS, CERN, ABMD, etc.), and drops 101 low-volume live names that
 ;; they crowded out by 2019 dollar-volume rank. See
 ;; `dev/notes/delisted-aware-p4-result-2026-05-18.md` for the full P4
 ;; writeup.
 ;;
 ;; Measured 2026-05-18 (delisted-aware universe):
 ;;   total_return_pct   78.34  total_trades 263   win_rate 31.94
 ;;   sharpe_ratio       0.69   max_drawdown 42.17 avg_holding_days 41.99
 ;;   open_positions_value 1,424,418  sortino 0.96  calmar 0.29
 ;;   ulcer 19.01
 ;;
 ;; Prior measurement (pre-delisted-aware, kept for #1180 narrative):
 ;;   total_return_pct  174.69  total_trades 248   win_rate 30.65
 ;;   sharpe_ratio      0.62   max_drawdown 59.06 ulcer 26.89
 ;;
 ;; The selection-bias finding from #1180 is borne out: return drops 55%
 ;; (175% → 78%) once we stop excluding names that delisted between
 ;; snapshot and 2026. Risk metrics IMPROVE (MaxDD -29%, Ulcer -29%,
 ;; Sortino +31%) because the new universe is less concentrated in
 ;; extreme-volatility growth names (AMZN/NVDA/TSLA still in but no
 ;; longer dominating the top of the cap-rank distribution). The 8σ gap
 ;; to the random-sample mean (+12.66%, #1180) narrows from ~8σ to ~3σ.
 ;;
 ;; Tolerances ±20% across the board, EXCEPT max_drawdown_pct +
 ;; win_rate + avg_holding_days at ±15% (those have lower per-run
 ;; variance per the #1180 random-sample distribution).
 ;;
 ;; **RE-PINNED 2026-06-24 (#1729 decision C): complete-universe warehouse run
 ;; (top-500-2019, 500/500 symbols loaded; 515 incl. ^GSPC + sector ETFs).**
 ;; The 2026-05-18 band was measured against a test_data store that covered only
 ;; a survivor subset (~337/500) of this delisting-aware composition universe —
 ;; the runner silently skipped the missing names. Re-measured against the
 ;; delisting-complete warehouse snapshot /tmp/snap_top3000_1998_2026 (3015 syms).
 ;; Return (72.77%) lands close to the prior band (which was already
 ;; delisted-aware), but the full universe is less risky: MaxDD/ulcer fall and
 ;; calmar rises. Determinism established on the sibling decade cell (bit-identical
 ;; across two runs). This cell will (correctly) keep FAILING in GHA perf-tier3 /
 ;; golden-runs-custom-universe against the incomplete committed test_data — that
 ;; failure is the intentional missing-data signal; a local snapshot run
 ;; reproduces the band below. Tolerances unchanged (±20%, EXCEPT DD/win/holding
 ;; at ±15%); wall_seconds band kept (perf guard, not data-dependent).
 ;;
 ;; Measured 2026-06-24 (complete-universe warehouse, top-500-2019):
 ;;   total_return_pct  72.77  total_trades 262  win_rate 36.64
 ;;   sharpe_ratio 0.77  max_drawdown 27.31  avg_holding_days 39.39
 ;;   open_positions_value 1,472,159  sortino 1.13  calmar 0.42  ulcer 12.57
 (expected
  ((total_return_pct   ((min  58.2)         (max  87.3)))
   (total_trades       ((min 210)           (max 314)))
   (win_rate           ((min  31.1)         (max  42.1)))
   (sharpe_ratio       ((min   0.61)        (max   0.92)))
   (max_drawdown_pct   ((min  23.2)         (max  31.4)))
   (avg_holding_days   ((min  33.5)         (max  45.3)))
   (open_positions_value ((min 1177727.0)   (max 1766591.0)))
   (sortino_ratio_annualized ((min  0.90)   (max   1.36)))
   (calmar_ratio       ((min   0.34)        (max   0.51)))
   (ulcer_index        ((min  10.1)         (max  15.1)))
   ;; wall_seconds wide (CI ~5x local, local ~190s) — catches only
   ;; catastrophic 2x slowdowns per design intent.
   (wall_seconds       ((min 100.0)         (max 1800.0))))))
