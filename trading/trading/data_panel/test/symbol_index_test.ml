open OUnit2
open Core
open Matchers
module Symbol_index = Data_panel.Symbol_index

let _make_idx universe =
  match Symbol_index.create ~universe with
  | Ok t -> t
  | Error err ->
      assert_failure (Printf.sprintf "create failed: %s" err.Status.message)

let test_create_basic _ =
  let idx = _make_idx [ "AAPL"; "MSFT"; "GOOG" ] in
  assert_that idx
    (all_of
       [
         field Symbol_index.n (equal_to 3);
         field
           (fun i -> Symbol_index.to_row i "AAPL")
           (is_some_and (equal_to 0));
         field
           (fun i -> Symbol_index.to_row i "MSFT")
           (is_some_and (equal_to 1));
         field
           (fun i -> Symbol_index.to_row i "GOOG")
           (is_some_and (equal_to 2));
         field (fun i -> Symbol_index.to_row i "AMZN") is_none;
         field (fun i -> Symbol_index.of_row i 0) (equal_to "AAPL");
         field (fun i -> Symbol_index.of_row i 1) (equal_to "MSFT");
         field (fun i -> Symbol_index.of_row i 2) (equal_to "GOOG");
       ])

let test_empty_universe _ =
  let idx = _make_idx [] in
  assert_that idx
    (all_of
       [
         field Symbol_index.n (equal_to 0);
         field (fun i -> Symbol_index.to_row i "AAPL") is_none;
       ])

let test_duplicate_rejected _ =
  let result = Symbol_index.create ~universe:[ "AAPL"; "MSFT"; "AAPL" ] in
  assert_that result (is_error_with Status.Invalid_argument ~msg:"AAPL")

let test_empty_string_rejected _ =
  let result = Symbol_index.create ~universe:[ "AAPL"; ""; "MSFT" ] in
  assert_that result (is_error_with Status.Invalid_argument)

let test_of_row_out_of_range _ =
  let idx = _make_idx [ "AAPL"; "MSFT" ] in
  assert_raises
    (Invalid_argument "Symbol_index.of_row: index 5 out of range [0, 2)")
    (fun () -> Symbol_index.of_row idx 5);
  assert_raises
    (Invalid_argument "Symbol_index.of_row: index -1 out of range [0, 2)")
    (fun () -> Symbol_index.of_row idx (-1))

let test_symbols_round_trip _ =
  let universe = [ "ZYX"; "AAPL"; "BRK.A"; "GOOG"; "TSLA" ] in
  let idx = _make_idx universe in
  assert_that (Symbol_index.symbols idx) (equal_to universe)

let test_5000_symbols _ =
  let universe = List.init 5000 ~f:(fun i -> Printf.sprintf "SYM%04d" i) in
  let idx = _make_idx universe in
  assert_that idx
    (all_of
       [
         field Symbol_index.n (equal_to 5000);
         field
           (fun i -> Symbol_index.to_row i "SYM0000")
           (is_some_and (equal_to 0));
         field
           (fun i -> Symbol_index.to_row i "SYM2500")
           (is_some_and (equal_to 2500));
         field
           (fun i -> Symbol_index.to_row i "SYM4999")
           (is_some_and (equal_to 4999));
         field (fun i -> Symbol_index.of_row i 0) (equal_to "SYM0000");
         field (fun i -> Symbol_index.of_row i 4999) (equal_to "SYM4999");
       ])

let suite =
  "Symbol_index tests"
  >::: [
         "test_create_basic" >:: test_create_basic;
         "test_empty_universe" >:: test_empty_universe;
         "test_duplicate_rejected" >:: test_duplicate_rejected;
         "test_empty_string_rejected" >:: test_empty_string_rejected;
         "test_of_row_out_of_range" >:: test_of_row_out_of_range;
         "test_symbols_round_trip" >:: test_symbols_round_trip;
         "test_5000_symbols" >:: test_5000_symbols;
       ]

let () = run_test_tt_main suite
