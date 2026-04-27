# Plan: daily-snapshot streaming — data warehouse for tier-4 release-gate (2026-04-27)

## Status

PROPOSED. **Option 2** of the post-Phase-1 hybrid-tier replanning
(see `dev/notes/hybrid-tier-phase1-results-2026-04-27.md`, #610).
Triggered by the user's 2026-04-27 shower-thought: split the data
pipeline into offline ops-data (per-day cross-sections with all
derived indicators precomputed) + a streaming runtime that mmap's
only ±30 days of snapshots.

This is the architectural pivot needed for **tier-4 release-gate at
N=5,000-10,000**, where every other approach hits a wall.

## The wedge

The matrix fit `RSS ≈ 68 + 4.3·N + 0.2·N·(T−1)` MB makes tier-4
projections clear:

| N × T | Projected RSS | Fits 8 GB? |
|---|---:|:---:|
| 1,000 × 10y | 6.2 GB | ✓ |
| 5,000 × 10y | 30 GB | ✗ |
| 10,000 × 10y | 61 GB | ✗ |

The β = 4.3 MB / loaded-symbol cost is **structural** under the
current design: every symbol's full history sits resident in OCaml
heap (panels + working state) for the whole run. Even with engine-
layer pooling (Option 1) bringing β down to ~1 MB, N=10K × 10y is
still 10 GB.

The pivot: **stop loading full history at all**. Load only what's
needed for "today" + the indicator continuity window (~30 days).

## Goal

At N=10K × 10y: peak RSS **~25 MB** (vs 61 GB extrapolated). 300×
reduction. Approach:

- **Offline ops-data pipeline**: per-symbol CSV → per-day cross-section
  files. Each file contains all loaded symbols' OHLCV + every
  pre-computed indicator value for that single day.
- **Snapshot file format**: mmap-friendly, schema-versioned. Each
  file ~720 KB at N=10K (5 OHLCV + 5 indicators × 10K × 8 bytes).
- **Runtime**: streams snapshots ±30 days for indicator continuity.
  Drops day D−1 once D's strategy work completes.

## Architecture

### Snapshot file format

Per-day file at `data/snapshots/<schema-hash>/<YYYY-MM-DD>.snap`:

```
Magic: 'DSNP' (4 bytes)
Schema version: u32
Symbol_index: array of (offset, length) pairs into a string section
String section: symbol names
Field count: u32
Field metadata: array of (name, type, offset_in_row, byte_size)
Cell array: float64[N × n_fields], C-layout, row=symbol, col=field
```

**Row-major (symbol-major)**: hot path is "for each symbol, read its
OHLCV + indicators once" — contiguous row read. Cross-section reads
also fast (stride n_fields × 8 bytes; cache-line-friendly at typical
n_fields ≤ 12).

mmap-friendly: contiguous flat structure. Runtime
`Bigarray.Array2.map_file` reads the cell array directly.

Schema versioning: indicators registered in `Snapshot_schema.t`; hash
deterministic over (field_name, field_type, …) tuples. New indicator
→ new schema → full corpus rebuild via the offline pipeline.

### Offline pipeline

`bin/build_snapshots.exe` (~600 LOC):

1. Load symbol universe.
2. For each symbol: load its full per-symbol CSV history.
3. For each trading day: open per-day snapshot file; for each symbol
   write OHLCV + every indicator value (computed from the symbol's
   history up to that day); close.
4. Write `manifest.sexp` indexing all snapshots.

Total at N=10K × T=2520: ~1.8 GB of snapshot files. Build time ~5 min
single-threaded; trivially parallel across days. One-time cost per
schema bump.

### Runtime

`Daily_panels.t`:

```ocaml
type t = {
  manifest : Snapshot_manifest.t;
  schema : Snapshot_schema.t;
  cache : (Date.t, Snapshot.t) Hashtbl.t;  (* mmap'd, LRU-bounded *)
  cache_window_days : int;  (* default 30 *)
}

val advance : t -> Date.t -> unit
val read_today : t -> symbol:string -> field:Field.t -> float
val read_history : t -> symbol:string -> field:Field.t -> n:int -> float array
```

Replaces `Bar_panels.t` / `Indicator_panels.t` for runtime reads.
Same `weekly_view_for` / callback construction APIs preserved — just
backed by streaming layer.

Pre-computed weekly indicators (30-week MA, 52-week RS) stored
per-day-per-symbol scalars; `read_today` returns directly, no walk.

### Engine + simulator

`Price_path` doesn't need history beyond today (generates intra-day
paths from today's OHLC range). Stops_runner reads the last N days,
within cache window. Both fit the streaming model.

## Phasing

**Phase A — design + format** (~1 week, 150 LOC). Define
`Snapshot_schema.t`, `Snapshot.t`, file format spec; round-trip test;
schema-hashing logic.

**Phase B — offline pipeline** (~1.5 weeks, 700 LOC). `bin/build_snapshots.exe`
universe-driven writer; reuse existing kernels (`Sma`, `Ema`, `Rsi`,
`Atr`, `Stage.classify`, `Rs.analyze`); manifest + verifier;
incremental rebuild CLI.

**Phase C — runtime layer** (~1.5 weeks, 800 LOC). `Daily_panels.t`
mmap-cache + LRU eviction; `read_today` / `read_history` API;
strategy + screener consume via thin shim preserving existing
callback APIs.

**Phase D — engine + simulator integration** (~1 week, 400 LOC).
Replace `Bar_panels.t` references in `simulator.ml` / `panel_runner.ml`
with `Daily_panels.t`. Engine's per-tick price reads via
`Daily_panels.read_today`; Stops_runner via `read_history`.

**Phase E — validation + tier-4 spike** (~1 week, 150 LOC). Run S&P
500 5y golden, assert metrics within band. Tier-4 spike at N=10,000
× T=10y; confirm peak RSS ~25 MB.

**Phase F (optional) — retire `Bar_panels.t` / `Indicator_panels.t`**.
Once `Daily_panels.t` is canonical, the old panel modules go away.

Total ~3,000 LOC across 5-8 PRs over ~5-6 weeks.

## Catches

- **C1 — indicators must be self-contained per (symbol, day).**
  Anything that depends on dynamic portfolio state (RS vs entry price)
  can't be precomputed. The vast majority of Weinstein indicators are
  static.
- **C2 — schema migration cost.** New indicator → full rebuild. Mitigated
  by parallel build + ~5 min wall.
- **C3 — rebuild dependency on CSV refresh.** New bars require ~2-day
  hot-snapshot rebuild. Incremental builder reads the most recent
  existing snapshot's state + CSV deltas.
- **C4 — schema rigidity.** Strategy changes that need a new derived
  value require a schema bump. Mitigated by hash-based schema
  coexistence (multiple versions in parallel directories).
- **C5 — mmap + Linux page cache interactions.** 30 days × 720 KB =
  22 MB cache window, well within page cache. Explicit LRU eviction
  via munmap.
- **C6 — tooling: ops-data ownership.** `ops-data` agent owns the
  offline pipeline. Agent definition gets a §"Snapshot pipeline"
  section.

## Decisions to make before Phase A

1. **Float64 vs Float32 in snapshots?** Float64 for parity gate;
   revisit if disk constrains.
2. **Snapshot file = single contiguous binary with sexp manifest.**
3. **`data/snapshots/` lives inside `data/`, gitignored;** CI runs
   `build_snapshots.exe` as setup step.
4. **Indicator set lock-in?** Phase A schema enumerates: EMA-50, SMA-50,
   ATR-14, RSI-14, Stage classification, RS line, Macro composite. ~10
   fields per (symbol, day).

## Risks

- **R1 — rebuild loop friction.** ~5 min wall × frequent schema bumps.
  Mitigation: parallel build + incremental.
- **R2 — golden parity at the boundary.** Pre-computed indicator values
  must be bit-equal to runtime-computed. Mitigation: same kernels in
  both places; round-trip test pins this.
- **R3 — panel-mode vs snapshot-mode parity gate.** Add a
  `daily-snapshot-mode` to the loader strategy enum + similar parity
  test. Both layers coexist during Phases C/D.
- **R4 — ops-data scope creep.** Today ops-data fetches CSVs; this
  plan adds derived snapshot pipeline + schema versioning. Mitigation:
  agent definition gets a clear scope section. Or split into `ops-data`
  + new `ops-snapshot`. Single agent for now.

## Relation to Option 1 (engine-layer pooling)

Complementary. Different RSS components:

- **Option 1**: per-tick allocation churn in simulator. β: 4.3 → ~1 MB.
- **Option 2** (this): collapses load floor entirely. β: O(1) constant
  per loaded symbol, independent of T.

Tier-4 at N=10K × T=10y needs both:
- Option 1 alone: 25 GB (still over 8 GB).
- Option 2 alone: 25 MB (fits, but engine wasteful).
- Both: 25 MB + cleaner engine.

Recommended: Option 1 first (smaller, faster payoff), then Option 2.

## What this plan does NOT do

- **Does not change strategy logic.** Pure storage refactor.
- **Does not introduce live mode.** Snapshot pipeline is offline /
  batch.
- **Does not retire CSV ingestion.** Per-symbol CSVs remain source
  of truth; snapshots are derived.

## Triggers to start

- After Option 1 (engine-layer pooling) lands.
- When tier-4 release-gate run at N≥5,000 becomes a near-term
  requirement.
- Phase A (design + format) can start anytime.

## References

- Triggering thought: 2026-04-27 user shower-thought.
- Triggering finding: `dev/notes/hybrid-tier-phase1-results-2026-04-27.md`
- Master plan: `dev/plans/columnar-data-shape-2026-04-25.md`
- Companion: `dev/plans/engine-layer-pooling-2026-04-27.md` (Option 1).
- Superseded: `dev/plans/hybrid-tier-architecture-2026-04-26.md`
  (Phase 2 design no longer fits per Phase 1 results).
