open OUnit2
open Core
open Matchers

let _write path contents =
  Core_unix.mkdir_p (Filename.dirname path);
  Out_channel.write_all path ~data:contents

let _csv rows = "date,open,high,low,close,adjusted_close,volume\n" ^ rows

let _metadata ~symbol ~start_ ~end_ =
  sprintf
    "((symbol %s) (last_verified 2026-08-18) (verification_status Verified) \
     (data_start_date %s) (data_end_date %s) (has_volume true) \
     (last_n_prices_avg_below_10 false) (last_n_prices_avg_above_500 false))"
    symbol start_ end_

let _entry_is ~symbol ~start_ ~end_ =
  all_of
    [
      field (fun (e : Inventory.entry) -> e.symbol) (equal_to symbol);
      field
        (fun (e : Inventory.entry) -> Date.to_string e.data_start_date)
        (equal_to start_);
      field
        (fun (e : Inventory.entry) -> Date.to_string e.data_end_date)
        (equal_to end_);
    ]

(* AA has metadata (its range is taken from there, not from the csv); BB has
   only a data.csv (a bulk gap fetch) and must be indexed from its rows; CC has
   a header-only csv and is skipped. *)
let test_build_indexes_csv_without_metadata _ =
  let root = Core_unix.mkdtemp "/tmp/test_inventory" in
  _write (root ^ "/A/A/AA/data.csv") (_csv "2020-01-02,1,1,1,1,1,1\n");
  _write
    (root ^ "/A/A/AA/data.metadata.sexp")
    (_metadata ~symbol:"AA" ~start_:"2019-01-02" ~end_:"2021-01-04");
  _write
    (root ^ "/B/B/BB/data.csv")
    (_csv
       "2010-03-01,1,1,1,1,1,1\n\
        2010-03-02,1,1,1,1,1,1\n\
        2010-03-03,1,1,1,1,1,1\n");
  _write (root ^ "/C/C/CC/data.csv") (_csv "");
  let inv = Inventory.build ~data_dir:(Fpath.v root) in
  assert_that inv.symbols
    (elements_are
       [
         _entry_is ~symbol:"AA" ~start_:"2019-01-02" ~end_:"2021-01-04";
         _entry_is ~symbol:"BB" ~start_:"2010-03-01" ~end_:"2010-03-03";
       ])

let () =
  run_test_tt_main
    ("Inventory"
    >::: [
           "build indexes csv without metadata"
           >:: test_build_indexes_csv_without_metadata;
         ])
