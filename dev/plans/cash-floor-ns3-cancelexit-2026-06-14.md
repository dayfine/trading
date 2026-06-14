# NS3 — `CancelExit` core Position transition (2026-06-14)

Track: cash-floor-correctness (item NS3). Branch: `feat/cash-floor-ns3-cancelexit`.
Ticket: #1557#2 (follow-up to #1556).

## Context

#1556 fixed the stuck-`Exiting` zombie (#1553): when a portfolio rejects an exit
(cover/sell) fill, the position is stranded in `Exiting` forever because the stop
machinery only re-evaluates `Holding` positions. #1556's fix
(`Cancel_handler.revert_rejected_exits`) reverts the unfilled `Exiting` back to
`Holding` so the stop re-fires next cycle.

That revert is done at the **simulation layer** via `_holding_from_exiting`, a
manual reconstruction of the `Holding` state from the exposed `position_state`.
The core `Position` state machine has `CancelEntry` (`Entering -> cancel`) but **no
`CancelExit`** (`Exiting -> Holding`), so the entry/exit sides are asymmetric. The
existing docstrings on `_holding_from_exiting` and `cancel_handler.mli` name this
exact follow-up.

Post-NS1 (the root cash-floor fix), a rejected cover no longer happens in
practice, so this is now **defense-in-depth + architecture symmetry**, not a
behavior change.

## Approach

Mirror `CancelEntry` exactly:

1. Add a `CancelExit of { reason : string }` variant to `transition_kind` (.mli +
   .ml), classified `Simulator` in `trigger_of_kind`.
2. Validator arm: `Exiting { filled_quantity; _ }, CancelExit _` → reuse
   `_validate_no_fills filled_quantity` (rejects partially-filled `Exiting` with
   "Cannot cancel entry after fills occurred" — same `_validate_no_fills` message
   as CancelEntry; the guard is what matters, not the string).
   - Actually add a dedicated `_validate_no_exit_fills` to give a `CancelExit`-
     specific message? No — keep minimal; reuse `_validate_no_fills`. The message
     is diagnostic only. Decision: reuse `_validate_no_fills` to keep diff minimal
     and symmetric.
3. Apply arm in `_apply_exiting_transition`: `Exiting { quantity; entry_price;
   entry_date; risk_params; _ }, CancelExit _` → build
   `Holding { quantity; entry_price; entry_date; risk_params }`, set
   `last_updated = date`. **No change to `exit_reason`** — match
   `_holding_from_exiting` which leaves all `t` fields except `state` /
   `last_updated` untouched. (CancelEntry sets `exit_reason = Some
   PortfolioRebalancing` because it CLOSES; CancelExit reverts to Holding, so it
   must NOT touch exit_reason to stay byte-identical to the current revert.)
4. Route `Cancel_handler._revert_one` through `Position.apply_transition` /
   `apply_to_positions` by emitting a `CancelExit` transition instead of calling
   `_holding_from_exiting`. Keep the `_is_unfilled_exiting_for_symbol` match (the
   partial-fill guard) so we only attempt the transition on unfilled exits — and
   the core validator is a second backstop.
5. Remove `_holding_from_exiting` once dead.

## Files to change

- `trading/trading/strategy/lib/position.mli` — add `CancelExit` variant + doc.
- `trading/trading/strategy/lib/position.ml` — variant, `trigger_of_kind`,
  validator arm, apply arm.
- `trading/trading/strategy/test/test_position.ml` — core unit tests.
- `trading/trading/simulation/lib/cancel_handler.ml` — route through core
  transition; drop `_holding_from_exiting`.
- `trading/trading/simulation/lib/cancel_handler.mli` — update the
  `revert_rejected_exits` docstring (no longer "no core transition is used").
- `dev/status/cash-floor-correctness.md` — mark NS3 done.

## Behavior-identity argument (load-bearing — no golden re-pin)

The current revert (`_holding_from_exiting`) produces:
`{ pos with state = Holding { quantity; entry_price; entry_date; risk_params };
   last_updated = date }` — i.e. it carries the four `Exiting` fields into
`Holding` and updates only `state` + `last_updated`, leaving `id`, `symbol`,
`side`, `entry_reasoning`, `exit_reason`, `portfolio_lot_ids` untouched.

The new `CancelExit` apply arm produces the **same record**: same four carried
fields into `Holding`, same `last_updated = date`, and (crucially) it does NOT set
`exit_reason` (unlike `CancelEntry`). So the reverted `Holding.t` is byte-identical
field-for-field. The simulation-layer match guard
(`_is_unfilled_exiting_for_symbol`, `filled_quantity = 0.0`) is preserved, so the
SET of positions reverted is identical. Therefore no backtest result changes; no
golden/snapshot re-pin. Full `dune runtest` must be exit 0 with no fixture edits.

## Risks

- **`exit_reason` drift.** If the apply arm set `exit_reason` (copying
  CancelEntry), the reverted Holding would differ → golden re-pin. Mitigated by
  explicitly NOT touching `exit_reason` (tested).
- **Validator rejects unfilled exit.** Must use `_validate_no_fills` (= 0.0
  passes) not `_validate_has_fills`. Tested both directions.
- **A1 core edit.** Authorized for this track. Transition is generic (no Weinstein
  logic), symmetric with CancelEntry. qc-structural FLAGs, qc-behavioral checks
  generalizability.

## Acceptance

- `dune build @fmt`, `dune build`, `dune runtest` exit 0; no golden re-pin.
- Core tests: `CancelExit` valid from unfilled `Exiting` → `Holding` carrying
  fields; rejected from `Holding`/`Entering`/`Closed`; rejected from
  partially-filled `Exiting`.
- `cancel_handler` tests stay green, now routing through the core transition.

## Out of scope

- Partial-fill revert (a partially-filled `Exiting` must NOT be revertible —
  preserved exactly as today).
- Any behavior change / config flag (this is behavior-identical correctness +
  architecture symmetry).
