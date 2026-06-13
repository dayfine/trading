# Status: cash-floor-correctness

## Last updated: 2026-06-13

## Status
IN_PROGRESS

## Interface stable
NO

NS1 shipped (PR open on `feat/cash-floor-closing-exempt`); NS2–NS4 remain a
scoped Next-Steps queue. Each NS lands a new default-off config field;
interfaces firm up as NS2→NS4 ship.

## Completed

- **[NS1] #1557#3 — cash-floor closing-trade exemption** (branch
  `feat/cash-floor-closing-exempt`). Added default-off
  `Portfolio_risk.config.exempt_closing_trades_from_cash_floor : bool
  [@sexp.default false]` (the `portfolio_config` seam of
  `Weinstein_strategy.config`), threaded as a plain bool into
  `Portfolio.create` via `Simulator.dependencies` /
  `Panel_runner._make_simulator` so core `Portfolio` stays strategy-agnostic
  (A1-generalizable). When on, `_check_sufficient_cash` (now delegating to the
  new `Portfolio_cash_floor` module) skips the floor for the reducing portion of
  a closing trade; an over-cover that flips short→long exempts only the closing
  portion (`min(|trade_qty|, |existing_qty|)` split, mirroring
  `portfolio_margin.ml:_classify_trade`), the new-opening portion still faces
  the floor. Default-off ⇒ all goldens bit-equal (full `dune runtest` exit 0, no
  re-pin). Plan: `dev/plans/cash-floor-closing-exempt-2026-06-13.md`. Axis-able:
  pinned by `test_variant_matrix.ml` (`portfolio_config.exempt_closing_trades_from_cash_floor`
  nested key). Unit tests in `test_portfolio.ml`: default-off no-op,
  full/partial cover exempt, over-cover split (opening portion rejected /
  accepted), long-sell reducing exempt (generalizability). File-length /
  nesting linter pressure handled by extracting `Portfolio_cash_floor` +
  `Simulator_metrics` modules (no limit bumps).

## Owner
feat-weinstein (core Portfolio/Position edits authorized per the per-task notes
below; every item lands as a **default-off flag** so merge is a no-op — the
experiment-flag-discipline pattern. Flipping any default to on stays
human-gated, after the WF-CV experiment in NS4.)

## Context

Cluster surfaced by the #1553 zombie autopsy + the 2026-06-13 cash-floor
investigation (read `gh issue view 1557`, `gh issue view 1563`, and the
investigation summary in the #1557 thread before dispatching). The live cash
floor is core `Portfolio._check_sufficient_cash` (`portfolio.ml:338-350`): an
absolute-dollar solvency check that subtracts ALL negative unrealized P&L
(stale drag). It rejected the THM short *cover* — blocking the one trade that
would have *reduced* risk — which stranded the position and produced the −240%
zombie. The strategy-side `min_cash_pct` %-floor is dead code (no caller;
`portfolio_risk.mli:156-162`); do NOT sweep it (bit-identical → silently-dropped
axis).

## Next Steps (ordered; each is a default-off flag → safe merge)

1. **[NS1] #1557#3 — cash-floor closing-trade exemption.** ✅ SHIPPED — see
   §Completed. Branch `feat/cash-floor-closing-exempt`.

2. **[NS2] #1563 — short-sale proceeds collateral.** FIRST deliverable is a
   short design-recommendation in `dev/notes/` (read-only analysis): backtests
   run margin-OFF (`margin_config.ml:18`), so short proceeds hit `current_cash`
   with no collateral lock → short sizing over-deploys. Options: (a) enable
   margin mode in backtests, (b) reserve proceeds as locked collateral in the
   non-margin path behind a default-off flag, (c) document margin-on requirement
   for short-side backtests. Recommend one, then (if b) implement behind a
   default-off flag. **A1 core; needs the design call surfaced before the impl.**
   Moot for long-only Cell-E; matters for the long-short track.

3. **[NS3] #1557#2 — `CancelExit` core Position transition.** Replace #1556's
   simulation-layer state reconstruction (Exiting→Holding) with a proper
   `CancelExit` transition in the core Position state machine. Behavior-identical
   to #1556 (no golden re-pin). **Reassess scope after NS1** — with the NS1 root
   fix a rejected cover no longer happens, so this shrinks to pure
   defense-in-depth. `position/` is in feat-weinstein scope.

4. **[NS4] WF-CV experiment — cash-floor opportunity cost.** After NS1 merges,
   run `exempt_closing_trades_from_cash_floor ∈ {false,true}` as a WF-CV axis on
   bear-regime cells (top-3000-2011 15y incl. the THM run; a deep 2008 window;
   SP500 2019-2023). Measure realized return + **tail drawdown** (the zombie
   excursions live in the left tail), not headline CAGR. Expected shape:
   strictly DD-improving, neutral return → behaves like a correctness fix, not a
   tunable edge. A blanket floor-OFF is NOT safe (entries would open with
   negative cash); the axis is the boolean closing-trade exemption only. Promote
   the default to on only after this clears (human-gated).

## Not in scope here
Warmup-trading default flip (`feat/warmup-trading-default-flip`) — handled
separately on backtest-infra; do not touch.
