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
  - **⚠ MACRO-regime diversity, not just calendar diversity (2026-05-31 lesson).**
    Disjoint sub-windows *within one macro era* are not enough. The
    early-admission grid had FOUR independent post-2009 cells all agreeing
    (ma=13 robust, DSR 1.0) — and a 27y cell adding the **dot-com bust + GFC**
    flat-out reversed it (baseline dominated every variant). **Whenever the data
    permits, one grid cell MUST span a genuinely different macro regime —
    ideally a deep window covering 2000-02 + 2008.** Build the deep data via the
    `fetch-historical-data` skill + `dev/scripts/build_deep_universe.sh` if it
    isn't already present. A grid that never sees a bear-dominated regime can
    only certify a bull-regime artifact.
- **Universe diversity — BROAD vs BROAD only.** The canonical universe **plus ≥1
  different broad universe**: a different PIT composition vintage
  (`top-3000-2019` vs `top-3000-2000`), or a different breadth tier (top-1000 vs
  top-3000). A survivor-biased composition golden is fine here because the bias
  hits baseline and candidate equally — the *relative* comparison still holds
  (see `project_composition_golden_survivor_bias`).

  ⚠ **An earlier version of this clause offered "SP500-510 vs top-3000" as the
  example. That is superseded by `.claude/rules/universe-discipline.md`**
  (user instruction 2026-08-20: never measure performance on sp500; use it only
  for sanity checks and rule validation). Narrowing to a large-cap index is not
  a diversity axis — it is a different experiment, and it silently moves breadth
  while you think you are moving period. PR #2436 shipped a conclusion resting
  on exactly that confound. **The worked example below used SP500 cells and
  stays as historical record; a grid built that way today does not satisfy the
  rule.**

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
