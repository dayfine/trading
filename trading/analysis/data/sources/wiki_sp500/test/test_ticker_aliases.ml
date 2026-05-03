open Core
open OUnit2
open Matchers
open Wiki_sp500.Ticker_aliases

(* FB → META rename took effect 2022-06-09. *)
let _meta_rename_date = Date.create_exn ~y:2022 ~m:Month.Jun ~d:9
let _pre_rename = Date.create_exn ~y:2022 ~m:Month.Jun ~d:1
let _post_rename = Date.create_exn ~y:2022 ~m:Month.Jun ~d:10
let _arbitrary_date = Date.create_exn ~y:2020 ~m:Month.Jan ~d:1

let test_meta_aliased_to_fb_pre_2022_06_09 _ =
  assert_that (canonicalize ~symbol:"META" ~as_of:_pre_rename) (equal_to "FB")

let test_meta_unaliased_post_2022_06_09 _ =
  assert_that
    (canonicalize ~symbol:"META" ~as_of:_post_rename)
    (equal_to "META")

(* The exact effective_date is the first day the new ticker is the
   canonical one — we should NOT alias on or after that date. *)
let test_meta_unaliased_on_effective_date _ =
  assert_that
    (canonicalize ~symbol:"META" ~as_of:_meta_rename_date)
    (equal_to "META")

let test_unknown_symbol_passes_through _ =
  assert_that
    (canonicalize ~symbol:"UNKNOWN" ~as_of:_arbitrary_date)
    (equal_to "UNKNOWN")

(* Idempotence: applying canonicalize to its own output gives the same
   answer (the historical symbol is itself not in the [current_symbol]
   column for any alias whose date matters here). *)
let test_canonicalization_idempotent _ =
  let once = canonicalize ~symbol:"META" ~as_of:_pre_rename in
  let twice = canonicalize ~symbol:once ~as_of:_pre_rename in
  assert_that twice (equal_to once)

(* Each curated alias must have a distinct [current_symbol] — otherwise
   [canonicalize] would silently pick whichever [List.find] returns
   first, which is brittle. *)
let test_all_entries_have_distinct_current_symbols _ =
  let symbols = List.map all ~f:(fun a -> a.current_symbol) in
  let unique = List.dedup_and_sort symbols ~compare:String.compare in
  assert_that (List.length symbols) (equal_to (List.length unique))

let suite =
  "ticker_aliases_test"
  >::: [
         "meta_aliased_to_fb_pre_2022_06_09"
         >:: test_meta_aliased_to_fb_pre_2022_06_09;
         "meta_unaliased_post_2022_06_09"
         >:: test_meta_unaliased_post_2022_06_09;
         "meta_unaliased_on_effective_date"
         >:: test_meta_unaliased_on_effective_date;
         "unknown_symbol_passes_through" >:: test_unknown_symbol_passes_through;
         "canonicalization_idempotent" >:: test_canonicalization_idempotent;
         "all_entries_have_distinct_current_symbols"
         >:: test_all_entries_have_distinct_current_symbols;
       ]

let () = run_test_tt_main suite
