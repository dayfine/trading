(** Portfolio view utilities for strategies.

    Strategies receive [Position.t String.Map.t] but have no direct access to
    the portfolio's cash balance. The simulator injects cash as a synthetic
    position before calling the strategy; this module encapsulates that
    convention so strategies never see the raw encoding.

    {1 Cash encoding}

    Cash is represented as a [Position.t] in [Holding] state with
    [symbol = "__CASH__"], [quantity = cash_amount], [entry_price = 1.0]. The
    reserved key [cash_key] in the positions map holds it. *)

val cash_key : string
(** Reserved map key for the synthetic cash position (["__CASH__"]). *)

val inject_cash :
  cash:float -> Position.t Core.String.Map.t -> Position.t Core.String.Map.t
(** Add a synthetic cash position to the map. Overwrites any existing entry at
    [cash_key]. Used by the simulator before calling the strategy. *)

val extract_cash : Position.t Core.String.Map.t -> float
(** Read the cash balance from the positions map. Returns [0.0] if no cash
    position is present or if it is not in [Holding] state. *)

val compute_portfolio_value :
  Position.t Core.String.Map.t ->
  get_price:(string -> Types.Daily_price.t option) ->
  float
(** Total portfolio value: cash + mark-to-market of all [Holding] positions.
    Positions not in [Holding] state or without a current price are excluded.
    The cash position (at [cash_key]) contributes its quantity directly (price =
    1.0). *)

val positions_only :
  Position.t Core.String.Map.t -> Position.t Core.String.Map.t
(** Filter out the cash position, returning only real trading positions. Useful
    when iterating positions for stop management or screening. *)
