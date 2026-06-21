# Barbell promotion grid — 2026-06-20 PM

**Lever:** barbell = post-hoc daily-return NAV blend of two legs —
FLOOR = `Spy_only_weinstein` (SPY 30wk MA, long/flat, index-timing) +
ENGINE = full Cell-E Weinstein on PIT S&P 500. The 2026-06-02 work
(`project_barbell_on_stocks`, PRs #1434/#1435) showed the blend dominates
**both** pure legs on Calmar in deep (2000-26) and bull (2010-26) regimes, but
was **never taken to a promotion-confirmation grid**. Both 06-19 stop/short P0
levers were NO-BUILD (winner/loser-touching, taxed the fat tail); barbell is the
live lever because it is a **structural diversification layer** that does NOT
touch the long tail (per `weinstein-faithful-core.md` + `edge_is_the_fat_tail`).

**Why a grid (`.claude/rules/promotion-confirmation.md`):** a single-surface win
is necessary-but-not-sufficient to flip a default. The 06-02 result was two
overlapping windows on ONE universe (SP500 PIT-2000). Before recommending a
blend weight for live deployment, the promotable *weight* must be robust across
≥3 independent (period × universe) cells, including a genuinely different macro
regime (a bear-dominated window).

## Grid (4 engine cells × {pure floor, 50/60/70/80% floor, pure engine})

| cell | window | universe | role |
|------|--------|----------|------|
| **A** | 2000-2026 | SP500 PIT-2000 | full history; spans dotcom+GFC = bear-macro ✓ (the "ACCEPT" cell) |
| **B** | 2010-2026 | SP500 PIT-2000 | disjoint **bull** window (period diversity) |
| **C** | 2010-2026 | SP500 PIT-**2010** | different index composition (universe diversity) |
| **D** | 2000-2010 | SP500 PIT-2000 | disjoint **bear-dominated** window (dotcom+GFC, no recovery bull) |

Period diversity: A(full) + B(bull) + D(bear). Macro-regime diversity: A & D
span dotcom+GFC. Universe diversity: B vs C (PIT-2000 vs PIT-2010 composition).

**Known caveat (recorded up front):** universe diversity here is "different PIT
snapshot of the same index" — the *weaker* form the rule permits, not a breadth
jump (top-1000/3000). The /tmp snapshot warehouses were cleared, and N≥1000 deep
in CSV mode risks OOM, so a breadth cell needs a rebuilt snapshot warehouse
(~26min) — deferred to a follow-up confirmation IF the cheap grid shows a robust
weight. The deep top-3000 contiguous run (`project_deep_1998_2026_contiguous`,
realized +1552%) already established the *engine* generalizes to breadth; this
grid's question is narrower: **is the blend WEIGHT robust?**

## Method

- Each leg run by `scenario_runner` (CSV mode, parallel=1) → `equity_curve.csv`
  (`date,portfolio_value` per step). Output root:
  `dev/backtest/scenarios-2026-06-20-235722/`.
- `blend.awk` inner-joins floor+engine on date, blends daily returns at weight w,
  reconstructs NAV, emits total-return / annualized-Sharpe / MaxDD / Calmar /
  Ulcer. Floor 2000-26 → A; floor 2010-26 → B,C; floor 2000-2010 → D.

## Decision rule (`promotion-confirmation.md`)

- **PROMOTE weight V** only if V beats baseline (pure engine) on the
  risk-adjusted frontier in a strong-majority of cells (all-but-one of 4) AND is
  never badly dominated in any cell.
- The single-window Calmar winner is NOT automatically promotable — pick the
  weight robust across the grid (often a neighbour of per-window winners).
- If no single weight is robust → keep barbell as a documented option, promote
  the most conservative robust weight with a regime-sensitivity caveat, or
  promote nothing. Never promote the headline single-window winner on grid
  disagreement.

## Results

_(filled when the run completes — see FINDINGS.md)_
