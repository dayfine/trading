---
name: split-safe-resistance-basis
description: Resistance sketches were split-blind (raw basis); fixed hash-gated 2026-07-28; CLMB dropped from 07-24 picks on honest grading; backtest impact re-run still owed
metadata: 
  node_type: memory
  type: project
  originSessionId: 3f2dbf6c-5e5e-4297-9d15-8571a3c1ccb4
---

Resistance supply machinery measured RAW prices while warehouses store raw
OHLC + separate Adjusted_close — any split inside the 520w lookback mis-scaled
overhead (forward splits hid supply, reverse splits fabricated it). Found via
user chart-review of CLMB (4:1 split 2026-03-23; "Clean (0.12)" grade despite
a real $25-34 adjusted supply wall). Issue #2133 defect 2.

**Fix (#2145, merged 2026-07-28, hash-gated):**
- `Snapshot_pipeline.Adjusted_basis.to_adjusted_basis` shared rescale helper.
- Side-tables now built adjusted-basis; `Weekly_sidetable.format_hash` NEW =
  `128e4c1e…` (adjusted), old kept as `format_hash_raw_basis`.
- Reader accepts both hashes: Raw ⇒ anchor at `Close` (bit-identical legacy),
  Adjusted ⇒ anchor at `Adjusted_close`. Unknown hash fails loud.
- Live from-bars path (`compute_windowed` / `live_resistance_sketch`) rescales
  inputs unconditionally.

**Regrade result (07-24 v4 record `dev/weekly-picks/790d23a06/`, PR #2150):**
CLMB (rank 2, score 86) dropped ENTIRELY; PH entered; 19 others bit-identical;
validator zero findings. Weekly-review warehouse rebuilt adjusted-basis
(3,173/3,173).

**Still owed:** backtest blast radius — v5thin (+ other backtest warehouse)
side-tables are STILL raw-basis/old-hash, deliberately bit-identical; the
promoted resistance-v2 bundle's evidence used split-blind grades. Re-run =
rebuild side-tables split-safe (pinned worktree per sweep-hygiene) +
record-convention re-run + compare before any claim/golden changes. Also open:
support_floor wick-vs-close anchoring knob (#2133 item 3); validator
`split_in_window` flags ~30 historical picks (SMCI, ANET, FCEL, SHAZ×4,
AGPU×4…) whose grades were basis-suspect at pick time.

Ops law reinforced: weekly warehouse rebuild = `build_snapshots.exe
-csv-data-dir data -output-dir dev/data/snapshots/weekly-review
-universe-path <Pinned superset: universe + 15 context syms>
-benchmark-symbol GSPC.INDX -start-date 2024-06-01 -end-date <as-of>`
(full, non-incremental, to refresh side-tables). Pinned grammar:
`(Pinned ( ((symbol X) (sector "S")) ... ))`. [[leverage-dawn-drift-root-cause]]
