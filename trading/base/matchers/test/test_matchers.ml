open OUnit2
open Matchers

let assert_fails f =
  let raised =
    try
      f ();
      false
    with _ -> true
  in
  assert_bool "Expected matcher to fail but it passed" raised

(* Stricter than [assert_fails]: the matcher must fail an OUnit assertion (not
   some other exception) and the failure message must contain [substring]. *)
let assert_fails_naming ~substring f =
  match f () with
  | () -> assert_failure "Expected matcher to fail but it passed"
  | exception OUnitTest.OUnit_failure msg ->
      assert_that msg (contains_substring substring)

let nan = Float.nan

(* ------------------------------------------------------------------ *)
(* not_                                                                 *)
(* ------------------------------------------------------------------ *)

let test_not_passes_when_inner_fails _ =
  assert_that 1 (not_ (equal_to 2));
  assert_that "hello" (not_ (equal_to "world"))

let test_not_fails_when_inner_passes _ =
  assert_fails (fun () -> assert_that 1 (not_ (equal_to 1)))

(* ------------------------------------------------------------------ *)
(* gt / ge / lt / le                                                   *)
(* ------------------------------------------------------------------ *)

let test_gt_passes _ =
  assert_that 5 (gt (module Int_ord) 4);
  assert_that 1.0 (gt (module Float_ord) 0.0)

let test_gt_fails_when_equal _ =
  assert_fails (fun () -> assert_that 4 (gt (module Int_ord) 4))

let test_gt_fails_when_less _ =
  assert_fails (fun () -> assert_that 3 (gt (module Int_ord) 4))

let test_ge_passes _ =
  assert_that 4 (ge (module Int_ord) 4);
  assert_that 5 (ge (module Int_ord) 4)

let test_ge_fails_when_less _ =
  assert_fails (fun () -> assert_that 3 (ge (module Int_ord) 4))

let test_lt_passes _ =
  assert_that 3 (lt (module Int_ord) 4);
  assert_that (-1.0) (lt (module Float_ord) 0.0)

let test_lt_fails_when_equal _ =
  assert_fails (fun () -> assert_that 4 (lt (module Int_ord) 4))

let test_lt_fails_when_greater _ =
  assert_fails (fun () -> assert_that 5 (lt (module Int_ord) 4))

let test_le_passes _ =
  assert_that 4 (le (module Int_ord) 4);
  assert_that 3 (le (module Int_ord) 4)

let test_le_fails_when_greater _ =
  assert_fails (fun () -> assert_that 5 (le (module Int_ord) 4))

(* ------------------------------------------------------------------ *)
(* float_equal                                                          *)
(* ------------------------------------------------------------------ *)

let test_float_equal_passes_within_epsilon _ =
  assert_that 1.0 (float_equal 1.0);
  assert_that 1.0000000001 (float_equal 1.0);
  assert_that 1.05 (float_equal ~epsilon:0.1 1.0)

let test_float_equal_fails_beyond_epsilon _ =
  assert_fails (fun () -> assert_that 1.1 (float_equal 1.0));
  assert_fails (fun () -> assert_that 1.2 (float_equal ~epsilon:0.1 1.0));
  assert_fails (fun () -> assert_that 0.8 (float_equal ~epsilon:0.1 1.0))

let test_float_equal_fails_at_exactly_epsilon _ =
  assert_fails (fun () -> assert_that 0.5 (float_equal ~epsilon:0.5 0.0))

let test_float_equal_infinities _ =
  assert_that Float.infinity (float_equal Float.infinity);
  assert_that Float.neg_infinity (float_equal Float.neg_infinity);
  assert_fails (fun () ->
      assert_that Float.neg_infinity (float_equal Float.infinity));
  assert_fails (fun () -> assert_that 1.0 (float_equal Float.infinity));
  assert_fails (fun () -> assert_that Float.infinity (float_equal 1.0))

let test_float_equal_fails_when_actual_is_nan _ =
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that nan (float_equal 1.0));
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that nan (float_equal 0.0))

let test_float_equal_fails_when_expected_is_nan _ =
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that 1.0 (float_equal nan));
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that 0.0 (float_equal nan))

let test_float_equal_fails_when_actual_is_nan_against_infinity _ =
  assert_fails (fun () -> assert_that nan (float_equal Float.infinity));
  assert_fails (fun () -> assert_that Float.infinity (float_equal nan))

let test_float_equal_fails_when_both_nan_by_default _ =
  assert_fails_naming ~substring:"nan_equal" (fun () ->
      assert_that nan (float_equal nan));
  assert_fails (fun () -> assert_that nan (float_equal ~nan_equal:false nan))

