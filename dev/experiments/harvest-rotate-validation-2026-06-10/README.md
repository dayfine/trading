# Harvest-and-rotate thesis — read-only validation — 2026-06-10

> ## ⚠ Correction (2026-06-10, post-review) — the verdict below was OVERCLAIMED
>
> The original verdict ("REJECT — both fail decisively") was drawn from
> point-estimate medians and does not survive looking at the **distributions**.
> The honest finding is weaker and differently shaped. This screen is a
> **NO-BUILD *decision*** (no obvious free lunch + a standing prior against
> explorative position-management), **not a rigorous rejection of the mechanism.**
> The corrective rule is `.claude/rules/mechanism-validation-rigor.md`.
>
> **(b) realizable per-event test** `diff = C_fwd − P_mostext_fwd` over the 373
> actual cash-blocked decisions:
> `median −0.12% · mean −1.79% · C beats P 49.9% · p10 −22.9% p25 −10.3% p75 +8.6% p90 +16.3%`.
> → a **coin flip** per decision; the negative *mean* is a fat-LEFT-tail effect
> (occasionally rotating out of a name that then rips), **not** a consistent
> per-decision disadvantage.
>
> **(a) fresh-early vs mature-extended** fwd-4w (held-weeks): early mean +1.15%
> (**+14.9%/yr**), mature mean +2.59% (**+33.6%/yr**) — the mean gap is large, BUT
> the distributions overlap almost fully (early p10/p90 −10.7%/+12.5%, mature
> −11.0%/+15.8%), n is small (311 vs 114), and **mature-extended is
> survivor-selected** (conditioned on surviving 27+ weeks and staying 20%+
> extended), so it reads falsely favourable and is not the decision the rule faces
> in real time.
>
> A real rejection requires the mechanism implemented as a default-off **surface**
> (harvest fraction `k`, late/extension threshold, candidate pick-rank) backtested
> under WF-CV with the engine doing the real rotation and stops. Everything below
> is the original (overclaimed) writeup, kept for the record.

---

**[SUPERSEDED] Original verdict: REJECT at validation. Do NOT build the harvest-rotate dial.**

This is the P0 from `dev/notes/next-session-priorities-2026-06-10-PM.md`: validate
the *capital-allocation-by-forward-expected-return* thesis **before** building any
mechanism (the discipline that just saved the cascade-reweight). It does not
survive the validation.

## The thesis under test

As a winner (e.g. AXTI) climbs its Stage-2 curve, the gain is banked but the
*forward* expected return per dollar still parked in it was assumed to **fall**
(later in the move, more extended above the MA, nearer the Stage-3 top). A fresh
early-Stage-2 breakout was assumed to have *higher* forward expected return per
dollar. So at the margin: harvest some of the mature winner and rotate into the
fresher, cash-blocked candidate (the AAPL-dividend logic). Two measurable
preconditions, both required:

- **(a) Forward-return decay** — for held positions, does subsequent N-week return
  *fall* as the position gets later / more-extended in Stage 2, and is it *lower*
  than fresh early-S2 entries' forward returns?
- **(b) Opportunity cost** — are early-S2 candidates skipped for insufficient cash
  *while* mature extended winners are held, and would the skipped names have
  *out-returned* the capital left in the mature hold?

Decision rule (from the priorities doc): build only if **both** hold. "If forward
return does **not** decay, it's just churn+cost → drop it."

## Data

Single full-period Cell-E **top-3000** backtest (the universe where the
concentration actually arises), snapshot mode `snap_top3000_2011`,
`2011-01-01 → 2026-04-30`. Run: `scenarios-2026-06-10-184414/cascade-rw-base-top3000`
(761.0% return / 650 trades / 34.6% WR / 27.9% MaxDD — the standard Cell-E
top-3000 baseline). Spec = `cascade-reweight-wfcv-2026-06-10/base_top3000.sexp`.

