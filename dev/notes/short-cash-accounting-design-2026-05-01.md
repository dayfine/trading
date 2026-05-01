# Short-cash accounting — broker-cash vs margin-cash semantics

Research note framing the architectural question that drives the
path-dependency between `sp500-2019-2023` (with shorts) and
`sp500-2019-2023-long-only`. Filed 2026-05-01 after G14 + G15 step 1
landed and the with-shorts variant settled at -1.2% return / 34% MaxDD
vs long-only's +26% / 41%.

## What the path-dependency analysis showed

Post-G14, comparing the two scenarios' long-trade composition:

```
with-shorts:       86 LONG entries
long-only:        113 LONG entries
shared (sym+entry_date):  46
identical (+ exit + qty):  0
```

Of the 46 longs that share `(symbol, entry_date)` across both scenarios,
**zero have matching quantities**. With-shorts sizes ~15–20% larger:

```
CCL  2023-06-10:  ws=9348 shares    lo=7897   (+18%)
ATO  2022-01-01:  ws=2180 shares    lo=1797   (+21%)
AEP  2022-01-29:  ws=2661 shares    lo=2225   (+20%)
```

Cause: short entry credits proceeds to `current_cash`. The next long's
position size is computed as
`portfolio_value × risk_pct / |entry − stop|`, where
`portfolio_value = cash + Σ signed_mtm`. At short entry,
signed_mtm contribution from the short = `-current * qty` ≈
`-entry * qty`, which roughly cancels the proceeds increase to cash.
But position sizing's denominator is dominated by `cash` (the larger
component) — so the next long's sizing scales with the inflated cash
balance.

Result: the same long entry day produces a 20% larger position when
shorts are open. With-shorts is implicitly leveraging.

## The architectural question

**Should short proceeds count as freely-available trading liquidity?**

Two stances, mapped to broker reality:

### Stance A: Cash-account semantics (current implementation)

Short proceeds are treated as ordinary cash. `Portfolio.current_cash`
is incremented by `entry_price * qty` at short entry. Position sizing
uses `Portfolio_view.portfolio_value` which includes that cash. Long
entries can be funded from short proceeds.

This corresponds to a (rare) trading account where shorts auto-credit
and the proceeds are usable for any new position — sometimes called
"cash-account shorting" but more typically refers to broker-internal
cash-management.

Implication: implicit leverage. A strategy with 30% short notional and
70% long notional has total exposure 100% of portfolio_value, but its
position-sizing-available-cash equals (initial_cash + short_proceeds)
which exceeds initial_cash. The strategy is effectively levered up by
the short notional.

### Stance B: Margin-account semantics (the standard real-world model)

Short proceeds are credited to a separate "short-margin account" and
NOT freely available for long entries. The trader's
"position-sizing-available cash" excludes those proceeds. Aggregate
exposure (long notional + short notional) is bounded by the actual cash
the trader put up.

This is how real brokerages handle shorts: Reg-T or Portfolio Margin
both keep short proceeds in a margin sub-account that secures the
buy-back liability, and may pay interest, but isn't freely deployable.

Implication: position sizing uses `current_cash − short_proceeds_held`
as the denominator. A 100K long-side strategy that opens a 30K short
position has 70K of usable-cash, not 130K. The scenario's long-side
sizing wouldn't inflate when shorts are added.

## Why this matters for G15 measurements

G15's first two steps (asymmetric per-position thresholds + 30% short
notional cap) make the with-shorts side safer at the per-trade and
per-portfolio levels. But neither addresses the cash-treatment question
— the two scenarios' long sides will continue to diverge in sizing.

Concrete consequence: if we attempt to attribute the with-shorts
return-vs-long-only return delta to "short-side P&L", the answer is
contaminated by the indirect long-sizing effect. The 27 percentage point
gap between -1.2% (with-shorts) and +26% (long-only) is part shorts'
direct contribution and part the inflated long-sizing's own performance
on different entries / different sizes.

This makes performance attribution noisy. Cleaner attribution requires
the strategies to make the same long decisions at the same sizes
across scenarios.

## Recommended design (Stance B)

Move to margin-account semantics. Rough shape:

1. **Add `short_proceeds_held : float` to `Trading_portfolio.Portfolio.t`.**
   Credited at short entry, debited at short exit (cover). Independent
   of `current_cash`. Total cash position remains
   `current_cash + short_proceeds_held` for accounting purposes, but
   the two halves are tracked separately.

2. **Modify `Portfolio.apply_single_trade` for shorts.** Today, opening
   a short does
   `current_cash += entry_price * qty`. Replace with
   `short_proceeds_held += entry_price * qty`. Closing a short (buy-back)
   today does `current_cash -= cover_price * qty`. Replace with
   `short_proceeds_held -= entry_price * qty` (release the held proceeds)
   plus `current_cash -= (cover_price - entry_price) * qty` (realised
   P&L; can be positive or negative).

