# sp500 short-side rerun blocked — new gap G9 (force-liquidation portfolio_value sign bug)

Re-enabling shorts on `goldens-sp500/sp500-2019-2023` per
`dev/notes/short-side-gaps-2026-04-29.md` § "Re-enabling shorts" (after G1–G5 +
G7 + G8 landed via #689–#705) was attempted on 2026-04-30 PM. The rerun
produced metrics that traced to a NEW gap, not a recurrence of G1–G8. The
`enable_short_side = false` override stays in place until G9 closes.

This note supersedes the prior
`dev/notes/sp500-shortside-rerun-blocked-g7-2026-04-30.md` which documented
the now-closed G7. G9 is the immediate downstream gap surfaced after G7+G8
fixes were applied to the production scenario.

## Run captured

Container path: `/workspaces/trading-1/dev/backtest/scenarios-2026-04-30-130835/sp500-2019-2023/`.

| Metric | Value |
|---|---:|
| Total return | **+22.79 %** |
| Total trades | **1,572** |
| Win rate | 53.82 % |
| Sharpe | 0.43 |
| Max drawdown | **22.59 %** |
| Avg holding days | **3.46** |
| Unrealized PnL | $0 |
| Final portfolio value | $1,227,943.74 |
| **Force-liquidation events** | **928** |
| Realized PnL | +$282,103.78 |
| CAGR | +3.76 % |

Compare to:
- Long-only canonical baseline (2026-04-28, bfbd105f): 134 trades / +70.8 % / 97.7 % MaxDD (the 97.7 % is split-day phantom, see decisions.md).
- G7-blocked rerun (2026-04-30 AM, pre-G7+G8): 1,530 trades / -5.2 % return / 53.4 % MaxDD / 910 force-liquidations / 3.47 avg holding.
- G8 partially-applied rerun (post-G7, no G8): 1,514 trades / +29.4 % / 69.4 % MaxDD / 902 force-liquidations.
- This G7+G8 rerun: **1,572 trades / +22.8 % / 22.6 % MaxDD / 928 force-liquidations / 3.46 avg holding**.

## Decision-tree result

Per the rerun task's decision tree:

| Criterion | Threshold | Actual | Verdict |
|---|---|---|---|
| Total return | > -10 % | +22.79 % | PASS |
| Force-liquidation count | ≤ 50 | **928** | **FAIL** |
| Portfolio value never goes negative | true | true (min $774K on 2019-02-15) | PASS |
| Avg holding days | > 20 | **3.46** | **FAIL** |
| Position sizing (3 short entries) | ≤ 30 % of portfolio | $104K / $124K / $124K — all ≤ 13 % | PASS |

Two FAILs: force-liquidation count and avg holding days. Override stays.

## What G7+G8 fixed

**G7 (#702)** — `Portfolio_risk.compute_position_size` now respects
`max_short_exposure_pct`. Verified in audit: ABBV 2019-02-01 short
entry sized at 1,025 shares × $101.59 = $104,129.75 (10.4 % of $1M
portfolio), down from pre-fix 12,191 shares × $101.59 = $1,238,483
(124 %). All short entries in the new rerun have
`initial_position_value` clustered around $100K-$125K — never breaching
the 30 % cap.

**G8 (#705)** — `Portfolio_view._holding_market_value` now signs by
`pos.side`, so shorts contribute `-quantity × close_price` (a
liability) rather than `+quantity × close_price` (an asset). Verified
by the lower MaxDD (22.6 % vs. prior 53-69 %) and by `unrealized_pnl =
$0` at run end (positions all closed via force-liquidation rather than
left mark-to-market open).

## G9 — `Force_liquidation_runner._portfolio_value` has the same shorts-sign bug as pre-G8 `Portfolio_view`

**Symptom**: the first batch of force-liquidations on 2019-02-14
includes ABBV short with `unrealized_pnl = +$21,596.75` (a 20.7 %
profit), CVS short at +$21,635, HWM short at +$30,412, and seven other
profitable shorts — all `reason = Portfolio_floor`. Profitable shorts
should not trigger Portfolio_floor; the floor fires when
`portfolio_value < peak * 0.40`. With the equity_curve showing minimum
$774,148.99 (which is 77 % of $1M starting cash, well above the 40 %
floor), Portfolio_floor should never have fired in this period.

**Root cause**: G8 fixed `Portfolio_view._holding_market_value` (file:
`trading/trading/strategy/lib/portfolio_view.ml`) to sign by
`pos.side`. But there is a SECOND, independent copy of the same
calculation in
`trading/trading/weinstein/strategy/lib/force_liquidation_runner.ml:33-41`
(`_portfolio_value`):

```ocaml
let _portfolio_value ~cash ~positions ~get_price =
  Map.fold positions ~init:cash ~f:(fun ~key:_ ~data:pos acc ->
      match pos.Position.state with
      | Position.Holding { quantity; _ } -> (
          match get_price pos.symbol with
          | Some (bar : Types.Daily_price.t) ->
              acc +. (quantity *. bar.close_price)   (* ← unsigned: bug *)
          | None -> acc)
      | _ -> acc)
```

`Position.t.state.Holding.quantity` is unsigned (always positive); the
side lives in `pos.side`. This pre-G8 formula adds `+quantity *
close_price` for shorts when it should subtract.

**Effect on the rerun**: cash inflates with each short entry (proceeds
credited). Buggy `_portfolio_value` adds positive position-values on
top of inflated cash → `portfolio_value` is roughly 2× the true value
when a portfolio is heavily short. `Peak_tracker.observe` records the
inflated peak. As shorts continue to profit (price drops), unsigned
`quantity * close_price` DECREASES (close_price is dropping), so
buggy `portfolio_value` DECREASES even when the true equity is
RISING. Peak stays high; current `portfolio_value` (buggy) drops below
40 % of inflated peak — Portfolio_floor fires on profitable shorts.

**Why G8 missed this**: G8's PR description names the fix as
`Portfolio_view._holding_market_value`. The sibling copy in
`Force_liquidation_runner._portfolio_value` was added by G4 (PR #695,
force-liquidation policy) before G8 was diagnosed; G8's qc-behavioral
review only tested the entry-sizing path (which uses
`Portfolio_view.portfolio_value`). The force-liquidation path's
internal portfolio_value was not on the patch radar.

The two functions have the same name suffix and intent but live in
different modules. The fix is mechanically identical to G8.

## Fix surface (G9)

Single-file change to `trading/trading/weinstein/strategy/lib/force_liquidation_runner.ml`:

```ocaml
let _portfolio_value ~cash ~positions ~get_price =
  Map.fold positions ~init:cash ~f:(fun ~key:_ ~data:pos acc ->
      match pos.Position.state with
      | Position.Holding { quantity; _ } -> (
          match get_price pos.symbol with
          | Some (bar : Types.Daily_price.t) ->
              let signed_qty =
                match pos.Position.side with
                | Long -> quantity
                | Short -> -. quantity
              in
              acc +. (signed_qty *. bar.close_price)
          | None -> acc)
      | _ -> acc)
```

A one-line equivalent: refactor `_portfolio_value` to delegate to
`Portfolio_view.portfolio_value` (with cash + positions adapted), so the
single source of truth lives in `Portfolio_view`. This is the better
long-term shape but requires a small adapter.

## Pre-fix regression test

Add a test under `trading/trading/weinstein/strategy/test/test_force_liquidation_runner.ml`:

- Build a portfolio with $1M cash, then enter a short of 1,000 shares
  at $100. After entry: cash = $1.1M, position is `Holding { quantity
  = 1000; ...}` with `pos.side = Short`. Current price stays at $100
  (zero P&L).
- Call `_portfolio_value ~cash:1_100_000.0 ~positions ~get_price` (one
  position).
- Pre-fix returns $1,200,000 (cash + 1000 × $100 = $1.1M + $100K =
  $1.2M, INFLATED).
- Post-fix returns $1,000,000 (cash - 1000 × $100 = $1.1M - $100K =
  $1M, CORRECT).

Same shape as G8's `test_portfolio_view`'s short-shorts test, just on
the other module. Pinning both call sites against the same scenario
prevents the third copy from diverging.

## Connection to higher-level metrics

After G9 closes, the expected outcome is:

- Force-liquidation count drops from 928 → single-digits or zero (Peak_tracker no longer sees inflated peak).
- Avg holding days rises from 3.46 → multiple weeks (positions exit via
  stop-loss and trend-failure as Weinstein intended, not via spurious
  Portfolio_floor force-closes).
- Total return likely changes (small short positions are no longer being
  yanked profitably-early; some will lose more before stops fire).

If after G9 the force-liquidation count remains in the dozens, there's
ANOTHER gap underneath (e.g., a per-position trigger or a
peak_tracker reset bug). G9 is the next-most-likely single fix; further
gaps would emerge after the rerun.

## Updated re-enabling sequence

`dev/notes/short-side-gaps-2026-04-29.md` § "Re-enabling shorts" needs:

> Once **G1 + G2 + G3 + G4 + G7 + G8 + G9** close, the sp500 scenario's
> `config_overrides` should be reverted...

i.e., G9 is now a precondition. Owner: `feat-weinstein` (force_liquidation_runner scope).

## Files relevant to G9

- `trading/trading/weinstein/strategy/lib/force_liquidation_runner.ml`
  (`_portfolio_value`, lines 33-41)
- `trading/trading/strategy/lib/portfolio_view.ml` (the post-G8
  reference shape)
- `trading/trading/weinstein/strategy/test/test_force_liquidation_runner.ml`
  (regression test home)

## What was NOT done (deliberately)

- No PR opened that re-enables shorts — STOP rule fired (force-liquidation count > 50 AND avg holding days < 20).
- No re-pinning of `expected` ranges in the scenario file — broken run.
- This finding committed as a docs-only PR; the G9 fix itself is left
  for a feat-weinstein follow-up PR.
