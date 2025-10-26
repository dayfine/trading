(** Testing utilities for asserting on Result types.

    This module provides helper functions to reduce boilerplate in tests while
    maintaining clarity. These helpers work with OUnit2 test framework and
    Status.status_or types. *)

val assert_ok_with : msg:string -> 'a Status.status_or -> f:('a -> unit) -> unit
(** [assert_ok_with ~msg result ~f] asserts that [result] is [Ok value] and
    executes [f value] for further assertions. If [result] is [Error], fails
    with [msg] and the error details.

    Example:
    {[
      assert_ok_with ~msg:"Operation failed" (some_operation ())
        ~f:(fun value ->
          assert_equal expected_value value ~msg:"Value mismatch")
    ]} *)

val assert_error : msg:string -> 'a Status.status_or -> unit
(** [assert_error ~msg result] asserts that [result] is [Error]. If [result] is
    [Ok], fails with [msg].

    Example:
    {[
      assert_error ~msg:"Should fail with invalid input"
        (validate_input invalid_data)
    ]} *)

val assert_ok : msg:string -> 'a Status.status_or -> 'a
(** [assert_ok ~msg result] asserts that [result] is [Ok value] and returns
    [value]. If [result] is [Error], fails with [msg] and the error details.
    This is useful for test setup where you need the unwrapped value.

    Example:
    {[
      let portfolio =
        assert_ok ~msg:"Failed to create portfolio"
          (create_portfolio ~cash:10000.0)
    ]} *)

val assert_float_equal : ?epsilon:float -> float -> float -> msg:string -> unit
(** [assert_float_equal ?epsilon expected actual ~msg] asserts that [expected]
    and [actual] are equal within the given epsilon tolerance (default: 1e-9).
    Uses OUnit2's assert_equal with a custom float comparator.

    Example:
    {[
      assert_float_equal 10.5 (calculate_total ()) ~msg:"Total should be 10.5"
    ]} *)

val assert_some_with : msg:string -> 'a option -> f:('a -> unit) -> unit
(** [assert_some_with ~msg option ~f] asserts that [option] is [Some value] and
    executes [f value] for further assertions. If [option] is [None], fails with
    [msg].

    Example:
    {[
      assert_some_with ~msg:"Position should exist"
        (get_position portfolio "AAPL") ~f:(fun position ->
          assert_float_equal 100.0 position.quantity ~msg:"Quantity mismatch")
    ]} *)

val assert_some : msg:string -> 'a option -> 'a
(** [assert_some ~msg option] asserts that [option] is [Some value] and returns
    [value]. If [option] is [None], fails with [msg]. This is useful for test
    setup where you need the unwrapped value.

    Example:
    {[
      let position =
        assert_some ~msg:"Position should exist after buy"
          (get_position portfolio "AAPL")
    ]} *)

val assert_none : msg:string -> 'a option -> unit
(** [assert_none ~msg option] asserts that [option] is [None]. If [option] is
    [Some], fails with [msg].

    Example:
    {[
      assert_none ~msg:"Position should be closed"
        (get_position portfolio "AAPL")
    ]} *)
