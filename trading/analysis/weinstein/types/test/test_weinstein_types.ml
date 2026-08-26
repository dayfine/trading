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

(* GICS canonical spellings must parse. *)
let test_gics_of_string_canonical _ =
  assert_that
    (gics_sector_of_string_opt "Information Technology")
    (is_some_and (equal_to Information_technology));
  assert_that
    (gics_sector_of_string_opt "Health Care")
    (is_some_and (equal_to Health_care));
  assert_that
    (gics_sector_of_string_opt "COMMUNICATION SERVICES")
    (is_some_and (equal_to Communication_services))

(* All 11 Finviz sector display labels (verified against
   finviz.com/groups.ashx?g=sector) must map to a GICS variant. If
   Finviz ever renames one, this test fails loudly. *)
let test_gics_of_string_all_finviz_labels _ =
  let finviz_to_gics =
    [
      ("Basic Materials", Materials);
      ("Communication Services", Communication_services);
      ("Consumer Cyclical", Consumer_discretionary);
      ("Consumer Defensive", Consumer_staples);
      ("Energy", Energy);
      ("Financial", Financials);
      ("Financial Services", Financials);
      ("Healthcare", Health_care);
      ("Industrials", Industrials);
      ("Real Estate", Real_estate);
      ("Technology", Information_technology);
      ("Utilities", Utilities);
    ]
  in
  List.iter
    (fun (label, expected) ->
      assert_that
        (gics_sector_of_string_opt label)
        (is_some_and (equal_to expected)))
    finviz_to_gics

let test_gics_of_string_unknown _ =
  assert_that (gics_sector_of_string_opt "Bogus") is_none;
  assert_that (gics_sector_of_string_opt "") is_none

(* normalize_sector_name returns the canonical GICS spelling for known
   names, passes unknowns through unchanged. *)
let test_normalize_sector_name _ =
  assert_that
    (normalize_sector_name "Technology")
    (equal_to "Information Technology");
  assert_that (normalize_sector_name "Financial") (equal_to "Financials");
  assert_that (normalize_sector_name "Healthcare") (equal_to "Health Care");
  assert_that
    (normalize_sector_name "Information Technology")
    (equal_to "Information Technology");
  assert_that (normalize_sector_name "Bogus") (equal_to "Bogus")

(* [rs_trend]'s sexp encoding is by CONSTRUCTOR NAME, not by position, so
   inserting [Positive_declining] in the middle of the variant (issue #2556)
   cannot change how any previously-written atom decodes. That is the property
   that makes the placement free — and it is worth pinning, because the obvious
   alternative assumption (positional encoding) would make every archived sexp
   carrying a post-[Positive_flat] state decode to the wrong constructor.

   Asserted over ALL SIX pre-existing atoms in one shot rather than a
   representative one: a positional encoding would leave the three atoms that
   sort before the insertion point correct and only corrupt the three after it,
   so a single-atom check could pass on exactly the bug it is meant to catch. *)
let test_rs_trend_sexp_is_name_encoded _ =
  let decode name = rs_trend_of_sexp (Sexplib.Sexp.Atom name) in
  assert_that
    (List.map decode
       [
         "Bullish_crossover";
         "Positive_rising";
         "Positive_flat";
         "Negative_improving";
         "Negative_declining";
         "Bearish_crossover";
       ])
    (equal_to
       [
         Bullish_crossover;
         Positive_rising;
         Positive_flat;
         Negative_improving;
         Negative_declining;
         Bearish_crossover;
       ])

(* The new constructor round-trips like any other. *)
let test_positive_declining_sexp_round_trips _ =
  assert_that
    (rs_trend_of_sexp (sexp_of_rs_trend Positive_declining))
    (equal_to Positive_declining)

let suite =
  "weinstein_types"
  >::: [
         "rs_trend sexp is name-encoded" >:: test_rs_trend_sexp_is_name_encoded;
         "Positive_declining sexp round-trips"
         >:: test_positive_declining_sexp_round_trips;
         "stage_eq" >:: test_stage_eq;
         "ma_direction_eq" >:: test_ma_direction_eq;
         "gics_of_string canonical" >:: test_gics_of_string_canonical;
         "gics_of_string all finviz labels"
         >:: test_gics_of_string_all_finviz_labels;
         "gics_of_string unknown" >:: test_gics_of_string_unknown;
         "normalize_sector_name" >:: test_normalize_sector_name;
       ]

let () = run_test_tt_main suite
