# Barbell promotion grid — FINDINGS (2026-06-20 PM)

**Verdict: PROMOTE the 70/30 (floor/engine) barbell weight** as the robust
risk-adjusted blend — with a flagged breadth-confirmation follow-up before live
capital. This is the **first lever to PASS a promotion grid** in the recent arc;
contrast the 8 `edge_is_the_fat_tail` rejections (laggard, force-exit,
stage2-ma-hold, late-flag, macro-trim, harvest-rotate, short-sleeve,
vol-scaled-stop). The barbell passes precisely because it is a **structural
diversification layer that does NOT touch the long tail** — a post-hoc capital
allocation between two whole strategies, not a winner-/loser-touching knob.

See `PLAN.md` for grid design + decision rule. Legs run by `scenario_runner`
(CSV mode, current code), blended by `blend.awk`. Output:
`dev/backtest/scenarios-2026-06-20-235722/`.

## The grid (4 engine cells; SPY-only floor per matching window)

| cell | window | universe | engine ret%/MaxDD% | floor ret%/MaxDD% |
|------|--------|----------|--------------------|-------------------|
| **A** | 2000-26 | SP500 PIT-2000 | 1570 / 36.8 | 387 / 18.8 |
| **B** | 2010-26 | SP500 PIT-2000 | 173 / 20.3 | 239 / 18.8 |
| **C** | 2010-26 | SP500 PIT-2010 | 245 / 18.9 | 239 / 18.8 |
| **D** | 2000-10 | SP500 PIT-2000 | 364 / 36.8 | 40 / 18.3 |

Period diversity: A(full) + B(bull) + D(bear). Macro-regime: A & D span
dotcom+GFC. Universe diversity: B vs C (PIT-2000 vs PIT-2010 composition).
Floor (SPY 30wk long/flat) does its job in the lost decade D: +40% at 18% MaxDD
vs SPY buy-hold's ~−10%/55%DD — index-timing dodged both crashes.

## Calmar (annualized return / MaxDD) — the risk-adjusted frontier metric

| w_floor | A | B | C | D | min-cell |
|---------|------|------|------|------|------|
| 0.00 (pure engine) | 0.296 | 0.303 | 0.403 | **0.435** | 0.296 |
| 0.50 | 0.369 | 0.451 | **0.462** | 0.417 | 0.369 |
| 0.60 | 0.398 | **0.452** | 0.460 | 0.414 | 0.398 |
| **0.70** | **0.437** | 0.451 | 0.457 | 0.413 | **0.413** |
| 0.80 | 0.433 | 0.449 | 0.453 | 0.407 | 0.407 |
| 1.00 (pure floor) | 0.319 | 0.400 | 0.400 | 0.183 | 0.183 |

## Sharpe (annualized)

| w_floor | A | B | C | D | min-cell |
|---------|------|------|------|------|------|
| 0.00 | 0.801 | 0.535 | 0.656 | **1.011** | 0.535 |
| 0.50 | 0.801 | 0.683 | 0.750 | 0.877 | 0.683 |
| 0.60 | 0.776 | 0.695 | 0.748 | 0.812 | 0.695 |
| **0.70** | 0.739 | 0.699 | 0.738 | 0.729 | **0.699** |
| 0.80 | 0.692 | 0.696 | 0.720 | 0.626 | 0.626 |
| 1.00 | 0.575 | 0.669 | 0.669 | 0.379 | 0.379 |

## Decision-rule application (`promotion-confirmation.md`)

- **70/30 beats pure-engine Calmar in 3 of 4 cells** (A 0.437>0.296, B
  0.451>0.303, C 0.457>0.403; D 0.413<0.435). 3/4 = "strong majority"
  (all-but-one of 4). ✓
- **Never badly dominated.** The one loss (D, isolated bear decade) is a ~5% gap,
  not a collapse. ✓
- **70/30 has the highest worst-cell Calmar (0.413) AND worst-cell Sharpe
  (0.699)** of any weight — the most regime-robust point. The per-cell Calmar
  winners disagree (A→0.70, B→0.60, C→0.50, D→0.00), so the single-window winner
  is NOT the promotable value; 70/30 is the robust pick, exactly as the rule
  prescribes.
- Convergent evidence: matches the 06-02 finding (70/30 beat both legs in each
  regime, `project_barbell_on_stocks`) and the ETF-lab barbell 70/30 (#1426).

## WHY it works (the transferable mechanism)

Genuine diversification, not less-risk-taking. Cell A: pure-engine annret ≈10.9%
at 36.8% MaxDD; 70/30 annret ≈7.6% at 17.4% MaxDD. Return fell 30% but MaxDD fell
53% — **DD falls faster than return because the two legs are imperfectly
correlated** (the engine's deepest drawdowns are partly offset by the SPY-timing
floor sitting in cash). That asymmetry is the free lunch; it raises Calmar. The
barbell does not tax the fat tail — the engine's winners run fully inside the
engine leg; the floor only reallocates *capital weight*, never trims a position.

**Regime dependence (the nuance):** the benefit concentrates where the two legs
have *comparable return* (bull cells B, C → blending is near-free DD reduction,
Sharpe AND Calmar both up) and where the full-window engine DD is high relative
to return (A). It vanishes in the **isolated bear decade D**, where the engine's
own crash-dodging machinery (stage3-force-exit h=1 + laggard-rotation h=2)
already delivers Sharpe 1.01 — the floor can only dilute an already-defended
book. Reading: the barbell and the engine's internal crash defense are partial
substitutes; you get the most marginal value from the floor in mixed/bull
regimes, least in a pure grinding bear (where the engine alone already wins).

## Caveats (honest, per `mechanism-validation-rigor.md`)

1. **Universe-diversity leg is thin.** 3 of 4 cells share SP500 PIT-2000; only C
   uses a different composition (PIT-2010) — and that is a *snapshot variant*,
   not a breadth jump (top-1000/3000). The rule permits it, but the cross-
   universe evidence rests largely on one cell. **Follow-up before live capital:**
   one breadth-confirmation cell (top-1000 or top-3000 deep) via a rebuilt
   snapshot warehouse (~26min; /tmp warehouses were cleared). The engine itself
   is already known to generalize to breadth (`project_deep_1998_2026_contiguous`,
   realized +1552%); this confirms the *weight* transfers to breadth.
2. **Absolute engine returns drifted up vs 06-02** (cell A 1570% vs the doc's
   918%) — current code carries 18 days of fixes (lazy market-state #1481,
   cash-floor #1556, stale-exit #1487). MaxDD reproduced (36.8 vs 37.3). The grid
   is **internally valid** (all legs current code); absolute numbers are not
   comparable to the old writeup, only within-grid.
3. **No `enable_barbell` config flag exists.** The barbell is a post-hoc
   portfolio overlay across two strategy runs, not a single-strategy config axis.
   "Promotion" here = a documented deployable recommendation (run capital as a
   70/30 floor/engine blend), not a default flip in `Weinstein_strategy.config`.
   Building the overlay as deployable, rebalanced code is the next engineering
   step if live deployment is pursued.

## Recommendation

Adopt **70/30 (SPY-timing floor / Cell-E engine)** as the robust barbell weight
for risk-adjusted deployment. It is the regime-robust Calmar/Sharpe maximizer and
the first lever to clear a promotion grid. **Gate before live capital on** (a) a
breadth-universe confirmation cell, and (b) building the rebalanced overlay as
real code with a default-off enable flag per `experiment-flag-discipline.md`.
