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

- **PR-lever-a `feat/virgin-crossing-readmission` (MERGED #1997)** — virgin-crossing
  re-admission, default-off (lever (a) below). New top-level flag
  `Weinstein_strategy_config.virgin_crossing_readmission : bool
  [@sexp.default false]` (threaded like `overhead_supply`), so it resolves
  through `Overlay_validator` and is a `Variant_matrix`
  `(flag virgin_crossing_readmission)` axis. New pure predicate
  `Resistance_supply.is_virgin ~sketch ~breakout_price` (the v1 `>=
  max_high_520w` test in isolation, finite-guarded, single source of truth for
  virginity — pinned bit-equal to `analyze`'s `Virgin_territory` branch).
  `Stock_analysis.config` += `virgin_crossing_readmission`, `t` +=
  `virgin_readmission` (computed = armed ∧ sketch present ∧ virgin, via
  `get_sketch` — independent of `overhead_supply`; sketch absent → false, no
  fabrication); `is_breakout_candidate` gains a `_virgin_readmission_arm` in the
  OR-chain (Stage-2 ∧ `virgin_readmission`) that bypasses the
  `early_stage2_max_weeks` staleness cut while keeping volume+RS gates. Mirrors
  the `continuation` precedent — no Screener/param threading.
  `_stock_analysis_config_for` copies the flag in. Restores access to the
  crash-recovery "redeemed monster" cohort the `overhead_supply` penalty
  correctly demotes at their supplied breakout but which turns genuinely virgin
  later (AXTI post-mortem). Default-off = bit-identical to baseline. Tests:
  `is_virgin` predicate + agreement-with-`analyze`; readmission arm (stale
  virgin admitted only when armed; fresh unaffected); compute path (armed+virgin
  → true, non-virgin → false, sketch absent → false, off → false); strategy
  back-compat parse (field absent → false) + override resolves; variant-matrix
  flag-axis expansion. Verify: `dune runtest analysis/weinstein/resistance/test
  analysis/weinstein/stock_analysis/test trading/backtest/walk_forward/test`.

- **PR-lever-a-fix `feat/virgin-crossing-hist-empty` (OPEN)** — the 28y w30+vc
  re-run showed the lever NEVER fired on the AXTI redemption it was designed
  for: `is_virgin` requires `breakout >= max_high_520w`, but the sketch's
  `max_high_520w` INCLUDES the current week's own high, so a close-anchored
  breakout is `close <= own high <= max_520w` — structurally unsatisfiable
  except on an exact high-tick tie (AXTI 2026-01-06: close 20.17, max 20.345,
  hist_sum 0). Fix: new `Resistance_supply.is_clear_of_supply ~sketch` (finite ∧
  `bars_seen > 0` ∧ every `hist` bin 0 = zero recent overhead mass: no prior
  weekly bar with high above the current close whose mid-price is at/above it —
  the same histogram mass `analyze` scores);
  `Stock_analysis_supply._virgin_readmission`
  now ORs `is_virgin || is_clear_of_supply`. No new config field, flag unchanged,
  still default-off (R1/R2 untouched). Tests: `is_clear_of_supply` truth table +
  own-week-high divergence; compute-path AXTI shape (max above breakout, hist
  empty) → readmission true, genuine overhead (nonzero bin) → false. 28y w30+vc
  re-run happens post-merge.

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
   28y single-path: w30 +1,991% vs baseline +7,914% (same trade COUNT —
   but per the 07-17 divergence forensic the books differ: 367/1,187
   tickets shared, AXTI = $62.6M of the $64.7M forfeited cohort; note
   `dev/notes/resistance-supply-divergence-forensic-2026-07-17.md`).
   **Decision input #1 DONE (07-18): rolling-start distribution**
   (`dev/notes/resistance-supply-rolling-start-2026-07-18.md`): w30 wins
   9/12 paired starts (median +1.15pp CAGR/yr, MaxDD better on every
   path) but the 3 losses are −5.8..−8.5pp/yr and are exactly the
   post-crash-recovery-window starts (2000/2008/2010) — a systematic
   regime-conditional left tail, not one-draw luck. **Decision input #2
   DONE + all follow-on surfaces DONE (07-19)** — see the promotion
   memo `dev/notes/resistance-supply-promotion-memo-2026-07-19.md`
   (six lenses, options, recommendation = test-then-promote the
   BUNDLE w30 + vc + floors-zero). Ledger 07-19: vc-flag surface
   REJECT (inert 9/13 folds — fold resets under-power rare
   long-memory admission levers); floor-axis surface
   Inconclusive-promising (floors-zero recovers +5.2pp return at
   equal DD, 10/13 Sharpe wins — the floor staircase was the
   redeemed-cohort tax; plain w30 keeps best mean Sharpe 0.860 vs
   bundle 0.827). **Bundle studies DONE (07-20)** — note
   `dev/notes/bundle-studies-results-2026-07-20.md`, ledger
   `2026-07-20-bundle-promotion-studies` (Inconclusive-pending-human):
   sp500 cell CONFIRMS (bundle-w15 .737 / w30 .570 vs .396, both above
   the w-only cell); broad-2011 cell REGRESSES to wash (bundle-w30
   .599±.674 vs baseline .619 — vs w-only's .825±.223: floors are
   regime-dependent); rolling-start REPAIRS the motivating tail
   (2000/2008/2010 starts: w30 −5.8/−6.7/−8.5 → bundle +0.4/+0.2/−1.9
   pp/yr vs baseline; 9/12 wins, median +2.08; worst-start realized
   edge +7.79% = best of all three configs; MaxDD compression kept).
   Human gate options: A promote BUNDLE (recommended — decisive-lens
   argument), B keep axes pending lever (f), C bare w30 (not
   recommended). Do NOT flip any default without the user.
3. **Designed levers (default-off, in order):** (a) virgin-crossing
   re-admission — Stage-2 name crossing its 520w max on volume = fresh
   admissible breakout (AXTI-class access restored; book-faithful) —
   **MERGED #1997 (2026-07-18), default-off, QC 5/5**; next = 28y vc pair
   (in flight, see 2.) then WF-CV as a paired axis with
   `overhead_supply=w30` on the deep grid;
   (b) regime softener `w × (1 − k·index_supply)` — STATE-based modulators
   only (user 07-16: no reversal/bottom calls), k ∈ {0,.5,1}, deep-grid
   testable only; (c) `stale_old_floor` axis {0,.1,.3}; (d) RS-slope
   laggard metric (loser-touching class); (e) supply-located stop
   tightening (insurance class, ext-stop precedent);
   (f) **age-banded histogram (sketch v3)** — designed 2026-07-19 with the
   user. Motivation: supply should decay with AGE (old bag-holders
   capitulate), and separate prior tops should carry separate discounts;
   today's hist is age-blind within 130w and invisible beyond (only the
   3-step horizon-max floors, which the AXTI case showed can be set by a
   name's OWN rally). Design: replace `Res_hist int × 20` with **20 price
   buckets × 4 age bands** (0-26w / 26-78 / 78-130 / 130-520) = 80 int
   columns; decay applied at SCORE time as per-band config weights (an
   Overlay_validator axis family — a decay half-life baked at build time
   would make the axis a warehouse parameter, one rebuild per value, R2
   hostile). Per-bar accumulation separates multiple tops naturally
   (price × age clusters), handles same-price different-era tops, and the
   130-520w band makes old supply MEASURED — horizon floors retire except
   for genuinely blind (insufficient-history) sketches. Cost: schema-hash
   bump + one full warehouse rebuild. Gate to build: lever (c)'s floor
   surface first; build (f) only if the floor verdict shows the mechanism
   wants real age structure (e.g. optimal floors regime-unstable).
   **CODE LANDED 2026-07-19 (PR `feat/resistance-v2-age-bands`, default-off):**
   schema `Res_hist` is now 80 band-major cells (4 age bands × 20 price
   buckets, `Snapshot_schema.n_age_bands`/`n_hist_cells`); the pipeline
   accumulates the 520-week histogram into age bands; `Resistance_supply`
   collapses bands via four `config.band_weight_*` fields
   (`[@sexp.default 1/1/1/0]`, Overlay_validator axes) at score time — default
   weights `[1;1;1;0]` reproduce the pre-lever-f age-blind 130w histogram
   bit-identically (pinned by `test_default_collapse_sums_recent_bands`). The
   warehouse reader detects v3 (20-column) vs v4 (80-column) width and packs
   v3 into the youngest band, so **existing v3 warehouses keep scoring
   identically with NO rebuild** (`hist_bands_of_legacy`). The v4 warehouse
   rebuild is DEFERRED pending the bundle verdict — no rebuild in this PR.
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
