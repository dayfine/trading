(** Portfolio and position management *)

(** Portfolio state *)
type t = {
  positions: Base.position list;
  cash: Base.money;
  total_value: Base.money;
}

(** Create a new portfolio *)
val create : Base.money -> t

(** Add a position to the portfolio *)
val add_position : t -> Base.symbol -> Base.quantity -> Base.price -> t

(** Remove a position from the portfolio *)
val remove_position : t -> Base.symbol -> Base.quantity -> t

(** Get position for a symbol *)
val get_position : t -> Base.symbol -> Base.position option

(** Get all positions *)
val get_positions : t -> Base.position list

(** Calculate position value *)
val calculate_position_value : Base.position -> Base.price -> float

(** Calculate unrealized P&L for a position *)
val calculate_unrealized_pnl : Base.position -> Base.price -> float

(** Update portfolio value based on current prices *)
val update_portfolio_value : t -> Base.price Map.M(Base.String).t -> t

(** Get portfolio summary *)
val get_summary : t -> {
  num_positions: int;
  total_positions: int;
  cash: Base.money;
  total_value: Base.money;
}
