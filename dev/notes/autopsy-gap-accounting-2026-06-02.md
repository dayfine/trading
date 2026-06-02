# Autopsy gap accounting — how much have we actually closed? (2026-06-02)

**Question:** the 2026-05-29 trade autopsy found a large gain-capture gap. With the
models built since (sector rotation #1419, macro gate #1422, barbell), how much of
that gap have we closed, and how much is unexplained?

**Short answer:** the gap is real and reproduced, but a single "% closed" number is
*not extractable from the autopsy* — and the honest decomposition shows the gains we
banked came from axes the autopsy doesn't even measure (selection + deployment +
downside), while the modes it *did* label remain largely open.

## The gap, reproduced exactly (baseline = primitive per-symbol strategy #1353)

Re-ran `autopsy_runner` on SPY+11 sectors, 1998-2025, 196 trades — identical to the
2026-05-29 run:

| mode | # trades | missed gain | what it is |
|---|--:|--:|---|
| late_reentry | 48 | **+1557.83%** | dead-money cash-waits after a (false) exit |
| stage3_false_positive | 71 | **+1176.23%** | premature S3 exits that recover |
| late_stage2_admission | 100 | +505.01% | entering trends late |

These are **per-symbol missed *upside***, overlapping (not summable), and — by the
autopsy's own Caveat 2 — **NOT convertible to a CAGR/return gap**. The autopsy never
measures *downside* (the losses an exit avoids).

## What the autopsy PRESCRIBED — and what happened: ~0% closed via its own cures

The autopsy's recommended fixes for the top modes were all built and **rejected by
walk-forward CV / deep-window testing**:
- **Stage-3 hysteresis** (#1364-66, for #1/#2) — wins 5y, loses 15y, loses 4/31 folds.
- **Exit-timing** (#1375) — same rejection, re-confirmed on repaired/deep data.
- **Early-admission** (#1378, for #3) — post-2009 grid ACCEPTed, but the 27y deep test
  had baseline dominate every variant; a bull-regime artifact.

So via the autopsy's *prescribed mechanisms*, essentially **none** of the gap was
closed durably. (Banked lesson: the autopsy is a failure-mode *labeller*, not a
knob-recommender — `project_stage3_hysteresis_rejected_wfcv`.)

## What we DID close — on axes the autopsy can't see

The gains this session came from rotation, selection, and gating — none of which the
per-symbol autopsy models. Measuring them directly:

### Deployment (cash-drag) — the realized late_reentry axis
Deployment = fraction of equity-curve days the value *moves* (long) vs is flat (cash) —
a semantics-free measure that correctly counts the open multi-year position (which
`trades.csv` round-trips do not):

| | SPY-only (no rotation) in-mkt | sector-k3 gate-ON in-mkt | rotation gain |
|---|--:|--:|--:|
| Bull 2009-25 | 77.8% | 86.7% | +8.9pp |
| Deep 2000-25 | 67.3% | 79.3% | +12.0pp |

**SPY-only is already ~67-78% deployed — it is NOT badly idle.** Rotation recovers only
~⅓-40% of its remaining cash-drag (+9-12pp). So the late_reentry leak, as realized by
the *reference* strategy (not the primitive one the autopsy scored), is modest, and
rotation closes a minority of it.

### Selection — the bigger lever, invisible to the autopsy
Sector-k3 out-returns single-symbol SPY-only by **+103pp bull** (440% vs 337%) and
**+108pp deep** (528% vs 420%). Rough decomposition (compounding-naive: if deployment
alone explained it, sector-k3 ≈ SPY-only × deploy-ratio):

| | total uplift | ~from deployment | ~from selection |
|---|--:|--:|--:|
| Bull | +103pp | ~39pp | **~64pp** |
| Deep | +108pp | ~75pp | ~33pp |

Selection (holding stronger-trending names than the index) is the **larger** lever in
the trending bull regime; deployment dominates in the bear-heavy deep regime. The
autopsy — single-symbol, no selection — cannot measure either.

### Downside / drawdown — a whole axis the autopsy omits
The autopsy only scores missed upside. The gate + barbell improved the *downside*:
SPY-only's 18.8% MaxDD floor, the gate's −4pp on sector-k3, the 70/30 barbell's
19-22%. None of this is in the autopsy's ledger at all.

## Accounting — mode by mode

| autopsy mode | status | by what |
|---|---|---|
| late_reentry (+1557, #1) | **partially closed** | rotation (+9-12pp deploy) + selection; NOT the recommended timing fix. Unquantifiable as a clean % (see below) |
| stage3_false_positive (+1176, #2) | **open** | direct fix WF-rejected; rotation softens but doesn't plug the false signal |
| late_stage2_admission (+505, #3) | **open** | early-admission fix WF-rejected (bull artifact) |
| (downside / DD — not an autopsy mode) | improved | gate + barbell |

## Why there is no single "% of gap closed" number

Two hard reasons, both real:
1. **The autopsy is per-symbol; our mechanisms are portfolio-level.** late_reentry =
   "weeks until *this symbol* re-enters." Rotation's benefit is redeploying that
   capital to *another* symbol — which the per-symbol tool is structurally blind to.
   Re-running the per-symbol autopsy on sector-k3 would *mis*-measure mode #1.
2. **Missed-gain % ≠ CAGR** (autopsy Caveat 2). The buckets can't be back-converted to
   return impact.

The deployment + return decomposition above is the best honest quantification, and its
verdict is: **most of our banked gain came from selection, deployment, and downside
control — axes the autopsy does not model — not from fixing the timing leaks it
labelled, which we could not fix durably.**

## Recommendation — a portfolio-level gap meter

The per-symbol autopsy has hit its ceiling of usefulness. To get a real "gap closed"
number, build a **portfolio-level gap tool**: deployment / cash-drag accounting (the
equity-curve-motion method here, productionized) + a "perfect-redeployment" ceiling
(idle capital earning the best-available Stage-2 name). That would score rotation and
selection on the same footing — which the per-symbol tool cannot. Small, well-scoped,
and arguably the right next diagnostic investment before more strategy mechanism work.
