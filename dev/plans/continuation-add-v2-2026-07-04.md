# Continuation-add v2 — the book's actual trigger (plan, 2026-07-04)

**Status:** PLANNED. Follow-on to the scale-in v1 REJECT (ledger
`2026-07-03-scale-in-v1-surface`) and its participation autopsy + retraction
(#1843/#1846/#1847, `dev/experiments/scale-in-participation-2026-07-03/RESULTS.md`).

## Motivation — v1 conflated two book mechanisms

Re-reading the book (Ch. 3) shows Weinstein has TWO distinct "buy again"
mechanisms, and v1 mixed them into one channel with an invented trigger:

1. **Pullback second-chance (investor ½+½)** — applies to the INITIAL base
   breakout only: ~80% of base breakouts pull back close to the breakout
   point; buy the remaining half there (volume ideally contracting). v1's
   `Pullback` trigger approximates this. Fine, but it is an
   initial-position-completion tactic, not a general add channel.
2. **Continuation buy (Ch. 3 §THE TRADER'S WAY)** — the actual
   press-the-winner mechanism, which v1 never implemented:
   - Stage 2 advance well underway; price **drops back close to the rising
     30-week MA and CONSOLIDATES** (a real multi-week reconsolidation zone —
     Swift Energy: five months after +150%).
   - **Gate: the MA must be clearly trending higher** ("if the MA starts to
     roll over and flatten out, you don't want that stock").
   - **Trigger: a fresh breakout above the TOP of the consolidation's
     resistance zone**, on impressive volume.
   - **Sizing: "buy your entire position when it overcomes its significant
     resistance"** — explicitly because **<50% of continuation breakouts ever
     pull back, "especially true if the stock is going to be a grand-slam
     home run."**

v1's `Early_new_high` ("close above all post-entry closes") was a proxy
invention, not this. The gap-and-go monsters that motivated it never pull
back to entry — but they DO consolidate mid-run near the rising MA, which is
exactly where the book adds, at full size. Faithfulness: continuation entry
mode is an explicit dial in `.claude/rules/weinstein-faithful-core.md`; this
plan pins it to the book's actual definition (Ch. 3 §The Trader's Way).

## What v1's REJECT did and did not test

Per the corrected participation autopsy: v1 tested *½-sizing + breadth
conversion + {pullback-hold, early-new-high} adds*. The ½-sizing is a
confirmed fat-tail tax (WHY 1); the adds fill fine (retraction #1846) but
their triggers are not the book's continuation buy. **The untested shape —
full-size initial entries + book-faithful continuation adds — is a different
mechanism**, aimed squarely at the "press the winner without taxing entry"
half of the idea.

## Build spec (all default-off; experiment-flag-discipline R1/R2)

### 1. Explicit `add_fraction` knob (unblocks full-size entries)

`Scale_in_detector.config` gains `add_fraction : float option
[@sexp.default None]`. `None` → the v1-derived `1.0 −. initial_entry_fraction`
(bit-identical backcompat). `Some f` → the add is sized at `f` of a full risk
unit, still capped by `max_position_pct_long` aggregate notional. The v2
surface sets `initial_entry_fraction 1.0` + `add_fraction (Some 1.0)`
(book: full position at the continuation breakout; the per-symbol cap is the
real ceiling).

### 2. `Consolidation_breakout` trigger (the book's continuation buy)

New `trigger` variant + nested `consolidation_config` (pure detection over
the position's weekly bars, same seam as v1):

| Condition | Param (axis) | Default | Book basis |
|---|---|---|---|
| Consolidation window: last `min_weeks` completed weekly bars before the current bar | `min_weeks` | 4 | "consolidates" — a real zone, not a wiggle |
| Window is tight: `(max_close − min_close) / max_close ≤ band_pct` | `band_pct` | 0.10 | consolidation = range, not trend |
| Window sits near the MA: `min_close ≤ ma × (1 + ma_proximity_pct)` | `ma_proximity_pct` | 0.10 | "drops back close to its MA" |
| Breakout: current close > window max close | — | — | "breaks out anew above the top of its resistance zone" |
| Volume: current bar volume ≥ `volume_ratio_min ×` window avg volume | `volume_ratio_min` | 1.25 | "impressive volume" |
| MA health: existing `require_not_late` gate (Stage2 `late` = MA deceleration) | (existing) | true | "MA must be clearly trending higher" |

The book gives no numeric thresholds — every param above is a searchable
`Variant_matrix` axis, defaults are starting points only.

**Extension-gate interplay (the "Either dead at 0.15" lesson):** the runner's
`extension_max_pct` gate applies to ALL triggers uniformly. A consolidation
breakout close sits structurally at ≈ `(1 + ma_proximity)(1 + band) − 1 ≈ 21%`
above the MA at most (plus any gap). **The v2 surface must set
`extension_max_pct ≥ 0.25`** or the trigger is structurally dead on arrival —
this is called out in the spec sexp, not left to memory.

### 3. Out of scope (unchanged)

- Sibling-position architecture, shared ticker stop, fill routing (#1830–#1837).
- `max_adds` stays 1 for the first surface.
- Live-path add order shape (`StopLimit(close,close)` divergence) — separate
  prerequisite before any PROMOTION; does not affect backtests.

## Surface design (broad-only — user directive: sp500 is not decisive)

Cell: **top-3000 PIT-2000, 2000–2026, 13×2y non-overlapping folds**,
production caps + catstop (mirror `scale-in-base-top3000.sexp`), snapshot
warehouse, fork-per-fold. No sp500 cell.

Variants (≤5 trials for DSR honesty):

1. `baseline` (scale-in off)
2. `cont_add` — `initial_entry_fraction 1.0`, `add_fraction (Some 1.0)`,
   `add_trigger Consolidation_breakout`, `extension_max_pct 0.25`
3. `cont_add_tight` — same, `band_pct 0.06` (tighter zone; probe the axis)
4. (optional) `cont_add_vol` — same as 2, `volume_ratio_min 1.5`

Gate: standard (`Sharpe m=7/13, worst_delta 0.30`) + DSR; verdict + WHYs to
the ledger either way. Instrument add flow from day one (emit/funded/filled
counts — the #1846 lesson: verify the measurement layer before reading
conclusions; trades.csv is now trustworthy post-#1847).

## PR sequence

1. This plan doc (docs-only).
2. `feat`: detector (`consolidation_breakout` + config) + `add_fraction`
   sizing in `Scale_in_runner` + tests. Default-off, bit-identical; full
   3-gate review.
3. Surface spec + WF-CV run + ledger entry (experiment, docs/artifacts).

## Priors to beat (honest framing)

Seven-plus winner-touching levers rejected (`project_edge_is_the_fat_tail`);
v1 itself REJECTED. What is different here: this lever does NOT touch the
initial entry (no ½-sizing tax), adds only into book-defined revealed
strength, and is the book's own trader-mode dial rather than an invented
variant. It is still capital REALLOCATION under a binding cash constraint —
every add displaces a marginal new entry, so the null hypothesis (return-flat)
remains live. The surface exists to find out; no promotion without ACCEPT +
confirmation grid.
