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

(** Strategy that creates a position on first call, exits on second call.

    Used for testing position lifecycle: CreateEntering -> Holding -> Exiting ->
    Closed *)
module Enter_then_exit_strategy : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : unit -> unit
  (** Reset the internal call counter for test isolation *)
end
