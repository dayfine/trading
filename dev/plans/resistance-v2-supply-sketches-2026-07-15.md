# Resistance-v2 — continuous overhead-supply score on precomputed PIT top-sketches

**Date:** 2026-07-15 · **Track:** resistance-v2 (P0 per
`dev/notes/next-session-priorities-2026-07-15.md` §P0)
**Motivation:** `dev/notes/resist520-armed-run-2026-07-14.md` — the armed
520-bar run showed (a) honest virgin grades tax the mid-tier fat tail
(−55% vs Run D; the false virgins were load-bearing), (b) the binary
grade flip is all-or-nothing where the real question is a searchable
weight, (c) the per-survivor 520-bar weekly walk costs ~5h wall vs
~1.5h unarmed. Resistance-v2 is the arbitration path: precomputed
sketches kill the perf wall, a continuous score replaces the binary
grade, and WF-CV (including weight=0) decides whether the false-virgin
signal was luck or structure.

## What we build (one sentence each)

1. **Sketch columns** in the columnar snapshot warehouse: per symbol-day
   rolling max-high family (520w/260w/130w), a ~20-bucket log-price
   trailing histogram of the 130w window, and a true bars-seen counter —
   computed at build time from FULL symbol history (not the windowed
   warehouse slice).
2. **Supply score**: pure O(1) function of the sketches at a breakout —
   `supply(B) = Σ_{buckets above B} bars × age_decay × proximity` — with
   letter grades still derivable for display back-compat.
