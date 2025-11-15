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

val elements_are : 'a list -> ('a -> unit) list -> unit
(** [elements_are list callbacks] applies each callback function to the
    corresponding element in [list]. The list and callbacks must have the same
    length, otherwise the assertion fails. This is useful for checking specific
    properties of each element in order.

    Example:
    {[
      elements_are reports
        [
          (fun r -> assert_equal "order1" r.order_id);
          (fun r -> assert_equal "order2" r.order_id);
          (fun r -> assert_equal "order3" r.order_id);
        ]
    ]} *)

val all_of : ('a -> unit) list -> 'a -> unit
(** [all_of checks] returns a function that applies all check functions to a
    given value. This is useful for combining multiple assertions into a single
    callback, reducing nesting when used with elements_are.

    Example:
    {[
      elements_are reports
        [
          all_of
            [
              (fun r -> assert_equal order.id r.order_id);
              (fun r -> assert_equal Filled r.status);
            ];
        ]
    ]} *)

val field : ('a -> 'b) -> ('b -> unit) -> 'a -> unit
(** [field accessor matcher] creates a check that extracts a field using
    [accessor] and applies [matcher] to it. This enables a declarative style for
    field assertions.

    Example:
    {[
      elements_are reports
        [
          all_of
            [
              field (fun r -> r.order_id) (equal_to order.id);
              field (fun r -> r.status) (equal_to Filled);
            ];
        ]
    ]} *)

val equal_to : ?cmp:('a -> 'a -> bool) -> ?msg:string -> 'a -> 'a -> unit
(** [equal_to ?cmp ?msg expected actual] asserts that [actual] equals
    [expected]. Optionally takes a custom comparison function and message.

    Example:
    {[
      field (fun r -> r.order_id) (equal_to "order123")
    ]} *)

(** {1 Fluent Matcher API}

    These functions provide a composable, declarative API for assertions.
    Matchers are values that can be combined and passed around. *)

type 'a matcher = 'a -> unit
(** A matcher is a function that takes a value and performs assertions on it *)

val assert_that : 'a -> 'a matcher -> unit
(** [assert_that value matcher] applies the matcher to the value. This is the
    entry point for fluent assertions.

    Example:
    {[
      assert_that reports
        (is_ok_and_holds (elements_are (all_of [ (* matchers *) ])))
    ]} *)

val is_ok_and_holds : 'a matcher -> 'a Status.status_or matcher
(** [is_ok_and_holds matcher] creates a matcher for Result types that asserts
    the value is Ok and applies the inner matcher to the unwrapped value.

    Example:
    {[
      asserts_that result (is_ok_and_holds (equal_to expected_value))
    ]} *)

val each : 'a matcher -> 'a list matcher
(** [each matcher] creates a matcher that applies the given matcher to each
    element in a list.

    Example:
    {[
      asserts_that reports
        (each (all_of [ field (fun r -> r.status) (equal_to Filled) ]))
    ]} *)

val one : 'a matcher -> 'a list matcher
(** [one matcher] creates a matcher for a list with exactly one element,
    applying the matcher to that element.

    Example:
    {[
      asserts_that reports (one (field (fun r -> r.order_id) (equal_to id)))
    ]} *)