let test_float_equal_passes_when_both_nan_and_opted_in _ =
  assert_that nan (float_equal ~nan_equal:true nan);
  assert_that nan (float_equal ~epsilon:0.1 ~nan_equal:true nan)

let test_float_equal_nan_equal_does_not_excuse_one_sided_nan _ =
  assert_fails (fun () -> assert_that nan (float_equal ~nan_equal:true 1.0));
  assert_fails (fun () -> assert_that 1.0 (float_equal ~nan_equal:true nan))

let test_float_equal_nan_is_visible_through_not_ _ =
  (* A NaN is "not equal" to a number, so the negated matcher passes. *)
  assert_that nan (not_ (float_equal 1.0));
  assert_that 1.0 (not_ (float_equal nan));
  assert_that nan (not_ (float_equal nan))

let test_float_equal_works_as_unapplied_function _ =
  (* Call sites pass [float_equal] straight to [List.map]; the optional
     arguments must keep being erased there. *)
  let matchers = List.map float_equal [ 1.0; 2.0 ] in
  assert_that [ 1.0; 2.0 ] (elements_are matchers)

(* ------------------------------------------------------------------ *)
(* Float_ord with NaN                                                   *)
(* ------------------------------------------------------------------ *)

(* [Float.compare] orders NaN below every number, so without a guard
   [lt]/[le] would pass on a NaN actual and [gt]/[ge] on a NaN threshold. *)

let test_float_ord_gt_fails_on_nan _ =
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that nan (gt (module Float_ord) 0.0));
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that 1.0 (gt (module Float_ord) nan));
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that nan (gt (module Float_ord) nan))

let test_float_ord_ge_fails_on_nan _ =
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that nan (ge (module Float_ord) 0.0));
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that 1.0 (ge (module Float_ord) nan));
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that nan (ge (module Float_ord) nan))

let test_float_ord_lt_fails_on_nan _ =
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that nan (lt (module Float_ord) 0.0));
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that (-1.0) (lt (module Float_ord) nan));
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that nan (lt (module Float_ord) nan))

let test_float_ord_le_fails_on_nan _ =
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that nan (le (module Float_ord) 0.0));
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that (-1.0) (le (module Float_ord) nan));
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that nan (le (module Float_ord) nan))

let test_float_ord_is_between_fails_on_nan _ =
  let between = is_between (module Float_ord) in
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that nan (between ~low:0.0 ~high:1.0));
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that 0.5 (between ~low:nan ~high:1.0));
  assert_fails_naming ~substring:"NaN" (fun () ->
      assert_that 0.5 (between ~low:0.0 ~high:nan))

let test_float_ord_ordinary_comparisons_unchanged _ =
  assert_that 1.0 (gt (module Float_ord) 0.0);
  assert_that 1.0 (ge (module Float_ord) 1.0);
  assert_that (-1.0) (lt (module Float_ord) 0.0);
  assert_that 1.0 (le (module Float_ord) 1.0);
  assert_that 0.5 (is_between (module Float_ord) ~low:0.0 ~high:1.0);
  assert_that Float.infinity (gt (module Float_ord) 1e300);
  assert_that Float.neg_infinity (lt (module Float_ord) (-1e300));
  assert_fails (fun () -> assert_that 0.0 (gt (module Float_ord) 1.0));
  assert_fails (fun () -> assert_that 1.0 (lt (module Float_ord) 0.0))

(* ------------------------------------------------------------------ *)
(* pair                                                                 *)
(* ------------------------------------------------------------------ *)

let test_pair_passes _ =
  assert_that (1, "hello") (pair (equal_to 1) (equal_to "hello"))

let test_pair_fails_on_first _ =
  assert_fails (fun () ->
      assert_that (2, "hello") (pair (equal_to 1) (equal_to "hello")))

let test_pair_fails_on_second _ =
  assert_fails (fun () ->
      assert_that (1, "world") (pair (equal_to 1) (equal_to "hello")))

(* ------------------------------------------------------------------ *)
(* matching                                                             *)
(* ------------------------------------------------------------------ *)

let test_matching_passes_when_some _ =
  assert_that (Some 42)
    (matching (function Some x -> Some x | None -> None) (equal_to 42))

let test_matching_fails_when_none _ =
  assert_fails (fun () ->
      assert_that None
        (matching (function Some x -> Some x | None -> None) (equal_to 42)))

let test_matching_custom_msg_fails _ =
  assert_fails (fun () ->
      assert_that (`B 1)
        (matching ~msg:"Expected variant A"
           (function `A x -> Some x | _ -> None)
           (equal_to 0)))

