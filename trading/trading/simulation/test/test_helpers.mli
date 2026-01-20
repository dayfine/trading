(** Shared test helpers for simulation tests *)

open Core

val ok_or_fail_status : ('a, Status.t) Result.t -> 'a
(** Extract Ok value or fail with status message *)

val with_test_data :
  string -> (string * Types.Daily_price.t list) list -> f:(Fpath.t -> 'a) -> 'a
(** RAII-style test data setup with automatic cleanup.

    Sets up test data, runs the provided function, and cleans up regardless of
    whether the function succeeds or raises.

    @param test_name Unique name for this test
    @param prices_by_symbol List of (symbol, prices) pairs
    @param f Function to run with the test data directory *)

val step_exn :
  Trading_simulation.Simulator.t ->
  Trading_simulation.Simulator.t * Trading_simulation.Simulator.step_result
(** Step the simulator, expecting Stepped outcome. Fails if Completed or Error.
*)

module Noop_strategy : Trading_strategy.Strategy_interface.STRATEGY
(** No-op strategy for tests that don't need strategy logic *)

(** {1 Parameterized Enter-Then-Exit Strategies} *)

type position_side =
  | Long
  | Short  (** Position side for parameterized strategies *)

type enter_exit_config = {
  side : position_side;
  symbol : string;
  target_quantity : float;
  entry_price : float;
}
(** Configuration for enter-then-exit test strategy *)

val default_enter_exit_config : enter_exit_config
(** Default config: Long AAPL, quantity 10.0, entry price 150.0 *)

(** Functor to create parameterized enter-then-exit strategy.

    Usage:
    {[
      module My_strategy = Make_enter_then_exit_strategy (struct
        let config = { default_enter_exit_config with symbol = "MSFT" }
      end)
    ]} *)
module Make_enter_then_exit_strategy (_ : sig
  val config : enter_exit_config
end) : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : unit -> unit
  (** Reset the internal call counter for test isolation *)

  val side : position_side
  (** The position side this strategy uses *)
end

(** Long position strategy - creates long position on day 1, exits on day 2 *)
module Long_strategy : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : unit -> unit
  val side : position_side
end

(** Short position strategy - creates short position on day 1, exits on day 2 *)
module Short_strategy : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : unit -> unit
  val side : position_side
end

(** Backward-compatible alias for Long_strategy *)
module Enter_then_exit_strategy : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : unit -> unit
  val side : position_side
end
