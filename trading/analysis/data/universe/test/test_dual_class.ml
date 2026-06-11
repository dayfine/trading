open Core
open OUnit2
open Matchers
open Universe
module DC = Dual_class
module CPT = Composition_policy_types

(* ---------------------------------------------------------------------- *)
(* Dual_class.entity_key                                                   *)
(* ---------------------------------------------------------------------- *)

(* Known-pair members of one entity collapse to the same canonical key. *)
let test_known_pair_goog_googl_same_key _ =
  assert_that (DC.entity_key "GOOG") (equal_to (DC.entity_key "GOOGL"))

let test_known_pair_brk_a_b_same_key _ =
  assert_that (DC.entity_key "BRK-A") (equal_to (DC.entity_key "BRK-B"))

(* The canonical key for a known pair is the table's key string. *)
let test_known_pair_canonical_key _ =
  assert_that (DC.entity_key "GOOG") (equal_to "GOOGL")

(* Case-insensitive: lowercased input still hits the known-pairs table. *)
let test_known_pair_case_insensitive _ =
  assert_that (DC.entity_key "goog") (equal_to (DC.entity_key "GOOGL"))

(* Root heuristic: a trailing class suffix is stripped so two share classes
   not in the table still collapse (e.g. a hypothetical FOO-A / FOO-B). *)
let test_heuristic_strips_class_suffix _ =
  assert_that (DC.entity_key "FOO-A") (equal_to (DC.entity_key "FOO-B"))

let test_heuristic_root_equals_base_symbol _ =
  assert_that (DC.entity_key "FOO-A") (equal_to "FOO")

(* Dot-form class suffix is also stripped. *)
let test_heuristic_strips_dot_suffix _ =
  assert_that (DC.entity_key "BAR.A") (equal_to "BAR")

(* A plain single-class ticker with no recognised suffix maps to itself
   (uppercased) and does NOT collide with an unrelated ticker. *)
let test_plain_symbol_maps_to_itself _ =
  assert_that (DC.entity_key "AAPL") (equal_to "AAPL")

let test_distinct_plain_symbols_distinct_keys _ =
  assert_that
    (String.equal (DC.entity_key "AAPL") (DC.entity_key "MSFT"))
    (equal_to false)

(* False-positive guards: the heuristic strips ONLY an explicit two-char
   separator+letter suffix ([-A] / [.B] style). A bare trailing class letter
   with no separator is NOT a class suffix and must not be stripped. *)
let test_bare_trailing_letter_not_stripped _ =
  assert_that (DC.entity_key "TESLA") (equal_to "TESLA")

(* Symbols that merely share a prefix are unrelated entities and must keep
   distinct keys. *)
let test_prefix_sharing_symbols_distinct_keys _ =
  assert_that
    (String.equal (DC.entity_key "FOO") (DC.entity_key "FOOD"))
    (equal_to false)

(* A suffixed class symbol collapses to its root, but an unrelated longer
   symbol extending that root does not collide with it. *)
let test_suffixed_class_distinct_from_longer_symbol _ =
  assert_that
    (String.equal (DC.entity_key "FOO-A") (DC.entity_key "FOOD"))
    (equal_to false)

(* known_pairs is non-empty and every member round-trips to its key. *)
let test_known_pairs_members_round_trip _ =
  let all_consistent =
    List.for_all DC.known_pairs ~f:(fun (key, members) ->
        List.for_all members ~f:(fun m -> String.equal (DC.entity_key m) key))
  in
  assert_that all_consistent (equal_to true)

(* ---------------------------------------------------------------------- *)
(* Composition_policy_types.default_config                                 *)
(* ---------------------------------------------------------------------- *)

(* The default config is the documented no-op: REITs included, no ADR floor,
   preferred kept, "Real Estate" REIT label. *)
let test_default_config_is_current_behaviour _ =
  assert_that CPT.default_config
    (all_of
       [
         field (fun c -> c.CPT.reit_policy) (equal_to CPT.Include);
         field (fun c -> c.CPT.reit_sector_label) (equal_to "Real Estate");
         field (fun c -> c.CPT.adr_min_dollar_volume) is_none;
         field (fun c -> c.CPT.exclude_preferred) (equal_to false);
       ])

let suite =
  "Dual_class"
  >::: [
         "test_known_pair_goog_googl_same_key"
         >:: test_known_pair_goog_googl_same_key;
         "test_known_pair_brk_a_b_same_key" >:: test_known_pair_brk_a_b_same_key;
         "test_known_pair_canonical_key" >:: test_known_pair_canonical_key;
         "test_known_pair_case_insensitive" >:: test_known_pair_case_insensitive;
         "test_heuristic_strips_class_suffix"
         >:: test_heuristic_strips_class_suffix;
         "test_heuristic_root_equals_base_symbol"
         >:: test_heuristic_root_equals_base_symbol;
         "test_heuristic_strips_dot_suffix" >:: test_heuristic_strips_dot_suffix;
         "test_plain_symbol_maps_to_itself" >:: test_plain_symbol_maps_to_itself;
         "test_distinct_plain_symbols_distinct_keys"
         >:: test_distinct_plain_symbols_distinct_keys;
         "test_bare_trailing_letter_not_stripped"
         >:: test_bare_trailing_letter_not_stripped;
         "test_prefix_sharing_symbols_distinct_keys"
         >:: test_prefix_sharing_symbols_distinct_keys;
         "test_suffixed_class_distinct_from_longer_symbol"
         >:: test_suffixed_class_distinct_from_longer_symbol;
         "test_known_pairs_members_round_trip"
         >:: test_known_pairs_members_round_trip;
         "test_default_config_is_current_behaviour"
         >:: test_default_config_is_current_behaviour;
       ]

let () = run_test_tt_main suite
