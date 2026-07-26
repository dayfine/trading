# Sketch v5 — per-symbol weekly side-table (sparse resistance storage)

Status: DESIGN DRAFT (2026-07-20, user-initiated). Build gate: none — user
queued it unconditionally; priority rises if the (f) sp500 surface shows the
age lever matters.

## Motivation (the user's observation, 2026-07-20)

The resistance information content per symbol is just the trailing weekly
bars — ~520 `(week, price)` points for the 10y window, ~12KB, growing ~52
points/yr. v4 instead materializes, for EVERY trading day, an 80-cell
histogram of those same bars re-anchored to that day's close:
80 cols × ~6,800 rows × 8B ≈ 4.3MB/symbol — **~350× redundant** (consecutive
days share almost all weekly bars; only the anchor moves). Consequences hit
in production the same day the redundancy landed:

- top-3000 v4 warehouse = 8.4G (v3 3.3G) → does not fit the 7.8G Docker VM;
  broad (f) surface thrashed at ~2h/fold (D-state) and was killed. The panel
  memory ceiling (`project_panel_runner_memory_ceiling`) is back at v4 scale.
- Bucket geometry (20 rungs of 2^(1/20), the 2× cutoff) and the weekly-
  aggregation cadence are BAKED at build time — each is a warehouse
  parameter, R2-hostile, one rebuild per candidate value.

## Design

### Storage

Per symbol, next to `SYMBOL.snap`: a `SYMBOL.weekly` side-file holding the
condensed weekly series over the full (deep-fed) history:

```
weekly_entry = { week_end_date : date; mid : float; high : float }
```

- ≤ 520 + deep-feed entries per symbol (~12-20KB); top-3000 total ~35-60MB.
- Append-only semantics; incremental rebuild appends new weeks.
- Same manifest + schema-hash discipline as `.snap` (side-table format hash
  folded into the manifest so a stale side-table fails loudly).
- The daily `.snap` panel DROPS: `Res_hist × 80`, `Res_max_high_{130,260,520}w`,
  `Res_bars_seen` (all derivable) → schema back to ~13 columns, warehouse
  back to ~v1/v3-core size. One schema-hash bump.

### Read path

`Resistance_sketch_reader` (or a v5 sibling) takes the row's date + close C:

1. Binary-search the side-table for the window ending at the row's day
   (lookback = config, default 520w; deep feed just means more entries).
2. Walk ≤520 entries: for each with `high > C`, bucket
   `mid ∈ [C·2^(k/n), C·2^((k+1)/n))` and age-band by `row_date − week_end`.
3. Emit the same `Resistance_supply.sketch` record as today (bands matrix +
   max-highs + bars_seen) — scoring module unchanged.

Cost: ~520 compares + a few hundred float ops per evaluated candidate.
v1's runtime sin was CSV/bar LOADING per candidate, not arithmetic; the
side-table is one mmap'd read per symbol, cached.

### What becomes config (full R2)

- band boundaries (today 26/78/130/520w — baked in #2015's pipeline)
- bucket count + width (today 20 × 2^(1/20) — baked since #1975)
- proximity cutoff (today 2× — baked)
- lookback horizon (today 520w — baked)
- weekly-vs-daily aggregation stays baked (the one build-time choice left).

### PIT correctness invariants (carry from v3/v4 — pin in tests)

- Current partial week included as of the row's day (v3 parity requires it:
  the "own high sets the max" behavior in the AXTI forensic).
- Weekly mid = (H+L)/2 of the weekly bar; high = raw weekly high — raw
  (unadjusted) basis, matching v1 resistance mapper.
- Virgin test `breakout >= max(high over 520w)` bit-equal to v3/v4 incl. tie.
- Dedup (rename twins) operates before side-table build, as for `.snap`.

### Certification

1. Reader-level: v5 sketch record == v4 row cells on sampled (symbol, day)
   grid (property test over the sp500 warehouse).
2. Surface-level: re-run the (f) sp500 surface spec on a v5 warehouse — all
   rows must reproduce the v4 numbers (same discipline as v4's
   bands-1/1/1/0 cert row vs the v3 bundle cell).
3. Size + throughput: warehouse total, fold wall-time vs v3 baseline.

### PR chain (each < 500 lines)

1. Side-table format + codec + writer (`Snapshot_pipeline` emits both during
   transition; flag-gated).
2. Reader + `Resistance_sketch_reader` v5 path (width/presence detection:
   side-file present → v5; else v4/v3 columns — three-generation reader).
3. Certification tests + warehouse rebuild + surface re-cert.
4. Retire dense columns (schema bump, drop 84 cols) once cert green.

## Open questions

- Live path: weekly CSV path currently returns `get_sketch = None`; v5 could
  make the live sketch cheap (side-table from live weekly bars) — in scope?
- Keep `.snap` hist columns during a deprecation window, or hard-cut?
- Does `Daily_panels` cache account the side-tables (tiny, but should be
  under the cap for cleanliness)?
