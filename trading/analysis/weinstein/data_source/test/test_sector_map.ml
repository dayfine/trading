open OUnit2
open Core
open Matchers

let test_data_dir = Data_path.default_data_dir ()

let test_load_valid_csv _ =
  let tbl = Sector_map.load ~data_dir:test_data_dir in
  assert_that (Hashtbl.length tbl) (gt (module Int_ord) 0);
  assert_that (Hashtbl.find tbl "AAPL")
    (is_some_and (equal_to "Information Technology"));
  assert_that (Hashtbl.find tbl "JPM") (is_some_and (equal_to "Financials"));
  assert_that (Hashtbl.find tbl "CVX") (is_some_and (equal_to "Energy"))

let test_load_missing_file _ =
  let tbl = Sector_map.load ~data_dir:(Fpath.v "/nonexistent/path") in
  assert_that (Hashtbl.length tbl) (equal_to 0)

let test_load_all_rows _ =
  let tbl = Sector_map.load ~data_dir:test_data_dir in
  (* CI uses test_data/ (7 rows); dev container uses data/ (1654 rows) *)
  assert_that (Hashtbl.length tbl) (gt (module Int_ord) 0)

(* Every sector name in the CSV must be a recognized GICS sector. This catches
   drift between the CSV data and the canonical enum. *)
let test_all_sector_names_are_valid_gics _ =
  let tbl = Sector_map.load ~data_dir:test_data_dir in
  let invalid =
    Hashtbl.fold tbl ~init:[] ~f:(fun ~key:ticker ~data:sector_name acc ->
        match Weinstein_types.gics_sector_of_string_opt sector_name with
        | Some _ -> acc
        | None -> (ticker, sector_name) :: acc)
  in
  assert_that invalid is_empty

let suite =
  "Sector_map"
  >::: [
         "load valid CSV" >:: test_load_valid_csv;
         "load missing file returns empty" >:: test_load_missing_file;
         "load all rows" >:: test_load_all_rows;
         "all sector names are valid GICS"
         >:: test_all_sector_names_are_valid_gics;
       ]

let () = run_test_tt_main suite