3. **Wiring + axis**: default-off score weight in screener scoring,
   expressible as a `Variant_matrix` axis (weight=0 = today's behavior),
   then the WF-CV surface run.

## Design decisions (pinned)

### D1 — No format-version bump; append schema fields

`Snapshot_schema.field` is an order-significant 13-variant list whose
MD5 `schema_hash` gates every reader
(`trading/trading/data_panel/snapshot/lib/snapshot_schema.mli:55-76`).
Appending fields keeps existing column indices, changes the hash, and
auto-rejects stale warehouses via the manifest gate — the documented
extension path. All sketch values are dense per-row Float64, so
`Snapshot_columnar` (`format_version = 1`, `SNAPCOL1`) is untouched.
The priorities doc said "format-version bump"; the codebase's actual
seam is the schema hash — cheaper and equally safe (old warehouses
cannot be silently misread).

New fields (appended, in order):

```
Res_max_high_130w   (* rolling max high over trailing 650 bars  *)
Res_max_high_260w   (* rolling max high over trailing 1300 bars *)
Res_max_high_520w   (* rolling max high over trailing 2600 bars *)
Res_bars_seen       (* true count of bars available before this row,
                       capped at 2600 — honest Insufficient_history *)
Res_hist_00 .. Res_hist_19   (* 20-bucket trailing histogram, below *)
```

24 new fields → schema 13 → 37. Disk: +24 × 8B × ~7,000 rows ≈ +1.3 MB
per symbol, ≈ +4 GB for a top-3000 warehouse — acceptable (local,
never committed). Runtime cost ≈ 0: mmap page-faults only columns
actually read, and these are read once per survivor-Friday.

### D2 — Daily cadence, close-anchored histogram

The format is per-day rows; computing sketches per day (not per week)
avoids cadence/forward-fill bugs. The histogram is anchored at the
row's own close `C`: bucket `k` counts bars of the trailing 650-bar
window whose `[low, high]` range intersects the log-price band
`[C·r^k, C·r^(k+1))`, `r = 2^(1/20)` (~3.5%/bucket), spanning
`[C, 2C)`. This matches the query shape exactly — a breakout at ~`C`
asks "how much supply sits 0–100% above me" — so bucket `k` IS the
proximity band, no re-binning at query time. Supply >2× above the
breakout is proximity-negligible and is dropped (the max-high family
still detects non-virgin at any distance).

Range-intersection counting mirrors the v1 mapper's congestion
accumulation (`analysis/weinstein/resistance/lib/resistance.ml`
`_accumulate_chart`/`_bucket_idx`), not a close-only count.

### D3 — Age decay at horizon granularity

Per-bar age is lost in a histogram. Approximation: the virgin gradient
comes from the max-high family (breakout above 520w max ⊃ virgin-10y;
above 260w ⊃ virgin-5y; above 130w ⊃ virgin-2.5y), and within-130w
supply is age-flat. WF-CV searches only the total weight; if the
mechanism earns a promotion, finer age resolution (a second 65w
histogram) is a follow-up axis, not v1 scope.

### D4 — Honest history at build time (the crux)

The false-virgin defect was starved windows. Sketches computed only
from the warehouse's warmup-windowed bars would reproduce it at the
backtest start (a symbol trading since 1980 looks virgin in 2000).
Therefore the pipeline computes sketch columns from the symbol's FULL
available CSV-store history (or `row_date − 520w`, whichever is
shorter), while snapshot rows still span only the scenario window.
`Res_bars_seen` records the true depth so Insufficient_history is
honest, not window-relative. This is a build-time-only cost (one
extra backward read per symbol; offline).

Point-in-time honesty: every sketch value uses only bars ≤ its row
date. Rolling constructions are causal by definition.

### D5 — Score and grade derivation

Pure module (new, alongside the v1 mapper):

```
supply_score ~config ~sketches ~breakout_price : float
  = Σ_{k : band_low(k) > breakout} hist(k) × proximity(k)
    — normalized by window size to [0, ~1]
quality_of_sketches : ... -> overhead_quality   (* display back-compat *)
```

- `proximity(k)` = configurable decay in bucket index (default
  exponential; all constants in config, never hardcoded).
- Letter `overhead_quality` derivable from score thresholds + max-high
  family (virgin iff breakout > `Res_max_high_520w` AND `Res_bars_seen`
  ≥ min-history) — resolves the live-arming tension: display text stays
  honest regardless of what ranking weight WF-CV picks (score/display
  split, decision #2 of the 07-14 note).
- v1 `Resistance.analyze_with_callbacks` stays untouched (pure, tested);
  v2 is a parallel pure module consuming sketches.

### D6 — Config surface (experiment-flag discipline, R1–R3)

- `w_overhead_supply : int option [@sexp.default None]` in
  `Screener_scoring.scoring_weights` — `None` = no contribution =
  bit-identical today. MUST be `[@sexp.default None]`, NOT
  `[@sexp.option]`, so `Overlay_validator` can target it
  (`screener_scoring.mli:23-48` precedent: `w_virgin_support`).
- Supply-curve constants in a `supply_config` sub-record with no-op
  defaults, nested under the resistance config.
- Axis: `((key (screening_config weights w_overhead_supply))
  (values (0 …)))` — weight 0 in every surface (R2; weight=0 ≡ today).
- No default flip without ledger ACCEPT + confirmation grid (R3,
  `promotion-confirmation.md`).
- When `w_overhead_supply` is armed, the continuous score REPLACES the
  binary `_resistance_signal` points for the long side (not additive —
  two overlapping resistance signals would double-count); weight=None
  keeps the v1 binary path bit-identical.

### D7 — What the WF-CV run answers

The score-weight surface (incl. 0) on the record convention, top-3000
deep window, fold-honest: "were the false virgins luck or structure?"
Positive weight winning = overhead supply is real signal when priced
continuously; weight 0 winning = the 07-14 armed-run verdict stands
(honest virgin ≈ no signal) with fold honesty instead of a single path.
Negative-direction test (penalizing virgins!) is expressible by sign if
the surface warrants. Per `weinstein-faithful-core.md` this is a dial
(numeric threshold/weight on a book rule — the virgin-preference rule
itself is spine-faithful; we are pricing it, not removing it).

## PR sequence (each < 500 lines, builds + tests green)

| PR | Content | Gate |
|----|---------|------|
| A | This plan doc | docs-only, CI |
| B | Schema fields + pipeline sketch computation + full-history feed + unit tests (synthetic bars: known rolling max, histogram counts, bars_seen, warmup edge) | goldens BIT-IDENTICAL after warehouse rebuild (new columns must not perturb existing 13); committed `.snap` fixtures regenerated |
| C | `resistance_supply` pure module: score + grade derivation + parity tests vs v1 `Resistance` on synthetic data (virgin/heavy/insufficient agree) | unit tests |
| D | Strategy/screener wiring: sketch read at `as_of` (O(1) via `Daily_panels.read_today` fields), `w_overhead_supply` weight, config plumbing, axis expansion test | weight=None run bit-identical to record convention (do-no-harm cell) |
| E | (experiment, not code) WF-CV score-weight surface + ledger entry; perf check: armed wall ≈ unarmed | ledger verdict |

Key seams (from code map):

- Build-time computation site: `analysis/weinstein/snapshot_pipeline/lib/pipeline.ml`
  `build_for_symbol` — has full per-symbol bar history at build time.
  Full-history feed (D4) may need `Build_runner`/`Scenario_snapshot_plan`
  to widen the per-symbol bar LOAD window (rows emitted unchanged).
- Query seam being replaced: `weinstein_strategy_screening.ml:251-275`
  `_full_analysis_of_survivor`'s per-survivor
  `Bar_reader.weekly_view_for ~n:resistance_lookback_bars` walk.
- Scoring seam: `screener_scoring.ml:146-153` `_resistance_signal`
  (binary grade→points map v2 replaces when armed).

## Risks / watch

1. **Schema-hash bump invalidates every local warehouse** — rebuild
   (~30-40 min each; the dedup-v2 28y top-3000 warehouse is the big
   one). Sequence PR-B's merge away from any in-flight long run
   (container long runs solo — standing constraint).
2. **Bit-identity gate on PR-B**: existing 13 columns byte-for-byte
   unchanged after rebuild; any drift = builder bug. Same gate that
   protected the S1-S4 columnar migration.
3. **Histogram build cost**: naive O(650) per row × ~7,000 rows ×
   3,000 symbols ≈ 10^10 band intersections — minutes, not hours;
   acceptable offline. Optimize (sliding window) only if measured slow.
4. **Full-history feed** must not leak post-window bars (PIT: only
   bars ≤ row date) and must not change which ROWS are emitted.
5. **Live weekly-review**: keeps `resistance_lookback_bars 520` armed
   for text honesty until v2 lands end-to-end; then live display
   switches to sketch-derived grades (still honest) and the ranking
   weight follows the ledger verdict.

## Standing constraints honored

- `resistance_lookback_bars` stays OFF in backtest conventions until
  the PR-E verdict (07-15 priorities §constraints).
- Not an entry GATE — a continuous ranking weight. The trend-context
  gate class is CLOSED on realized-cohort evidence; any gate-shaped
  variant must first report blocked-winner $ share on the record cohort.
- `mechanism-validation-rigor.md`: PR-E is the real test (WF-CV
  surface), not a proxy screen; verdicts calibrated accordingly.
