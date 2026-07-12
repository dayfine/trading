open Core
open OUnit2
open Matchers
module ATB = Universe.Asset_type_blocklist

(* ---------------------------------------------------------------------- *)
(* empty is a true no-op                                                    *)
(* ---------------------------------------------------------------------- *)

let test_empty_size_zero _ = assert_that (ATB.size ATB.empty) (equal_to 0)

let test_empty_is_blocked_false _ =
  assert_that (ATB.is_blocked ATB.empty ~symbol:"FTHY") (equal_to false)

(* ---------------------------------------------------------------------- *)
(* of_entries / find / is_blocked                                          *)
(* ---------------------------------------------------------------------- *)

let _entries =
  [
    { ATB.symbol = "FTHY"; category = ATB.Bond_cef };
    { ATB.symbol = "PHYS"; category = ATB.Bullion_trust };
    { ATB.symbol = "GAB"; category = ATB.Equity_cef };
  ]

let test_find_returns_category _ =
  let t = ATB.of_entries _entries in
  assert_that (ATB.find t ~symbol:"FTHY") (is_some_and (equal_to ATB.Bond_cef))

let test_find_absent_is_none _ =
  let t = ATB.of_entries _entries in
  assert_that (ATB.find t ~symbol:"AAPL") is_none

(* Symbol matching is case-insensitive: the stored form is uppercased and the
   lookup uppercases its argument. *)
let test_find_is_case_insensitive _ =
  let t = ATB.of_entries [ { ATB.symbol = "fthy"; category = ATB.Bond_cef } ] in
  assert_that (ATB.find t ~symbol:"FtHy") (is_some_and (equal_to ATB.Bond_cef))

let test_is_blocked _ =
  let t = ATB.of_entries _entries in
  assert_that
    (List.map [ "PHYS"; "AAPL" ] ~f:(fun symbol -> ATB.is_blocked t ~symbol))
    (elements_are [ equal_to true; equal_to false ])

(* On a duplicate symbol the last entry wins. *)
let test_duplicate_last_wins _ =
  let t =
    ATB.of_entries
      [
        { ATB.symbol = "X"; category = ATB.Bond_cef };
        { ATB.symbol = "X"; category = ATB.Equity_cef };
      ]
  in
  assert_that (ATB.find t ~symbol:"X") (is_some_and (equal_to ATB.Equity_cef))

(* ---------------------------------------------------------------------- *)
(* entries is sorted + size                                                *)
(* ---------------------------------------------------------------------- *)

let test_entries_sorted_by_symbol _ =
  let t = ATB.of_entries _entries in
  assert_that
    (List.map (ATB.entries t) ~f:(fun e -> e.ATB.symbol))
    (elements_are [ equal_to "FTHY"; equal_to "GAB"; equal_to "PHYS" ])

let test_size _ = assert_that (ATB.size (ATB.of_entries _entries)) (equal_to 3)

(* ---------------------------------------------------------------------- *)
(* union                                                                   *)
(* ---------------------------------------------------------------------- *)

let test_union_size_and_precedence _ =
  let a =
    ATB.of_entries
      [
        { ATB.symbol = "A"; category = ATB.Bond_cef };
        { ATB.symbol = "SHARED"; category = ATB.Bond_cef };
      ]
  in
  let b =
    ATB.of_entries
      [
        { ATB.symbol = "B"; category = ATB.Equity_cef };
        { ATB.symbol = "SHARED"; category = ATB.Bullion_trust };
      ]
  in
  let u = ATB.union a b in
  assert_that u
    (all_of
       [
         field (fun u -> ATB.size u) (equal_to 3);
         field
           (fun u -> ATB.find u ~symbol:"SHARED")
           (is_some_and (equal_to ATB.Bullion_trust));
       ])

(* ---------------------------------------------------------------------- *)
(* curated seed                                                            *)
(* ---------------------------------------------------------------------- *)

