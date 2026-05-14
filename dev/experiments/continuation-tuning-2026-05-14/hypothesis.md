# Continuation-buys parameter tuning — 5y sp500-2019-2023 (2026-05-14)

## Setup

Cell E baseline overlay (`max_position_pct_long=0.14`,
`max_long_exposure_pct=0.70`, `min_cash_pct=0.30`, stage3 force-exit h=1,
laggard rotation h=2) on the 5y `sp500-2019-2023` universe (500 symbols).
`enable_continuation_buys = true` for every cell.

**One-at-a-time sweep** per PR #1082's recommendation: vary one detector
parameter at a time around its ship default, holding the other three at
`Continuation.default_config`.

| Axis | Param | Cells | Default |
|---|---|---|---|
| 1 | `ma_slope_min` | 0.005, 0.01, 0.02 | 0.01 |
| 2 | `pullback_band` width | ±3% [0.97,1.03], ±5% [0.95,1.05], ±8% [0.92,1.08] | ±5% |
| 3 | `consolidation_weeks` | 2, 4, 6 | 4 |
| 4 | `consolidation_range_pct` | 0.05, 0.10, 0.15 | 0.10 |

Total: 8 unique cells beyond `baseline` (which is the shared default point
where all four axes equal their ship value).

## Authority

- `dev/notes/next-session-priorities-2026-05-14.md` §P3
- PR #1078 — Interpretation B detector wiring, default-off.
- PR #1082 — sanity sweep at ship defaults; 2 continuation fires /
  5y / 500 syms → too selective to evaluate; tuning needed.
- `dev/plans/continuation-buys-2026-05-13.md`
- `docs/design/weinstein-book-reference.md` §4.6 Continuation Buys (Ch. 3).

## Hypothesis

The detector's ship defaults are too selective on the 5y / 500-sym Cell E
universe. Loosening any of the four axes should admit more trades; the
question is which axis trades selectivity for fill-rate most efficiently
without trashing per-trade edge.

**Per-axis directional expectations:**

- **Axis 1 (`ma_slope_min`).** Lowering to 0.005 admits flatter-MA late-Stage-2
  names (slope is too lenient — borders on Stage 3). Raising to 0.02 demands
  a steeper rising trend (likely produces 0 fires).
- **Axis 2 (`pullback_band` width).** Narrowing to ±3% only admits textbook
  MA-touches; widening to ±8% admits shallower / deeper retracements.
  Wider band should increase trade count most directly.
- **Axis 3 (`consolidation_weeks`).** Shortening to 2 weeks dramatically
  relaxes the base-length requirement; lengthening to 6 weeks tightens it
  (harder for `(hi-lo)/avg <= 0.10` to hold over 6 bars).
- **Axis 4 (`consolidation_range_pct`).** Tightening to 0.05 (5% range) is
  the strictest pattern-quality gate; loosening to 0.15 admits choppy bases.

**Target headline measure**: continuation-trade count. Each cell's
`total_trades` minus the baseline `total_trades` gives a rough estimate of
the marginal trades admitted by the loosening (or removed by the tightening).
Target band: **5–15 trades / year = 25–75 over the 5y window**.

## Falsifiability

- If **no axis cell pushes trade count above 270** (baseline ~265, so a
  ~5/year admit-rate target requires ≥ 290), the detector is structurally
  too narrow for the universe at any of these single-knob settings. Either
  the cascade gate is binding (0.70 long-exposure cap) or the pattern
  itself is rare on this universe. Recommend combination sweep or retire.
- If trade count blows past **400** at a wide-axis cell, the detector at
  that setting is over-admitting — quality almost certainly tanks.

## Decision criteria

For each axis:
- **Promote-friendly direction:** a cell that lifts trade count into the
  25–75 admit band while preserving Sharpe ≥ 0.55 (baseline 0.59) AND
  MaxDD within +1 pp of baseline.
- **Retire-friendly evidence:** every cell within the tested range either
  fires fewer than ~10 added trades, OR adds ≥ 30 trades but tanks Sharpe
  / inflates MaxDD ≥ 2 pp.

The combined verdict guides:
1. Which axis to promote individually as a default change (if any), OR
2. Which 2–3 axes to combine in a follow-up grid sweep (if no single
   axis individually achieves the admit band), OR
3. Whether to recommend the detector be retired as ill-suited on 5y
   Cell E and revisited only on 10y/16y horizons (where rare patterns
   accumulate enough statistical power).

## Scenario inventory

```
scenarios/baseline.sexp                              -- continuation-on at ship defaults
scenarios/axis1-ma_slope_min-0.005.sexp              -- 0.005 (default 0.01)
scenarios/axis1-ma_slope_min-0.02.sexp               -- 0.02
scenarios/axis2-pullback_band-pm3.sexp               -- [0.97, 1.03] (default ±5%)
scenarios/axis2-pullback_band-pm8.sexp               -- [0.92, 1.08]
scenarios/axis3-consolidation_weeks-2.sexp           -- 2 (default 4)
scenarios/axis3-consolidation_weeks-6.sexp           -- 6
scenarios/axis4-consolidation_range_pct-0.05.sexp    -- 0.05 (default 0.10)
scenarios/axis4-consolidation_range_pct-0.15.sexp    -- 0.15
```
