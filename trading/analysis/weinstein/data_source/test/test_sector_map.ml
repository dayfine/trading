open OUnit2
open Matchers

let test_data_dir = Fpath.v "../../test_data"

let test_load_valid_csv _ =
  let tbl = Sector_map.load ~data_dir:test_data_dir in
  assert_that (Hashtbl.length tbl) (gt (module Int_ord) 0);
  assert_that
    (Hashtbl.find tbl "AAPL")
    (is_some_and (equal_to "Information Technology"));
  assert_that
    (Hashtbl.find tbl "JPM")
    (is_some_and (equal_to "Financials"));
  assert_that
    (Hashtbl.find tbl "CVX")
    (is_some_and (equal_to "Energy"))

let test_load_missing_file _ =
  let tbl = Sector_map.load ~data_dir:(Fpath.v "/nonexistent/path") in
  assert_that (Hashtbl.length tbl) (equal_to 0)

let test_load_all_rows _ =
  let tbl = Sector_map.load ~data_dir:test_data_dir in
  (* test_data/sectors.csv has 7 stocks *)
  assert_that (Hashtbl.length tbl) (equal_to 7)

let suite =
  "Sector_map"
  >::: [
         "load valid CSV" >:: test_load_valid_csv;
         "load missing file returns empty" >:: test_load_missing_file;
         "load all rows" >:: test_load_all_rows;
       ]

let () = run_test_tt_main suite
