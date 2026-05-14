# M5.5 axis-3 min_score_override sweep — hypothesis

Date: 2026-05-14
Scenario: `sp500-2019-2023.sexp` (Cell E config, shorts ON)
Design doc: `dev/notes/p3-tuning-sweep-design-2026-05-13.md` (PR #1064)

## Why axis-3 (after axis-1/axis-2/cross all rejected)

- Axis-1 (PR #1079 → #1081): partial CONDITIONAL GO; broad-1000 inconclusive.
- Axis-2 (PR #1083 → #1086): STOP on all three long horizons (catastrophic on 16y).
- Cross-sweep (PR #1084): combined is destructive.

All three rejected axes target **stop distance**. Axis-3 targets a different
mechanism — the **cascade entry gate** (`screening_config.min_score_override`).
It tightens the admission filter (fewer marginal candidates) rather than
widening per-trade stops.

## Cells (5)

Vary only `screening_config.min_score_override`. The default screener uses
`min_grade = C` which corresponds to score ≥ 40. An override replaces the
grade ladder with a numeric floor.

| Cell      | min_score_override | Grade-equivalent          |
|-----------|--------------------|---------------------------|
| baseline  | None (default)     | C (score >= 40)           |
| cell-45   | 45                 | between C and B           |
| cell-50   | 50                 | between C and B (midpoint)|
| cell-55   | 55                 | at grade B threshold      |
| cell-60   | 60                 | between B and A           |

Grade ladder (per screener.ml): A+ ≥85, A ≥70, B ≥55, C ≥40.

## Hypothesis

Tighter score floor → fewer admitted candidates → entry-walk competition
is stiffer because supply is reduced. Expected directional effects:

- Trade count drops monotonically (mechanical: fewer admissions).
- Win-rate may rise as lower-quality cells are excluded.
- Return is ambiguous — fewer trades, each higher-quality.
- MaxDD: unclear — could improve (better selectivity) or worsen (less
  diversification across leaders).

## Falsifiable Δ-thresholds (vs baseline)

Pre-registered, identical to axis-1/axis-2 evaluation:

- **ΔCalmar ≥ +0.05** → winner candidate.
- **ΔCalmar in [−0.05, +0.05]** → neutral, no recommendation.
- **ΔCalmar < −0.05** → reject.

If a winner is identified on 5y, recommend validation on 10y (`decade-2014-2023`)
and 16y (`sp500-2010-2026`) per the lessons from PR #1081 / #1086 (5y wins
that fail to generalize).

## Risk

- Tightening admission may starve the portfolio of candidates during
  bear phases (2020 H1, 2022) when fewer names score well — potential
  drawdown worsening due to under-diversification or cash idling.
- The grade ladder may already approximate a sensible default; large
  jumps (cell-55/60) could over-tighten and degrade returns sharply.
