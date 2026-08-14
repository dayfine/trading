(** Unit tests for [Backtest.Trades_csv_schema] — reader-side, header-addressed
    column lookup for [trades.csv].

    The contract these pin is narrow but load-bearing: a reader must recover
    [position_id] by column {b name}, and must report absence rather than guess
    when the column isn't there. Covers:
    - populated cell → [Some]
    - empty cell → [None] (never [Some ""])
    - header without the column → [None]
    - row shorter than the column index → [None]
    - a column inserted ahead of [position_id] → still the right cell (a reader
      pinned to today's fixed index fails this one)
    - [legacy] → always [None] *)

open OUnit2
open Core
open Matchers
module Schema = Backtest.Trades_csv_schema
module TC = Backtest.Trade_context

(** The full header a current [Result_writer] emits: the 13 base columns plus
    {!TC.csv_header_fields}. [position_id] sits at index 19 today, but no reader
    may hardcode that — hence the by-name lookup under test. *)
let _canonical_header =
  String.concat ~sep:","
    ([
       "symbol";
       "side";
       "entry_date";
       "exit_date";
       "days_held";
       "entry_price";
       "exit_price";
       "quantity";
       "pnl_dollars";
       "pnl_percent";
       "entry_stop";
       "exit_stop";
       "exit_trigger";
     ]
    @ TC.csv_header_fields)

(** Mirrors the pre-G2 12-column header, which has no [position_id] column. *)
let _legacy_header =
  "symbol,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars,pnl_percent,entry_stop,exit_stop,exit_trigger"

(* 21 cells matching [_canonical_header], with [position_id] parameterised. *)
let _canonical_row ~position_id =
  String.split ~on:','
    ("AAPL,LONG,2024-01-15,2024-02-20,36,150.00,165.00,10,150.00,10.00,140.00,160.00,signal_reversal,Stage2,2.4000,0.0800,intraday,36,75,"
   ^ position_id ^ ",0.0650")

(* The 13 base cells only — a row written before the trailing context block
   existed. *)
let _base_only_row =
  String.split ~on:','
    "AAPL,LONG,2024-01-15,2024-02-20,36,150.00,165.00,10,150.00,10.00,140.00,160.00,signal_reversal"

let test_populated_cell_reads_the_id _ =
  assert_that
    (Schema.position_id_of_cells
       (Schema.of_header_line _canonical_header)
       (_canonical_row ~position_id:"AAPL-wein-7"))
    (is_some_and (equal_to "AAPL-wein-7"))

let test_empty_cell_reads_none _ =
  (* The empty cell is the canonical missing-data sentinel
     [Trade_context.csv_row_fields] writes for [None]. It must not surface as
     [Some ""] — an empty id joins nothing yet would still suppress a caller's
     fallback if that caller only checks [is_some]. *)
  assert_that
    (Schema.position_id_of_cells
       (Schema.of_header_line _canonical_header)
       (_canonical_row ~position_id:""))
    is_none

let test_header_without_the_column_reads_none _ =
  assert_that
    (Schema.position_id_of_cells
       (Schema.of_header_line _legacy_header)
       (String.split ~on:','
          "AAPL,2024-01-15,2024-02-20,36,150.00,165.00,10,150.00,10.00,140.00,160.00,signal_reversal"))
    is_none

let test_row_shorter_than_the_column_index_reads_none _ =
  (* Header advertises the column, but this row stops at the 13 base cells.
     Reading past the end is a missing value, not an error. *)
  assert_that
    (Schema.position_id_of_cells
       (Schema.of_header_line _canonical_header)
       _base_only_row)
    is_none

let test_lookup_follows_the_header_not_a_fixed_index _ =
  (* A layout that inserts a column ahead of [position_id]: the by-name lookup
     tracks it. A reader pinned to today's index 19 returns the neighbouring
     [screener_score_at_entry] cell ("75") and fails here. *)
  let header =
    String.substr_replace_first _canonical_header
      ~pattern:"screener_score_at_entry"
      ~with_:"inserted_column,screener_score_at_entry"
  in
  assert_that
    (Schema.position_id_of_cells
       (Schema.of_header_line header)
       (String.split ~on:','
          "AAPL,LONG,2024-01-15,2024-02-20,36,150.00,165.00,10,150.00,10.00,140.00,160.00,signal_reversal,Stage2,2.4000,0.0800,intraday,36,inserted,75,AAPL-wein-9,0.0650"))
    (is_some_and (equal_to "AAPL-wein-9"))

let test_legacy_schema_never_yields_an_id _ =
  (* Even handed a row that does carry the cell — [legacy] describes a layout
     without the column, so it reads nothing. *)
  assert_that
    (Schema.position_id_of_cells Schema.legacy
       (_canonical_row ~position_id:"AAPL-wein-7"))
    is_none

let test_column_name_matches_the_writer_side _ =
  assert_that
    (List.mem TC.csv_header_fields Schema.position_id_column_name
       ~equal:String.equal)
    (equal_to true)

let suite =
  "Trades_csv_schema"
  >::: [
         "populated cell reads the id" >:: test_populated_cell_reads_the_id;
         "empty cell reads none" >:: test_empty_cell_reads_none;
         "header without the column reads none"
         >:: test_header_without_the_column_reads_none;
         "row shorter than the column index reads none"
         >:: test_row_shorter_than_the_column_index_reads_none;
         "lookup follows the header not a fixed index"
         >:: test_lookup_follows_the_header_not_a_fixed_index;
         "legacy schema never yields an id"
         >:: test_legacy_schema_never_yields_an_id;
         "column name matches the writer side"
         >:: test_column_name_matches_the_writer_side;
       ]

let () = run_test_tt_main suite
