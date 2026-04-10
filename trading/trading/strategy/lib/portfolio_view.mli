(** Read-only portfolio snapshot for strategies.

    Bundles the cash balance and open positions into a single value that the
    simulator constructs before calling [STRATEGY.on_market_close]. Strategies
    use this to derive portfolio value for position sizing without needing
    direct access to the simulator's [Portfolio.t]. *)

type t = {
  cash : float;  (** Current cash balance *)
  positions : Position.t Core.String.Map.t;  (** Open positions by ID *)
}

val portfolio_value :
  t -> get_price:(string -> Types.Daily_price.t option) -> float
(** Total portfolio value: [cash] + mark-to-market of all [Holding] positions.
    Positions not in [Holding] state or without a current price are excluded. *)
