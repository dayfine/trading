open Core
open OUnit2
open Matchers
module Tiers = Trading_portfolio.Short_margin_tiers

(* Researched-style example table (kept in the test, not baked into code):
   sub-$5 → 100%, $5-$17 → ≈83%, ≥ ~$17 → flat fallback (0.30 here). *)
let example_tiers =
  [
    { Tiers.price_below = 5.0; value = 1.0 };
    { Tiers.price_below = 17.0; value = 0.83 };
  ]

let flat_fallback = 0.30

let lookup price = Tiers.tier_value ~tiers:example_tiers ~flat_fallback ~price

let test_empty_table_returns_fallback _ =
  assert_that
    (Tiers.tier_value ~tiers:[] ~flat_fallback ~price:3.0)
    (float_equal flat_fallback)

let test_tightest_band_wins_low_price _ =
  (* $3 is covered by both bands ($5 and $17); the tightest ($5) wins. *)
  assert_that (lookup 3.0) (float_equal 1.0)

let test_middle_band _ =
  (* $10 is covered only by the $17 band. *)
  assert_that (lookup 10.0) (float_equal 0.83)

let test_uncovered_price_uses_fallback _ =
  (* $20 is above every band → flat fallback. *)
  assert_that (lookup 20.0) (float_equal flat_fallback)

let test_price_at_boundary_excludes_band _ =
  (* price_below is exclusive: $5 exactly is NOT below the $5 band, so it
     falls through to the $17 band. *)
  assert_that (lookup 5.0) (float_equal 0.83)

let test_order_independent _ =
  (* Reversing the tier list yields the same tightest-band selection. *)
  let reversed = List.rev example_tiers in
  assert_that
    (Tiers.tier_value ~tiers:reversed ~flat_fallback ~price:3.0)
    (float_equal 1.0)

let suite =
  "short_margin_tiers"
  >::: [
         "test_empty_table_returns_fallback" >:: test_empty_table_returns_fallback;
         "test_tightest_band_wins_low_price" >:: test_tightest_band_wins_low_price;
         "test_middle_band" >:: test_middle_band;
         "test_uncovered_price_uses_fallback" >:: test_uncovered_price_uses_fallback;
         "test_price_at_boundary_excludes_band"
         >:: test_price_at_boundary_excludes_band;
         "test_order_independent" >:: test_order_independent;
       ]

let () = run_test_tt_main suite
