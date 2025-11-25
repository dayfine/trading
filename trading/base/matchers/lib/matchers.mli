(** Testing utilities with a fluent matcher API.

    This module provides composable matchers for writing expressive test
    assertions. Matchers work with OUnit2 test framework and Status.status_or
    types. *)

(** {1 Core Matcher Types} *)

type 'a matcher = 'a -> unit
(** A matcher is a function that takes a value and performs assertions on it.
    Matchers can be composed and combined to create complex assertions. *)

val assert_that : 'a -> 'a matcher -> unit
(** [assert_that value matcher] applies the matcher to the value. This is the
    entry point for fluent assertions.

    Example:
    {[
      assert_that actual_price (float_equal 150.25)
    ]}
    {[
      assert_that result (is_ok_and_holds (equal_to expected_value))
    ]} *)

(** {1 Basic Matchers} *)

val equal_to : ?cmp:('a -> 'a -> bool) -> ?msg:string -> 'a -> 'a -> unit
(** [equal_to ?cmp ?msg expected actual] asserts that [actual] equals
    [expected]. Optionally takes a custom comparison function and message.

    Example:
    {[
      assert_that result (is_ok_and_holds (equal_to expected))
    ]}
    {[
      field (fun r -> r.order_id) (equal_to "order123")
    ]} *)

val field : ('a -> 'b) -> ('b -> unit) -> 'a -> unit
(** [field accessor matcher] creates a matcher that extracts a field using
    [accessor] and applies [matcher] to it. This enables a declarative style for
    field assertions.

    Example:
    {[
      assert_that order (field (fun o -> o.status) (equal_to Filled))
    ]}
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

val all_of : ('a -> unit) list -> 'a -> unit
(** [all_of matchers] returns a matcher that applies all matchers to a given
    value. This is useful for combining multiple assertions.

    Example:
    {[
      assert_that order
        (all_of
           [
             (fun o -> assert_equal "order1" o.order_id);
             (fun o -> assert_equal Filled o.status);
           ])
    ]}
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

(** {1 Result Matchers}

    Matchers for [Result.t] and [Status.status_or] types *)

val is_ok : 'a Status.status_or matcher
(** [is_ok] creates a matcher that asserts a Result is Ok. Does not check the Ok
    value - use [is_ok_and_holds] if you need to assert on the value.

    Example:
    {[
      assert_that (validate_input valid_data) is_ok
    ]} *)

val is_ok_and_holds : 'a matcher -> 'a Status.status_or matcher
(** [is_ok_and_holds matcher] creates a matcher that asserts a Result is Ok and
    applies the inner matcher to the unwrapped value.

    Example:
    {[
      assert_that result (is_ok_and_holds (equal_to expected_value))
    ]}
    {[
      assert_that result (is_ok_and_holds (float_equal 150.25))
    ]} *)

val is_error : 'a Status.status_or matcher
(** [is_error] creates a matcher that asserts a Result is Error. Does not check
    the error details - use [is_error_with] if you need to check the status
    code.

    Example:
    {[
      assert_that (validate_input invalid_data) is_error
    ]} *)

val is_error_with : Status.code -> 'a Status.status_or matcher
(** [is_error_with code] creates a matcher that asserts a Result is Error with
    the specified status code.

    Example:
    {[
      assert_that (get_order manager "nonexistent") (is_error_with NotFound)
    ]}
    {[
      assert_that (create_order invalid_params) (is_error_with Invalid_argument)
    ]} *)

(** {1 Option Matchers}

    Matchers for [Option.t] types *)

val is_some_and : 'a matcher -> 'a option matcher
(** [is_some_and matcher] creates a matcher that asserts an Option is Some and
    applies the inner matcher to the unwrapped value.

    Example:
    {[
      assert_that
        (get_position portfolio "AAPL")
        (is_some_and (field position_quantity (float_equal 100.0)))
    ]}
    {[
      assert_that (Map.find cache key) (is_some_and (equal_to expected))
    ]} *)

val is_none : 'a option matcher
(** [is_none] creates a matcher that asserts an Option is None.

    Example:
    {[
      assert_that (get_position portfolio "AAPL") is_none
    ]}
    {[
      assert_that (Map.find cache "nonexistent") is_none
    ]} *)

(** {1 Numeric Matchers} *)

val float_equal : ?epsilon:float -> float -> float matcher
(** [float_equal ?epsilon expected] creates a matcher that checks a float value
    equals [expected] within the given epsilon tolerance (default: 1e-9).

    Example:
    {[
      assert_that actual_price (float_equal 150.25)
    ]}
    {[
      assert_that computed_value (float_equal ~epsilon:0.01 expected)
    ]} *)

(** {1 List Matchers} *)

val each : 'a matcher -> 'a list matcher
(** [each matcher] creates a matcher that applies the matcher to each element in
    a list. All elements must match.

    Example:
    {[
      assert_that orders (each (field (fun o -> o.status) (equal_to Filled)))
    ]}
    {[
      assert_that reports
        (each (all_of [ field (fun r -> r.status) (equal_to Filled) ]))
    ]} *)

val one : 'a matcher -> 'a list matcher
(** [one matcher] creates a matcher for a list with exactly one element,
    applying the matcher to that element.

    Example:
    {[
      assert_that pending_orders (one (field (fun o -> o.id) (equal_to id)))
    ]}
    {[
      assert_that results (one (equal_to expected))
    ]} *)

val elements_are : 'a matcher list -> 'a list matcher
(** [elements_are matchers] creates a matcher that applies each matcher to the
    corresponding element in the list. The list and matchers must have the same
    length. This is useful for checking specific properties of each element in
    order.

    Example:
    {[
      assert_that reports
        (elements_are
           [
             (fun r -> assert_equal "order1" r.order_id);
             (fun r -> assert_equal "order2" r.order_id);
             (fun r -> assert_equal "order3" r.order_id);
           ])
    ]}
    {[
      assert_that orders
        (elements_are
           [
             all_of
               [
                 field (fun o -> o.id) (equal_to "order1");
                 field (fun o -> o.status) (equal_to Pending);
               ];
             all_of
               [
                 field (fun o -> o.id) (equal_to "order2");
                 field (fun o -> o.status) (equal_to Filled);
               ];
           ])
    ]} *)

val unordered_elements_are : 'a matcher list -> 'a list matcher
(** [unordered_elements_are matchers] creates a matcher that checks:
    - All matchers match at least one element
    - All elements match at least one matcher
    - The list and matchers have the same length

    This enables matching elements in any order, useful for cases where order
    doesn't matter.

    Example:
    {[
      assert_that reports
        (unordered_elements_are
           [
             field (fun r -> r.order_id) (equal_to "order1");
             field (fun r -> r.order_id) (equal_to "order2");
             field (fun r -> r.order_id) (equal_to "order3");
           ])
    ]}
    {[
      assert_that positions
        (unordered_elements_are
           [
             field (fun p -> p.symbol) (equal_to "AAPL");
             field (fun p -> p.symbol) (equal_to "MSFT");
           ])
    ]} *)

val size_is : int -> 'a list matcher
(** [size_is n] creates a matcher that checks a list has exactly n elements.

    Example:
    {[
      assert_that pending_orders (size_is 3)
    ]}
    {[
      assert_that completed_orders (size_is 0)
      (* equivalent to equal_to [] *)
    ]} *)
