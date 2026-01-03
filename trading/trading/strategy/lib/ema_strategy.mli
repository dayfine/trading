(** EMA crossover strategy

    This module implements the {!Strategy_interface.STRATEGY} interface with
    EMA-based entry/exit logic. *)

type config = {
  symbols : string list;  (** Symbols to trade *)
  ema_period : int;
  stop_loss_percent : float;  (** e.g., 0.05 = -5% *)
  take_profit_percent : float;  (** e.g., 0.10 = +10% *)
  position_size : float;  (** Number of shares to trade per symbol *)
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
