# Track: resistance-v2 — continuous supply score on precomputed PIT top-sketches

## Status

IN_PROGRESS

## Last updated: 2026-07-17

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

- **PR-live-path #1989 (MERGED)** — the live
  bar-list path (`Stock_analysis.callbacks_from_bars`) now gets a real
  sketch, closing the PR-D documented gap. New `Live_resistance_sketch`
  adapter (`snapshot/gen/lib`) bridges a symbol's FULL in-memory daily
  history to a `Resistance_supply.sketch` via
  `Snapshot_pipeline.Resistance_sketch.compute_windowed ~deep_bars:[||]`,
  extracting the analysis-Friday (last) day; `bars_seen` honestly reflects
  a shallow (<520w) fetched window rather than fabricating history.
  `Weekly_snapshot_generator` computes it from `Bar_reader.daily_bars_for`
  when `overhead_supply` is armed and injects the `get_sketch` thunk via
  `callbacks_from_bars` + `analyze_with_callbacks` (the two steps
  `Stock_analysis.analyze` wraps — no `Stock_analysis` signature change,
  so its ~18 callers are untouched); threads `overhead_supply` into the
  per-stock analysis config. Display split: `_resistance_grade` renders
  the v2 grade + continuous score ("`<quality> (0.NN)`") when
  `analysis.supply` is `Some`, else the v1 label. All gated by the SAME
  default-off `overhead_supply` config → byte-identical output when
  disarmed. Ranking already wired via PR-D's `w_overhead_supply` (left
  off here, so arming display alone doesn't change candidate selection).
  Tests: `Live_resistance_sketch` direct unit tests (known cells / shallow
  honesty / empty=None); generator display gating (default=v1 label,
  armed=v2 score). Verify: `dune runtest trading/weinstein/snapshot/gen`.

## Next steps

1. **CONFIRMATION GRID 3/3 — mechanism ACCEPT (2026-07-17).** Home curve is
   a concave hump peaking w≈45 (.691→.897→.772 at 60); sp500 cell confirms
   on a different universe+geometry (w15 .623 / w30 .552 vs .396); 2011
   period cell confirms (w30 .825 vs .619, fold-σ collapse .566→.223).
   Cross-grid robust value **w=30** (3/3, never dominated); w=15 the
   conservative alternative. Ledger
   `2026-07-17-resistance-supply-confirmation-grid.sexp`; note
   `dev/notes/resistance-supply-grid-2026-07-17.md`.
2. **PROMOTION DECISION — HUMAN-GATED (R3), with the terminal-wealth flag.**
   28y single-path: w30 +1,991% vs baseline +7,914% (identical 1,187
   trades, better DD 29.0 vs 32.3) — the penalty excludes the
   crash-recovery monster cohort (AXTI forensic: correct score at entry;
   virgin at $11-17 later but stale-inadmissible). Promotion needs the
   rolling-start terminal-wealth distribution lens, and plausibly the
   virgin-crossing lever (below) built first. Do NOT flip any default
   without the user.
3. **Designed levers (default-off, in order):** (a) virgin-crossing
   re-admission — Stage-2 name crossing its 520w max on volume = fresh
   admissible breakout (AXTI-class access restored; book-faithful);
   (b) regime softener `w × (1 − k·index_supply)` — STATE-based modulators
   only (user 07-16: no reversal/bottom calls), k ∈ {0,.5,1}, deep-grid
   testable only; (c) `stale_old_floor` axis {0,.1,.3}; (d) RS-slope
   laggard metric (loser-touching class); (e) supply-located stop
   tightening (insurance class, ext-stop precedent).
4. dedup-v2 warehouse deletable (v3 certified bit-identical:
   `scenarios-2026-07-16-131756` baseline = Run D to 13 decimals).

## Standing constraints honored

- `resistance_lookback_bars` stays OFF in backtest conventions until PR-E's
  verdict; live keeps it armed for text honesty (07-15 priorities §constraints).
  With PR-live-path merged, arming `overhead_supply` in the live weekly-review
  config additionally switches the displayed resistance grade to the v2
  sketch-derived grade+score (still default-off; disarmed = v1 label, unchanged).
- Ranking weight, not an entry gate (trend-context gate class CLOSED).
- Default-off everywhere until a ledger ACCEPT + confirmation grid.
