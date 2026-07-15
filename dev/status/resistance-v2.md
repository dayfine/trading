# Track: resistance-v2 — continuous supply score on precomputed PIT top-sketches

## Status

IN_PROGRESS

## Last updated: 2026-07-16

## Interface stable

NO

(PR-D extended `Stock_analysis.config`/`callbacks`/`t`,
`Screener_scoring.scoring_weights`, and `Weinstein_strategy_config` — all
additive, default-off. Interface settles once PR-E's WF-CV verdict lands.)

**Owner:** local-session (2026-07-15)

Plan of record: `dev/plans/resistance-v2-supply-sketches-2026-07-15.md` (merged #1974).
Motivation: `dev/notes/resist520-armed-run-2026-07-14.md` (false virgins were
load-bearing; binary grade → searchable weight; kill the 5h armed-run wall).

## Shipped

- **PR-B #1975 (MERGED)** — 24 sketch fields appended to `Snapshot_schema`
  (13 → 37): `Res_max_high_{130,260,520}w`, `Res_bars_seen`,
  `Res_hist of int` × 20; computed per day by
  `Snapshot_pipeline.Resistance_sketch` (deque sliding max + close-anchored
  log histogram). Virgin test `breakout >= Res_max_high_520w` bit-equal to v1
  incl. the tie (qc-behavioral rework, parity-pinned). Schema-hash bump —
  **all local warehouses are stale and need rebuild before any snapshot-mode
  run** (dedup-v2 28y top-3000 included). No consumers read the columns yet.
- **PR-C #1979 (MERGED)** — `Resistance_supply` pure module: continuous score
  in [0,1] (proximity-weighted histogram mass saturated at 8 bars; horizon
  floors 0.4/0.25/0.1 when the histogram is blind; virgin = 0;
  Insufficient_history = 0.5 so unknown ≠ virgin). Letter grade derivable
  (score/display split). No consumers.
- **PR-B2 #1982 (MERGED)** — deep-history sketch feed
  (plan §D4). `Resistance_sketch.compute_windowed ~deep_bars ~bars_arr` builds
  a combined weekly prefix over `deep_bars @ bars_arr`, computes the sketch,
  and returns the trailing window slice; `Pipeline.build_for_symbol` gains
  `?deep_bars` (default `[]`, bit-identical) fed ONLY to the sketch columns —
  the 13 warmup-windowed columns stay bit-identical (basis-guard pinned).
  `Build_runner` / both bins split the per-symbol load into
  `(deep = [start − sketch_deep_days, start), window)`; named constant
  `default_sketch_deep_days = 3650` + CLI `-sketch-deep-days`. `Res_bars_seen`
  now reflects true weekly depth (capped 520). No warehouse rebuild in this PR
  (sketch columns still unconsumed). Verify: `dune runtest
  analysis/weinstein/snapshot_pipeline`.
- **PR-D #1983 (MERGED)** — screener wiring, default-off.
  `Resistance_supply.config` gains `[@@deriving sexp]` (ppx_sexp_conv added to
  resistance pps). `Stock_analysis.config` += `overhead_supply` option,
  `callbacks` += `get_sketch`, `t` += `supply`; `analyze_with_callbacks`
  computes `supply` only when armed AND a sketch is present AND a breakout
  price exists. `Panel_callbacks.stock_analysis_callbacks_of_weekly_views`
  gains `?snapshot_cb` and reads the sketch columns
  (`Res_max_high_{130,260,520}w`, `Res_bars_seen`, `Res_hist 0..19`, `Close`)
  at (symbol, view's last date); the bar-list / live CSV path stays
  `fun () -> None` (v1 binary grade). `Screener_scoring.scoring_weights` +=
  `w_overhead_supply : int option [@sexp.default None]`; `_resistance_signal`
  long side uses `round(w * (1 - score))` REPLACING the binary points when
  both weight and supply are present (either absent → binary path
  bit-identical); short-side `_support_signal` untouched.
  `Weinstein_strategy_config`/`.mli`/`weinstein_strategy.mli` += `overhead_supply`
  option; `_stock_analysis_config_for` copies it in. All default-off →
  bit-identical to baseline. Tests: scoring branch (None/None, Some/None,
  score 0 = full w, score 1 = 0, score 0.5 w15 = 8), stock_analysis supply
  gating (armed+sketch → Some; sketch None → None; config off → None),
  Variant_matrix axis `(screening_config weights w_overhead_supply)` expands +
  validates, strategy-config back-compat parse (field absent → None) + Some
  round-trip.

## Next steps

1. **PR-E RAN 2026-07-16 — verdict Inconclusive (promising, unpowered,
   boundary winner; no promotion).** Monotone improvement with positive
   weight (baseline Sharpe .691 → w15 .787 → w30 .860; MaxDD 16.6 → 14.0;
   w30 also wins return); prefer-overhead (w=−15) refuted; w=0 ≈ neutral.
   **The false virgins were LUCK** (path-sizing lottery), not structure.
   Ledger `2026-07-16-resistance-supply-weight-surface.sexp`; note
   `dev/notes/resistance-supply-wfcv-2026-07-16.md`. Warehouse of record:
   `/tmp/snap_top3000_dedup_v3_sketch` (dedup-v3, 37-col, deep feed;
   rebuilt 07-15, 2908 symbols, verified).
2. **Follow-up surface** `[non-blocking]`: extend weight axis {45, 60}
   (winner on boundary) + `min_history_bars`/`insufficient_score` axes;
   same spec pattern
   (`test_data/walk_forward/resistance-supply-weight-BROAD-2000-2026.sexp`).
   sp500 test warehouses still need a rebuild pass when next used
   (schema-hash gate). Container long runs solo.

## Standing constraints honored

- `resistance_lookback_bars` stays OFF in backtest conventions until PR-E's
  verdict; live keeps it armed for text honesty (07-15 priorities §constraints).
- Ranking weight, not an entry gate (trend-context gate class CLOSED).
- Default-off everywhere until a ledger ACCEPT + confirmation grid.
