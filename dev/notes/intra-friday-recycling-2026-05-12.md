# Intra-Friday capital-recycling diagnostic — 2026-05-12

## Source

`dev/backtest/scenarios-2026-05-12-021705/entry-caps-15y-arm-a-baseline/trades.csv`
(15y Cell E baseline; 510 sym sp500-historical; 768 round-trips).

## Question

Per the candidate-supply bottleneck note (2026-05-11), `Insufficient_cash`
dominates rejection reasons. Hypothesis: T+1 settle delays + Friday-only
entry cadence leave ~1 week of cash idle between intraweek exit and next
Friday's entry decision. Verify against the trade tape.

## Findings

| Metric | Count | % |
|---|---:|---:|
| Distinct exit dates | 602 | 100% |
| of which on Friday (weekly cadence) | 280 | 46.5% |
| of which intraweek (Tue/Wed/Thu) | 303 | 50.3% |
| (Friday exits) with same-Friday entry | 165 | 59% of Friday exits |
| (Friday exits) with NO same-Friday entry | 115 | 41% of Friday exits |
| Distinct entry dates | 427 | (all Fridays) |
| Total Fridays in 15y window | ~780 | |
| Fridays with at least one entry | 427 | 55% |

Day-of-week distribution:

| | Exits | Entries |
|---|---:|---:|
| Friday close (stored as Sat) | 389 | 768 |
| Tue | 109 | 0 |
| Wed | 101 | 0 |
| Thu | 93 | 0 |
| Fri (intraday) | 76 | 0 |

## Verdict — recycling is modest, intraweek lag is real

1. **Intra-Friday recycling rate: 59%** of Friday exits coincide with
   same-Friday entries. The strategy uses freed cash within the same
   weekly decision cycle 59% of the time. The other 41% of Friday exits
   leave cash idle for at least one full week (no same-Friday entry).

2. **Intraweek exits leak 1-4 days of capital.** 50% of distinct exit
   dates are intraweek (~303 events over 15y, or ~20/yr). Each event
   leaves the position's notional sitting in cash until the next Friday.
   Average drag: ~2.5 days × 20 events/yr = ~50 trading-day-positions of
   idle capital per year.

3. **Most importantly: the strategy is NOT trying to fully deploy.** Of
   ~780 weekly Fridays, only 427 (55%) had any entries at all. With
   `min_cash_pct=0.30` already reserving 30% as buffer, plus 45% of
   Fridays with no entry, the strategy intentionally sits in cash a lot.

## Implications

The intra-Friday recycling lag is **not** the dominant capital-utilization
gap. Even fully eliminating it (T+0 same-week recycling on every exit)
would only buy back the ~50 idle-day-positions/yr from intraweek exits.

The bigger gap is **45% of Fridays produce zero entries** — the cascade
either has no qualifying candidates or all slots are full. Per the
candidate-supply bottleneck note, the cascade DOES emit ~12 candidates
per Friday on average, so "all slots full" is the dominant gate, not
"no candidates".

The candidate-supply bottleneck note's recommendation stands: the binding
constraint is **holding-period capital lock-up**, not Friday-only cadence
or T+1 settle. The 16-cell holding-period sweep
(`dev/experiments/holding-period-sweep-2026-05-12/report.md`) confirmed
that tweaking holding-period hysteresis doesn't materially help Sharpe
either — the strategy at this position-size config is near the front of
its risk-adjusted-return envelope.

## Closes

P5 from the 2026-05-12 overnight plan. Verifies the candidate-supply
note's diagnosis from a different angle (trade tape vs cascade
diagnostics). Both point to the same conclusion: per-position size
(`max_position_pct_long`) is the dominant capital-throughput lever, and
0.14 is already Sharpe-optimal per the 2026-05-10 sweep.
