# Next-session priorities — 2026-06-16 (PM2 / late continuation)

**Supersedes** `next-session-priorities-2026-06-16-PM.md`. Check main CI green first.

---

## PROGRESS — P0 format-v2 underway (2026-06-16 PM3)

**S0 + S1 are DONE.** The snapshot-format-v2 columnar-mmap project has started.

- **S0 (de-risk spike) — PASS.** Confirmed the substrate on this exact
  container/toolchain (throwaway spike, not committed):
  - `Core_unix.map_file fd ~pos:(Int64.of_int byte) kind c_layout ~shared:false
    [| n |]` then `Bigarray.array1_of_genarray` gives a **zero-copy** view —
    **and `pos` does NOT need to be page-aligned** (offsets 32096 / 256096 mapped
    fine). This removes the alignment worry; columns can sit back-to-back.
  - float64 round-trips **bit-identical including `Float.nan`** (via
    `Int64.bits_of_float`); `Array1.sub` over a binary-searched `int32` date
    index is correct.
- **S1 (the v2 format module) — MERGED as PR #1624** (`b4c20fae`). New module
  **`Snapshot_columnar`** (`.ml`/`.mli`) + sibling **`Snapshot_columnar_codec`**
  (byte/mmap primitives) in `trading/trading/data_panel/snapshot/lib/`,
  **alongside** the unmodified v1 `Snapshot_format`. Layout: `magic "SNAPCOL1"` |
  header (`format_version`,`n_rows`,`n_fields`,`schema_hash`,`symbol`) | sorted
  `int32` epoch-days (1970 epoch) | one dense `float64[n]` column per schema
  field. API: `write` (single-symbol+single-schema validated, sorts by date) ·
  `open_reader`/`close`/`with_reader` · `read_all` · `read_range ~from ~until`
  (inclusive; empty/inverted → `Ok []`) · `read_with_expected_schema`
  (schema-hash gate). 13 tests pin every contract incl. nan bit-identity, bad
  magic, range boundaries. 3 gates green (CI + structural + behavioral score 5).

**NEXT = S2** — `Daily_panels` range/column-aware cache
(`analysis/weinstein/snapshot_runtime/lib/daily_panels.ml`): replace the
whole-file `_load_symbol_file` decode with mmap handles that slice the mapped
columns over `[from,until]` ∩ fields via `Snapshot_columnar`. This is where the
~2.95 GB → ~130 MB working-set drop happens. Then **S3** (writers
`build_snapshots` / `build_scenario_snapshots` emit v2), **S4** (regenerate
warehouses + **goldens bit-identical = the gate**), **S5** (tighten over-reads).
Plan detail: `dev/plans/snapshot-format-research-2026-06-16.md` §S2-S5.

---

## P0 — Snapshot format v2 (columnar mmap): the durable fix that unblocks top-3000

**This is the headline project for a fresh session.** Plan + research:
`dev/plans/snapshot-format-research-2026-06-16.md` (decision, layout, OCaml
library survey, step-by-step S0-S5, acceptance gate). Background:
`dev/experiments/panel-runner-perf-2026-06-16/WINDOW-PRUNE-FINDINGS.md`,
`memory/project_panel_runner_memory_ceiling`.

**Why:** the snapshot warehouse is whole-file sexp → whole-file decode → the
top-3000 26y backtest can't fit the 7.8 GB container at any cache (~2.95 GB
working set, thrashes). The fix is a **memory-mapped columnar (splayed) format**
on `Bigarray.map_file` (stdlib, zero-dep) — gives range-prune + column-prune
together → working set ~2.95 GB → **~130 MB** → fits at `cache≤1024`, no thrash,
no RAM bump, and speeds every broad-universe run.

**Decision already made (don't re-litigate):** implement a **minimal custom
columnar mmap format**, NOT Arrow/Parquet (OCaml Arrow bindings are immature —
C++ libarrow FFI or a young pure-OCaml reimpl; interop we don't need for an
internal, never-committed artifact). Not a novel invention — it's the standard
kdb-splayed / Arrow-IPC / npy mmap pattern, minimally instanced for our fixed
13-float schema. ~150-250 LOC + the `Daily_panels` cache redesign.

**Steps (full detail in the plan doc):** S0 spike (mmap round-trip, bit-identity)
→ S1 `Snapshot_format` v2 writer/reader (bump `schema_hash`) → S2 `Daily_panels`
range/column-aware mmap cache → S3 writers (`build_snapshots`) → S4 regenerate
warehouses + **goldens bit-identical (the gate)** → S5 tighten the over-reads.
**Acceptance:** goldens bit-identical AND the top-3000 26y 2000-26 matrix runs in
7.8 GB at `cache≤1024`, completes in ~hours.

**Low-risk to land:** no committed `.snap` corpora to migrate (0 in git); the
existing `schema_hash` auto-rejects stale local files; all changes golden-gated.

## Fast alternative (independent of P0)

If you want a top-3000 lens **before** the format work: **bump Docker RAM to
12-16 GB**, then rerun the top-3000 2000-26 matrix at `cache=4096` (the #1614
`Gc.compact` fix makes it fit) → ~2-6 h. This holds the whole-file working set in
RAM; it does not need the format change. The two paths are independent — RAM is
the quick unblock, format v2 is the durable fix.

## The payoff (what either path unblocks)

Rerun the **top-3000 2000-26 rolling-start matrix** → re-run the **factor-lens
H1/H2/H3 causal analysis on top-3000**. The top-1000 result
(`dev/experiments/rolling-start-matrix-t1k-2000-2026/ANALYSIS.md`,
`memory/project_factor_lens_regime_governs_edge`) established the **regime-shape**
(H1 dodge-correction r=−0.79 CONFIRMED; H3 entry-supply DEAD — regime governs the
edge, not entry-selection). top-3000 is needed for the **net-edge sign** (top-1000
realized edge was all-negative — the edge needs top-3000 breadth / the fat tail).

## State as of this handoff (2026-06-16 session)
- **All PRs merged, main green, 0 open PRs.** Shipped: #1614 (`Gc.compact`), #1617
  (README top-line numbers, regenerable), #1618/#1620/#1621 (docs/lens/memory),
  branch cleanup (27 stale branches).
- **Lens done** on top-1000 (#1620). **README numbers** on main (1998-12-22 →
  2026-06-12: SPY BAH +888.9%, BRK-B +1132.4%, SPY-Weinstein +408%, Sector-ETF
  +528.9%; both Weinstein trail B&H on this bull window — expected).
- Matrix NOT running (intentionally paused for the format/RAM decision above).
- New memories: `project_panel_runner_memory_ceiling`,
  `project_factor_lens_regime_governs_edge`.

## Deferred / unchanged
- Initiative B (margin / long-short Phase 5) — still oversight-gated, the profit
  lever, unchanged from prior handoffs.
- A2 per-start DD projection bug — still open (affects DD columns, not edge/CAGR).
