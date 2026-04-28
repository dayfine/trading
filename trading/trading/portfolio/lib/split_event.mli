(** Split-event ledger primitive — broker-model adjustment for stock splits.

    A {!t} records a corporate-action split for a single symbol: on [date] the
    issuer multiplied outstanding shares by [factor]
    ([factor = new_shares /. old_shares]). For a 4:1 forward split, [factor] is
    [4.0]; for a 1:5 reverse split it is [0.2]; for fractional splits like 3:2
    it is [1.5].

    Applying a split event to a held position multiplies the share count by
    [factor] and divides the per-share cost basis by [factor], preserving total
    cost basis. Fractional shares are kept as-is — {!Types.position_lot}'s
    [quantity] is a [float]. The lots' [acquisition_date] is unchanged.

    PR-2 establishes this primitive but does not invoke it from the simulator.
    The simulator wiring is PR-3 of the broker-model redesign — see
    [dev/plans/split-day-ohlc-redesign-2026-04-28.md] §PR-3. *)

open Trading_base.Types
open Types

type t = {
  symbol : symbol;
  date : Core.Date.t;
  factor : float;  (** [new_shares /. old_shares]; positive, non-zero. *)
}
[@@deriving show, eq, sexp]

val apply_to_position : t -> portfolio_position -> portfolio_position
(** [apply_to_position event position] applies a split to a single position.
    Each lot's [quantity] is multiplied by [event.factor]; each lot's
    [cost_basis] (a {e total}, not per-share) is unchanged because total cost
    basis is preserved across a split. The per-share cost (recoverable as
    [cost_basis /. abs quantity]) is therefore divided by [factor]. The
    position's [symbol], [accounting_method], and each lot's [lot_id] +
    [acquisition_date] are unchanged. Pure. *)

val apply_to_portfolio : t -> Portfolio.t -> Portfolio.t
(** [apply_to_portfolio event portfolio] applies the split to the portfolio's
    held position for [event.symbol], if any. If no position is held for that
    symbol, returns the portfolio unchanged (cash, positions, trade history,
    accounting method all preserved). Pure; returns a new portfolio. Cash and
    [trade_history] are never modified — splits do not generate trades. *)
