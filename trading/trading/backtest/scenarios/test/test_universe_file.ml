open OUnit2
open Core
open Matchers
module Universe_file = Scenario_lib.Universe_file

let test_pinned_parses _ =
  let sexp =
    Sexp.of_string
      {|
    (Pinned (
      ((symbol AAPL) (sector "Information Technology"))
      ((symbol JPM)  (sector Financials))))
  |}
  in
  let uf = Universe_file.t_of_sexp sexp in
  match uf with
  | Universe_file.Full_sector_map -> assert_failure "expected Pinned"
  | Pinned entries ->
      assert_that entries
        (elements_are
           [
             all_of
               [
                 field (fun e -> e.Universe_file.symbol) (equal_to "AAPL");
                 field
                   (fun e -> e.Universe_file.sector)
                   (equal_to "Information Technology");
               ];
             all_of
               [
                 field (fun e -> e.Universe_file.symbol) (equal_to "JPM");
                 field (fun e -> e.Universe_file.sector) (equal_to "Financials");
               ];
           ])

let test_full_sector_map_parses _ =
  let uf = Universe_file.t_of_sexp (Sexp.of_string "Full_sector_map") in
  match uf with
  | Universe_file.Full_sector_map -> ()
  | Pinned _ -> assert_failure "expected Full_sector_map"

let test_roundtrip_pinned _ =
  let original =
    Universe_file.Pinned
      [
        { symbol = "AAPL"; sector = "Information Technology" };
        { symbol = "JPM"; sector = "Financials" };
      ]
  in
  let roundtripped =
    Universe_file.t_of_sexp (Universe_file.sexp_of_t original)
  in
  match roundtripped with
  | Pinned entries ->
      assert_that (List.length entries) (equal_to 2);
      assert_that (List.hd_exn entries).symbol (equal_to "AAPL")
  | Full_sector_map -> assert_failure "expected Pinned after roundtrip"

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

let test_committed_universes_parse _ =
  match _universes_root () with
  | None ->
      assert_failure
        (sprintf "universes/ dir not found from cwd=%s" (Stdlib.Sys.getcwd ()))
  | Some root -> (
      let small = Universe_file.load (Filename.concat root "small.sexp") in
      let broad = Universe_file.load (Filename.concat root "broad.sexp") in
      (* Small universe: at least 100 symbols, spanning multiple sectors. *)
      (match small with
      | Pinned entries ->
          assert_bool
            (sprintf
               "small universe too small: %d (want >= 100 for sector diversity)"
               (List.length entries))
            (List.length entries >= 100);
          let sectors =
            List.map entries ~f:(fun e -> e.Universe_file.sector)
            |> List.dedup_and_sort ~compare:String.compare
          in
          assert_bool
            (sprintf "small universe has only %d distinct sectors"
               (List.length sectors))
            (List.length sectors >= 8)
      | Full_sector_map ->
          assert_failure "small.sexp should be Pinned, not Full_sector_map");
      (* Broad universe: the sentinel. *)
      match broad with
      | Full_sector_map -> ()
      | Pinned _ -> assert_failure "broad.sexp should be Full_sector_map")

let suite =
  "Universe_file"
  >::: [
         "Pinned parses" >:: test_pinned_parses;
         "Full_sector_map parses" >:: test_full_sector_map_parses;
         "Pinned round-trips" >:: test_roundtrip_pinned;
         "symbol_count" >:: test_symbol_count;
         "committed universes parse" >:: test_committed_universes_parse;
       ]

let () = run_test_tt_main suite
