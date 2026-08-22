# Funding three-way grid — mechanisms work, defaults don't change (2026-08-22)

The A1-4 grid from `dev/plans/ticket-funding-2026-08-16.md` step 4: what should
happen when a triggered entry ticket is refused for insufficient cash, instead
of today's silent destruction? Five arms, one override each, on the
record-convention `fullbook-graded` base (26y, top-3000, build `1281dab97`
with G2a #2463 + G2b #2468). Sequential, single worker, same warehouse and
data root for all five. Specs + per-arm artifacts committed under
`dev/experiments/funding-grid-2026-08-22/` (raw `trades.csv` + `actual.sexp` +
ticket-level `*-tickets.tsv` extracted from the audits; join key is
`symbol|placement_date` for tickets, `position_id` for trades).

## Top line (context only — NOT the verdict surface)

| arm | policy | return | trades | MaxDD | hold |
|---|---|---:|---:|---:|---:|
| null | destroy (today) | +305.2% | 1,270 | 39.1% | 38.2d |
| g2a1 | retry ×1 | +218.8% | 1,368 | 36.4% | 35.4d |
| g2a2 | retry ×2 | +197.6% | 1,379 | 40.3% | 35.1d |
| g2b | resize ≥0.5 | +174.4% | 1,407 | 41.4% | 34.8d |
| g3 | reserve at placement | **−1.1%** | **53** | 6.6% | 51.2d |

The 86–131pp gaps of the three handling arms sit at or inside the 132.5pp 26y
return null on this base — **no top-line verdict**. The trade-level record
below is the verdict surface.

## Event-level findings (the actual dissection)

**Population** (from the audits): null placed 2,013 tickets, destroyed **527**
for funding, filled 1,486. The handling arms destroy fewer (g2a1 431, g2a2
371, g2b 399) and fill more (~1,600). g3 places only **58 tickets in 26
years** — reservation moves starvation upstream from fill to placement.

**1. The mechanisms work on their targets, and the saved tickets MAKE money.**
Tracing the null's 527 destroyed tickets into each arm:

| arm | cohort keys present | saved (filled) | saved closed trades | saved P&L |
|---|---:|---:|---:|---:|
| g2a1 | 390 | 159 | 103 | **+$538,710** |
| g2a2 | 382 | 187 | 107 | +$166,300 |
| g2b | 390 | 166 | 163 | +$288,458 |

Direct effect: +17 to +54pp of the $1M book, positive in all three arms. The
funding failure was destroying net-profitable entries — the plan's premise is
confirmed at the event level (the AXTI class of loss is real).

**2. The top-line gaps are a monster lottery, not mechanism cost.** The
ticket-identity displacement join initially showed $1.0–1.6M of "lost" null
P&L per arm — but at the *opportunity* level much of it is the same catch on a
different ticket (MSTR 2020: all four arms caught it, +$539k…+$795k). The
genuine reshuffles at the top:

- Null-only: **CLS 2023-07 (+$658k)** and LGND 2012 (+$175k) — missed by all
  three handling arms.
- Arm-only: **SKYW 2023 (+$428k g2a1 / +$355k g2b)** and BPT 2022 (+$179k
  g2b) — missed by the null. (SKYW and BPT are the named crash-recovery
  monsters from the ladder-v3 record.)

One reshuffled monster ≈ 66pp — the whole inter-arm spread. Any cash-timing
perturbation re-rolls which fat-tail name gets caught
(`project_edge_is_the_fat_tail`, `project_clock26_is_a_tail_lottery`); the
funding mechanisms are, at the top line, exactly such a perturbation.

**3. One extra retry rewrites a third of the trade set.** g2a1 vs g2a2 share
only 895 of ~1,370 `symbol|entry_date` pairs (473/484 arm-only; divergence
starts 2003-10-27; of the shared pairs only 209 have identical P&L). The
cascade through the shared cash pool dominates everything downstream of the
first divergence.

## Verdicts (per `experiment-flag-discipline.md` / `mechanism-validation-rigor.md`)

- **G3 `reserve_cash_for_resting_tickets` — REJECT as a default, terminal.**
  53 trades in 26y; the reservation exhausts the deployable pool and the
  system stops trading. Structural, not noise (population collapse, not
  return). Classification: REJECT-do-not-revive *as a global default*; the
  flag itself stays (R1-compliant no-op) since a capital-rich preset could
  legitimately revisit it — record says: do not re-test as a default.
- **G2a retry / G2b resize — keep, default-off, as axes. No promotion case.**
  The direct effect is positive and the mechanisms behave exactly as
  specified, but the displaced-monster variance dominates the top line and no
  single value clears the noise. A promotion would need the confirmation grid
  with salted nulls (`promotion-confirmation.md`); nothing here argues that
  effort is a priority.
- **The why, transferable:** funding-failure handling is a *tail-preserving
  lever in intent but a tail-reshuffling lever in effect* — the saved cohort
  is median-sized while the displacement risk is monster-sized. Any future
  funding lever must be judged on whether it protects specific *monster*
  entries (e.g. reserve-only-for-A+-grade), not on aggregate ticket counts.

## Method notes

- Raw WARN-line counts are NOT comparable across arms (each failed retry logs
  its own line: g2a1 975 vs g2a2 1,351 lines describe *fewer* distinct starved
  tickets, 431 vs 371).
- The audit-extracted ticket tables (527 cancelled) differ from a raw
  `grep -c cancel_reason` (530) by 3 — records whose header pattern the
  extractor's line-anchored parser missed; the 527 keys are the join
  population and all joins are internally consistent.
- g3's 6.6% MaxDD / −1.1% return is a portfolio that held ~98% cash for 26
  years — not a defensive success.
