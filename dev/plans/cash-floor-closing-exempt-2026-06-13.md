# Plan: cash-floor closing-trade exemption (NS1, #1557#3)

Date: 2026-06-13
Track: `dev/status/cash-floor-correctness.md` (NS1)
Branch: `feat/cash-floor-closing-exempt`

## 1. Context

The live cash floor is core `Portfolio._check_sufficient_cash`
(`trading/trading/portfolio/lib/portfolio.ml:338-350`): an absolute-dollar
solvency check `current_cash + cash_change + sum(min(0, unrealized_pnl)) >= 0`.
It subtracts ALL negative unrealized P&L (stale paper-loss drag). It fires on
both Buy and Sell sides — so it can reject a short **cover** (a `Buy` reducing a
short) when the portfolio carries heavy paper losses, even though the cover is
the one trade that *reduces* risk. That is the #1553 zombie: the THM cover was
rejected, the position stranded into a −240% excursion.

#1556 shipped a simulation-layer backstop (`revert_rejected_exits`): re-revert a
rejected `Exiting` position to `Holding` so the stop re-fires. That's a retry
loop, not a fix — the cover keeps getting rejected.

NS1 is the **root** fix: let a genuinely-reducing trade (the closing portion)
bypass the floor, behind a default-off flag, so the cover books first-try.
#1556's revert becomes a pure backstop.

### Current trade-application data flow (verified)

```
Simulator._process_fills_and_cancels
  -> Cancel_handler.apply_trades_best_effort portfolio trades
       -> Portfolio.apply_single_trade portfolio trade
            -> _check_sufficient_cash portfolio cash_change   <-- the floor
```

The margin path (`Portfolio_margin.apply_single_trade_with_margin`) also calls
`Portfolio.apply_single_trade` internally, so fixing the floor in core Portfolio
covers both paths.

`portfolio_config` in the spec = `Portfolio_risk.config`
(`trading/trading/weinstein/portfolio_risk/lib/portfolio_risk.ml:49`), which is
a field of `Weinstein_strategy.config` (`portfolio_config : Portfolio_risk.config`,
`weinstein_strategy_config.ml:17`). The backtest runner threads
`input.config` (a `Weinstein_strategy.config`) into `Panel_runner._make_simulator`,
which already derives `~margin_config:input.config.margin_config` for
`Simulator.create_deps`. That is the precedent seam this plan mirrors.

## 2. Approach

Two-part wiring — config field for axis-ability, plain bool threaded to the
core check for strategy-agnosticism.

### (a) Axis-able config field (R1 + R2)

Add to `Portfolio_risk.config`:

```ocaml
exempt_closing_trades_from_cash_floor : bool; [@sexp.default false]
```

Default `false` (R1: no-op on merge). Because `Portfolio_risk.config` is the
`portfolio_config` field of `Weinstein_strategy.config`, the
`Overlay_validator` sexp deep-merge resolves the dot-path
`portfolio_config.exempt_closing_trades_from_cash_floor`, so a
`Variant_matrix` axis
`((flag portfolio_config.exempt_closing_trades_from_cash_floor) (values (true false)))`
expands and validates (R2). Pinned by a `test_variant_matrix.ml` axis test
mirroring `test_short_min_price_axis_expands` / the nested
`hysteresis_weeks` key axis.

### (b) Core Portfolio: strategy-agnostic plain-bool seam (A1, generalizable)

Core Portfolio must NOT depend on `Portfolio_risk` (layering). So the flag
reaches core Portfolio as a plain `bool`, stored on `Portfolio.t` exactly like
`accounting_method`:

- New field `exempt_closing_trades_from_cash_floor : bool` on `Portfolio.t`.
- New optional param `?exempt_closing_trades_from_cash_floor` on `create`
  (default `false`). All 29 existing `create` call sites keep the old behaviour.
- `apply_single_trade` passes `~portfolio` (which carries the flag) +
  the position context into `_check_sufficient_cash`.

The simulator wires the value:
`Portfolio.create ~exempt_closing_trades_from_cash_floor:
  config.portfolio_config.exempt_closing_trades_from_cash_floor`.

This keeps the floor logic entirely inside core Portfolio (where it lives),
makes the change a generic boolean any strategy can set, and satisfies the
qc-behavioral A1 generalizability check.

### The reducing-portion split (the load-bearing detail)

`_check_sufficient_cash` is extended to receive the existing position quantity
and the signed trade quantity. The logic:

1. Compute `existing_qty` = signed position quantity for the trade's symbol
   (0.0 if none), `trade_qty_signed` = `+qty` for Buy, `-qty` for Sell.
2. A trade is **reducing** when it is opposite-signed to the position and
   `existing_qty <> 0`. The **closing portion** is
   `closed = min(|trade_qty|, |existing_qty|)`; the **opening portion** is
   `|trade_qty| - closed` (non-zero only on an over-cover / flip).
   This mirrors `portfolio_margin.ml:_classify_trade`'s
   `Float.min trade.quantity (Float.abs existing_qty)`.
3. When the flag is on:
   - **Genuinely reducing** (`|trade_qty| <= |existing_qty|`, opening portion
     0): the whole trade is the closing portion. Skip the floor entirely —
     return `Ok new_cash`.
   - **Over-cover / flip** (opening portion > 0): the closing portion is exempt
     but the new-opening portion still faces the floor. We check the floor
     against a `cash_change` that *excludes* the released/neutral closing
     portion: the opening portion's cash impact is
     `opening_qty * price (+/- commission share)`. Concretely, compute the
     opening-only cash change and require
     `current_cash + opening_cash_change + unrealized_drag >= 0`.
   - Non-reducing trades (opening / adding same-direction): floor unchanged.