3. **Modify position sizing.** `Portfolio_risk.compute_position_size`
   takes `~portfolio_value` today. It should additionally take
   `~sizing_cash` (= `current_cash`, NOT `short_proceeds_held`). Use
   `sizing_cash` (not `portfolio_value`) as the denominator for
   position-fraction-of-portfolio sizing. This is the one place the
   stance change actually affects strategy behaviour.

4. **Keep `Portfolio_view.portfolio_value` unchanged.** It still equals
   `current_cash + short_proceeds_held + Σ signed_mtm`. Reporting,
   force-liq, and equity_curve all continue to consume that.

5. **Trade-audit and reporting.** New `audit_recorder` entries for
   `Skipped` reason `Short_proceeds_held_not_available` if the cap
   pattern from G15 step 2 is reused. Cleanup audit records to track
   `short_proceeds_held` snapshots.

## LOC + risk estimate

- `trading/trading/portfolio/lib/portfolio.{ml,mli}` — type extension,
  apply_trade dispatch on side. Core module → A1.
- `trading/trading/portfolio/lib/types.mli` — possibly a new type
  for the bookkeeping breakdown.
- `trading/trading/portfolio/test/*` — extensive: every existing
  cash-flow test needs verification against the new accounting. Likely
  need new tests pinning short open + short close + realised P&L flow.
- `trading/trading/portfolio/portfolio_risk/lib/portfolio_risk.ml` —
  `compute_position_size` signature change (`~sizing_cash` argument).
- `trading/trading/weinstein/strategy/lib/entry_audit_capture.ml` —
  pass new `~sizing_cash` arg to `Portfolio_risk.compute_position_size`.
- `trading/trading/simulation/lib/simulator.ml` and broker model —
  trade processing must split short proceeds away from current_cash.
- All scenarios will re-pin: long-side sizing changes globally for
  with-shorts strategies. Goldens regen needed (panel-mode + sp500 +
  goldens-broad).

Estimated 250–400 LOC across 8–12 files, ≥3 PRs to ship cleanly:

1. **PR 1 (foundation):** `Portfolio.t` extension + `apply_single_trade`
   side-dispatch + portfolio-side tests. No strategy-side change yet.
2. **PR 2 (sizing wire):** `Portfolio_risk.compute_position_size` accepts
   `~sizing_cash`; `entry_audit_capture` threads it.
3. **PR 3 (regen + verify):** Re-pin all goldens + scenarios. Measure
   sp500 with-shorts vs long-only; expect long-side sizing to converge
   on shared entries.

A1 (core-module-modification) flag will fire on PR 1. The change is
strategy-agnostic (any strategy doing shorts wants this), so
qc-behavioral should approve on generalizability grounds.

## Risks

- **Hidden coupling**: the simulator's broker-fill code (`engine.ml`,
  `simulator.ml._apply_trades_best_effort`) also does cash arithmetic
  on every trade. Need to audit every site that reads `current_cash`
  or modifies it — easy to miss one and produce inconsistent state.
- **Test pollution**: tests that mock portfolios with cash but no
  shorts work today; tests with shorts will need updating to set
  `short_proceeds_held` correctly.
- **Backward-compat for legacy scenarios**: strict golden bit-equality
  on long-only scenarios may break despite no behaviour change, due
  to type-derived sexp serialization changes.

## Decision needed before any code

1. **Stance choice**: A (current cash-account) or B (margin-account)?
   This is a strategy modeling decision, not a code decision. The
   strategy as-conceived in Weinstein book is ambiguous on cash
   treatment for shorts; the book is dollar-cost-thinking in spirit, so
   B aligns better.

2. **Sizing denominator**: `sizing_cash = current_cash` only, OR
   `sizing_cash = current_cash + (some haircut on short_proceeds_held)` to
   model some level of pledgeable-collateral access? Pure B treats
   short proceeds as fully unavailable; broker reality is more nuanced
   (Reg-T allows ~50% pledgeable, Portfolio Margin allows much more).

3. **Threshold tuning post-change**: G15 step 2's 30% notional cap is
   denominated in `portfolio_value`. Under stance B, the cap may want
   to be denominated in `sizing_cash` or `initial_cash` instead. Open
   question.

These are owner decisions. Filing this note as the design surface for
when it's time to move forward.

## Cross-references

- This session's path-dependency measurement (see assistant turn after
  G14 land for the empirical numbers).
- `dev/notes/force-liq-cascade-findings-2026-05-01.md` — broader G14/G15
  framing.
- Weinstein book Stop-Loss Rules / Short-Selling Rules — the book's
  treatment of "money risked" is implicitly margin-style (the trader
  puts up cash; shorts add risk on top of that cash).
- The next G15 step (notional cap) lands tactically without
  requiring this architectural change. Stance B is a future
  enhancement, not a blocker for shorts being usable.
