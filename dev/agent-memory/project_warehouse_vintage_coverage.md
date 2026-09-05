---
name: project_warehouse_vintage_coverage
description: "The split-safe warehouse /tmp/snap_top3000_dedup_v5thin_adj is the 2000-VINTAGE composition (2,908 snaps): covers 94% of top-3000-2000 but only 44% of the 2009 and 32% of the 2019 vintage; the runner silently skips absent symbols, so every 'broad-5y cell B' (top-3000-2019) result ran on ~980 survivor-tilted names. Within-cell A/B valid; levels and cross-window comparisons are not. Measured 2026-09-02."
metadata:
  type: project
  originSessionId: ea0190a3-7ee9-4a89-9d5b-89dfd6df71d3
  modified: 2026-09-03T03:23:31.447Z
---

**Measured 2026-09-02** (`dev/experiments/arc-rerun-2026-09-01/README.md`
§"Fast grid"): exact `(symbol X)` extraction from
`trading/test_data/goldens-custom-universe/composition/top-3000-<v>.sexp`
joined to the warehouse's `*.snap` names. Coverage by vintage: 1998 56%,
2000 **94%**, 2001 72%, 2004 58%, 2005 54%, 2009 44%, 2013 39%, 2019 **32%**,
2023 28%, 2025 26%. All three `/tmp/snap_top3000*` dirs are the same
2000-vintage universe (2,908–2,999 snaps).

**Consequence.** Specs that name `top-3000-2019.sexp` (the "broad-5y cell
B" family: `rt-freshness-broad5y-2026-08-20`, sa2408 `stop-anchor-surface`,
clock-surface cell B, the 2026-09-01 arc ladder) did NOT run on a 3,000-name
2019 PIT universe; they ran on the ~978 names present in both the 2019
composition and the 2000-vintage warehouse — i.e. 2000-era members that
survived to 2019. The runner skips missing symbols silently (no warning in
the cell log).

**What stays valid.** Within-cell A/B (same names both arms) — the
[[project_composition_golden_survivor_bias]] argument. **What does not:**
absolute levels of any 2019-window cell, cross-window comparisons (a 2000
window at 94% vs a 2019 window at 32% are different universes), and any
"breadth" claim about cell B. The broad-5y noise floor (14.65pp) was itself
measured on this subset.

**Fix.** Build vintage-specific warehouses (top-3000-2009, -2019 from the
CSV store / EODHD — `fetch-historical-data` skill + the warehouse rebuild
path, `project_snapshot_format_v2`). Until then, prefer windows whose
vintage the warehouse covers (2000–2004 at 94%) for anything that needs a
level, and label every cell-B number with its effective name count.

Related: [[project_never_measure_on_sp500]], [[project_broad_universe_semantics]],
[[project_pit_survivorship_inflation]].

**AMENDMENT 2026-09-04 — vintage warehouses BUILT.** Fresh from the CSV
store (current adjusted basis by construction), superset universe
(composition + `GSPC.INDX`), build `e4984c5fe`'s `build_snapshots.exe`:
- `/tmp/snap_top3000_2019` — 2,209 snaps (2,208 names of the 2,904-name
  2019 composition ≈ **76%**, vs 32% on the 2000-vintage warehouse), bars
  2018-01-01..2026-09-04, 513 MB, 12 min.
- `/tmp/snap_top3000_2009` — 2,033 snaps (≈ **73%** of 2,780), bars
  2008-01-01.., 891 MB, 21 min.
Missing names (≈700 per vintage) are delisted symbols with no CSV — an
EODHD delisted fetch closes the gap ([[project_eodhd_delisted_unlock]]).
First consumer: `dev/experiments/clock-default-fixed-basis-2026-09-04/`.
Gotcha on the way: [[project_build_snapshots_incremental_clobbers_manifest]].
Levels across the 2000-vintage and 2019-vintage warehouses are still
different universes — never compare a 2019-window level across them.
