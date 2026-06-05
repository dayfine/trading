open Core
open OUnit2
open Matchers
module Snapshot = Universe.Snapshot

(* --- Helpers ------------------------------------------------------------- *)

(* The Pinned universe shape mirrors [scenario_lib/universe_file]:
   [(Pinned ((symbol AAPL) (sector "...")) ...)]. Built as a raw sexp string so
   the test pins the exact on-disk shape [build_snapshots] must accept. *)
let pinned_sexp symbols =
  let entries =
    List.map symbols ~f:(fun s ->
        Printf.sprintf "((symbol %s) (sector \"\"))" s)
  in
  Sexp.of_string
    (Printf.sprintf "(Pinned (%s))" (String.concat ~sep:" " entries))

let entry ~symbol ~synthetic ~sector : Snapshot.entry =
  { symbol; weight = 0.001; sector; synthetic }

(* A composition snapshot in the on-disk shape [Universe.Snapshot.save] writes.
   Serialized via [sexp_of_t] so the test exercises the real decode path. *)
let composition_sexp entries =
  Snapshot.sexp_of_t
    {
      date = Date.of_string "1998-05-31";
      method_ = Composition_from_individuals;
      size = List.length entries;
      entries;
      aggregate_period_return = 0.0;
    }

(* --- Pinned (regression) ------------------------------------------------- *)

let test_pinned_returns_symbols_verbatim _ctx =
  let result =
    Universe_loader.symbols_of_sexp (pinned_sexp [ "AAPL"; "MSFT" ])
  in
  assert_that result
    (is_ok_and_holds (elements_are [ equal_to "AAPL"; equal_to "MSFT" ]))

let test_full_sector_map_is_unimplemented _ctx =
  let result =
    Universe_loader.symbols_of_sexp (Sexp.of_string "Full_sector_map")
  in
  assert_that result (is_error_with Status.Unimplemented)

(* --- Composition --------------------------------------------------------- *)

let test_composition_returns_real_tickers _ctx =
  let sexp =
    composition_sexp
      [
        entry ~symbol:"AAPL" ~synthetic:false ~sector:"Information Technology";
        entry ~symbol:"JPM" ~synthetic:false ~sector:"Financials";
      ]
  in
  let result = Universe_loader.symbols_of_sexp sexp in
  assert_that result
    (is_ok_and_holds (elements_are [ equal_to "AAPL"; equal_to "JPM" ]))

(* Synthetic [SYNTH_*] entries carry no CSV bars, so the loader must drop them —
   mirrors [universe_snapshot]'s synthetic-dropping. *)
let test_composition_drops_synthetic_entries _ctx =
  let sexp =
    composition_sexp
      [
        entry ~symbol:"AAPL" ~synthetic:false ~sector:"Information Technology";
        entry ~symbol:"SYNTH_HiTec_0042" ~synthetic:true ~sector:"HiTec";
        entry ~symbol:"JPM" ~synthetic:false ~sector:"Financials";
      ]
  in
  let result = Universe_loader.symbols_of_sexp sexp in
  assert_that result
    (is_ok_and_holds (elements_are [ equal_to "AAPL"; equal_to "JPM" ]))

(* All-synthetic → no tradeable symbols, mirroring [universe_snapshot]'s
   [Failed_precondition] guard. *)
let test_all_synthetic_is_failed_precondition _ctx =
  let sexp =
    composition_sexp
      [
        entry ~symbol:"SYNTH_HiTec_0001" ~synthetic:true ~sector:"HiTec";
        entry ~symbol:"SYNTH_Manuf_0002" ~synthetic:true ~sector:"Manuf";
      ]
  in
  let result = Universe_loader.symbols_of_sexp sexp in
  assert_that result (is_error_with Status.Failed_precondition)

(* --- Unrecognized shape -------------------------------------------------- *)

let test_unrecognized_shape_is_failed_precondition _ctx =
  let result =
    Universe_loader.symbols_of_sexp (Sexp.of_string "(not a universe)")
  in
  assert_that result (is_error_with Status.Failed_precondition)

let suite =
  "universe_loader"
  >::: [
         "pinned returns symbols verbatim"
         >:: test_pinned_returns_symbols_verbatim;
         "full_sector_map is unimplemented"
         >:: test_full_sector_map_is_unimplemented;
         "composition returns real tickers"
         >:: test_composition_returns_real_tickers;
         "composition drops synthetic entries"
         >:: test_composition_drops_synthetic_entries;
         "all-synthetic is failed_precondition"
         >:: test_all_synthetic_is_failed_precondition;
         "unrecognized shape is failed_precondition"
         >:: test_unrecognized_shape_is_failed_precondition;
       ]

let () = run_test_tt_main suite
