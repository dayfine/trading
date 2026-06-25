# Capacity / concentration surface — WF-CV deep 2000-2026 (2026-06-25)

**Verdict: INCONCLUSIVE / no-promote.** Concentration (`max_position_pct_long`)
is a real, live lever but a return-for-DD/dispersion tradeoff with no robustly
promotable value. The canonical default (0.30) already sits in the favourable
region and stays unchanged. Ledger:
`dev/experiments/_ledger/2026-06-25-capacity-concentration-surface.sexp`.

## Why this experiment

The optimal-strategy lens (`dev/notes/optimal-lens-insights-2026-06-25.md`)
redefined the strategic direction: the strategy's misses are **`Insufficient_cash`,
not bad picks** — the cascade correctly identifies the breakout winners (JBL, DVN,
PWR, ODFL…) but they go unfunded because capital is sprayed thin. The deep
sp500-historical goldens cap each long at `max_position_pct_long = 0.14`, so ~5
small slots churn while the monsters starve. Entry-selection is settled-dead (3rd
confirmation); the live lever is the **capital envelope**. This is a
tail-**preserving/amplifying** funding lever (fund the identified winners larger),
the right class per `project_edge_is_the_fat_tail` — not a winner-touching trim.

Two axes, deep 2000-2026 sp500-as-of-2000 PIT, rolling 365/365 → 26 folds:
- `max_position_pct_long` ∈ {0.14, 0.20, 0.25, 0.30, 0.35, 0.40} (base 0.14)
- `max_long_exposure_pct` ∈ {0.70, 0.90}

`min_cash_pct` was **excluded** — deprecated, never wired into the entry walk.

## The full curve (v2 {0.14,0.25,0.40}×exposure + v3 fill {0.20,0.30,0.35}; same base/folds)

| cap | Sharpe | Calmar | MaxDD % | Return μ% | Return σ | Sharpe-wins/26 |
|-----|-------:|-------:|--------:|----------:|---------:|---------------:|
| 0.14 (deep-golden base) | 0.562 | 1.030 | 9.95 | 9.30 | 12.6 | — |
| 0.20 | 0.572 | 1.129 | 10.52 | 10.40 | 16.0 | 14 |
| **0.25** | **0.858** | **2.075** | 10.17 | 17.29 | 27.4 | 19 |
| 0.30 (**canonical default**) | 0.643 | 1.440 | 11.49 | 13.77 | 22.9 | 15 |
| 0.35 | 0.650 | 1.547 | 11.44 | 13.57 | 21.5 | 14 |
| 0.40 | 0.608 | 1.597 | 12.40 | 13.59 | 22.3 | 14 |

## What the curve says (the WHY, not just the verdict)

1. **The mechanism is live and amplifies the fat tail.** Every cap above 0.14
   raises return (9.3 → 10–17%) and Calmar (1.03 → 1.13–2.08). Concentration does
   fund the winners — confirming the optimal-lens diagnosis and the
   `edge_is_the_fat_tail` thesis (concentration is the right lever *class*).

2. **But it is a return-for-DD/dispersion tradeoff, not a free Sharpe.** MaxDD
   rises 9.95 → 10.5–12.4 and return-σ rises 12.6 → 16–27 in lockstep with return.
   The Sharpe gain outside the 0.25 spike is modest and noisy (0.562 → ~0.57–0.65),
   and fold-win-rates are barely above half (14–15/26). Concentrating into an
   *unpredictable* tail raises variance as fast as it raises return.

3. **The 0.25 "near-doubling" is a knife-edge single-point spike — overfit, not a
   peak.** Sharpe 0.858 at 0.25 sits far above *both* neighbours (0.20 = 0.572,
   0.30 = 0.643). Attribution: it is path-dependent fat-tail luck at that exact cap
   value. Fold-000 (the strong 2000-01 year) return is **non-monotonic** across the
   cap — **52% (0.14) → 131% (0.25) → 97% (0.30)**. A higher cap funds the monster
   *less* at 0.30 than at 0.25 because the exact cap changes which positions get
   funded to what size in a path-dependent order. A single value winning while its
   neighbours don't is the textbook single-point overfit this whole loop exists to
   catch. **Not promotable.**

4. **`max_long_exposure_pct` is inert.** {0.70, 0.90} produced bit-identical
   metrics at every concentration level — the per-position cap is the *sole*
   binding constraint; the 0.70/0.90 aggregate long ceiling never binds. Drop it
   from future capacity surfaces.

## Process note — the Fold_gate is mis-specified for this lever

The per-variant `Fold_gate` (`worst_delta = 0.0`, copied from the arming-speed
tail-risk-insurance spec) FAILs every cell, because it demands *no fold worse than
baseline*. That is the correct gate for an insurance mechanism (must never hurt)
but **wrong for a return-amplifying lever**, which necessarily makes some folds
worse (dispersion rises) while winning on aggregate. The honest read for this
lever class is the Pareto frontier + fold-win-rate + the full response curve — not
the strict gate. Future capacity/return-amplifier surfaces should use a `worst_delta`
budget > 0 (or a return/Calmar gate), not the insurance gate.

## Decisions

- **No config-default flip.** Default `max_position_pct_long = 0.30` already sits
  in the mildly-favourable region; nothing to promote.
- **Deep long-only goldens at 0.14 are mildly conservative** (lower return/Calmar,
  lower DD vs the default). Re-pinning them to 0.30 would be a deliberate
  "match production default" choice — a Pareto tradeoff, **not** an alpha claim —
  and would need the confirmation grid (`.claude/rules/promotion-confirmation.md`)
  first. Left as-is for now. NB the long-only catstop base has
  `enable_short_side = false`, so 0.14's original short-diversification /
  force-liquidation-cascade rationale does not even apply to it.

## Forward guidance (narrows the capacity search)

Concentration is the right *class* of lever but does not hand over free
risk-adjusted return because the tail it concentrates into is unpredictable
(knife-edge, fold-dependent). So within the capacity envelope, **stop expecting a
clean concentration optimum** and pivot the remaining P1 capacity levers toward
ones that change *which* names get funded / *how turnover frees cash*, where the
gain isn't pure tail-variance:

- **Turnover / laggard-rotation cadence** — the rotation churn is what exhausts
  cash in the first place (280 churned trades in the optimal lens). Slowing
  rotation to preserve dry powder is a capacity lever that does *not* simply
  crank single-name variance. (Laggard on/off is settled ON; *cadence* is open.)
- **Position-count cap** (`max_positions`) — fewer slots forces concentration via a
  *count* constraint rather than a *size* cap; worth one surface to see if it
  behaves differently from the size cap (which is knife-edge).

Both stay default-off axes → WF-CV (use a return/Calmar gate, not the insurance
gate) → confirmation grid before any flip.
