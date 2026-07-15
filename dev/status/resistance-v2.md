# Track: resistance-v2 — continuous supply score on precomputed PIT top-sketches

## Status

IN_PROGRESS

## Last updated: 2026-07-15

## Interface stable

NO

(PR-D will extend `Stock_analysis.config`/`callbacks`/`t`,
`Screener_scoring.scoring_weights`, and `Weinstein_strategy_config` — all
additive, default-off.)

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
- **PR-C #1979 (OPEN)** — `Resistance_supply` pure module: continuous score
  in [0,1] (proximity-weighted histogram mass saturated at 8 bars; horizon
  floors 0.4/0.25/0.1 when the histogram is blind; virgin = 0;
  Insufficient_history = 0.5 so unknown ≠ virgin). Letter grade derivable
  (score/display split). No consumers.
- **PR-B2 #1982 (OPEN)** — deep-history sketch feed
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

## Next steps

1. **PR-D — screener wiring (default-off)** `[blocking: local session shepherds]`
   Design (pinned during 07-15 session):
   - `Resistance_supply.config` gains `[@@deriving sexp]` (add
     `ppx_sexp_conv` to resistance lib pps).
   - `Stock_analysis.config` += `overhead_supply : Resistance_supply.config
     option [@sexp.default None]` (None = never compute — bit-identical).
   - `Stock_analysis.callbacks` += `get_sketch : unit ->
     Resistance_supply.sketch option`; `analyze_with_callbacks` fills new
     `Stock_analysis.t` field `supply : Resistance_supply.result option`
     when config armed AND sketch present.
   - `Panel_callbacks.stock_analysis_callbacks_of_weekly_views` builds
     `get_sketch` from `Snapshot_callbacks.read_field` (24 reads at
     (symbol, as_of = last bar date), O(1) each; NaN row → None →
     Insufficient handled inside Resistance_supply). Bar-list constructor
     (`Stock_analysis.callbacks_from_bars`, live CSV path) sets
     `get_sketch = fun () -> None` — live report stays v1 until a follow-up.
   - `Screener_scoring.scoring_weights` += `w_overhead_supply : int option
     [@sexp.default None]` (MUST be `[@sexp.default None]`, NOT
     `[@sexp.option]` — Overlay_validator serialization rule, see
     screener_scoring.mli w_early_stage2 precedent). `_resistance_signal`
     long side: when `Some w` AND `a.supply = Some r`, points =
     `Float.round_nearest (w × (1 − r.score))`, REPLACING the binary
     virgin/clean points (not additive — double-count). Either None → binary
     path bit-identical. Short-side `_support_signal` untouched.
   - `Weinstein_strategy_config` += `overhead_supply :
     Resistance_supply.config option [@sexp.default None]`;
     `_stock_analysis_config_for` copies it into the stock-analysis config.
   - Tests: scoring branch (None/None, Some/None, Some/Some incl. score 0 =
     full w and score 1 = 0 points); stock_analysis supply computation gated
     by config; axis-expansion test `((key (screening_config weights
     w_overhead_supply)) (values (…)))` through Variant_matrix/
     Overlay_validator; weight-None do-no-harm (existing goldens unchanged).
   - Split D1 (stock_analysis + panel_callbacks) / D2 (scoring + strategy
     config + axis) if > 500 lines.
2. **PR-B2 — deep-history feed (plan §D4)** — SHIPPED (#1982). Pipeline
   `?deep_bars` + `Build_runner` deep-load split landed; existing 13 columns
   bit-identical (basis-guard pinned).
3. **Warehouse rebuild** (after B2): dedup-v2 top-3000 28y + sp500 test
   warehouses — schema-hash gate rejects the old ones. Container long runs
   solo (no concurrent agent dispatches).
4. **PR-E — WF-CV score-weight surface** (incl. weight = 0 = today), record
   convention, fold-honest answer to "were the false virgins luck or
   structure". Ledger entry either way. Perf acceptance: armed wall ≈
   unarmed (~1.5h not ~5h).

## Standing constraints honored

- `resistance_lookback_bars` stays OFF in backtest conventions until PR-E's
  verdict; live keeps it armed for text honesty (07-15 priorities §constraints).
- Ranking weight, not an entry gate (trend-context gate class CLOSED).
- Default-off everywhere until a ledger ACCEPT + confirmation grid.
