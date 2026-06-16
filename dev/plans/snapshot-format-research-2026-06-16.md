# Snapshot file-format research — what to use for range/column-pruned reads

**Date:** 2026-06-16 · Context: the snapshot warehouse is whole-file sexp
(`snapshot_format.ml`), which forces whole-file decode → the top-3000 memory
ceiling (`dev/experiments/panel-runner-perf-2026-06-16/WINDOW-PRUNE-FINDINGS.md`).
A format that supports **partial decode** (a date range, and only the needed
columns) is the durable fix. This evaluates the options.

## Requirements (the access pattern that must be cheap)

- Data: per symbol, a **dense daily time series**, ~7 000 rows × **13 fixed float
  fields** (OHLCV + Adjusted_close + 7 precomputed indicators), sorted by date.
  ~3 000-10 000 symbols.
- Hot read: for one symbol, a **date-range slice** `[from, until]` (binary-search
  date → return rows), of **only the few columns** the backtest touches (close,
  adj_close, OHLC, volume — ~6 of 13). The universe scan does this for
  ~1 000-3 000 symbols every backtest week.
- Write: **offline, write-once** (the snapshot pipeline), read many.
- Files are **internal, machine-only, never committed** (`.gitignore` line 109;
  0 `.snap` tracked) — so **no interop/tooling requirement** and **no committed
  corpus to migrate**.
- Repo ethos: one toolchain, minimal deps (deliberately Python-free, Core/Jane
  Street based). A heavy C++ FFI dep is a real cost.

The two prunes we need — **range** (window-prune) and **column** (the per-row
overhead/extra-field waste) — are the same thing a **memory-mapped columnar
(struct-of-arrays / "splayed") layout** gives for free: page-fault only the
columns + row-ranges actually read.

## The public pattern (this is well-trodden, not novel)

Memory-mapped columnar storage with a sorted key index is the standard design for
exactly this workload:
- **kdb+ splayed / partitioned HDB** — each column a separate on-disk file,
  mmap'd, page-faulted only when a query touches that column/partition. The
  canonical time-series HDB pattern.
- **Apache Arrow IPC / Feather** — columnar, zero-copy mmap, range/column slices.
- **NumPy `.npy`** — header (dtype, shape) + contiguous block; trivially mmap'd.
- **Parquet** — columnar + compressed + row-groups, but pages must be *decoded*
  (no zero-copy mmap); better for storage/interchange than a hot random-range
  read path.

So we are choosing an *instance* of a known pattern, not inventing one.

## OCaml library support (researched 2026-06)

| option | OCaml support | fit |
|---|---|---|
| **`Bigarray.map_file`** (stdlib `Unix`/`Bigarray`; Core `Bigstring`) | **Mature, zero-dep, in-tree.** True mmap; `Array1.sub` is a zero-copy view. | ✅ ideal substrate |
| **Arrow / Feather** | **Immature.** `LaurentMazare/ocaml-arrow` = C++ libarrow FFI, stuck on Arrow 4-5 (current is 21); `mtelvers` fork updated to 21 (still C++ dep); `mtelvers/arrow` = a young **pure-OCaml** reimpl (single maintainer, unproven). None clearly on opam. | ⚠️ heavy/young for an internal artifact |
| **Parquet** | Same immature Arrow bindings; no zero-copy mmap. | ❌ wrong access pattern |
| **`bin_prot`** (Jane Street, already a dep) | Mature, fast — but **whole-value** (no random access). | ✓ for the small header/manifest only |
| **HDF5 / capnp / SQLite** | Bindings exist (C deps / heavier per-read). | ❌ overkill for a fixed float matrix |

**Takeaway:** Arrow's value is *interop + tooling*, which we don't need (internal,
never-committed, no Python/external consumer). Its OCaml on-ramp is a C++ libarrow
dependency (build complexity + version skew) or an unproven pure-OCaml lib —
a poor trade for this repo. `Bigarray.map_file` is stdlib and gives us exactly the
mmap zero-copy slicing we need.

## Recommendation

**Implement a minimal custom columnar (splayed / struct-of-arrays) mmap format on
`Bigarray.map_file`. Do NOT adopt Arrow/Parquet; do NOT invent anything novel** —
it is a minimal instance of the standard memory-mapped-columnar pattern, tailored
to our fixed 13-float schema. ~150-250 LOC.

### Layout (per symbol; or a sharded multi-symbol file)
```
header:  magic | format_version | schema_hash | n_rows | field list | per-column byte offsets
dates:   int32[n_rows]        # epoch-days, sorted  -> binary-search the range
col_0:   float64[n_rows]      # struct-of-arrays: one dense array per field
col_1:   float64[n_rows]
...                            # (column-major = each field contiguous)
```
- **Range read**: binary-search `dates` for `[from, until]` → `Array1.sub` a
  zero-copy slice of *each requested column* over `[lo, hi]`. O(log n) seek +
  O(range) copy-free.
- **Column read**: only the columns the caller asks for are touched → the OS
  page-faults just those (kdb-style). The 7 precomputed indicator columns the
  backtest doesn't read are never paged in.
- Together these collapse the cache working set from ~2.95 GB (whole files) to
  **≈ needed_cols × hot_range × symbols ≈ ~130 MB** for top-3000 → fits the
  current 7.8 GB container with huge margin, no RAM bump, no thrash.
