# Next-session priorities — 2026-06-21

**Supersedes** `next-session-priorities-2026-06-20-PM.md`. Check main CI green
first (`.claude/rules/session-rampup.md`). The 2026-06-20 PM session ran the
**barbell promotion grid** — the lever the 06-20-PM doc named as P0 NEXT after
both stop/short levers were NO-BUILD.

## What happened 2026-06-20 PM — barbell grid PASSES (first lever to clear a grid)

Full record: `dev/backtest/barbell-grid-2026-06-20/FINDINGS.md` (+ PLAN.md,
specs, `blend.awk`). Legs run by `scenario_runner` (CSV mode, current code);
outputs `dev/backtest/scenarios-2026-06-20-235722/` (gitignored).

**Verdict: PROMOTE 70/30 (SPY-timing floor / Cell-E engine) as the robust
risk-adjusted barbell weight.** 4-cell grid (A=2000-26 full/bear-macro,
B=2010-26 bull, C=2010-26 diff-index-composition, D=2000-2010 bear decade):

- 70/30 **beats pure-engine Calmar in 3/4 cells** (A 0.437>0.296, B 0.451>0.303,
  C 0.457>0.403), loses only narrowly in D (0.413<0.435), and has the **highest
  worst-cell Calmar (0.413) AND Sharpe (0.699)** of any weight → the regime-robust
  pick. Per-cell winners disagree (0.70/0.60/0.50/0.00) so the single-window
  winner is NOT promotable; 70/30 is. Matches 06-02 + ETF-lab 70/30.
- **Why real:** genuine diversification, not less-risk-taking. Cell A: annret
  −30% but MaxDD −53% (legs imperfectly correlated) → Calmar UP. Does NOT tax the
  fat tail (engine winners run fully inside the engine leg; floor only reweights
  capital). This is why it passes where 8 tail-touching levers were rejected.
- **Regime nuance:** benefit concentrates in bull/mixed (B,C: Sharpe+Calmar both
  up) and high-DD full window (A); **vanishes in the isolated bear decade D**,
  where the engine's own stage3-exit+laggard machinery already gives Sharpe 1.01
  — the barbell and the engine's internal crash defense are partial substitutes.

## P0 NEXT — gate #1 CLOSED 2026-06-21; gate #2 (build overlay) remains

1. **Breadth-universe confirmation cell — DONE 2026-06-21, 70/30 CONFIRMED.**
   Record: `dev/backtest/barbell-breadth-2026-06-21/FINDINGS.md`. Ran two breadth
   cells (2000-26, vs `floor-2000-deep`): top-1000 PIT-2000 (2×) and top-3000
   PIT-2000 (6×). **70/30 beats pure-engine Calmar in EVERY cell** (SP500 .437,
   top-1000 .225, top-3000 .311 — all > their pure-engine). In the engine's real
   breadth universe (**top-3000**), the Calmar/Sharpe optimum lives in **w∈[0.6,0.8]**
   and **70/30 is the robust central pick** (Sharpe 0.652 ≈ peak; Calmar 0.311
   within 5% of the 0.80 peak; blend cuts DD 43%→19% at ~flat return). Diagnostic
   exception: at **top-1000** (the engine's documented trough, `project_factor_lens`)
   the optimum collapses to pure-floor — so **deploy the engine leg only on an
   edge universe (SP500/top-3000), never top-1000**. Warehouse-build recipe:
   `build_scenario_snapshots.exe` (single-dash flags) → `scenario_runner
   --snapshot-dir`, cache=1024, parallel=1.
2. **Build the barbell overlay as deployable code.** Today's blend is post-hoc
   (`blend.awk` over two equity curves). There is no `enable_barbell` config.
   To deploy live, build a rebalanced 70/30 floor/engine capital overlay behind a
   default-off flag per `experiment-flag-discipline.md` (R1 default-off, R2
   searchable axis, R3 no default-on without the ACCEPT this grid provides).
   This is real engineering (two-strategy capital allocation), not a screen.

## Secondary (unchanged from 06-20-PM, lower priority than the barbell gates)

- **Short-supply screen** [~76min deep run]: loosen `short_min_price 17→5` (and a
  1.0 variant), re-run the long-short deep cell, decompose shorts by exit-year +
  win/loss distribution. Question: does a bigger short book stay per-trade-favorable
  AND finally fire in 2008? Yellow flag: 2008 whipsaw loss suggests name-level
  Stage-4 short timing is the real failure — loosening supply may just lose more.
  If it still loses in 2008 → "name-level shorts aren't a dependable bear hedge;
  use the regime/index overlay (= the barbell) instead" and this line closes.
  Recipe in `next-session-priorities-2026-06-20-PM.md` §Queued.

## Guardrail (unchanged)
Live class = **structural diversification layers** (barbell ← now PASSED;
regime-gating overlays; offsetting legs that actually pay). NOT winner/loser-
touching levers (`edge_is_the_fat_tail`, 8 rejections) and NOT entry/cascade/
short-pick selection (dead 5×). The barbell passing CONFIRMS the guardrail's
prediction: the diversification-layer class is where the gains are.

## State
- 1 commit this session (docs/research): barbell grid artifacts +
  `blend.awk` + FINDINGS/PLAN + this doc. No code change (post-hoc blend; the
  deployable overlay is P0 NEXT #2 above).
- Barbell ACCEPT now exists for the 70/30 weight (this grid) — satisfies
  `experiment-flag-discipline.md` R3's ACCEPT prerequisite for a future
  default-on, pending the breadth-confirmation cell.
- v2 /tmp snapshot warehouses were CLEARED; rebuild for any breadth/top-N run.
