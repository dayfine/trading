---
name: project_snapshot_format_v2
description: "snapshot-format-v2 columnar-mmap project — S0/S1 done, S2-S5 next; reusable Core_unix.map_file facts"
metadata: 
  node_type: memory
  type: project
  originSessionId: 527a3825-6180-4e33-9073-07795b6b2ddb
---

The durable fix for the top-3000 memory ceiling
([[project_panel_runner_memory_ceiling]]): replace the whole-file sexp
snapshot format with a memory-mapped columnar (splayed) format so reads
prune by date-range AND column. Plan + steps:
`dev/plans/snapshot-format-research-2026-06-16.md` (S0-S5, acceptance gate).
Decision locked: **minimal custom mmap format, NOT Arrow/Parquet** (OCaml
Arrow bindings immature; internal never-committed artifact needs no interop).

**Status 2026-06-16:**
- **S0 (de-risk) PASS.** Reusable facts for S2+:
  - `Core_unix.map_file fd ~pos:(Int64.of_int byte) Bigarray.float64
    Bigarray.c_layout ~shared:false [|n|]` → `Bigarray.array1_of_genarray` is a
    **zero-copy** view, **and `pos` need NOT be page-aligned** (verified
    32096/256096) — columns can sit back-to-back, no padding.
  - float64 round-trips **bit-identical incl. `Float.nan`** (compare via
    `Int64.bits_of_float`, not `Float.equal`); `Array1.sub` over a
    binary-searched `int32` epoch-days index is correct.
  - Use `Stdlib.Bytes.set_int64_le`/`set_int32_le` (Core shadows `Bytes`).