(* ------------------------------------------------------------------ *)
(* contains_substring                                                   *)
(* ------------------------------------------------------------------ *)

let test_contains_substring_passes _ =
  assert_that "hello world" (contains_substring "world");
  assert_that "## Verdict: PASS" (contains_substring "PASS")

let test_contains_substring_fails_when_absent _ =
  assert_fails (fun () ->
      assert_that "hello world" (contains_substring "goodbye"))

let test_contains_substring_empty_substring_passes _ =
  (* Empty substring is contained in every string per String.is_substring. *)
  assert_that "anything" (contains_substring "")

let test_contains_substring_empty_haystack_fails _ =
  assert_fails (fun () -> assert_that "" (contains_substring "nonempty"))

let test_contains_substring_equal_strings_passes _ =
  assert_that "exact" (contains_substring "exact")

let suite =
  "matchers"
  >::: [
         "not_passes_when_inner_fails" >:: test_not_passes_when_inner_fails;
         "not_fails_when_inner_passes" >:: test_not_fails_when_inner_passes;
         "gt_passes" >:: test_gt_passes;
         "gt_fails_when_equal" >:: test_gt_fails_when_equal;
         "gt_fails_when_less" >:: test_gt_fails_when_less;
         "ge_passes" >:: test_ge_passes;
         "ge_fails_when_less" >:: test_ge_fails_when_less;
         "lt_passes" >:: test_lt_passes;
         "lt_fails_when_equal" >:: test_lt_fails_when_equal;
         "lt_fails_when_greater" >:: test_lt_fails_when_greater;
         "le_passes" >:: test_le_passes;
         "le_fails_when_greater" >:: test_le_fails_when_greater;
         "float_equal_passes_within_epsilon"
         >:: test_float_equal_passes_within_epsilon;
         "float_equal_fails_beyond_epsilon"
         >:: test_float_equal_fails_beyond_epsilon;
         "float_equal_fails_at_exactly_epsilon"
         >:: test_float_equal_fails_at_exactly_epsilon;
         "float_equal_infinities" >:: test_float_equal_infinities;
         "float_equal_fails_when_actual_is_nan"
         >:: test_float_equal_fails_when_actual_is_nan;
         "float_equal_fails_when_expected_is_nan"
         >:: test_float_equal_fails_when_expected_is_nan;
         "float_equal_fails_when_actual_is_nan_against_infinity"
         >:: test_float_equal_fails_when_actual_is_nan_against_infinity;
         "float_equal_fails_when_both_nan_by_default"
         >:: test_float_equal_fails_when_both_nan_by_default;
         "float_equal_passes_when_both_nan_and_opted_in"
         >:: test_float_equal_passes_when_both_nan_and_opted_in;
         "float_equal_nan_equal_does_not_excuse_one_sided_nan"
         >:: test_float_equal_nan_equal_does_not_excuse_one_sided_nan;
         "float_equal_nan_is_visible_through_not_"
         >:: test_float_equal_nan_is_visible_through_not_;
         "float_equal_works_as_unapplied_function"
         >:: test_float_equal_works_as_unapplied_function;
         "float_ord_gt_fails_on_nan" >:: test_float_ord_gt_fails_on_nan;
         "float_ord_ge_fails_on_nan" >:: test_float_ord_ge_fails_on_nan;
         "float_ord_lt_fails_on_nan" >:: test_float_ord_lt_fails_on_nan;
         "float_ord_le_fails_on_nan" >:: test_float_ord_le_fails_on_nan;
         "float_ord_is_between_fails_on_nan"
         >:: test_float_ord_is_between_fails_on_nan;
         "float_ord_ordinary_comparisons_unchanged"
         >:: test_float_ord_ordinary_comparisons_unchanged;
         "pair_passes" >:: test_pair_passes;
         "pair_fails_on_first" >:: test_pair_fails_on_first;
         "pair_fails_on_second" >:: test_pair_fails_on_second;
         "matching_passes_when_some" >:: test_matching_passes_when_some;
         "matching_fails_when_none" >:: test_matching_fails_when_none;
         "matching_custom_msg_fails" >:: test_matching_custom_msg_fails;
         "contains_substring_passes" >:: test_contains_substring_passes;
         "contains_substring_fails_when_absent"
         >:: test_contains_substring_fails_when_absent;
         "contains_substring_empty_substring_passes"
         >:: test_contains_substring_empty_substring_passes;
         "contains_substring_empty_haystack_fails"
         >:: test_contains_substring_empty_haystack_fails;
         "contains_substring_equal_strings_passes"
         >:: test_contains_substring_equal_strings_passes;
       ]

let () = run_test_tt_main suite
