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
         "pair_passes" >:: test_pair_passes;
         "pair_fails_on_first" >:: test_pair_fails_on_first;
         "pair_fails_on_second" >:: test_pair_fails_on_second;
         "matching_passes_when_some" >:: test_matching_passes_when_some;
         "matching_fails_when_none" >:: test_matching_fails_when_none;
         "matching_custom_msg_fails" >:: test_matching_custom_msg_fails;
       ]

let () = run_test_tt_main suite
