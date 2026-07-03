# Scale-in v1 WF-CV surface — REJECT for promotion (keep default-off axis)

**Mechanism:** explore/exploit scale-in (plan
`dev/plans/capital-management-scale-in-2026-07-02.md`, merged default-off via
#1830/#1831/#1832/#1833): ½-unit initial entries + max 1 sibling add into
revealed strength, reallocation inside the existing 0.30 envelope.
**Ledger:** `2026-07-03-scale-in-v1-surface` (Reject).
**Artifacts:** `dev/experiments/scale-in-wfcv-2026-07-03/` (specs, both cells'
reports + aggregates, fold-001 solo repro).

## Design

Two cells, 2000–2026, thirteen 2-year non-overlapping folds each (bear-inclusive:
dot-com, GFC, 2022), production caps (0.30/0.70/0.30), Cell-E long-only +
stage3/laggard:

- **Cell A** sp500-515 PIT-2000 (CSV, parallel=4) — comparability anchor.
- **Cell B** top-3000 PIT-2000 (snapshot warehouse, fork-per-fold) — the
  **decisive** cell: the capacity bottleneck and the gap-and-go monsters live on
  breadth (user correction, same as 2026-06-25 capacity-BROAD precedent).

Variants: `baseline`, `scale_in_pullback` (fraction 0.5, v1 defaults),
`scale_in_either` (sp500: ext 0.15 → structurally dead, see below;
broad: `either_loose` with `extension_max_pct 0.25`).

## Results

| Cell | Variant | Sharpe μ±σ | Return μ±σ | MaxDD μ | Calmar μ | Sharpe wins | DD wins |
|---|---|---|---|---|---|---|---|
| sp500 | baseline | 0.923 ± 0.858 | 36.1 ± 42.3 | 14.9 | 1.41 | — | — |
| sp500 | pullback (≡ either@0.15) | 0.775 ± 0.733 | 23.4 ± 24.7 | 14.2 | 1.09 | — | — |
| broad | baseline | 0.597 ± 0.494 | 19.9 ± 20.6 | 15.4 | 0.68 | — | — |
| broad | pullback | 0.623 ± 0.523 | 20.1 ± 20.1 | 14.8 | 0.73 | 6/13 | 7/13 |
| broad | either_loose | 0.662 ± 0.463 | 20.1 ± 17.4 | 13.9 | 0.76 | 6/13 | **10/13** |

Formal gate (m=7/13 Sharpe wins, worst-Δ 0.30): **FAIL everywhere** (6/13;
fold-003 worst-gap 0.70–0.77). The broad Sharpe edge (+0.065 mean for
either_loose) does not survive deflation (t ≈ 0.5 over 13 folds, ~5 trials).

## The why (the part that transfers)

1. **The ½-sized initial entry is itself a fat-tail tax.** It halves exposure
   to the unpredictable monster at the one moment we're guaranteed to be in it;
   the add restores size only when the name behaves politely (pullback-hold),
   and gap-and-go monsters don't. sp500 fold-002 (2003–05 recovery): 146% →
   55%. This is `project_edge_is_the_fat_tail` from the **explore** side —
   under-sizing unpredictable winners is the same class as trimming them.
   (Plan §3.4's monster-under-sizing concern, confirmed at fold level.)
2. **`Either` is structurally dead at `extension_max_pct = 0.15`.** Breakout
   entries already sit 10–20% above the 30-week MA, so a post-entry new high
   reads "extended"; only the pullback arm survives (pullback ≡ either
   bit-identical on all 13 sp500 folds + a fold-001 A/B; adds DO fire, ~4 per
   fold). At 0.25 the Either arm lives — and supplies **all** the incremental
   risk benefit. The continuation-add is the risk-improving half; the
   pullback-add alone is nearly neutral.
3. **Breadth reverses the sign** (third instance of the breadth-dependent-knob
   pattern after declining-MA and capacity-BROAD). On narrow sp500 the freed
   half-capacity has nowhere productive to go, so the tax dominates (−0.15
   Sharpe, −13pp return). On broad it redeploys into more names and nets out:
   return dead-flat, risk mildly down — `either_loose` cuts MaxDD in 10/13
   folds, drops return dispersion (σ 17.4 vs 20.6), and nearly neutralizes the
   2022 bear fold (Sharpe −0.42 → −0.03). **Scale-in as designed is a
   diversifier, not an amplifier.**

## Forward guidance

- **Return-seeking: stop here.** The lever redistributes; it does not add.
- **If a smoother broad book is ever wanted:** revisit `either_loose`
  (Either + ext ≈ 0.25) as tail-risk-lite. The more promising untested shape:
  **full-size initial entries + continuation adds** (drop the ½-sizing — keep
  only the un-taxed press-the-winner half). That is a fresh surface, not this
  one.
- Mechanism stays merged, default-off, a searchable axis. No golden churn.

## AMENDMENT 2026-07-03 (participation-effect measurement)

Decision-level measurement (`dev/experiments/scale-in-participation-2026-07-03/RESULTS.md`)
**contradicts finding (2)'s second half and re-attributes the broad smoothing**:

- **The add channel never functioned anywhere.** "Adds DO fire ~4/fold"
  counted *funded orders*, not fills. Instrumented f011: pullback 20 funded /
  **1 filled**; either_loose 22 funded / **1 filled**. Root cause: adds are
  emitted as zero-width `StopLimit(close, close)` at Friday's close of a
  stock signalling *strength* — a gap-up can trigger the stop but never meet
  the limit, so the designed press-the-winner fill is structurally
  unreachable; the order fills only when price retreats to Friday's close =
  adverse selection (4/4 observed fills collided with same-day parent exits).
- **either_loose's risk benefit is therefore NOT continuation-adds.** It is a
  side-effect bundle: funded-but-unfillable adds reserve cash on the emit
  Friday (≈$590–736k cumulative per f011 cell on $1M), displacing marginal
  new entries (helpful in bear tape, costly in bull), plus path divergence.
- **Confirmed the strong way:** ½-sizing → breadth is near-lossless (79–92%
  of newly-entered names were baseline's `Insufficient_cash` near-misses;
  skips-per-Friday flat at ~10 — the cash constraint always binds), and the
  fat-tail tax is visible per-decision (avg entry ~halves, never restored).
- **REJECT stands**, but the *tested object* was "½-sizing + breadth + an
  unfillable-add cash-reservation throttle", not the designed explore/exploit
  reallocation. Prerequisites before the untested full-size+adds shape:
  fillable add order type (stop-market above close / market-at-open),
  add/exit-coherence gate, explicit `add_fraction` knob.

## Validation bonus

The surface caught a real simulator bug on its first fold: same-state sibling
fill mis-routing ("Filled quantity exceeds target") → fixed as **#1837**
(order→position link routing, exact-with-fallback), double-QC'd + merged. The
experiment paid for itself before producing a verdict.
