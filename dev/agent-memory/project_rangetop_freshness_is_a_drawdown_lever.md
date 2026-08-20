---
name: project-rangetop-freshness-is-a-drawdown-lever
description: "entry_freshness_basis=Range_top_breakout (the book's §4.7 pre-breakout GTC placement) cuts mean MaxDD 38.76→30.81 (-21%) on the 26y top-3000 base, beating drawdown's own null at all 3 salts — while return and Sharpe flip sign and stay inside their nulls. NOT an exposure artifact: rt holds MORE concurrent positions and deploys MORE capital at every salt."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7959dddf-3101-4cab-8f02-c90b77a7d8fd
  modified: 2026-08-20T12:44:49.420Z
---

**The book's §4.7 order mechanics buy drawdown, not return.** Six-cell paired
seeded run, 26y top-3000, 2026-08-20 (`dev/experiments/rt-freshness-seeded-2026-08-20/`).

`entry_freshness_basis = Range_top_breakout` screens the setup while it is still
**under** the range top and rests a GTC buy-stop at the anchor, instead of
admitting only after the MA cross. Single-flag delta off `ttl-retest-00-null`.

| salt | core DD | rt DD | Δ | return Δ |
|---|---:|---:|---:|---:|
| 0 | 39.03 | **27.68** | **+11.35** | +73.4 (in-null) |
| 1 | 36.25 | **31.42** | **+4.83** | −9.1 (in-null) |
| 2 | 41.01 | **33.34** | **+7.67** | +282.8 (BEAT) |
| mean | 38.76 | **30.81** | **−7.95pp / −21%** | +115.7 (in-null) |

**Nulls, from core's own three salts** — the reason the six-cell design was
necessary: return **132.51pp**, MaxDD **4.76pp**, Sharpe 0.0797, trades 37. The
prior seeded run recorded only return + trades, so **drawdown's null had never
been measured** — and drawdown is the metric that moves. Two cells would have
concluded nothing.

Return and Sharpe **flip sign** between salts ⇒ not moved. MaxDD beats its null
at all three, same direction ⇒ moved. ⚠ Salt 1 clears by only **0.07pp**.

## NOT the position-count artifact

[[project-entry-cap-horizon-reversal]] warns a MaxDD-led win is an exposure
signal until proven otherwise. Measured from `trades.csv` (time-weighted over
the 9,671-day span):

| salt | avg concurrent | avg deployed |
|---|---|---|
| 0 | 5.71 → **5.77** | $1.23M → **$1.53M** |
| 1 | 5.53 → **5.67** | $1.29M → **$1.36M** |
| 2 | 5.61 → **5.62** | $1.16M → **$1.68M** |

**rt is MORE exposed at every salt and less drawdown-prone at every salt.** The
artifact explanation is refuted in the opposite direction. rt also turns over
less (1105 vs 1151 trades at higher concurrency ⇒ ~6% longer holds).

## Instrument validation

All three tripwires reproduced the recorded draws digit-for-digit
(281.707836178685 / 397.94778549196963 / 265.44150500657236), and the measured
null reproduced the historical one exactly — 132.51pp return, 37 trades vs a
record of 132.5 and 37.

## Reconciles the horizon contradiction

The 5y sp500 testbed (187 traded names, deterministic) said rt was much WORSE:
112.28 → 45.33, Sharpe 1.105 → 0.603, MaxDD 16.98 → **21.43**, holds 45.4 → 34.4.
The unseeded 26y hinted the opposite (44.28 → 32.51). Both are explained: **5
years of 187 names cannot resolve a ~3pp drawdown effect**, and the 5y window is
one bull-heavy regime. Note rt held *shorter* on 5y and *longer* on 26y — the
axis behaves differently across horizons, so 5y is not a proxy for it.

## Status

**Not promotable.** One universe, one window ⇒ earns a confirmation grid
(≥3 period × universe cells, one macro-diverse) per
[[project-promotion-confirmation-grid]], not a default flip. Do **not** quote
the +115.7pp mean return gain — it is inside the null.

Related: [[project-entry-cap-horizon-reversal]] (the null-measurement discipline
this run applied), [[project-record-gap-is-concentration]] (concurrency ~5.7 both
arms vs the record's 4.9).
