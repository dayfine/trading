# Rolling-start "impossible drawdown" investigation (A2)

**Date:** 2026-06-12 · **Trigger:** A2 from
`dev/experiments/rolling-start-matrix-2026-06-11/ANALYSIS.md` · **Status:**
ROOT-CAUSED (upstream, in portfolio cash accounting); reproduction is
warehouse-gated; **no fix in the rolling-start layer** (a guard there would
mask a real signal).

## The symptom

The 2026-06-11 preliminary matrix's `2023-01-26` start row reported:

- `MaxDrawdown` = **190.4 %**
- `MaxUnderwaterVsInitialPct` = **156.3 %**

For a long-only, 0.70-max-exposure portfolio the NAV cannot fall below
−56 % of initial capital, so a >100 % drawdown is impossible *if the NAV
series is correct*. The analysis flagged this as a runner/metric bug
(suspects: forked-summary projection, NAV reconstruction).

## What the two metrics arithmetically require

Both metrics are computed straight off the per-step `portfolio_value` (NAV)
series inside the backtest, then read verbatim out of `summary.metrics` by
the rolling-start projection. They are simple and bounded **for non-negative
NAV**:

- `drawdown_computer.ml`: `MaxDD = max over steps of (peak - value)/peak*100`.
  `190.4 %` ⇒ some step had `value = peak*(1 - 1.904) = -0.904*peak` — i.e.
  **NAV went negative** (≈ −90 % of the running peak).
- `capital_relative_drawdown_computer.ml`:
  `MaxUnderwater = max over steps of max(0, (initial - value)/initial*100)`.
  `156.3 %` ⇒ `value = initial*(1 - 1.563) = -0.563*initial` — again **NAV
  went negative** (≈ −56 % of the starting stake).

The two values are internally *consistent*: they are different lenses (peak-
relative vs initial-relative) on the **same negative-NAV step(s)**. This rules
out a fork/projection mixing bug — both come from one run's one equity curve.

## Ruling out the rolling-start layer

- `Rolling_start_runner.per_start_of_summary` reads `MaxDrawdown` /
  `MaxUnderwaterVsInitialPct` directly from `summary.metrics`; it does **not**
  recompute drawdown. No transformation that could inflate them.
- `Fork_pool` marshals back the finished `per_start` record (floats + a Date),
  reassembled by **input index** — not the raw `Summary.t`. The projection runs
  *inside* each child against that child's own summary. There is no cross-start
  summary leakage across the fork boundary.
- The equity curve the rolling-start layer builds (`result.steps |> map
  portfolio_value`) feeds only `time_underwater_pct`; the DD metrics come from
  the summary the simulator already computed. So the layer faithfully reflects
  whatever NAV the backtest produced.

Conclusion: the >100 % values are a **true reflection of a negative NAV step**
emitted by the backtest, not a rolling-start metric/projection defect.

## Root cause (upstream — portfolio cash accounting)

`portfolio_value positions cash market_prices = cash + Σ qty*price`
(`trading/trading/portfolio/lib/calculations.ml`). For long-only, `qty ≥ 0`
and `price ≥ 0`, so `Σ qty*price ≥ 0`. The only way NAV goes negative is
**`current_cash` going sufficiently negative**.

`current_cash` *can* go negative. The buy-side cash floor
(`Portfolio._check_sufficient_cash`, `portfolio.ml:338`) is:

```
new_cash       = current_cash + cash_change            (cash_change < 0 on a buy)
unrealized_drag = Σ min(0, unrealized_pnl_per_position) (only paper LOSSES count)
effective_cash  = new_cash + unrealized_drag
permit iff effective_cash ≥ 0
```

Two properties make this a footgun under a multi-year broad-universe run:

1. **The floor permits negative `new_cash`.** As long as the (clamped-negative)
   unrealized drag is small, a buy can push `current_cash` below zero. The
   invariant enforced is "cash + paper-loss-cushion ≥ 0", *not* "cash ≥ 0".
2. **`unrealized_pnl_per_position` is STALE.** Per the comment at
   `portfolio.ml:_refresh_unrealized_after_trade`, the accumulator is only
   refreshed on `mark_to_market`; between marks it carries the prior mark's
   numbers (and new positions seed at 0.0). So the floor is checked against an
   **outdated** cushion. If positions have since fallen, the *true* cushion is
   more negative than the floor believes, and the buy is permitted on an
   optimistic estimate.

When a later `mark_to_market` re-prices those holdings with fresh (lower)
bars, `portfolio_value = (already-negative cash) + (now-lower position value)`
can dip **below zero**, and the drawdown computers — correctly — report
>100 %. The 2023-01-26 start (a 2023 chop/drawdown entry into the broad
top-3000-2011 universe) is exactly the regime where many fresh buys are made
into names that then fall before the next weekly mark.

This is a *different* mechanism from the historical 2026-05-15 NAV-fallback bug
(`project_simulator_nav_fallback_bug.md`), which was fixed (#1123) and could
only ever produce ≤100 % MaxDD (it flatlined NAV to **non-negative** cash). A
>100 % MaxDD cannot come from that fallback — it requires a genuinely negative
NAV, which is the stale-drag-floor path above.

## Reproduction (warehouse-gated)

A faithful reproduction needs a full backtest that actually drives cash
negative, which requires the maintainer-local top-3000-2011 snapshot warehouse
(`/tmp/snap_top3000_2011`) — not available in CI / the devcontainer. The
precise repro:

```
rolling_start_eval --scenario <cell-E scenario>
  --snapshot-dir /tmp/snap_top3000_2011 --benchmark GSPC.INDX
  --end-date 2026-04-30 --start-stride-days 170 --jitter-seed 42 --parallel 1
# inspect the 2023-01-26 start's per-step NAV (equity curve); expect a
# negative portfolio_value step.
```

A *unit-level* reproduction of the metric propagation (negative NAV ⇒ >100 %
DD) is trivial and already implied by the arithmetic above, but it would only
re-assert that the computers are correct — it would NOT exercise the actual
defect (the stale-drag cash floor), which lives in `Portfolio` and needs a
trade sequence + marks to trigger. Pinning *that* belongs with the portfolio /
`feat-weinstein` owners, not the rolling-start tooling.

## Why no guard was added in the rolling-start layer

Clamping or rejecting >100 % DD in `per_start_of_summary` would **mask a real
data-integrity signal** — the same anti-pattern `portfolio_valuation.ml`
deliberately replaced with fail-loud (#1123, `project_simulator_nav_fallback_bug`).
The honest behaviour is to surface the impossible number so it is investigated,
which the matrix did. The rolling-start layer is correct as-is.

## Recommended follow-up (owner: portfolio / feat-weinstein)

1. **Fix the cash floor to use a fresh mark, or enforce `current_cash ≥ 0`
   for long-only.** The stale `unrealized_pnl_per_position` should be refreshed
   (or the floor should not credit a stale cushion) before permitting a buy
   that drives cash negative. Simplest faithful option: for long-only configs,
   require `new_cash ≥ 0` (no paper-loss credit) — Weinstein is cash-funded,
   not margin.
2. **Add a simulator-level invariant check** that `portfolio_value ≥ 0` for a
   long-only run (assert / fail-loud), so a negative NAV is caught at the
   source step rather than only surfacing as a >100 % DD metric downstream.
3. Until fixed, treat per-start `MaxDrawdown` / `MaxUnderwaterVsInitialPct`
   columns > 100 % as the "negative-NAV / cash-overdraft" tell, not as a real
   drawdown.
