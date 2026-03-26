open OUnit2
open Matchers

let test_not_passes_when_inner_fails _ =
  assert_that 1 (not_ (equal_to 2));
  assert_that "hello" (not_ (equal_to "world"))

let test_not_fails_when_inner_passes _ =
  let raised =
    try
      assert_that 1 (not_ (equal_to 1));
      false
    with _ -> true
  in
  assert_bool "Expected not_ to fail when inner matcher passes" raised

let suite =
  "matchers"
  >::: [
         "not_passes_when_inner_fails" >:: test_not_passes_when_inner_fails;
         "not_fails_when_inner_passes" >:: test_not_fails_when_inner_passes;
       ]

let () = run_test_tt_main suite
