# Promotion confirmation — the robustness grid

A ledger **ACCEPT** from a single walk-forward surface is **necessary but not
sufficient** to flip a mechanism's global default. Before promotion
(`experiment-flag-discipline.md` R3), the candidate must clear a **confirmation
grid**: the same surface re-run across several independent
(period × universe) contexts, with the promotable *value* required to be robust
**across the grid** — not just the DSR winner on the one window that produced
the ACCEPT.

This codifies the 2026-05-30 early-admission episode (below): the 15y DSR-1.0
winner did **not** generalise to an independent window. Promoting it would have
repeated the continuation-combined-axis (#1366) / hysteresis single-window-
overfit failures the whole experiment program exists to prevent.

## When this rule fires

Any time a mechanism has an **ACCEPT** in `dev/experiments/_ledger/` and someone
proposes flipping its default (default-off → on, or changing a no-op default
value). The confirmation grid is the gate between "ACCEPT recorded" and
"promotion PR".

It does **not** fire for: recording an ACCEPT (that's the single surface), or
for keeping a mechanism default-off as an axis.

## The grid

Re-run the *same candidate surface* (the winning value plus its 1-2 neighbours,
e.g. `{7,10,13}` not the full `{5,7,10,13}`) across **≥3 independent contexts**
spanning two axes:

- **Period diversity** — the full-history long window **plus ≥1 disjoint
  sub-window** in a different regime (e.g. an early 2011-2016 window vs a recent
  2019-2023 window). Overlapping windows are NOT independent.
- **Universe diversity** — the canonical universe **plus ≥1 different universe**
  (different breadth or a different point-in-time snapshot, e.g. SP500-510 vs
  top-3000). A different snapshot of the same index counts; a survivor-biased
  composition golden is fine here because the bias hits baseline and candidate
  equally — the *relative* comparison still holds (see
  `project_composition_golden_survivor_bias`).

Minimum viable grid: the long full-history window (gave the ACCEPT) + one
period-disjoint window + one different-universe window = 3 cells. More is better.

Each cell is a `Variant_matrix` surface → `Variant_ranking` (Pareto) +
`Deflated_sharpe`, exactly as in the gap-closing loop. **Confirm index/breadth
golden coverage spans each cell's window first** (`project_gspc_index_golden_2017_floor`):
a data floor silently truncates the test and invalidates the cell.

## The decision rule

For each grid cell, record per-variant Sharpe / Calmar / MaxDD, Pareto-frontier
membership, and whether baseline is dominated.

- **PROMOTE value V** only if V **beats baseline (on the frontier, or
  positive-DSR) in a strong majority of cells AND is never badly dominated in
  any** cell. "Strong majority" = all-but-one for a 3-cell grid.
- The **single-window DSR winner is NOT automatically the promotable value.**
  Pick the value that is robust across the grid (often a neighbour of the
  per-window winners, or their common frontier cell), not the one with the
  highest single-window Sharpe.
- If **no single value** is robust across the grid → record/keep
  **ACCEPT(mechanism)** but **do not promote a value**. Either (a) keep it as an
  axis and gather more evidence, or (b) promote the most conservative robust
  value with an explicit regime-sensitivity caveat in the promotion PR. Never
  promote the headline single-window winner on grid disagreement.

## Worked example — early-admission (2026-05-30)

`stage_config.early_admission_ma_period` (PR #1378), candidate values
`{5,7,10,13}`:

| context (period × universe) | baseline dominated? | per-window best | note |
|---|---|---|---|
| 2010-2026 × SP500-510 (31 folds, gave the ACCEPT) | yes | **ma=10** (Sharpe 0.82, DSR 1.0) | full history |
| 2019-2023 × SP500 (9 folds, diff snapshot) | yes | **ma=13** (0.62); ma=10 ≈ baseline | winner FLIPPED |
| ... third context pins the period ... | | | |

The 15y DSR-1.0 winner **ma=10 did not generalise** (collapsed to ≈baseline on
2019-2023). Only **ma=7** sat on the Pareto frontier of *both* windows; **ma=13**
was the best cross-window aggregate. Per the decision rule, ma=10 is **not**
promotable; the grid is needed to choose between ma=7 / ma=13 (or to conclude no
single value is robust). The mechanism keeps its ACCEPT; the default stays off
until the grid pins a value. Full record:
`dev/notes/early-admission-surface-v2-2026-05-30.md`,
`memory/project_early_admission_mechanism`.

## Relationship to the other rules

- `experiment-flag-discipline.md` — R3 ("no default-on without an ACCEPT") is the
  *gate*; this rule is the *evidence standard* that gate demands before a default
  flips. An ACCEPT lets a mechanism be promoted **eligible**; the grid decides
  **which value, if any** actually flips.
- `experiment-gap-closing` skill — step 7 ("If a winner survives — promote") now
  routes through this grid. The single surface is the loop; the grid is the
  promotion confirmation.