- Reuse `bin_prot` for the small header/manifest; `Bigarray.map_file` for the
  payload; versioned by the existing `schema_hash` (old local files auto-rejected).

### Why this is low-risk to land
- No committed corpora to migrate (0 `.snap` in git). Migration = bump
  `schema_hash`, rewrite `Snapshot_format` read/write + the `Daily_panels` cache
  to mmap-slice, regenerate local warehouses (`build_snapshots.exe`, ~30-40 min
  local), verify goldens **bit-identical**.
- Zero new external/toolchain deps; stays within Core/stdlib.
- Self-documenting fixed layout; the format already self-versions.

### When to reconsider Arrow
Only if we later need to **share** snapshot data with external/Python tooling or
want off-the-shelf dataframe ops on it. For the internal backtest hot path, the
custom mmap format wins on dep-cost, control, and exact-fit.

## Implementation plan (for a fresh session)

A self-contained, golden-gated migration. Each step builds + `dune runtest` green
before the next. Whole thing is ~1-2 focused sessions.

- **S0 — Spike (de-risk the substrate).** Prototype a standalone reader/writer for
  ONE symbol: write `header + int32 dates + float64 columns`, `Bigarray.map_file`
  it back, binary-search a date range, `Array1.sub` a column slice. Assert the
  round-tripped float64 values are **bit-identical** to the source and the slice
  is zero-copy. Confirms endianness, mmap lifetime (`Bigarray` free / fd close),
  and the slice mechanics before touching production code. (~throwaway exe.)
- **S1 — `Snapshot_format` v2 (columnar mmap).** New write path emitting the
  splayed layout (header w/ field byte-offsets · sorted `int32` date index · one
  dense `float64[n]` per field), `bin_prot` header/manifest, **bump
  `schema_hash`**. New read path returns a handle exposing
  `read_range ~symbol ~from ~until ~fields` over the mmap. Clean cut — no need to
  keep v1 readable (no committed corpora); old local files auto-reject on the
  hash. Keep the existing `Snapshot.t` row API as the boundary so callers don't
  change.
- **S2 — `Daily_panels` range/column-aware cache.** Replace whole-file load
  (`_load_symbol_file`) with: open+mmap the symbol once (cheap), serve
  `read_history`/`read_today`/`read_field_history` by slicing the mapped columns
  over the requested `[from,until]` ∩ fields. The "cache" becomes mmap handles +
  OS page cache (page-faulted on demand) rather than decoded full arrays — this is
  where the ~2.95 GB → ~130 MB drop happens. Keep the LRU only for handle count.
- **S3 — Writers.** Update `build_snapshots.exe` / `build_scenario_snapshots.exe`
  to emit v2.
- **S4 — Regenerate + verify (the gate).** Rebuild the local warehouses
  (`snap_top3000_2000` etc., ~30-40 min local). Run the SP500-5y + custom-universe
  **goldens — must be bit-identical** to pre-change. ANY drift = a column/range
  slice bug; fix before merge. Also regenerate any committed `.snap`-format test
  fixtures.
- **S5 — Tighten reads (now that partial decode exists).** Reduce the over-read:
  `weekly_bars_for`/`daily_bars_for` read only the needed range instead of the
  fixed 3653-day window; consider whether the backtest can read the precomputed
  `Stage`/`RS_line`/`Macro_composite` columns directly (the "summary numbers"
  path) for a further win. Each behind goldens.

**Acceptance:** goldens bit-identical; the **top-3000 26y 2000-26 matrix runs in
the 7.8 GB container at `cache≤1024` with no thrash and completes in ~hours** (the
proof the ceiling is gone). Then rerun it for the full-breadth factor-lens and
re-do the H1/H2/H3 analysis on top-3000 (the top-1000 result is the regime-shape
stand-in; top-3000 is needed for the net-edge sign — see
`dev/experiments/rolling-start-matrix-t1k-2000-2026/ANALYSIS.md`).

**Risks / watch:** (1) float64 bit-identity vs the old sexp decode — the gate; (2)
mmap fd/handle lifetime (use `Bigarray` free; cap open handles); (3) the
`Daily_panels` cache redesign is the substantive change — keep the row-level API
stable so the ~dozen call sites don't move; (4) endianness (pin LE in the header).

**Relationship to RAM:** this is the durable, no-RAM fix. The fast unblock remains
bumping Docker RAM to 12-16 GB (cache=4096 holds the whole-file working set) — do
that if you need a top-3000 lens *before* this lands. The two are independent.

## Sources
- [OCaml Arrow bindings (LaurentMazare/ocaml-arrow)](https://github.com/LaurentMazare/ocaml-arrow)
- [Parquet/Arrow in OCaml, 2025 state (incl. mtelvers pure-OCaml reimpl)](https://www.tunbury.org/2025/09/17/parquet-files/)
- [OCaml `Bigarray.map_file` (memory-mapped files)](https://www.cs.cornell.edu/courses/cs3110/2020sp/manual-4.8/libbigarray.html)
- [kdb+ splayed tables (columnar mmap, column-on-demand)](https://code.kx.com/q/kb/splayed-tables/)
- [kdb+ memory mapping methodology](https://kx.com/blog/memory-mapping-in-kdb/)
