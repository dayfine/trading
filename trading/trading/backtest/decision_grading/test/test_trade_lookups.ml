open Core
open OUnit2
open Matchers
module T = Decision_grading.Trade_lookups

let d = Date.of_string

let write_scenario ~csv =
  let dir = Filename_unix.temp_dir "trade_lookups" "" in
  Out_channel.write_all (Filename.concat dir "trades.csv") ~data:csv;
  dir

let key sym e x = (sym, d e, d x)

let test_exit_reason_content _ =
  let dir =
    write_scenario
      ~csv:
        "pnl,symbol,entry_date,exit_date,exit_trigger\n\
         1.0,AAPL,2020-01-02,2020-03-02,stop_loss\n\n\
         2.0,MSFT,2020-01-03,2020-04-01,laggard_rotation\n"
  in
  let tbl = T.exit_reason_lookup ~scenario_dir:dir in
  assert_that
    ( Hashtbl.length tbl,
      Hashtbl.find tbl (key "AAPL" "2020-01-02" "2020-03-02"),
      Hashtbl.find tbl (key "MSFT" "2020-01-03" "2020-04-01"),
      Hashtbl.find tbl (key "AAPL" "2020-01-03" "2020-03-02") )
    (equal_to
       (2, Some "stop_loss", Some "laggard_rotation", (None : string option)))

let test_exit_reason_skips_incomplete_rows _ =
  let dir =
    write_scenario
      ~csv:
        "symbol,entry_date,exit_date,exit_trigger\n\
         AAPL,2020-01-02,2020-03-02\n\
         MSFT,2020-01-03,2020-04-01,end_of_period\n"
  in
  let tbl = T.exit_reason_lookup ~scenario_dir:dir in
  assert_that (Hashtbl.to_alist tbl)
    (elements_are
       [
         equal_to
           ((key "MSFT" "2020-01-03" "2020-04-01", "end_of_period")
             : (string * Date.t * Date.t) * string);
       ])

let test_exit_reason_missing_column _ =
  let dir =
    write_scenario
      ~csv:"symbol,entry_date,exit_date\nAAPL,2020-01-02,2020-03-02\n"
  in
  assert_that
    (Hashtbl.length (T.exit_reason_lookup ~scenario_dir:dir))
    (equal_to 0)

let test_exit_reason_empty_file _ =
  let dir = write_scenario ~csv:"" in
  assert_that
    (Hashtbl.length (T.exit_reason_lookup ~scenario_dir:dir))
    (equal_to 0)

let test_exit_reason_empty_trigger_kept _ =
  let dir =
    write_scenario
      ~csv:
        "symbol,entry_date,exit_date,exit_trigger\n\
         AAPL,2020-01-02,2020-03-02,\n\
         MSFT,2020-01-03,2020-04-01,stop_loss\n"
  in
  let tbl = T.exit_reason_lookup ~scenario_dir:dir in
  assert_that
    (Hashtbl.length tbl, Hashtbl.find tbl (key "AAPL" "2020-01-02" "2020-03-02"))
    (equal_to ((2, Some "") : int * string option))

let test_exit_reason_duplicate_key_last_wins _ =
  let dir =
    write_scenario
      ~csv:
        "symbol,entry_date,exit_date,exit_trigger\n\
         AAPL,2020-01-02,2020-03-02,a\n\
         AAPL,2020-01-02,2020-03-02,c\n\
         AAPL,2020-01-02,2020-03-02,b\n"
  in
  let tbl = T.exit_reason_lookup ~scenario_dir:dir in
  (* The last row is neither the first, the max nor the min. *)
  assert_that
    (Hashtbl.find tbl (key "AAPL" "2020-01-02" "2020-03-02"))
    (equal_to (Some "b" : string option))

let test_exit_reason_leading_blank_line _ =
  let dir =
    write_scenario
      ~csv:
        "\n\
         symbol,entry_date,exit_date,exit_trigger\n\
         AAPL,2020-01-02,2020-03-02,stop_loss\n"
  in
  let tbl = T.exit_reason_lookup ~scenario_dir:dir in
  assert_that
    (Hashtbl.find tbl (key "AAPL" "2020-01-02" "2020-03-02"))
    (equal_to (Some "stop_loss" : string option))

let index =
  T.build_mfe_index
    [
      ("AAPL", d "2020-01-10", 0.30);
      ("AAPL", d "2020-01-16", 0.50);
      ("MSFT", d "2020-02-07", 0.10);
    ]

let find sym e = T.find_mfe index ~symbol:sym ~entry_date:(d e)

let test_find_exact_and_nearest _ =
  assert_that
    ( find "AAPL" "2020-01-10",
      find "AAPL" "2020-01-14",
      find "AAPL" "2020-01-12" )
    (equal_to
       ((Some 0.30, Some 0.50, Some 0.30)
         : float option * float option * float option))

let test_find_tolerance_edges _ =
  (* MSFT audit date 2020-02-07: gap 7 is in, gap 8 is out (both directions). *)
  assert_that
    ( find "MSFT" "2020-02-14",
      find "MSFT" "2020-02-15",
      find "MSFT" "2020-01-31",
      find "MSFT" "2020-01-30" )
    (equal_to
       ((Some 0.10, None, Some 0.10, None)
         : float option * float option * float option * float option))

let test_find_unknown_symbol _ =
  assert_that (find "ZZZ" "2020-01-10") (equal_to (None : float option))

let test_find_tie_prefers_later_listed _ =
  (* Both entries are 2 days from 2020-01-12. Asserting both listing orders
     separates "later listed wins" from date- and MFE-based tie-breaks. *)
  let tie entries =
    T.find_mfe
      (T.build_mfe_index entries)
      ~symbol:"AAPL" ~entry_date:(d "2020-01-12")
  in
  assert_that
    ( tie [ ("AAPL", d "2020-01-14", 0.50); ("AAPL", d "2020-01-10", 0.30) ],
      tie [ ("AAPL", d "2020-01-10", 0.30); ("AAPL", d "2020-01-14", 0.50) ] )
    (equal_to ((Some 0.30, Some 0.50) : float option * float option))

let test_tolerance_value _ = assert_that T.join_tolerance_days (equal_to 7)

let suite =
  "trade_lookups"
  >::: [
         "exit_reason content" >:: test_exit_reason_content;
         "exit_reason skips incomplete rows"
         >:: test_exit_reason_skips_incomplete_rows;
         "exit_reason missing column" >:: test_exit_reason_missing_column;
         "exit_reason empty file" >:: test_exit_reason_empty_file;
         "exit_reason empty trigger kept"
         >:: test_exit_reason_empty_trigger_kept;
         "exit_reason duplicate key last wins"
         >:: test_exit_reason_duplicate_key_last_wins;
         "exit_reason leading blank line"
         >:: test_exit_reason_leading_blank_line;
         "find_mfe exact and nearest" >:: test_find_exact_and_nearest;
         "find_mfe tolerance edges" >:: test_find_tolerance_edges;
         "find_mfe unknown symbol" >:: test_find_unknown_symbol;
         "find_mfe tie prefers later listed"
         >:: test_find_tie_prefers_later_listed;
         "join tolerance value" >:: test_tolerance_value;
       ]

let () = run_test_tt_main suite
