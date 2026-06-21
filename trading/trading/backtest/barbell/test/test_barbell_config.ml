open Core
open OUnit2
open Matchers

(* The default config is the fully inert no-op per experiment-flag-discipline. *)
let test_default_is_no_op _ =
  assert_that Barbell.Barbell_config.default
    (all_of
       [
         field (fun c -> c.Barbell.Barbell_config.enable) (equal_to false);
         field
           (fun c -> c.Barbell.Barbell_config.floor_weight)
           (float_equal 0.0);
         field (fun c -> c.Barbell.Barbell_config.rebalance_weeks) (equal_to 1);
       ])

(* A scenario sexp that omits every barbell field round-trips to the default,
   proving back-compat: nothing changes for callers that don't opt in. *)
let test_empty_sexp_is_default _ =
  let parsed = Barbell.Barbell_config.t_of_sexp (Sexp.of_string "()") in
  assert_that parsed (equal_to Barbell.Barbell_config.default)

(* rebalance_stride_days = weeks * 7, clamped to >= 1. *)
let test_stride_days _ =
  let weekly = { Barbell.Barbell_config.default with rebalance_weeks = 1 } in
  let monthly = { Barbell.Barbell_config.default with rebalance_weeks = 4 } in
  assert_that
    (List.map [ weekly; monthly ]
       ~f:Barbell.Barbell_config.rebalance_stride_days)
    (elements_are [ equal_to 7; equal_to 28 ])

let test_validate_accepts_default _ =
  assert_that
    (Result.is_ok
       (Barbell.Barbell_config.validate Barbell.Barbell_config.default))
    (equal_to true)

let test_validate_rejects_out_of_range_weight _ =
  let bad = { Barbell.Barbell_config.default with floor_weight = 1.5 } in
  assert_that
    (Result.is_error (Barbell.Barbell_config.validate bad))
    (equal_to true)

let test_validate_rejects_zero_weeks _ =
  let bad = { Barbell.Barbell_config.default with rebalance_weeks = 0 } in
  assert_that
    (Result.is_error (Barbell.Barbell_config.validate bad))
    (equal_to true)

let suite =
  "barbell_config"
  >::: [
         "default_is_no_op" >:: test_default_is_no_op;
         "empty_sexp_is_default" >:: test_empty_sexp_is_default;
         "stride_days" >:: test_stride_days;
         "validate_accepts_default" >:: test_validate_accepts_default;
         "validate_rejects_out_of_range_weight"
         >:: test_validate_rejects_out_of_range_weight;
         "validate_rejects_zero_weeks" >:: test_validate_rejects_zero_weeks;
       ]

let () = run_test_tt_main suite
