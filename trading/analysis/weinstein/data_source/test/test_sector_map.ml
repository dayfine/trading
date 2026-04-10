open Core
open OUnit2
open Matchers

(* Create a temp dir and clean it up after the test — mirrors the pattern
   used by test_historical_source. *)
let with_temp_dir f =
  let dir = Filename_unix.temp_dir "test_sector_map" "" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" dir) in
      ())
    (fun () -> f dir)

let write_file ~path contents = Out_channel.write_all path ~data:contents

(* ---- of_alist / find / to_alist ---- *)

let test_of_alist_and_find _ =
  let m =
    Sector_map.of_alist
      [ ("AAPL", "Technology"); ("JPM", "Financials"); ("XOM", "Energy") ]
  in
  assert_that m
    (all_of
       [
         field Sector_map.size (equal_to 3);
         field
           (fun m -> Sector_map.find m "AAPL")
           (is_some_and (equal_to "Technology"));
         field
           (fun m -> Sector_map.find m "JPM")
           (is_some_and (equal_to "Financials"));
         field (fun m -> Sector_map.find m "NOPE") is_none;
       ])

let test_of_alist_later_wins _ =
  (* When the same symbol appears twice the last binding should win. *)
  let m =
    Sector_map.of_alist
      [ ("AAPL", "Tech Sector v1"); ("AAPL", "Information Technology") ]
  in
  assert_that m
    (field
       (fun m -> Sector_map.find m "AAPL")
       (is_some_and (equal_to "Information Technology")))

let test_to_alist_sorted _ =
  let m = Sector_map.of_alist [ ("ZZZ", "Z"); ("AAA", "A"); ("MMM", "M") ] in
  assert_that (Sector_map.to_alist m)
    (elements_are
       [ equal_to ("AAA", "A"); equal_to ("MMM", "M"); equal_to ("ZZZ", "Z") ])

let test_empty _ =
  assert_that Sector_map.empty
    (all_of
       [
         field Sector_map.size (equal_to 0);
         field (fun m -> Sector_map.find m "AAPL") is_none;
       ])

(* ---- load (CSV parsing) ---- *)

(* Missing file is not an error — callers degrade gracefully. *)
let test_load_missing_file _ =
  with_temp_dir (fun dir ->
      let result = Sector_map.load ~data_dir:(Fpath.v dir) in
      assert_that result (is_ok_and_holds (field Sector_map.size (equal_to 0))))

let test_load_parses_header_and_rows _ =
  with_temp_dir (fun dir ->
      let path = Filename.concat dir "sectors.csv" in
      write_file ~path
        "symbol,sector\nAAPL,Information Technology\nJPM,Financials\n";
      let result = Sector_map.load ~data_dir:(Fpath.v dir) in
      assert_that result
        (is_ok_and_holds
           (all_of
              [
                field Sector_map.size (equal_to 2);
                field
                  (fun m -> Sector_map.find m "AAPL")
                  (is_some_and (equal_to "Information Technology"));
                field
                  (fun m -> Sector_map.find m "JPM")
                  (is_some_and (equal_to "Financials"));
              ])))

(* The header row is optional — files without it parse correctly. *)
let test_load_without_header _ =
  with_temp_dir (fun dir ->
      let path = Filename.concat dir "sectors.csv" in
      write_file ~path "XLK,Technology\nXLF,Financials\n";
      let result = Sector_map.load ~data_dir:(Fpath.v dir) in
      assert_that result (is_ok_and_holds (field Sector_map.size (equal_to 2))))

(* Blank lines and rows with an empty sector are silently dropped. *)
let test_load_ignores_blank_and_empty _ =
  with_temp_dir (fun dir ->
      let path = Filename.concat dir "sectors.csv" in
      write_file ~path
        "symbol,sector\n\nAAPL,Technology\nUNK,\n   \nJPM,Financials\n";
      let result = Sector_map.load ~data_dir:(Fpath.v dir) in
      assert_that result
        (is_ok_and_holds
           (all_of
              [
                field Sector_map.size (equal_to 2);
                field (fun m -> Sector_map.find m "UNK") is_none;
              ])))

(* Symbols with a dot (BRK.B) or other punctuation parse verbatim — the
   CSV uses only one comma as the separator, so anything after the first
   comma is treated as the sector value. *)
let test_load_handles_dotted_symbols _ =
  with_temp_dir (fun dir ->
      let path = Filename.concat dir "sectors.csv" in
      write_file ~path "symbol,sector\nBRK.B,Financials\n";
      let result = Sector_map.load ~data_dir:(Fpath.v dir) in
      assert_that result
        (is_ok_and_holds
           (field
              (fun m -> Sector_map.find m "BRK.B")
              (is_some_and (equal_to "Financials")))))

let test_sectors_csv_path _ =
  let path = Sector_map.sectors_csv_path (Fpath.v "/tmp") in
  assert_that (Fpath.to_string path) (equal_to "/tmp/sectors.csv")

let suite =
  "sector_map"
  >::: [
         "of_alist_and_find" >:: test_of_alist_and_find;
         "of_alist_later_wins" >:: test_of_alist_later_wins;
         "to_alist_sorted" >:: test_to_alist_sorted;
         "empty" >:: test_empty;
         "load_missing_file" >:: test_load_missing_file;
         "load_parses_header_and_rows" >:: test_load_parses_header_and_rows;
         "load_without_header" >:: test_load_without_header;
         "load_ignores_blank_and_empty" >:: test_load_ignores_blank_and_empty;
         "load_handles_dotted_symbols" >:: test_load_handles_dotted_symbols;
         "sectors_csv_path" >:: test_sectors_csv_path;
       ]

let () = run_test_tt_main suite