- **S1 MERGED (#1624, `b4c20fae`).** New `Snapshot_columnar` (.ml/.mli) +
  sibling `Snapshot_columnar_codec` (byte/mmap primitives), in
  `trading/trading/data_panel/snapshot/lib/`, ALONGSIDE unmodified v1
  `Snapshot_format`. Layout: magic "SNAPCOL1" | header(format_version,n_rows,
  n_fields,schema_hash,symbol) | sorted int32 epoch-days (1970) | dense
  float64[n] per schema field. API: write (single-symbol+schema validated,
  sorts by date) / open_reader / close / with_reader / read_all /
  read_range / read_with_expected_schema. (reader maps columns once at open;
  has schema_hash/symbol/n_rows accessors.)
- **S2 MERGED (#1626, `85635d3f`).** `Daily_panels`
  (`analysis/weinstein/snapshot_runtime/lib/`) is now **format-detecting**: v2
  (magic) → mmap path via `Snapshot_columnar.read_range`; v1 sexp → existing
  decode fallback (keeps current v1 warehouses + goldens green until S4).
  Eviction = byte budget + open-handle cap (closes fds). New `Daily_panels_backing`
  module. Public API unchanged. v2≡v1 behavioral parity pinned.
- **S3 MERGED (#1629, `424348733`).** `Build_runner` (used by both
  `build_snapshots.exe` + `build_scenario_snapshots.exe`) now writes v2 via
  `Snapshot_columnar.write`. New `Snapshot_io` (`data_panel/snapshot/lib`) =
  format-detecting whole-file reader (`is_columnar_file` +
  `read_with_expected_schema`); `snapshot_verifier` reads through it (v1+v2).
  `bar_reader.of_in_memory_bars` writer LEFT v1 (in-memory synthetic warehouses;
  follow-on). Note: merged via `--admin` (BEHIND by docs-only commits, CI green).
- **S4 PROVEN 2026-06-16/17 (after the single-mmap fix #1631).** top-3000
  2000-26 backtest over v2 warehouse at `SNAPSHOT_CACHE_MB=1024` runs CLEAN (RSS
  ~0.3-1.5 G, 6.8 G free, no thrash/OOM/Rosetta-crash) where v1 OOM'd. Memory
  ceiling GONE. Shipped arc: #1624 S1 / #1626 S2 / #1629 S3 / #1631 single-mmap.
  **PAYOFF DELIVERED 2026-06-17:** ran the top-3000 2000-26 rolling-start MATRIX
  (38 starts, parallel 2, stride 255, GSPC.INDX, cache=1024, ~10.3h, 0 errors)
  over the v2 mmap warehouse — the run the OOM ceiling blocked. Factor-lens
  H1/H2/H3 → H1 REPLICATES (r=-0.74), MTM edge flips +1.93%/60.5%-beat but realized
  edge negative every start. Full result in
  [[project_factor_lens_regime_governs_edge]] + `dev/experiments/rolling-start-matrix-t3k-2000-2026/ANALYSIS.md`.
  Remaining (next session): convert other warehouses (2011, 1998_2026) to v2; S5
  (marginal — single-mmap already page-faults per column); cleanup PR (remove v1 —
  needs bar_reader flipped to v2 first, it still writes v1).
- **(historical) S4 detour — correctness PROVEN, memory-on-Rosetta BLOCKED then FIXED.**
  - **Correctness PASS:** converted the real v1 warehouse `/tmp/snap_top3000_2000`
    → v2 `/tmp/snap_top3000_2000_v2` (throwaway tool): **3015/3015 symbols
    bit-identical** (dates + every IEEE-754 value bit, via
    `Snapshot_columnar.read_with_expected_schema`). v2 is SMALLER (1.2 G vs
    1.9 G — columnar raw float64 beats sexp text). The v2 warehouse is left on
    disk for the next proof attempt.
  - **Memory proof BLOCKED by Rosetta, NOT by real memory.** Running the
    top-3000 backtest (`rolling_start_eval`, which ALWAYS forks per start via
    `fork_pool` — the memory-safe path) over the v2 warehouse at
    `SNAPSHOT_CACHE_MB=1024` died: `rosetta error: mmap_anonymous_rw mmap
    failed, size=1000` → child SIGTRAP. Diagnosis: the v2 reader maps **~14
    mmaps per open symbol** (1 dates + 13 columns) × up-to-256 handle cap ≈
    **3840 VMAs**; `vm.max_map_count=262144` (fine for Linux) so the wall is
    **Rosetta's own translator bookkeeping** (this container is x86-64 ELF under
    Apple-Silicon Rosetta) exhausting in the forked child. Real memory was
    healthy (1.2 G reclaimable RSS, 6.7 G available — NOT an OOM).
  - **THE FIX (S4-blocker / informs the reader design): map each `.snap` as ONE
    mmap, not 14.** Rework `Snapshot_columnar`'s reader to map the whole file
    once as a `Bigstring` and read cells via `Bigstring.get_int32_le` (dates) /
    `get_int64_le |> Int64.float_of_bits` (values) by byte offset — 256 VMAs
    instead of 3840, Rosetta-safe under fork. Column-prune is preserved (pages
    fault per column accessed). Zero-copy typed Array1 views were never used
    downstream (rows are copied into `Snapshot.t` anyway), so nothing is lost.
    Alternative: run the proof on native (non-Rosetta) hardware — the
    per-column design is fine off-Rosetta. (Cf. `project_n3000_covid_oom`
    "Rosetta VMTracker slab" + the laggard fork-per-fold note.)
- **NEXT = single-mmap reader fix (above), then re-run S4 memory proof:** regenerate local
  warehouses (`build_*_snapshots`, ~30-40min) → SP500-5y + custom-universe
  **goldens MUST be bit-identical** (drift = v2 encode/slice bug) → the
  ~2.95GB→~130MB drop LANDS + re-try top-3000 26y at cache≤1024. Then S5 (tighten
  over-reads), then cleanup removing v1 `Snapshot_format` + `Decoded` fallback.
  Fast alternative independent of S4: bump Docker RAM 12-16GB → rerun top-3000
  at cache=4096.

Gotcha hit this session: CI `dune fmt (check only)` uses a different
ocamlformat than the container (docstring line-wrap skew,
[[project_ocamlformat_version_skew]]) — keep docstring lines well clear of
the 76-80 col margin so both versions wrap identically.
