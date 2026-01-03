(** Buy and Hold strategy - Enter position once and hold indefinitely

    This module implements the {!Strategy_interface.STRATEGY} interface with
    buy-and-hold logic: enter once and hold indefinitely. *)

type config = {
  symbols : string list;  (** Symbols to buy and hold *)
  position_size : float;  (** Number of shares to buy per symbol *)
  entry_date : Core.Date.t option;
      (** Optional specific entry date. If None, enter on first signal *)
}
[@@deriving show, eq]
(** Strategy configuration *)

val name : string
(** Strategy name *)

val make :
  config -> (module Strategy_interface.STRATEGY) * Strategy_interface.state
(** Create a strategy instance that implements the STRATEGY interface

    Returns both the strategy module (with config captured) and the initial
    state. This encapsulates state initialization within the strategy module. *)
