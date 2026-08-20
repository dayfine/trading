---
name: project-rangetop-freshness-is-a-drawdown-lever
description: "entry_freshness_basis=Range_top_breakout (the book's §4.7 pre-breakout GTC placement) is a SELECTIVITY lever on the 26y top-3000 base: ulcer index -26.5%, win rate +1.73pp, MaxDD -21% — all three beat their own nulls at all 3 salts, while return and Sharpe flip sign and stay in-null. Not an exposure artifact (concurrency does NOT fall) but also NOT 'more exposed'. Does not reconcile the 5y testbed, which moved DD the other way."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7959dddf-3101-4cab-8f02-c90b77a7d8fd
  modified: 2026-08-20T14:53:38.010Z
---

**The book's §4.7 order mechanics buy risk-shape, not return.** Six-cell paired
seeded run, 26y top-3000, 2026-08-20 (`dev/experiments/rt-freshness-seeded-2026-08-20/`).

`entry_freshness_basis = Range_top_breakout` screens the setup while it is still
**under** the range top and rests a GTC buy-stop at the anchor, instead of
admitting only after the MA cross. Single-flag delta off `ttl-retest-00-null`.

## Three metrics move, not one

| metric | core → rt (mean) | weakest leg | verdict |
|---|---|---|---|
| **ulcer index** | 14.98 → **11.02** (−26.5%) | **1.43×** null (1.851) | MOVED |
| **win rate** | 33.18% → **34.91%** | **1.96×** null (0.496pp) | MOVED |
| **max drawdown** | 38.76 → **30.81** (−21%) | **1.02×** null (4.76pp) | moved, fragile leg |
| return | 315.0 → 430.7 | sign flips | **not moved** (null 132.51pp) |
| Sharpe | sign flips | — | **not moved** (null 0.0797) |

⚠ An earlier version of this memory said **"moves drawdown and nothing else"**
— false, corrected 2026-08-20 by qc-behavioral on #2433. **Ulcer index repairs
MaxDD's fragile leg** (1.02× → 1.43×): a path-integrated drawdown measure is
less noisy than a single extremum. The shape is *selectivity* (fewer trades,
longer holds, more of them win), not "less risk" alone.

Per-salt MaxDD: 39.03→27.68 (+11.35), 36.25→31.42 (+4.83), 41.01→33.34 (+7.67).
Salt 1 clears by 0.07pp — the finding rests on s0/s2 being comfortable and s1
not contradicting.

## NOT the position-count artifact — but NOT "more exposed" either

[[project-entry-cap-horizon-reversal]] warns a MaxDD-led win is an exposure
signal until proven otherwise. Measured from `trades.csv`, time-weighted over
the 9,671-day span: concurrency 5.71→5.77 / 5.53→5.67 / 5.61→5.62.

⚠ An earlier version said **"rt is MORE exposed at every salt"** — overclaim,
corrected. Those gaps (+0.059 / +0.146 / +0.007) are **inside concurrency's own
null of 0.187**. And the raw dollar-deployment rise tracks the equity rise
almost exactly (×1.248 vs ×1.231, ×1.053 vs ×1.056, ×1.452 vs ×1.393); equity-
normalised, the fractional gaps flip sign (0.322→0.337, 0.260→0.279,
0.316→**0.259**).

**What survives is the half the conclusion needs: rt is NOT LESS exposed**, so
the ulcer/DD improvement cannot be "it holds less." rt does turn over less:
1105 vs 1151 trades at equal concurrency ⇒ ~5.5% longer holds (47.2→49.8 days).

## The 7.8pp objection to drawdown's null

`dev/notes/ladder-v4-read-2026-08-12.md` records a **behaviourally identical**
config pair on this same base differing by **0.222 Sharpe and 7.8pp of
drawdown** — exceeding two of the three gaps here. It is the **nondeterministic
binary's** contamination: that same doc puts its *return* floor at 278pp where
the seeded binary measures 132.51pp (2.1× tighter); drawdown shrinks the same
way, 7.8 → 4.76 (1.6×). #2279's path-seed fix is what removed the excess.

## Instrument validation

All three tripwires reproduced the recorded draws digit-for-digit
(281.707836178685 / 397.94778549196963 / 265.44150500657236); measured null
reproduced the historical one exactly — 132.51pp return, 37 trades vs a record
of 132.5 and 37.

## Does NOT reconcile the horizons

⚠ An earlier version claimed it did, on the grounds that "5 years of 187 names
cannot resolve a ~3pp drawdown effect." **That threshold was asserted, never
derived.** The 5y sp500 testbed (2019-2023, 187 traded names) moved MaxDD
**16.98 → 21.43, +4.45pp the wrong way**, and it is single-realization
deterministic — so its own drawdown null has never been measured. Dismissing it
needs a 5y floor above ~4.5pp that no run establishes.

**Cheapest next measurement in the whole program:** salt the 5y testbed three
ways (minutes of compute) and read its drawdown floor directly.

The only independent 26y support is directional: unseeded ladder-v4 put
core-w4 at 44.2845 and `02-fresh-rangetop` at 32.5078 — but those live in
**untracked** `.sweep-output/ladder-v4-artifacts-2026-08-12/`, from the
nondeterministic binary whose own DD contamination is 7.8pp, so an 11.78pp gap
is barely above its noise. Agrees in sign; not evidence alone.

## Status

**Not promotable.** One universe, one window ⇒ earns a confirmation grid
(≥3 period × universe cells, one macro-diverse) per
[[project-promotion-confirmation-grid]], not a default flip. Do **not** quote
the +115.7pp mean return gain — it is inside the null.

Related: [[project-entry-cap-horizon-reversal]] (the null-measurement discipline
this run applied), [[project-record-gap-is-concentration]] (concurrency ~5.7 both
arms vs the record's 4.9), [[feedback-run-the-null-control-first]].
