# Status: spy-only-reference

## Last updated: 2026-06-01

## Status
IN_PROGRESS

## Interface stable
YES

`Spy_only_weinstein_strategy` is a deliberately minimal single-instrument
testbed (long/flat by default, `enable_stage4_short` opt-in), separate
from the production `Weinstein_strategy`. Lives at
`trading/trading/weinstein/strategy/lib/spy_only_weinstein_strategy.{ml,mli}`
+ `spy_only_transitions.{ml,mli}`. Constructed via
`Strategy_choice.Spy_only_weinstein { symbol; ma_period_weeks;
enable_stage4_short }`.

## Goal

A research-ladder testbed that isolates Weinstein stage timing on the
cleanest possible signal (the index itself), to learn which mechanism
helps at which layer. Objective: drawdown defense / risk-adjusted
return (operationalized as win-size ≫ loss-size asymmetry), NOT raw
return.

## Completed

- **SPY-only long/flat reference** (PR #1397, MERGED). Long/flat,
  reuses `Stage.classify` + `Weinstein_stops`, strips
  screener/sizing/macro. On the deep window it cut MaxDD to ~18.8%
  (vs BAH SPY ~34-55%) by going flat in Stage 4. 70% win, Calmar 0.48
  > BAH 0.37.
- **Investor 30wk vs trader 10wk MA dial** (PR #1401). 10wk trader
  REJECTED — strictly worse than 30wk investor on both bull + deep
  windows. Investor 30wk is the drawdown-insurance sweet spot.
- **Stage-4 short leg** (`enable_stage4_short`, default-off testbed
  dial — THIS PR, `feat/spy-longshort`). When ON, the strategy goes
  short in Stage 4 instead of sitting flat: short sized like the long
  (`floor(cash/close)`), short stop via `Weinstein_stops ~side:Short`
  (above entry, ratchets down), covers when SPY leaves Stage 4 (Stage
  1/2) or on a short-stop hit. Default-off = bit-identical long/flat
  per `.claude/rules/experiment-flag-discipline.md` R1. Expressible as
  a scenario via `(enable_stage4_short true)`; scenario
  `spy-longshort.sexp`.

## Stage-4 short-leg result (report only — NOT promoted)

**Headline: the short leg does NOT lower MaxDD vs the long/flat twin
on either window — it RAISES it.** Same failure mode as the SP500
multi-symbol long-short: Stage-4 shorts get squeezed on fast-V bounces.

| window | scenario | Return | Sharpe | Calmar | MaxDD | Win% | trades | avg-win% | avg-loss% | win/loss ratio |
|---|---|---|---|---|---|---|---|---|---|---|
| 2009-2026 (post-GFC bull) | spy-investor (long/flat) | 317.9% | 0.77 | 0.48 | **18.8%** | 70.0% | 10 | 23.70 | -3.26 | 7.27 |
| 2009-2026 | spy-longshort (short ON) | 98.1% | 0.35 | 0.13 | **32.6%** | 36.0% | 25 | 18.68 | -5.26 | 3.55 |
| 1995-2025 (deep: dot-com + GFC + COVID) | spy-investor-deep (long/flat) | 1168.8% | 0.73 | 0.35 | **24.3%** | 52.4% | 21 | 30.79 | -2.81 | 10.97 |
| 1995-2025 | spy-longshort-deep (short ON) | 593.1% | 0.47 | 0.18 | **35.7%** | 37.5% | 48 | 21.97 | -4.60 | 4.77 |

Deep long-short trade decomposition (the smoking gun): of 48 closed
trades, the 21 LONGs are bit-identical to the long/flat twin (52.4%
win, +30.8/-2.8 asymmetry); the 27 SHORTs win only **25.9%** with
avg-win +8.1% / avg-loss -5.5% — a losing, drawdown-raising overlay.
On a deeper, macro-regime-diverse window (the regime where shorting
should help most), the short leg still halves return and raises MaxDD
24.3% → 35.7%.

Verdict: keep `enable_stage4_short = false` default. Shorting a single
clean instrument in sustained Stage-4 bears does NOT beat the long/flat
twin's drawdown — the V-bounce squeeze dominates even with the index's
clean signal. No promotion; testbed-only per R3.

## Next Steps

1. (Open question, not dispatched) If short-side drawdown defense is
   still wanted, the lever is NOT a naive Stage-4 short — test instead
   a regime-conditioned short (only short when the Stage-4 read has
   persisted N weeks AND the prior trend extreme is far below), or a
   put-overlay proxy. Both are new mechanisms, not dials; gate via the
   experiment ledger.
2. The long/flat investor 30wk remains the reference floor; selection
   (Cell E multi-symbol) ≫ timing for total return — see
   `dev/notes/spy-mode-comparison-2026-06-01.md`.

## References

- `trading/trading/weinstein/strategy/lib/spy_only_weinstein_strategy.mli`
  — `config` + `enable_stage4_short` short mechanics.
- `trading/trading/weinstein/stops/lib/weinstein_stops.mli` — `~side:Short`
  stop (above entry, ratchets down; `check_stop_hit` on `high ≥ stop`).
- `trading/test_data/backtest_scenarios/spy-longshort.sexp` — short-on
  scenario (2009-2026 window; deep companion run reported, not pinned).
- `docs/design/weinstein-book-reference.md` §Short-Selling Rules — shorting
  Stage-4 declines is faithful (the spine permits it; W1 intact).

## Ownership
`feat-weinstein` agent.