4. When the flag is off: behaviour is byte-identical to today (full
   `cash_change`, no split). Verified by default-off no-op test + goldens.

Rejected alternative: thread the bool as a parameter through
`apply_single_trade` / `Cancel_handler.apply_trades_best_effort` instead of
storing on `t`. Rejected because `apply_single_trade` has 29 call sites and the
parameter would ripple through `Portfolio_margin`, `Cancel_handler`, and every
test; storing on `t` (mirroring `accounting_method`) is the minimal,
already-established pattern and keeps `apply_single_trade`'s arity stable.

## 3. Files to change

- `trading/trading/portfolio/lib/portfolio.ml`
  - add `exempt_closing_trades_from_cash_floor : bool` to `t`
  - `create`: optional `?exempt_closing_trades_from_cash_floor` (default false)
  - `_check_sufficient_cash`: take position/trade context, implement the split
  - `apply_single_trade`: pass context + portfolio to the check
- `trading/trading/portfolio/lib/portfolio.mli`
  - document the new field + `create` param + updated `apply_single_trade`
    cash-floor semantics
- `trading/trading/weinstein/portfolio_risk/lib/portfolio_risk.ml` + `.mli`
  - add the `exempt_closing_trades_from_cash_floor` config field +
    `default_config` entry + .mli doc
- `trading/trading/simulation/lib/simulator.ml` (and panel_runner if needed)
  - wire `config.portfolio_config.exempt_closing_trades_from_cash_floor` into
    `Portfolio.create`. NOTE: `Simulator._build_initial_state` only has the
    run-`config` (initial_cash/dates), NOT the strategy config. The strategy
    config is `Weinstein_strategy.config` held by `Panel_runner.input.config`.
    So the bool must be threaded into the simulator deps (mirror `margin_config`):
    add a field to `Simulator.dependencies` +
    `?exempt_closing_trades_from_cash_floor` to `create_deps`, read it in
    `_build_initial_state`, and `Panel_runner._make_simulator` passes
    `input.config.portfolio_config.exempt_closing_trades_from_cash_floor`.
- `trading/trading/portfolio/test/test_portfolio.ml` (or test_margin_accounting)
  - new unit tests (see acceptance)
- `trading/trading/backtest/walk_forward/test/test_variant_matrix.ml`
  - new axis-expansion test for the nested portfolio_config flag path

## 4. Risks / unknowns

- **Sexp shape of `Portfolio.t`.** `t` is `[@@deriving sexp]`. Verified no
  golden fixture and no sexp round-trip test serializes `Portfolio.t` (greps:
  no `accounting_method`/`trade_history` in `test_data/`; no Portfolio
  `t_of_sexp` test). Adding a field is safe.
- **Threading the bool into the simulator.** `_build_initial_state` lacks the
  strategy config; mitigated by adding it to deps (mirrors `margin_config`).
  If the simulator wiring proves larger than expected, the core Portfolio +
  Portfolio_risk + axis test still land independently (the flag is correct and
  axis-able; only the live default-off wiring through the runner is the extra).
- **Over-cover commission attribution.** Commission is per-trade, not
  per-share. For the opening-portion floor check, attribute commission
  pro-rata by share fraction (`opening_qty / |trade_qty|`). Documented in code.
- **available_cash vs current_cash.** The floor uses `current_cash` (+drag),
  not `available_cash`; this change does not touch margin collateral. Left
  as-is.

## 5. Acceptance criteria

- `Portfolio_risk.config` has `exempt_closing_trades_from_cash_floor : bool
  [@sexp.default false]`; `default_config` sets it `false`.
- Default-off path is byte-identical: `dune runtest` exit 0, no golden re-pin.
- Axis test in `test_variant_matrix.ml`: the nested key path
  `portfolio_config.exempt_closing_trades_from_cash_floor` expands + validates
  through `Overlay_validator` to override sexp
  `((portfolio_config ((exempt_closing_trades_from_cash_floor true))))`.
- Unit tests in portfolio test:
  1. default-off no-op: a cover that the floor would reject is still rejected
     when the flag is off (pins R1 backward-compat at the unit level).
  2. genuinely-reducing exempt: with flag on + heavy unrealized drag, a short
     cover with `|trade_qty| <= |position_qty|` is accepted where it was
     rejected off.
  3. over-cover split: with flag on, an over-cover that flips short->long
     exempts the closing portion but the new-long portion still faces the floor
     (rejected when the opening portion alone breaches; accepted otherwise).
  4. long-sell reducing exempt: symmetry — a long sell (reducing) is also
     exempted (proves strategy-agnostic / generalizes beyond shorts).
- `dune build && dune runtest` exit 0; `dune fmt` clean.

## 6. Out of scope

- NS2/NS3/NS4 (short-sale proceeds, CancelExit core transition, WF-CV experiment).
- Flipping the default to on (R3 — human-gated, after NS4).
- `min_cash_pct` (dead code — do not touch).
- Warmup-trading flag (fenced to backtest-infra).
- Margin collateral accounting (`locked_collateral`) — untouched.
