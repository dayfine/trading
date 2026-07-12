# Rename-twin dedup pass for the snapshot warehouse builder — 2026-07-12

## Context

Historical PIT universe snapshots contain **rename-twins**: the same
company listed under an old and a new ticker with a near-identical price
series (the vendor duplicates the underlying series onto both symbols).
The record deep run held both legs simultaneously — ~$2.14M of $18.0M
realized PnL (11.9%) is clone legs. Live universe is clean (0 active
twins); the duplication lives in the historical snapshots consumed by the
warehouse builder (`trading/trading/backtest/snapshot_warehouse/`).

Known twin groups (visual audit + a fresh V6 validator run):
NLS/BFX, ISIS/IONS, WLY-triple (JW-A/JWA/WLY), COR/ABC (+COR_old triple),
BKR/BHI, BLL/BALL, SWM/MATV, TXNM/PNM, NVRI/HSC, SJW/HTO, plus the new
candidate ASB/CDX_old. `_old`-suffix symbols (USG_old, COR_old, CDX_old)
are ordinary symbols; they are typically the *dropped* leg because their
data ends earlier.

The V6 validator (`validator_row_checks.ml`) is a *trade-level* heuristic
(same entry/exit date + price + qty within 5%). That is deliberately
weaker and produces false positives (BALL/TAP — Ball Corp vs Molson Coors,
coincidental same-date trades). The builder-side detector here uses the
**stronger** criterion (≥100 overlapping days with >95% near-identical
adjusted_close), so the two cross-check rather than duplicate.

## Approach

A **default-off** rename-twin dedup pass, armed at warehouse build time.

Two parts:

1. **Pure detector** — new `twin_detector` library (core-only, no
   filesystem), fully unit-testable:
   - `Config.t` = `{ enabled; min_overlap_days; match_fraction;
     close_epsilon; prefilter_rel_tol }` with `default` (all thresholds
     routed through config; `enabled` defaults `false`).
   - Input `series = { symbol; data_end; closes : (Date * float) array }`.
   - **Criterion**: two symbols are twins iff they share ≥
     `min_overlap_days` dates AND `> match_fraction` of overlapping dates
     have relative `|a-b|/max(|a|,|b|)` ≤ `close_epsilon`.
   - **Prefilter** (avoid O(n²) full compares over ~3000 symbols): pick
     global anchor dates every `stride = max(1, min_overlap_days/2)`-th
     unique date; at each anchor sort active symbols by close and emit
     candidate pairs only within near-equal runs (consecutive relative
     gap ≤ `prefilter_rel_tol`). stride < `min_overlap_days` guarantees a
     dense ≥`min_overlap_days`-overlapping twin shares ≥1 anchor. Only
     candidate pairs get the full compare.
   - **Grouping**: union-find over verified twin edges → components
     (handles triples).
   - **Survivor**: latest `data_end` (the rename survivor); tie →
     lexicographically smallest. Others dropped. `_old` legs fall out as
     dropped automatically (earlier data_end).
   - Output `report = { config; groups; dropped_symbols }`; `survivors
     report ~all_symbols` = `all_symbols` minus dropped, order preserved;
     `render report` = human-readable text.

2. **Wiring** in `build_scenario_snapshots.ml` (the existing bridge
   executable, already links analysis libs via `scripts.build_runner`):
   load windowed bars per symbol → `series` → `Twin_detector.detect` →
   write `<output-dir>/rename_twin_report.txt` + stderr summary → pass the
   surviving symbol list to `Build_runner.build`. Gated on a
   `-dedupe-rename-twins` CLI flag (default off) plus optional threshold
   flags.

**Rejected alternatives:**
- Copying V6's trade-level heuristic — weaker, false-positive-prone; the
  builder should dedup on the *series*, not on realized trades.
- Bucketed hashing with neighbour emission — boundary-fragile and can
  blow up popular price buckets; the sorted-run prefilter is simpler and
  boundary-robust.
- Excluding the dropped leg only for the overlapping window (keeping its
  non-overlapping tail) — more correct in principle but adds windowing
  complexity; v1 excludes the dropped leg from the snapshot entirely
  (documented limitation in the `.mli`).

## Files to change

- `trading/trading/backtest/snapshot_warehouse/twin_detector.mli` (new)
- `trading/trading/backtest/snapshot_warehouse/twin_detector.ml` (new)
- `trading/trading/backtest/snapshot_warehouse/build_scenario_snapshots.ml`
  (wire the pass in, default-off)
- `trading/trading/backtest/snapshot_warehouse/dune` (new lib target +
  loader deps on the executable)
- `trading/trading/backtest/snapshot_warehouse/test/test_twin_detector.ml`
  (new) + `test/dune`
- `dev/status/rename-twin-dedup.md` (new track)

## Risks / unknowns

- Prefilter assumes reasonably dense daily overlap; extremely sparse
  overlaps could be missed. Documented; real market bars are dense.
- v1 drops the whole losing leg (not just the overlap window) — loses any
  genuinely-independent tail of the dropped ticker. Acceptable for the
  rename-twin case (series are duplicates); documented.
- No warehouse rebuild here — code + tests only; the rebuild + record
  re-pin is dispatcher-owned.

## Acceptance criteria

- `dune build && dune runtest` green, zero warnings.
- Detector: true pair (one survives), near-miss / brief-coincidence pair
  (both kept), triple group, flag-off passthrough — all pinned.
- Every public function documented in the `.mli`; no fn > 50 lines;
  thresholds all config-routed; default-off.

## Out of scope

- Warehouse rebuild, record re-pin, golden re-measurement (dispatcher).
- Any change to `analysis/data/universe/` or core modules.
- V6 validator changes.
