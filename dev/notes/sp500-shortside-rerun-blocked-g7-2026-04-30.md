; Title; date

# sp500 short-side rerun blocked — new gap G7 (position sizing for shorts)

Re-enabling shorts on `goldens-sp500/sp500-2019-2023` per
`dev/notes/short-side-gaps-2026-04-29.md` § "Re-enabling shorts" (after G1–G5
landed via #689–#695) was attempted on 2026-04-30. The rerun produced
broken metrics that traced to a NEW gap, not a recurrence of G1–G4. The
`enable_short_side = false` override stays in place until G7 closes.

## Run captured

Container path: `/workspaces/trading-1/dev/backtest/scenarios-2026-04-30-001624/sp500-2019-2023/`.

| Metric | With-shorts (post G1-G5) | Long-only baseline (canonical 2026-04-28) |
|---|---:|---:|
| Total return | **−5.20 %** | +70.80 % |
| Total trades | **1,530** | 134 |
| Win rate | 54.12 % | 38.06 % |
| Sharpe | 0.04 | 0.39 |
| Max drawdown | 53.41 % | 97.69 % (split-day phantom) |
| Avg holding days | **3.47** | 72.63 |
| Realized PnL | −$8K | +$198K |
| Unrealized PnL | $0 | $1,675K |
| Final portfolio value | $947,606 | (not pinned) |
| Trade frequency / mo | 45.84 | 5.03 |
| **Force-liquidation events** | **910** | n/a |

Side breakdown (with-shorts):
- 1,499 long round-trips: **+$443,819 PnL**
- 31 short round-trips: **−$451,947 PnL** (shorts cost $452K against long gains of $444K → net negative)
- 12,154 long entries vs 152 short entries in `trade_audit.sexp`
- 901 long force-liquidations + 9 short force-liquidations, all reason `Portfolio_floor`

## G7 — Position sizing for shorts is broken

**Symptom**: `trade_audit.sexp` records ABBV short opened 2019-02-01 with
`initial_position_value $1,238,483` against a $1M starting portfolio
— a 124 %-of-portfolio position. The cash floor (G3 fix, #694) does NOT
prevent this entry, even though `entry_audit_capture.ml:109`'s
`check_cash_and_deduct` literally compares `cost > remaining_cash` (which
should be `1,238,483 > 1,000,000 = TRUE → reject`).

**First force-liquidation cascade**: ABBV (2019-03-12) was a *profitable*
short (+22 % unrealized) when `Portfolio_floor` force-closed it — the
position was sized so large that the portfolio breached the value floor
regardless of price direction. The 910 force-liquidation events are
evidence the strategy's primary risk machinery (sizing + stops) is being
over-ridden by force-liquidation as the primary exit mechanism, not as
last-resort.

**Avg holding days collapse**: 72.6 → 3.47. The strategy is not "holding
through the cycle" — it's churning rapidly because every entry is force-
liquidated within 2-4 bars by the value floor.

**`risk_pct 0.08` in audit** vs `risk_per_trade_pct 0.01` default —
indicates either the scenario's `portfolio_config` is overriding the
default to 8 % risk per trade, or there's a calculation mismatch between
sizing and the recorded audit. Worth confirming before fixing.

## Hypotheses for fix surface

Three candidate causes (one or more may be true):

1. **G3 cash-check path bypassed for shorts.** G3 (PR #694) added a soft
   cash floor using `unrealized_pnl_per_position` accumulator. Possible
   that the `_check_sufficient_cash` extension only enforces the floor on
   *cover* (Buy after Sell), not on *entry* (Sell). Re-read
   `trading/trading/portfolio/lib/portfolio.ml` `_calculate_cash_change`
   and `_check_sufficient_cash` for the Sell-entry branch. Verify against
   the G3 PR's tests — they cover sequence-of-shorts but may not cover
   the single-position-too-large case.

2. **`compute_position_size` sign bug for shorts.**
   `trading/trading/weinstein/portfolio_risk/lib/portfolio_risk.ml`
   lines 124-145. For shorts, share count should be scaled by
   `available_short_collateral / share_price`, not raw portfolio value.
   The position appears to be sized as if the entire portfolio is
   collateral, ignoring `max_short_exposure_pct`.

3. **`target_quantity` semantics mismatch.** Audit log records
   `12,191 shares × $101.59 = $1.238M` for ABBV. If `target_quantity`
   for shorts is being computed as positive shares but the cash check
   later flips sign and ignores the cost-magnitude check, the entry
   passes a cash check that should have rejected it.

## Pre-fix verification

Before any code change, write a unit test in
`trading/trading/weinstein/portfolio_risk/test/test_portfolio_risk.ml` that:
- Builds a $1M portfolio + a $100/share short candidate.
- Calls `compute_position_size` with default `risk_per_trade_pct = 0.01`,
  default `max_short_exposure_pct` (currently 0.5 per the design docs).
- Asserts `target_quantity * entry_price ≤ max_short_exposure_pct *
  portfolio_value`.

Currently this test (or its absence) is the vector for the bug.

## Fix surface (post-investigation)

Likely a small change in `compute_position_size` or `_check_sufficient_cash`
+ a regression test. Should not exceed 200 LOC.

## Connection to G4 force-liquidation

The 910 force-liquidations are the **G4 mechanism doing its job** — they
prevented the portfolio from going as deep negative as the pre-G4 rerun
(−144.5 %, 245.8 % MaxDD). G4 saved the run from total wipeout. But the
G4 spec explicitly notes a non-zero force-liquidation count is a red
flag the primary risk machinery isn't doing its job — and 910 is far
beyond "occasional safety net." This is exactly the audit signal G4 was
designed to surface.

Fixing G7 should drop the force-liquidation count to single-digits or
zero; if it remains hundreds, there's another gap underneath.

## Updated re-enabling sequence

`dev/notes/short-side-gaps-2026-04-29.md` § "Re-enabling shorts" should
be updated to:

> Once **G1 + G2 + G3 + G4 + G7** close, the sp500 scenario's
> `config_overrides` should be reverted...

i.e., G7 is now a precondition. Owner: `feat-weinstein` (portfolio_risk
+ portfolio sizing scope).

## Files relevant to G7 investigation

- `trading/trading/weinstein/portfolio_risk/lib/portfolio_risk.ml`
  (`compute_position_size`)
- `trading/trading/weinstein/strategy/lib/entry_audit_capture.ml`
  (`check_cash_and_deduct`, line 105-114)
- `trading/trading/portfolio/lib/portfolio.ml`
  (`_check_sufficient_cash`, `_calculate_cash_change`)

## What was NOT done (deliberately)

- No PR opened — STOP rule fired (force-liquidation count > 100).
- No re-pinning of `expected` ranges in the scenario file — broken run.
- No update to status files yet — that's a downstream PR after G7 lands.
