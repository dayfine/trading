open OUnit2
open Core
open Matchers
module Universe_file = Scenario_lib.Universe_file

let when_pinned inner =
  matching ~msg:"expected Pinned"
    (function Universe_file.Pinned xs -> Some xs | _ -> None)
    inner

let test_pinned_parses _ =
  let sexp =
    Sexp.of_string
      {|
    (Pinned (
      ((symbol AAPL) (sector "Information Technology"))
      ((symbol JPM)  (sector Financials))))
  |}
  in
  assert_that
    (Universe_file.t_of_sexp sexp)
    (when_pinned
       (elements_are
          [
            equal_to
              ({ symbol = "AAPL"; sector = "Information Technology" }
                : Universe_file.pinned_entry);
            equal_to
              ({ symbol = "JPM"; sector = "Financials" }
                : Universe_file.pinned_entry);
          ]))

let test_full_sector_map_parses _ =
  assert_that
    (Universe_file.t_of_sexp (Sexp.of_string "Full_sector_map"))
    (matching ~msg:"expected Full_sector_map"
       (function Universe_file.Full_sector_map -> Some () | _ -> None)
       (equal_to ()))

let test_roundtrip_pinned _ =
  let original =
    Universe_file.Pinned
      [
        { symbol = "AAPL"; sector = "Information Technology" };
        { symbol = "JPM"; sector = "Financials" };
      ]
  in
  assert_that
    (Universe_file.t_of_sexp (Universe_file.sexp_of_t original))
    (when_pinned
       (elements_are
          [
            equal_to
              ({ symbol = "AAPL"; sector = "Information Technology" }
                : Universe_file.pinned_entry);
            equal_to
              ({ symbol = "JPM"; sector = "Financials" }
                : Universe_file.pinned_entry);
          ]))

let test_symbol_count _ =
  let pinned =
    Universe_file.Pinned
      [
        { symbol = "A"; sector = "X" };
        { symbol = "B"; sector = "X" };
        { symbol = "C"; sector = "Y" };
      ]
  in
  assert_that (Universe_file.symbol_count pinned) (is_some_and (equal_to 3));
  assert_that (Universe_file.symbol_count Full_sector_map) is_none

let test_to_sector_map_override_full _ =
  assert_that
    (Universe_file.to_sector_map_override Universe_file.Full_sector_map)
    is_none

let test_to_sector_map_override_pinned _ =
  let uf =
    Universe_file.Pinned
      [
        { symbol = "AAPL"; sector = "Information Technology" };
        { symbol = "JPM"; sector = "Financials" };
      ]
  in
  match Universe_file.to_sector_map_override uf with
  | None -> assert_failure "Pinned should yield Some sector-map"
  | Some tbl ->
      assert_that (Hashtbl.length tbl) (equal_to 2);
      assert_that (Hashtbl.find tbl "AAPL")
        (is_some_and (equal_to "Information Technology"));
      assert_that (Hashtbl.find tbl "JPM") (is_some_and (equal_to "Financials"))

(* The committed [universes/small.sexp] and [universes/broad.sexp] files must
   parse — this is the regression guard for the fixture itself. *)
let _universes_root () =
  let rec walk_up dir tries_left =
    if tries_left = 0 then None
    else
      let candidate =
        Filename.concat dir "trading/test_data/backtest_scenarios/universes"
      in
      if try Stdlib.Sys.is_directory candidate with _ -> false then
        Some candidate
      else
        let parent = Filename.dirname dir in
        if String.equal parent dir then None else walk_up parent (tries_left - 1)
  in
  walk_up (Stdlib.Sys.getcwd ()) 10

let _distinct_sector_count entries =
  List.map entries ~f:(fun e -> e.Universe_file.sector)
  |> List.dedup_and_sort ~compare:String.compare
  |> List.length

let test_committed_universes_parse _ =
  match _universes_root () with
  | None ->
      assert_failure
        (sprintf "universes/ dir not found from cwd=%s" (Stdlib.Sys.getcwd ()))
  | Some root ->
      (* Small universe: at least 100 symbols, spanning ≥8 sectors. *)
      assert_that
        (Universe_file.load (Filename.concat root "small.sexp"))
        (when_pinned
           (all_of
              [
                field List.length (ge (module Int_ord) 100);
                field _distinct_sector_count (ge (module Int_ord) 8);
              ]));
      (* Broad universe: the sentinel. *)
      assert_that
        (Universe_file.load (Filename.concat root "broad.sexp"))
        (matching ~msg:"expected Full_sector_map"
           (function Universe_file.Full_sector_map -> Some () | _ -> None)
           (equal_to ()))

let suite =
  "Universe_file"
  >::: [
         "Pinned parses" >:: test_pinned_parses;
         "Full_sector_map parses" >:: test_full_sector_map_parses;
         "Pinned round-trips" >:: test_roundtrip_pinned;
         "symbol_count" >:: test_symbol_count;
         "to_sector_map_override Full_sector_map"
         >:: test_to_sector_map_override_full;
         "to_sector_map_override Pinned" >:: test_to_sector_map_override_pinned;
         "committed universes parse" >:: test_committed_universes_parse;
       ]

let () = run_test_tt_main suite
