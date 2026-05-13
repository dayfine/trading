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
(** Total portfolio value: [cash] + signed mark-to-market of all [Holding]
    positions. Long holdings contribute [+quantity * close_price]; shorts
    contribute [-quantity * close_price] (the buy-back liability — cash already
    reflects proceeds credited at short entry, so subtracting the current
    liability tracks short P&L correctly). When [get_price] returns [None] for a
    held symbol, the position is marked at its [entry_price] (zero unrealized
    P&L) — defense in depth against silent NAV collapse on dataset gaps.
    Positions not in [Holding] state are excluded. *)
