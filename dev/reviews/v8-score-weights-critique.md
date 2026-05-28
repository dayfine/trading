# v8 score-formula critique — independent review

**Date:** 2026-05-28
**Reviewer:** independent (this PR)
**Plan reviewed:** `dev/plans/v8-bo-design-2026-05-28.md` §"Decision 2: Scoring metric"
**Authority:** `dev/notes/v7-results-2026-05-28.md`, `dev/scripts/promote_config.sh`

## Summary verdict

**RECOMMENDS_REVISION.**

The formula's SPY-anchor at cand=SPY holds and the worked-example arithmetic
verifies (Examples A/B/C/D/E all reproduce). The two claimed "corrections" are
real fixes. However, the formula has **three substantive defects** that
re-introduce or fail to neutralise the v7-iter42 fragility pattern it is
designed to defeat, and it does **not** structurally align with the promote
gate that motivates the redesign. Coefficient magnitudes also rest on
optimistic "typical winner" extremes not supported by v7 evidence.

---

## Findings

### 1. Single-window blockbuster gameable (BLOCKING)

The formula is **mean-aggregated** across windows, with only ε·var(Sharpe-α)
as a fragility check. A config that exactly matches SPY in 3 windows and
blows the doors off in 1 window scores extremely well:

| Pattern | Mean | Var(Sh-α) | ε·var | **Score** |
|---|---|---|---|---|
| +20pp CAGR + 1.0 Sh-α in W4 only, SPY elsewhere | 1.35 | 0.188 | 0.19 | **+1.16** |
| +50pp CAGR + 2.0 Sh-α in W4 only, SPY elsewhere | 3.20 | 0.750 | 0.75 | **+2.45** |

Per the design's own sanity table, +2.45 is in the "Decisively beats SPY"
band — but this is structurally the v7-iter42 failure mode (one-window
winner, ambiguous elsewhere). The ε term is too weak: a Sharpe-α deviation
of {0,0,0,+2} only generates var=0.75 → 0.75 score-point penalty, leaving
+2.45 net. The δ-gate doesn't fire because the cand never LOSES to SPY.

The design's *only* defence in the doc against single-window blockbusters
is "verdict criteria require holdout pass" — but the BO optimiser does not
know about the holdout, so the BO will happily converge on a config the
verdict-criteria later reject.

### 2. ε term is a narrow filter, not a general fragility detector (MAJOR)

The doc claims Example D shows ε "doing the work it was designed for."
Verified: var of {-0.4, -0.5, +0.3, +1.5} = 0.637, flips +0.32 → -0.32. But
the same CAGR-loss pattern with smoother Sharpe-α {-0.2, -0.2, +0.5, +0.7}
yields var=0.165, score = 0.28 − 0.17 = **+0.12** (passing). The fragility
signal collapses if the strategy fails on CAGR but doesn't fail
*disproportionately* on Sharpe.

The ε term is keyed only to Sharpe-α variance — not CAGR-α variance, not
DD variance, not per-window-pass/fail count. A "uniformly mediocre with
one blowout window" config (large CAGR-α var, small Sharpe-α var) passes.

### 3. DD-term incentivizes extra risk-taking in calm windows (MAJOR)

`γ · max(0, excess_dd)²` is asymmetric (no reward for being safer than SPY,
quadratic penalty for being riskier). The trade-off:

| Excess DD over SPY | Break-even CAGR alpha (α·Δcagr = γ·Δdd²) |
|---|---|
| +2pp | +0.20pp |
| +5pp | +1.25pp |
| +10pp | +5.00pp |
| +20pp | +20.00pp |

At small excess DD (<5pp), the marginal trade is wildly favourable — 1pp
of CAGR justifies 4pp of extra DD. This is exactly the pathology in calm
windows like W3 (post-GFC bull, SPY DD ~5%): a config that takes 15% DD vs
SPY's 5% pays ~1.0 score-point but only needs ~5pp extra CAGR to
break-even, with everything above 5pp being pure positive. In contrast to
the v7 promote-gate (`MaxDD increase ≤ 5pp` absolute, hard veto), the
smooth penalty here is far softer at the margins where most BO candidates
will live.

### 4. Promote-gate alignment claim is unsubstantiated (MAJOR)

Verified `promote_config.sh` (PROMOTE_VALIDATION_PANEL lines 219-222):
promote baseline is **cell-E**, not SPY; gates are Sharpe-regression ≤ 0.10
vs cell-E, MaxDD-increase ≤ 5pp vs cell-E, trades-ratio ≤ 2× cell-E.

