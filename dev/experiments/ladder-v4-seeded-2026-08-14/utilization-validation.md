# Is capital utilization too low? — 2026-08-14

Question asked directly: do we have validation that utilization is not chronically
low, *excluding* the periods where low utilization is correct — the initial ramp,
bear markets, and the moment right after an exit releases capital before a new
entrant takes the slot?

**We did not. There is no utilization series in any run artifact.**
`equity_curve.csv` carries only `date,portfolio_value`; `open_positions.csv` is a
single end-of-run snapshot. The only built-in view is the trade-audit HTML
report's capital-utilization chart, which needs a bar source and was itself the
subject of a split-basis defect (raw share count against a raw NAV, fixed by
#2265 on the G4 contract).

This reconstructs it from `trades.csv` + `equity_curve.csv` + `macro_trend.sexp`.

## Method

Cost-basis utilization, daily:

```
deployed(t) = Σ  quantity × entry_price   over trades with entry_date ≤ t < exit_date
util(t)     = deployed(t) / portfolio_value(t)
```

`quantity` and `entry_price` are both restated onto the exit leg's split basis
(`metrics.mli`), so their product is internally split-consistent — this is
deliberately *not* the mark × raw-share shape that #2265 fixed.

Cell `00-core-w4`, 26y × top-3000, 6,895 days. Macro state carried forward from
the weekly `macro_trend.sexp` reading.

## Result — not low. Saturated when the gate is open.

Configured ceiling is **70%** (`max_long_exposure_pct 0.70`, `min_cash_pct 0.30`).

| macro state | mean utilization | days | days <30% |
|---|---|---|---|
| **Bullish** | **70.2%** | 3861 | **2.2%** |
| Neutral | 61.3% | 989 | 13.3% |
| Bearish | 22.3% | 2041 | 69.1% |

Overall mean 54.7%; 14.2% of all days below 10%, 56.5% at or above 60%.

**In bullish regimes utilization sits at the configured cap.** There is no
headroom being wasted. The 2.2% of bullish days under 30% bounds the
"capital released, no new entrant yet" case to a rounding error.

By year, the only sub-20% years are the ones that should be:

| | | | |
|---|---|---|---|
| 2000 53.7% | 2001 **12.0%** | 2002 **17.5%** | 2003 46.8% |
| 2004 50.7% | 2005 66.6% | 2006 61.6% | 2007 62.9% |
| 2008 **8.6%** | 2009 40.2% | 2010 50.4% | 2011 41.5% |
| 2012 60.7% | 2013 72.8% | 2014 71.3% | 2015 54.3% |
| 2016 60.0% | 2017 73.3% | 2018 69.4% | 2019 70.0% |
| 2020 60.0% | 2021 65.9% | 2022 51.1% | 2023 75.2% |
| 2024 66.4% | 2025 65.2% | 2026 42.6% (partial) | |

2001, 2002 and 2008 are the macro gate blocking buys through the dot-com bust and
the GFC — the intended behaviour, and the user's own carve-out. Every year from
2003 onward sits between 40% and 75%.

## What this implies

**In bull markets the system is capital-constrained, not candidate-constrained.**
The cash floor binds before candidate supply does. That is the direct answer to
"are we trading too much / do we have too many candidates" from the other side:
additional candidates would not be deployed, because there is no cash to deploy
them with. Any work on candidate supply should be justified on selection quality,
not on throughput.

It also means utilization is **not** the explanation for the concentration gap in
`project_record_gap_is_concentration` (record 4.9 concurrent positions vs our
10.6 at the same ~70% exposure). We deploy the same fraction of capital; we
spread it over roughly twice as many names. The lever there is position size, not
deployment rate.

## Caveats

- **Cost basis, not mark-to-market.** The right measure for "how much capital is
  committed", but not the number a mark-based chart would print. A position that
  has doubled still counts at cost here.
- **One cell, on the pre-#2279 binary.** Utilization is structural — position
  sizing against NAV — so it is far less exposed to the unseeded intraday path
  than returns are, but it should be re-confirmed on the seeded run rather than
  assumed.
- **Bullish mean marginally exceeds the 70% cap** (70.2%). Expected: the exposure
  limit is enforced at entry against then-current NAV, so a later NAV drawdown
  raises the ratio without any new buying.

## Follow-up worth doing

Emit a utilization (or cash) series into the run artifacts. Reconstructing it by
hand from three files is why this question went unanswered until it was asked
directly, and every future "are we deploying?" question pays the same cost.
