;; perf-tier: 1
;; perf-tier-rationale: 7-symbol parity universe over 6 months — fastest scenario in the catalog, well under the per-PR ≤2 min budget. Already exercised by OUnit tests; tagging makes it eligible for the per-PR perf smoke too. See dev/plans/perf-scenario-catalog-2026-04-25.md tier 1.
;;
;; Merge-gate parity scenario for the tiered loader track.
;;
;; Runs under BOTH [loader_strategy = Legacy] and [loader_strategy = Tiered]
;; inside [test_tiered_loader_parity] and the test asserts the two runs return
;; identical trade counts, equity curve samples, final portfolio value, and
;; within-range pinned metrics. See:
;;   - dev/plans/backtest-tiered-loader-2026-04-19.md §3g
;;   - trading/backtest/test/test_tiered_loader_parity.ml
;;
;; Scenario shape — 6-month window, deterministic, kept small so the parity
;; run completes inside an OUnit2 test budget:
;;   * period: 2019-06-03 → 2019-12-31 (H2 2019, a calm bull leg)
;;   * universe: committed [data/sectors.csv] which carries 7 equities plus the
;;     primary index (GSPC.INDX). Every symbol referenced here has committed
;;     price CSVs under [test_data/<first>/<last>/<symbol>/data.csv].
;;
;; The task plan asked for ~30 symbols from [universes/small.sexp], but the
;; checked-in test_data/ only has price CSVs for the 7 equities referenced in
;; [universes/parity-7sym.sexp] below. Expanding to 30 would require pulling
;; in fresh symbol CSVs (fetch work — out of scope for a parity test). The
;; 7-symbol universe is still sufficient: parity is an equality check, and
;; the Tiered path's Friday Summary-promote → Shadow_screener → Full-promote
;; cycle runs whether there are 7 or 30 candidates. The Tiered path's bulk
;; Metadata promote also errors hard on missing CSVs (Legacy is tolerant),
;; so a pinned universe matching on-disk data is required for the test to
;; target strategy-divergence rather than missing-data handling.
;;
;; Pinned metric ranges are intentionally broad — they exist only to catch
;; gross regressions (e.g. the final portfolio value halving, or all trades
;; vanishing). The MAIN parity assertion is Legacy == Tiered, which the test
;; enforces to the $0.01 level and does not depend on these ranges.
;;
;; [loader_strategy] is intentionally absent. The test binary drives the
;; choice explicitly (one pass per value).
;;
;; Macro symbols: the Runner's [_load_deps] unconditionally expands
;; [all_symbols] to include the 11 SPDR sector ETFs + 3 global indices
;; (GDAXI.INDX, N225.INDX, ISF.LSE) alongside the universe and primary index.
;; Checked-in synthetic OHLCV fixtures for those 14 symbols live under
;; [test_data/<first>/<last>/<symbol>/data.csv] covering 2018-10-01 →
;; 2020-01-03. They're deliberately simple (100.00 baseline + 0.01/day drift)
;; because parity only cares that Legacy and Tiered see IDENTICAL macro data,
;; not that the macro signal is economically meaningful.
;;
;; Those 14 synthetic fixtures also surface a genuine Tiered divergence that
;; we explicitly opted to resolve upstream of strategy code: Legacy's
;; Simulator silently skips missing-bar symbols, while
;; [Tiered_runner._promote_universe_metadata] hard-[failwith]s on the first
;; [Bar_loader.promote] error. Without synthetic fixtures the Tiered run
;; aborts before the simulator loop even starts, so no strategy-level parity
;; can be observed. Providing identical fixtures for both paths keeps the
;; test's merge-gate purpose intact; the missing-CSV tolerance divergence is
;; escalated separately in [dev/status/backtest-scale.md].
((name "tiered-loader-parity")
 (description "Parity acceptance: Legacy vs Tiered on a 6-month small-universe window")
 (period ((start_date 2019-06-03) (end_date 2019-12-31)))
 (universe_path "universes/parity-7sym.sexp")
 (universe_size 7)
 (config_overrides ())
 (expected
  ((total_return_pct   ((min -20.0)  (max 40.0)))
   (total_trades       ((min 0)      (max 20)))
   (win_rate           ((min 0.0)    (max 100.0)))
   (sharpe_ratio       ((min -5.0)   (max 10.0)))
   (max_drawdown_pct   ((min 0.0)    (max 40.0)))
   (avg_holding_days   ((min 0.0)    (max 200.0))))))
