# Harvest-rotate — rigorous WF-CV test (steps 4a + 4b) — 2026-06-11

**Verdict: REJECT (WF-CV-grade). No `harvest_fraction` generalises.** Mechanism
stays default-off; the axis remains available but is not promotable. Ledger:
`dev/experiments/_ledger/2026-06-11-harvest-rotate-top3000.sexp`.

This is the rigorous test the user greenlit after the read-only screen
(`harvest-rotate-validation-2026-06-10/`) came back *inconclusive, not a
rejection*. The mechanism was built behind a default-off flag (steps 1–2, PRs
#1525 + #1528) and tested as a surface under WF-CV — the only thing that answers
*"timing + picks, reliably hit-able."*

## Setup

Cell-E top-3000-2011, 2011-2026, 15 rolling folds (test 365d, step 365d),
fork-per-fold. Surface: baseline (`enable_harvest_rotate=false`) vs
`harvest_fraction ∈ {0.33, 0.5, 1.0}` (the trim fraction on the `Stage2{late}`
flag; 0.5 = the book's "sell half"). Gate: ≥8/15 Sharpe wins vs baseline, no fold
worse by ΔSharpe>0.30. Spec + base + outputs in this dir.

## 4a — the surface (all variants FAIL the gate)

| variant | Sharpe μ±σ | Return % μ±σ | MaxDD % μ | Sharpe wins | gate |
|---|---|---|---|---|---|
| baseline | **0.645**±1.03 | 12.99±22.6 | 14.8 | 15/15 | — |
| harvest_k033 | 0.411±0.93 | 11.06±29.8 | 15.5 | 7/15 | **FAIL** (M) |
| harvest_k050 | 0.627±0.84 | 17.63±**37.0** | 14.4 | 8/15 | **FAIL** (Δ: fold-006 −1.57) |
| harvest_k100 | 0.414±1.09 | 13.25±27.8 | 15.5 | 6/15 | **FAIL** (M+Δ) |

No variant clears the per-fold gate. The best (k050) ties baseline on Sharpe
(0.627 vs 0.645) but is killed by one catastrophic fold.

## 4b — the decomposed WHY (the actual deliverable)

Per `.claude/rules/mechanism-validation-rigor.md` §"the real deliverable is the
why", a REJECT must explain the failure mechanism. Decomposing
(timing / picks / structural-tax / cost):

1. **No risk-adjusted edge.** The best variant's mean Sharpe (0.627) is
   *indistinguishable from — slightly below —* baseline (0.645); k033/k100 are
   clearly worse (0.41). Harvest adds no Sharpe.
2. **Dispersion amplification, not improvement.** k050 return σ = 37.0 vs
   baseline 22.6 — a **1.64× wider** return distribution. The trim-and-redeploy
   *scrambles* outcomes; it doesn't smooth them. (MaxDD is ~flat, so it's not
   buying drawdown protection either.)
3. **Not timing skill.** The per-fold return-delta vs baseline has **no regime
   pattern** — harvest helps in some strong folds (fold-002 +29pp, fold-010
   +50pp) and hurts in others (fold-006 −12pp, fold-009 −24pp). A learnable
   timing edge would show a consistent sign; this is noise.
4. **The structural tax is the gate-killer.** The worst folds are exactly the
   ones where **baseline rode winners to high Sharpe and harvest trimmed them**:
   fold-006 (2017) baseline Sharpe **2.48 → k050 0.91**; fold-009 baseline return
   **31% → k050 7%**. Trimming a still-advancing winner gave up the fat tail —
   the ΔSharpe>0.30 gate violation comes from precisely these episodes.

**Net:** the timing-wins (3) and structural-tax-losses (4) roughly cancel on
return, Sharpe is unchanged, and variance rises. Harvest-rotate is a
**dispersion-amplifying variance trade with no edge.**

## What this generalises to

This is a quantified, WF-CV-grade instance of `project_edge_is_the_fat_tail`:
**touching winners** (trimming them) scrambles the return distribution without
improving risk-adjusted return. It joins laggard / force-exit / stage2-ma-hold /
late-flag-stop-tighten / macro-trim as a rejected winner-touching lever. The
forward rule stands: *ask of any new lever — does it touch winners?* If yes, the
prior is strongly negative; bias toward tail-preserving levers (breadth, entry
quality, holding discipline, barbell).

## Caveat (honest)

A trade-level structural-tax-vs-timing split (the per-trim forward return of the
trimmed position vs the redeployed capital, the screen's (b) measurement re-run
on the *real* rule's trades) would further sharpen (3) vs (4). It is not done
here — but it cannot change the unanimous gate-FAIL verdict, only refine the
attribution. The fold-level evidence + the standing prior already deliver the
transferable why.