A v8 winner that beats SPY by 1pp Sharpe in each of W1/W2/W3/W4 can still
*fail* promote if cell-E itself beats SPY by 1.1pp Sharpe on the
2010-2026 16y window (v7 datapoint: cell-E Sharpe 0.78). PR-5 explicitly
defers the panel/baseline change ("Optional: `promote_config.sh` panel
expansion ... defer to v8 results"). Without changing the promote
baseline or panel, "alignment with promote" remains aspirational.

### 5. "Typical winner extreme" coefficients are aspirational (MAJOR)

Doc calibrates α at "+5pp CAGR alpha", β at "+0.7 Sharpe alpha." v7
evidence: iter 42 *lost* Sharpe to cell-E by 0.155 on sp500-2010-2026;
holdout 4-fold Sharpe-Δ {-0.23, -0.08, +1.47, +0.15} with three folds in
±0.25 and mean +0.328 dragged up by one bear-fold rescue. If v7-iter42 is
a typical converged winner, +5pp/+0.7 are substantially larger than
observed. Coefficients calibrated to dominate at +5pp contribute only
~+0.2-0.4 at the realistic +1-2pp operating point, leaving γ=100 (convex
DD) to dominate the surface gradient.

### 6. SPY-anchor at cand=SPY (verified, OBSERVATION)

All four signal terms + variance = 0 when cand=SPY: α and β reduce to
0×coef; γ·max(0,0)²=0; δ·max(0, 0−0.02)=δ·max(0,−0.02)=0 ✓; ε·var({0,0,0,0})=0.
Both "corrections" are correctly applied: gate uses `spy − cand − spy_tol`
(was `+ spy_tol`), DD term uses paired excess (was absolute threshold).

### 7. Worked example arithmetic (verified)

Independently reproduced:

- Example B (typical winner +2pp/+0.3/−5pp DD): per-window 0.82, mean 0.82,
  var 0, **score = 0.82** ✓
- Example C (marginal, +2pp excess DD): per-window −0.04, **score = −0.04** ✓
- Example D (v7-iter42 pattern): per-window {−1.45, −2.55, +1.21, +4.06},
  mean +0.3175, var 0.637, **score = −0.319** ✓
- Example E (W2 catastrophe): per-window {0, −7.6, 0, 0}, mean −1.90, var ≈ 0,
  **score = −1.90** ✓
- Example A (SPY itself): all zero, **score = 0.00** ✓

### 8. ε term contribution magnitude (MINOR)

Verified: stable {+0.5,+0.3,+0.4,+0.6} → var = 0.0125 → ε·var = 0.013.
That's **0.16% of a 0.82 typical score** — effectively zero in the
operating range. ε is binary in practice: 0 for normal configs, large
only for bimodal Sharpe patterns. Drop it or replace with a count-based
fragility detector (`#{w : cand_Sharpe < spy_Sharpe}`).

### 9. Sloppy verbiage in δ-derivation (MINOR)

Doc says "losing 5pp to SPY in any window incurs 1.0 score-point penalty."
Actually 1.0 score-point penalty requires loss=7pp (since spy_tol=0.02 is
subtracted before scaling). A 5pp loss yields gate=−0.60. The math in
Example D is self-consistent; only the prose around δ is confusing. Worth
clarifying.

### 10. Variance term: Bessel vs population (OBSERVATION)

Doc specifies "population variance (sum-of-squared-deviations / N)" which
is correct for a fixed K=4 windows. Implementation must match — if the
OCaml `Statistics` module defaults to N−1 (Bessel), ε would need to be
re-derived (var would be 33% larger at K=4). PR-2 unit tests should pin
this explicitly.

### 11. Cash strategy in bear windows scores positive (OBSERVATION)

Cash (CAGR 2%, Sharpe 0.5, DD 0%) vs hypothetical SPY: per-window
{+1.10, +1.10, −4.56, −3.88}, total −1.73. So all-cash is correctly
negative overall but scores **+1.10 in each bear window**. Not gameable
per se (no real strategy is bear-cash + bull-SPY oracle), but BO is
biased toward configs that defensively underperform in bears — possibly
the opposite of a trend-follower's intended behaviour.

---

## Suggested fixes

| Finding | Suggested fix |
|---|---|
| 1 — single-window blockbuster | Add per-window min-clip: `score_per_window_clipped = min(score_per_window, +3.0)` to bound any one window's contribution. Alternatively, change aggregation from `mean` to a CVaR/min-style aggregator (e.g. `0.5·mean + 0.5·min(score_per_window)`). |
| 2 — ε too narrow | Replace `ε·var(Sh-α)` with a count-based fragility penalty: `−ζ · #{w : score_per_window(w) < 0}`. A config that's negative in 2+ windows pays a structural penalty regardless of magnitude. |
| 3 — DD gaming in calm windows | Either use absolute DD threshold ALONGSIDE paired-DD (e.g. `γ·excess_dd² + γ_abs·max(0, cand_DD − 0.25)²`), or move the DD gate from quadratic-smooth to piecewise (zero penalty up to +3pp excess, then sharply rising). |
| 4 — promote alignment | Either (a) change `promote_config.sh` baseline from cell-E to SPY in the same PR-2 (currently deferred to PR-5 optional), or (b) explicitly verify cell-E vs SPY on the 2 promote scenarios and document the wedge before launching v8. |
| 5 — aspirational coefficients | Recalibrate using v7 evidence: anchor α at the *observed* iter-42-vs-cell-E magnitude (~+1pp paired CAGR over WF folds → α ≈ 100 if you want +1pp to contribute 1.0 score-point). Or accept smaller absolute scores and tighten the sanity-table verdict thresholds. |
| 8 — ε removal | If ε's contribution is consistently <2% of total score across the BO population, drop it; rely on the count-based fragility from fix #2. |
| 9 — δ verbiage | In the per-coefficient derivation, restate as "δ·0.05 = 1.0 score-point penalty for losing 7pp absolute (5pp past tolerance)" — match the math. |
| 10 — variance Bessel | Pin in PR-2 unit tests: assert `var` is population (`÷ N`) not Bessel. |
| 11 — defensive bias | If the strategy is intended to outperform in bears as well as bulls, no fix needed. If trend-following is the goal, consider per-window weighting that rewards capture-ratio in bulls. |
