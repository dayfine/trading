# Hypothesis — P3 follow-up combined-axis continuation sweep

(See `report.md` for results + verdict. This file is the pre-run
hypothesis, preserved for the record.)

PR #1091's one-at-a-time continuation-buy sweep produced two best
single-axis movers, both tying at 5y Sharpe 0.61 (vs 0.59 ship-default
baseline / 0.56 continuation-off):

- `consolidation_weeks = 2`
- `consolidation_range_pct = 0.15`

This follow-up combines them and validates the combined cell on both 5y
(`sp500-2019-2023`) and 16y (`sp500-2010-2026`) windows.

## Pre-run predictions

| Cell | Expected 5y Sharpe | Expected 16y Sharpe | Confidence |
|---|---|---|---|
| `combined` | 0.62-0.68 (stacks) | 0.65-0.75 | low — extrapolation |
| `baseline-anchor` | 0.59 (matches #1091 baseline) | 0.69 (matches recent runs) | high |
| `continuation-off-anchor` | 0.56 (matches PR #1082 off) | 0.71 (matches recent runs) | high |

## Things we expected to learn

1. **Stacking** — does combined > best-single (>0.61), confirming the
   two axes are complementary?
2. **Cross-window survival** — does the 5y signal hold up on 16y?
3. **Slot-budget bind** — PR #1091 found trade counts pinned at 261-266
   across all 8 single-axis cells under Cell E's
   `max_long_exposure_pct=0.70`. The combined cell trade count will
   measure whether the slot bind dominates the detector tuning.

## Rules we committed to in advance

Per `memory/project_m5-5-tuning-exhausted.md`: single-window 5y wins
without 10y+16y validation gates are not actionable. The 16y row decides
whether to ship the tuning or reject it.
