open OUnit2
open Weinstein_types
open Matchers

let test_stage_eq _ =
  let s2_early = (Stage2 { weeks_advancing = 3; late = false } : stage) in
  let s2_late = (Stage2 { weeks_advancing = 3; late = true } : stage) in
  assert_that s2_early (equal_to s2_early);
  assert_that s2_early (not_ (equal_to s2_late));
  assert_that
    (Stage1 { weeks_in_base = 4 } : stage)
    (not_ (equal_to (Stage3 { weeks_topping = 4 } : stage)))

let test_ma_direction_eq _ =
  assert_that (Rising : ma_direction) (equal_to Rising);
  assert_that (Rising : ma_direction) (not_ (equal_to Declining))

let suite =
  "weinstein_types"
  >::: [
         "stage_eq" >:: test_stage_eq;
         "ma_direction_eq" >:: test_ma_direction_eq;
       ]

let () = run_test_tt_main suite