(* The curated seed catches the specific leaks that motivated this module. *)
let test_curated_blocks_known_leaks _ =
  assert_that
    (List.map [ "FTHY"; "PHYS"; "PSLV" ] ~f:(fun symbol ->
         ATB.is_blocked ATB.curated ~symbol))
    (elements_are [ equal_to true; equal_to true; equal_to true ])

(* A genuine operating company is not in the curated blocklist. *)
let test_curated_allows_common_stock _ =
  assert_that (ATB.is_blocked ATB.curated ~symbol:"AAPL") (equal_to false)

let test_curated_categories _ =
  assert_that
    (List.map [ "FTHY"; "GAB"; "PHYS" ] ~f:(fun symbol ->
         ATB.find ATB.curated ~symbol))
    (elements_are
       [
         is_some_and (equal_to ATB.Bond_cef);
         is_some_and (equal_to ATB.Equity_cef);
         is_some_and (equal_to ATB.Bullion_trust);
       ])

(* ---------------------------------------------------------------------- *)
(* load from a committed sexp fixture                                      *)
(* ---------------------------------------------------------------------- *)

let _fixture_path = "data/asset_type_blocklist_sample.sexp"

let test_load_parses_fixture _ =
  match ATB.load ~path:_fixture_path with
  | Error err -> assert_failure ("load failed: " ^ Status.show err)
  | Ok t ->
      assert_that t
        (all_of
           [
             field (fun t -> ATB.size t) (equal_to 4);
             field
               (fun t -> ATB.find t ~symbol:"FTHY")
               (is_some_and (equal_to ATB.Bond_cef));
             field
               (fun t -> ATB.find t ~symbol:"GAB")
               (is_some_and (equal_to ATB.Equity_cef));
           ])

let test_load_missing_file_is_error _ =
  assert_that
    (ATB.load ~path:"data/does_not_exist.sexp")
    (is_error_with Status.Internal)

(* Pins the decode arm of [load]: a readable file whose sexp does not
   match the entry-list shape (unknown category variant) must be
   [Error Internal], not an exception. *)
let test_load_malformed_sexp_is_error _ =
  assert_that
    (ATB.load ~path:"data/asset_type_blocklist_malformed.sexp")
    (is_error_with Status.Internal)

(* sexp round-trip: to-sexp then of-sexp preserves membership + categories. *)
let test_sexp_round_trip _ =
  let t = ATB.of_entries _entries in
  let round = ATB.t_of_sexp (ATB.sexp_of_t t) in
  assert_that
    (List.map (ATB.entries round) ~f:(fun e -> (e.ATB.symbol, e.ATB.category)))
    (elements_are
       [
         equal_to ("FTHY", ATB.Bond_cef);
         equal_to ("GAB", ATB.Equity_cef);
         equal_to ("PHYS", ATB.Bullion_trust);
       ])

let suite =
  "Asset_type_blocklist"
  >::: [
         "test_empty_size_zero" >:: test_empty_size_zero;
         "test_empty_is_blocked_false" >:: test_empty_is_blocked_false;
         "test_find_returns_category" >:: test_find_returns_category;
         "test_find_absent_is_none" >:: test_find_absent_is_none;
         "test_find_is_case_insensitive" >:: test_find_is_case_insensitive;
         "test_is_blocked" >:: test_is_blocked;
         "test_duplicate_last_wins" >:: test_duplicate_last_wins;
         "test_entries_sorted_by_symbol" >:: test_entries_sorted_by_symbol;
         "test_size" >:: test_size;
         "test_union_size_and_precedence" >:: test_union_size_and_precedence;
         "test_curated_blocks_known_leaks" >:: test_curated_blocks_known_leaks;
         "test_curated_allows_common_stock" >:: test_curated_allows_common_stock;
         "test_curated_categories" >:: test_curated_categories;
         "test_load_parses_fixture" >:: test_load_parses_fixture;
         "test_load_missing_file_is_error" >:: test_load_missing_file_is_error;
         "test_load_malformed_sexp_is_error"
         >:: test_load_malformed_sexp_is_error;
         "test_sexp_round_trip" >:: test_sexp_round_trip;
       ]

let () = run_test_tt_main suite
