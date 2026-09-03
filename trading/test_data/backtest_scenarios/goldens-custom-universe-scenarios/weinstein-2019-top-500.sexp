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
  ;; Re-pinned 2026-07-08 for the warmup 210→364 fix (RS present from the first
  ;; screen; dev/notes/warmup-364-repin-2026-07-08.md), ±15% around 364 actuals:
  ;;   ret 102.39  trades 250  win 34.0  sharpe 0.87  maxDD 30.07  hold 41.00
  ;;   OPV 1,669,042  sortino 1.18  calmar 0.50  ulcer 12.22
  ;; Verified INERT under the 2026-07-11 REALISM-DEFAULTS flip (user mandate;
  ;; min_entry_dollar_adv 0.0→1e6 + stale_exit_after_days None→Some 5; ledger
  ;; 2026-07-10-realism-defaults-flip): re-measured against test_data (--parallel 3,
  ;; the survivor subset store per warmup-364 mapping) = BIT-IDENTICAL to the 364
  ;; pin (102.39% / 250 / 34.0 / 0.87 / 30.07 / 41.00 / OPV 1,669,042 / force_liqs 0).
  ;; The top-500-by-cap composition is liquid over this window → gate + stale-exit
  ;; no-op. Bands unchanged.
  ;; RE-PINNED 2026-08-25 to the book-faithful stops basis shipped in #2530
  ;; (initial_stop_buffer 1.02→1.0 + reset_anchor_on_stalled_cycle default-on,
  ;; ledger 2026-08-24-stops-basis-book-faithful) — part of the #2403 broad/
  ;; custom re-pin. Bands ±15% around the 2026-08-25 local run at main
  ;; e2f69bc69 (postsubmit script, --parallel 1, survivor-subset test_data
  ;; store — same store the GHA workflow runs against):
  ;;   ret 103.35  trades 191  win 38.22  sharpe 0.878  maxDD 29.83
  ;;   hold 57.24  OPV 1,662,331  sortino 1.225  calmar 0.513  ulcer 11.53
  ;; Signature matches the basis flip's known direction (fewer trades,
  ;; longer holds — see dev/experiments/record-baseline-2026-08-24): the
  ;; prior pin FAILed exactly on total_trades low + avg_holding_days high.
  ;; RE-PINNED 2026-08-26 for the #2380 RS-trend fix (PR #2555: lookback_bars
  ;; 52->56 makes the trend classifier + its FOUR consumers live for the
  ;; first time; the 4 deeper bars also reach volume/breakout detection).
  ;; +-15% around actuals from the paired run at PR tip 5b6472afd (local,
  ;; pinned worktree, committed store). CORRECTNESS re-pin: per the #2380
  ;; record, NO return-improvement claim attaches to these deltas -- the
  ;; large top-line swings are tail-path reshuffling on a pin, not evidence.

  ;; RE-PINNED 2026-08-26 for the fill-model default flip (PR #2569:

  ;; enable_sim_entry_stoplimit + entry_extension_max_pct 2.0 as the

  ;; default pair -- USER-directed fidelity decision, #2405 precondition;

  ;; entries now rest as StopLimit tickets like live). +-15% around the

  ;; paired-sweep actuals at PR tip aa4a513e2 (local pinned worktree,

  ;; committed store). NO return claim: the swings are entry-timing

  ;; reshuffles on regression pins, not evidence about the fill model.


  ;; RE-PINNED 2026-09-03 for the D1/D2 exit-basis default flip (PR #2648: sim_exit_fill_next_open + stop_skip_entry_bar on). ±15% around the NEW-arm actual at pinned build 398f57111; paired old arm + dissection in dev/experiments/exit-basis-flip-2026-09-03/. Correctness re-pin: no return claim attaches to the delta.
  ((total_return_pct ((min 34.5120) (max 46.6927)))
   (total_trades ((min 160.6500) (max 217.3500)))
   (win_rate ((min 23.8360) (max 32.2487)))
   (sharpe_ratio ((min 0.4109) (max 0.5559)))
   (max_drawdown_pct ((min 32.4418) (max 43.8918)))
   (avg_holding_days ((min 52.3177) (max 70.7828)))
   (open_positions_value ((min 972125.3395) (max 1315228.4005)))
   (sortino_ratio_annualized ((min 0.4938) (max 0.6681)))
   (calmar_ratio ((min 0.1575) (max 0.2130)))
   (ulcer_index ((min 13.6071) (max 18.4096)))
   ;; wall_seconds guards only the MAX (catastrophic slowdown). The old
   ;; min 100.0 was the 2026-08-25 "GHA flake" (#2547 root cause, read
   ;; from the first #2549-uploaded per-cell artifact): fast warm-cache
   ;; runners finish the backtest in ~96s and FAILed the band from
   ;; BELOW with digit-identical metrics. A minimum wall time guards
   ;; nothing — floor it at 0.
   (wall_seconds       ((min 0.0)           (max 1800.0))))))