Forward returns computed from the **adjusted_close** column of the CSV bar store
(raw close gives reverse-split glitches — NDN showed a fake +50,200% 4-week
return; that contamination is why the first pass reported absurd means).
Extension = `adj_close / 150-day SMA − 1` (150d ≈ Weinstein's 30-week MA).
Forward 4-week (`fwd20`) and 12-week (`fwd60`) returns. All aggregates are
**medians** (robust) with means alongside; forward returns with `|r| > 5` dropped
as residual data glitches.

Method + scripts in this dir: `p0_analyze.sh` (driver), `fwd_a.sh` (per-held-week
extension/maturity/forward sampler), `fwd_batch.sh` (per-symbol point
forward-return lookup). Raw per-held-week samples: `fwd_a_samples.csv`
(4,169 rows). Full stdout: `analyzer_output.txt`.

## (a) Forward-return decay — FAILS

`fwd20` median by **extension above the 150d MA** (pooled held-weeks, n≈4,150):

| ext bucket | n | median fwd20 | mean fwd20 |
|---|---|---|---|
| <0      | 138  | +0.83% | +0.49% |
| 0–10%   | 1532 | +1.03% | +0.98% |
| 10–20%  | 1379 | +0.21% | +0.72% |
| 20–30%  | 515  | −0.33% | −0.05% |
| 30–50%  | 368  | +1.15% | +2.76% |
| **>50%**| 220  | **+1.49%** | +1.83% |

`fwd20` median by **weeks-since-entry** (maturity):

| maturity | n | median fwd20 | mean fwd20 |
|---|---|---|---|
| wk0–4   | 1882 | +0.61% | +0.80% |
| wk5–12  | 1218 | +0.29% | +0.97% |
| wk13–26 | 806  | +1.05% | +0.95% |
| **wk27–52** | 242 | **+1.79%** | +2.14% |
| wk53+   | 4 | (n too small) | |

Direct contrast: **fresh early-S2 (wk0-4, kind=early) median +0.38%** vs
**mature-extended (wk27+, ext>20%) median +1.44%**.

There is **no forward-return decay**. If anything forward return is *flat-to-rising*
with both extension and maturity — the most-extended (>50%) bucket has the highest
median (+1.49%), and the oldest holds (wk27-52) the highest of the maturity axis
(+1.79%). Mature-extended capital earns **more** forward return than fresh
early-S2, not less. This is *let-winners-run* / momentum-persistence showing up
directly: the Stage-2 monsters keep advancing.

## (b) Opportunity cost — FAILS

380 distinct dates had ≥1 candidate skipped for `Insufficient_cash`; 373 matched a
held set. Comparing the **best** (top-cascade-score) skipped candidate's forward
4-week return against the capital it was blocked by:

| comparison | mean skipped (best) | mean held | % dates skipped > held |
|---|---|---|---|
| vs **average** held capital | +0.37% | +1.01% | 48.0% |
| vs **most-extended** held (the harvest target) | +0.37% | **+2.16%** | 49.9% |

The opportunity cost runs the **opposite** direction to the thesis. The harvest
target — the most-extended held winner — earns **+2.16%** forward, ~6× the best
cash-blocked fresh candidate's **+0.37%**. Rotating a dollar out of the extended
winner into the skipped fresh name moves it from +2.16% → +0.37% forward: strongly
value-destroying. Win-rate is a coin-flip (≈48–50%), so there isn't even a
median-level edge to the skipped names.

## Why this is the expected answer in hindsight

Three independent prior findings already pointed here; this validation makes it
quantitative:

- **Cascade-selection inversion** (`project_cascade_selection_inversion`): the
  confirmed breakout earns the **fat tail**; the breakout premium *is* the
  return, not a scoring error.
- **Entry-cap probe** (`concentration-entry-cap-probe-2026-06-10`): concentration
  **is** the return — the monsters need size; shrinking entries cut return ~6×.
- **Weinstein-faithful core**: *let winners run* — exit on Stage 3/4 or a
  trailing-stop break, never trim a still-advancing Stage-2 winner on a
  forward-rate argument that the data doesn't support.

Harvesting the mature winner contradicts all three. The "declining forward rate"
premise (the entire basis for the AAPL-dividend analogy) is simply false here:
the winner's forward rate does not decline while it is still in advancing Stage 2.

## Consequences

- **Drop the harvest-rotate dial.** No build. (Saved the P1 partial-exit core
  change too — it was only needed to *fund* this mechanism and the concentration
  trim, both of which are now dominated.)
- The concentration-trim direction generally (`concentration-rebalance-2026-06-10.md`)
  is on the same dead end: trimming an extended winner moves capital to a
  lower-forward-return use. The only residual reason to bound single-name NAV% is
  **unrealised-mark / tail-risk** (`project_broad_universe_790_mtm_inflated`), a
  *risk*-framed argument — not a *return*-framed one — and prior risk-cap probes
  were already strictly dominated.

## Caveats (honest)

- Extension uses a 150d-SMA proxy for the 30-week MA; maturity is weeks-since-entry;
  horizon is forward 4-week. These are proxies, but the signal is **consistent and
  well-powered across both axes** (extension AND maturity both fail to show decay)
  and the direct fresh-vs-mature contrast is unambiguous, so the conclusion is robust
  to the proxy choice.
- Single full-period surface (not WF-CV). That is the right cost for a
  *validation-before-build* gate: the thesis fails even its cheapest, most
  favourable test, so there is nothing to carry to WF-CV.
