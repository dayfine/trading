# resistance-supply w30 divergence forensic — the ¾ forfeit is one ticket + one regime class (2026-07-17)

Inline decomposition of the 28y single-path pair
(`trading/dev/backtest/scenarios-2026-07-16-131756/`, baseline record
convention +7,914% vs w=30 +1,991%) run while the rolling-start
distribution sweep executes. Corrects one recorded claim and sharpens the
promotion decision.

## Correction of record: the two runs do NOT trade the same tickets

Prior notes said "identical 1,187 trades / identical trade count". The
*count* is identical (capacity-bound, cap-20 + cash); the *book* is not:

- shared tickets (symbol, entry_date): **367 / 1,187**
- swapped: **820 tickets each side (69% of the book)**

w30 reorders the screener ranking at the cap boundary, funding different
candidates. Same-count was coincidence of capacity, not selection inertia.

## Cohort P&L (realized, $M)

| cohort | baseline | w30 |
|---|---:|---:|
| shared 367 tickets | +6.2 | +6.6 |
| swapped 820 tickets | **+64.7** | +7.0 |

**AXTI 2025-06-28 alone = +$62.6M of the +$64.7M.** Ex-AXTI the
baseline-only book nets ≈ +$2.1M — i.e. **excluding the single lottery
ticket, w30's replacement book WINS (+7.0 vs +2.1) with better DD (29.0
vs 32.3)**. Next forfeited names after AXTI: DDD 2020 (+4.4), BVN 2023
(+1.8), EGHT/BKE/AN 2020 (~+1.1-1.3 each) — the crash-recovery cohort,
as the AXTI forensic predicted.

## Year-end equity ratio (w30 / baseline)

2000-04: 1.00 → 0.70 (dot-com-recovery cohort forfeited)
2005-19: 0.70 → **0.99** (w30 outperforms ~+2.4pp/yr for 15 straight years)
2020-24: 0.99 → 0.87 (COVID-recovery cohort: DDD, EGHT, BKE, AN)
2025-26: 0.87 → **0.26** (AXTI chain: baseline $18.7M → $80.1M in 18mo)

## Reading

The mechanism's cost is not a diffuse tax — it is concentrated in
**post-crash recovery windows** (2003-04, 2020-21, 2025-26), exactly when
the market itself sits under broad overhead supply and the biggest
winners are recovery breakouts *through* that supply. Outside those
windows the supply weight is a clean improvement (fold Sharpes + the
2005-2019 equity ratio agree).

This maps 1:1 onto the two designed levers:

1. **Regime softener** (`w × (1 − k·index_supply)`) — targets precisely
   the three loss windows: when the index itself is below prior highs,
   soften the penalty. STATE-based, no bottom-calling.
2. **Virgin-crossing re-admission** — restores the redeemed-monster
   entry (AXTI at $11-17) that staleness currently forfeits.

## What this changes for the promotion decision

The question is no longer "accept losing ¾ of terminal wealth?" but
"accept losing the *single-draw lottery ticket* in exchange for a
better book everywhere else — or first build the lever that keeps both?"
The rolling-start distribution (in flight,
`/tmp/sweeps/rolling-start-promo/`, 13 paired biennial starts 2000-2024,
fixed end 2026-06-26) quantifies how often a path's terminal wealth is
AXTI-dominated vs w30-favored.

Method note: realized-P&L cohort sums above are not compounding-aware
(the equity-ratio timeline is the compounding-honest view); both agree
on the story.
