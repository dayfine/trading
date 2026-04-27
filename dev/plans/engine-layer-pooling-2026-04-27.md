# Plan: engine-layer pooling — reduce per-tick allocation churn (2026-04-27)

## Status

PROPOSED. Companion to `dev/plans/hybrid-tier-architecture-2026-04-26.md`
which was invalidated by the post-Phase-1 results
(`dev/notes/hybrid-tier-phase1-results-2026-04-27.md`, #610). This is
**Option 1** from that recommendation: the smaller, more direct fix
that attacks the wedge identified by Exp B's GC trace.

## The wedge

Per Exp B (#609 / #610): all heap growth happens in the simulator
loop (`fill_done` phase). Panel build + macro init add 4K words
combined; the simulator then promotes ~10 GB cumulative to major
heap (~1.4 GB peak resident).

Per the memtrace (`dev/notes/panels-memtrace-postA-2026-04-26.md`),
the dominant per-tick allocators are `Trading_engine.Price_path`
intra-day path generation: `_decide_high_first_directional` (4 KB
per call × 1,034 sampled), `_sample_standard_normal` (195K sampled),
`_sample_student_t.sum_squares` (85K sampled), `_append_segment`
(40K sampled), `_generate_bridge_segment.generate_points` (46K
sampled), plus `Engine.update_market.(fun)` (20K sampled).

Exp A (#610) confirmed: this allocation is per-loaded-symbol regardless
of activity. Strategy tier hygiene doesn't help; the engine itself
needs the fix.

## Goal

Drop the simulator's per-tick allocation rate by making `Price_path`
/ `Engine.update_market` reuse pre-allocated scratch buffers rather
than allocating fresh records / arrays per call. Target: collapse
the ~1.29 billion words promoted to major heap to <100M (10×
reduction); same engine behavior, parity-tested against existing
goldens.

Expected RSS impact at N=292 T=6y: 1,453 MB → ~600-800 MB. Engine
becomes the cleanest layer in the simulator before any larger
architectural pivot.

## Approach

**Per-symbol scratch records**: each loaded symbol gets one pre-allocated
`Price_path.scratch` buffer at panel-build time. Hot-path `_decide_*`
/ `_sample_*` / `_append_*` mutate it in place.

**Float-array buffers, not records**: replace `path_point list` /
`Daily_price.t list` allocations with mutable `float array` regions.
Bigarray slices for hot reads. Public API surface unchanged.

**Buffer pooling via `Stack`** for transient buffers that aren't
per-symbol. Acquire on entry, release on exit. Fits OCaml's existing
GC story.

## PRs (~600 LOC across 4-5 PRs)

### PR-1: instrument the engine-layer hotspots (~50 LOC)

Add `Gc.stat` counters at `Engine.update_market` entry / exit per
day. Output via the existing `--gc-trace` flag (Phase 1 from #609).
Confirms the hypothesis on real data before refactoring.

### PR-2: per-symbol scratch buffer for Price_path (~250 LOC)

Add `Price_path.scratch` record (mutable fields: `path_points :
float array`, `volatility : float`, etc.). Allocate one per loaded
symbol at panel-build time. Refactor `_decide_high_first_directional`,
`_append_segment`, `_generate_bridge_segment` to mutate scratch in
place.

Parity gate: `test_panel_loader_parity` round_trips golden + new
`test_price_path_buffer_reuse` pinning bit-equality across sequential
calls.

### PR-3: replace float-list intermediates with float arrays (~150 LOC)

Hunt for `float list` / `Daily_price.t list` allocations in
`Price_path` / `Engine.update_market`. Replace with pre-sized float
array buffers allocated once per symbol.

`_sample_standard_normal` and `_sample_student_t` are called per-bar
— their internal accumulation can use a fixed-size buffer. The 195K
+ 85K sampled calls × 1e4 = 2.8B real allocations; collapsing those
to 0 is a large win.

### PR-4: buffer pool for transient workspaces (~100 LOC)

`Engine.update_market.(fun)` and `_sample_student_t.sum_squares`
allocate small workspace buffers per call. Add a `Buffer_pool.t`
holding a Stack of free buffers; acquire on entry, release on exit.

### PR-5 (optional): metrics / wall validation (~50 LOC)

Re-run the matrix at {50, 292} × {1y, 6y} with all four PRs landed.
Update `dev/notes/panels-rss-matrix-post-engine-pool-<DATE>.md` with
the new fit. Expected: β drops from 4.3 to 1-1.5 MB/symbol.

## Out of scope

- **Strategy / screener layer.** Already addressed by Stage 4.5 PR-A/B.
- **Daily-snapshot streaming** (Option 2). Separate plan.
- **Engine algorithm changes.** Buffer reuse is purely memory-layout
  refactor; intra-day path generation logic unchanged.

## Risk

- **R1: stale buffer state across calls.** Mitigation: discipline at
  entry + parity test pinning bit-equality across sequential calls
  with different inputs.
- **R2: parity drift.** Floating-point arithmetic isn't commutative.
  Mitigation: load-bearing parity gate catches divergence in trade
  output.
- **R3: thread safety (future).** If the engine ever runs multi-
  threaded, per-thread scratch is needed. Mitigation: per-symbol
  record carried in the panel state; threads claim a symbol's scratch
  exclusively.

## Phasing

Total ~600 LOC across 4-5 PRs. Each PR mergeable independently;
parity gate is the same across all. Estimated wall: ~1.5 weeks for
one feat-backtest agent.

## Trigger to start

PR-1 (instrumentation) can start immediately. PR-2 onward depends
on PR-1 confirming the hypothesis at the engine layer.

## Relation to daily-snapshot-streaming (Option 2)

| | This plan (Option 1) | Daily-snapshot streaming (Option 2) |
|---|---|---|
| Layer | Engine (per-tick alloc) | Data pipeline (offline + streaming runtime) |
| Scope | ~600 LOC | ~3,000 LOC |
| RSS at N=292 T=6y | ~600-800 MB | ~25 MB |
| RSS at N=10K | ~6 GB | ~25 MB |
| Wall impact | small (less GC pressure) | larger (mmap + decode per tick) |
| Architecture risk | low (refactor within existing modules) | high (new offline pipeline) |

Complementary. Option 1 gets us to a workable N≤2,000 release-gate
quickly; Option 2 is required for tier-4 at N=5K-10K.

## References

- Triggering finding: `dev/notes/hybrid-tier-phase1-results-2026-04-27.md`
- Memtrace: `dev/notes/panels-memtrace-postA-2026-04-26.md`
- Code: `trading/trading/engine/lib/price_path.ml`,
  `trading/trading/engine/lib/engine.ml`
- Reused infra: `trading/trading/backtest/lib/gc_trace.{ml,mli}`,
  `--gc-trace <path>` flag (#609)
