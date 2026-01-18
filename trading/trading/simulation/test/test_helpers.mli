(** Shared test helpers for simulation tests *)

open Core

val ok_or_fail_status : ('a, Status.t) Result.t -> 'a
(** Extract Ok value or fail with status message *)

val setup_test_data :
  string -> (string * Types.Daily_price.t list) list -> Fpath.t
(** Set up test CSV data directory.

    @param test_name Unique name for this test (used as directory name)
    @param prices_by_symbol List of (symbol, prices) pairs to save
    @return Path to the created test data directory *)

val teardown_test_data : Fpath.t -> unit
(** Clean up test data directory *)

val with_test_data :
  string -> (string * Types.Daily_price.t list) list -> f:(Fpath.t -> 'a) -> 'a
(** RAII-style test data setup with automatic cleanup.

    Sets up test data, runs the provided function, and cleans up regardless of
    whether the function succeeds or raises.

    @param test_name Unique name for this test
    @param prices_by_symbol List of (symbol, prices) pairs
    @param f Function to run with the test data directory *)

module Noop_strategy : Trading_strategy.Strategy_interface.STRATEGY
(** No-op strategy for tests that don't need strategy logic *)
