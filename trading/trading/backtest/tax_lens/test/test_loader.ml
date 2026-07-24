(** Unit tests for [Tax_lens.Loader.load_exn].

    Pins the [.mli] contract verbatim: "parses [dir/trades.csv] and
    [dir/equity_curve.csv]. Raises if either file is missing or malformed." Five
    raising cases (missing dir, missing trades.csv, missing equity_curve.csv,
    malformed trades.csv row, malformed equity_curve.csv row) plus one happy
    path so the raising tests can't pass vacuously.

    Fixtures are written to a fresh [Filename_unix.temp_dir] per test — no
    committed fixture data, hermetic, no cleanup needed (tmp dirs are
    per-process and OS-reclaimed). *)

open OUnit2
open Core
open Matchers
module TT = Tax_lens.Tax_types
module Loader = Tax_lens.Loader

let _write_file dir name contents =
  Out_channel.write_all (Filename.concat dir name) ~data:contents

(* Minimal well-formed trades.csv: the parser only reads columns 0 (symbol), 1
   (side), 3 (exit_date), 4 (days_held), 8 (pnl_dollars) — see the comment
   above [Loader._trade_of_line] — but real [result_writer.ml] output always
   carries all 13 base columns, so the header here matches that shape. *)
let _trades_csv =
  "symbol,side,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars\n\
   AAPL,LONG,2021-01-05,2021-06-01,147,100.00,120.00,10,200.00\n\
   MSFT,SHORT,2021-08-01,2022-01-15,167,50.00,45.00,20,100.00\n"

(* Two rows in calendar year 2021 (last-seen wins per [Loader._year_ends]) plus
   one row in 2022; first/last dates give an exact 365-day span (2021 is not a
   leap year) so [span_years] is hand-computable. *)
let _equity_csv =
  "date,portfolio_value\n\
   2021-01-01,1000.00\n\
   2021-06-30,1100.00\n\
   2022-01-01,1300.00\n"

(* Catches any exception [thunk] raises and returns its rendered message, so
   error-path tests can pin a message substring instead of a bare catch-all
   that would also pass on an unrelated failure. [load_exn] raises different
   exception shapes depending on the failure (Sys_error for missing files,
   Failure for malformed trades rows, an [Error.t]-backed exception for the
   [Option.value_exn] equity-parsing guard) — a message-substring check is the
   one assertion style that covers all three uniformly. *)
let _raised_message thunk =
  try
    ignore (thunk ());
    None
  with exn -> Some (Exn.to_string exn)

(* ---------- Happy path (so the raising tests can't pass vacuously) ---------- *)

let test_load_exn_happy_path _ =
  let dir = Filename_unix.temp_dir "loader_test" "" in
  _write_file dir "trades.csv" _trades_csv;
  _write_file dir "equity_curve.csv" _equity_csv;
  let result = Loader.load_exn dir in
  assert_that result
    (all_of
       [
         field
           (fun (r : TT.run_data) -> r.trades)
           (elements_are
              [
                all_of
                  [
                    field
                      (fun (t : TT.realized_trade) -> t.TT.symbol)
                      (equal_to "AAPL");
                    field (fun t -> t.TT.side) (equal_to "LONG");
                    field (fun t -> t.TT.exit_year) (equal_to 2021);
                    field (fun t -> t.TT.days_held) (equal_to 147);
                    field (fun t -> t.TT.pnl) (float_equal 200.0);
                  ];
                all_of
                  [
                    field
                      (fun (t : TT.realized_trade) -> t.TT.symbol)
                      (equal_to "MSFT");
                    field (fun t -> t.TT.side) (equal_to "SHORT");
                    field (fun t -> t.TT.exit_year) (equal_to 2022);
                    field (fun t -> t.TT.days_held) (equal_to 167);
                    field (fun t -> t.TT.pnl) (float_equal 100.0);
                  ];
              ]);
         field
           (fun (r : TT.run_data) -> r.equity_year_ends)
           (elements_are
              [
                pair (equal_to 2021) (float_equal 1100.0);
                pair (equal_to 2022) (float_equal 1300.0);
              ]);
         field (fun (r : TT.run_data) -> r.initial_capital) (float_equal 1000.0);
         field
           (fun (r : TT.run_data) -> r.span_years)
           (float_equal ~epsilon:1e-6 (365. /. 365.25));
       ])

(* ---------- Raising cases ---------- *)

(* Case 1: the directory itself does not exist. *)
let test_load_exn_raises_when_dir_missing _ =
  let dir =
    Filename.concat (Filename_unix.temp_dir "loader_test" "") "missing_subdir"
  in
  assert_that
    (_raised_message (fun () -> Loader.load_exn dir))
    (is_some_and (contains_substring "No such file or directory"))

(* Case 2: the directory exists but trades.csv is absent. *)
let test_load_exn_raises_when_trades_csv_missing _ =
  let dir = Filename_unix.temp_dir "loader_test" "" in
  assert_that
    (_raised_message (fun () -> Loader.load_exn dir))
    (is_some_and
       (all_of
          [
            contains_substring "trades.csv";
            contains_substring "No such file or directory";
          ]))

(* Case 3: trades.csv is valid but equity_curve.csv is absent. *)
let test_load_exn_raises_when_equity_csv_missing _ =
  let dir = Filename_unix.temp_dir "loader_test" "" in
  _write_file dir "trades.csv" _trades_csv;
  assert_that
    (_raised_message (fun () -> Loader.load_exn dir))
    (is_some_and
       (all_of
          [
            contains_substring "equity_curve.csv";
            contains_substring "No such file or directory";
          ]))

(* Case 4: a trades.csv data row with the wrong column count. Before this PR,
   [Loader._trade_of_line] silently dropped rows that didn't match its 9-field
   pattern (via [List.filter_map]) instead of raising, contradicting the
   documented "raises ... if malformed" contract — see loader.ml for the fix
   (filter_map -> map, with an explicit [failwithf] on the non-matching case). *)
let test_load_exn_raises_on_malformed_trades_row _ =
  let dir = Filename_unix.temp_dir "loader_test" "" in
  _write_file dir "trades.csv"
    "symbol,side,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars\n\
     AAPL,LONG,only_three_fields\n";
  _write_file dir "equity_curve.csv" _equity_csv;
  assert_that
    (_raised_message (fun () -> Loader.load_exn dir))
    (is_some_and (contains_substring "malformed trades.csv row"))

(* Case 5: an equity_curve.csv whose first data row doesn't parse (here: wrong
   field count — a lone date with no value column). [Loader._load_equity]
   parses the first row separately via [Option.value_exn
   ~message:"unparseable first equity row"], so this is deterministic
   regardless of how later rows are handled. *)
let test_load_exn_raises_on_malformed_equity_row _ =
  let dir = Filename_unix.temp_dir "loader_test" "" in
  _write_file dir "trades.csv" _trades_csv;
  _write_file dir "equity_curve.csv" "date,portfolio_value\n2021-01-01\n";
  assert_that
    (_raised_message (fun () -> Loader.load_exn dir))
    (is_some_and (contains_substring "unparseable first equity row"))

let suite =
  "loader"
  >::: [
         "load_exn_happy_path" >:: test_load_exn_happy_path;
         "load_exn_raises_when_dir_missing"
         >:: test_load_exn_raises_when_dir_missing;
         "load_exn_raises_when_trades_csv_missing"
         >:: test_load_exn_raises_when_trades_csv_missing;
         "load_exn_raises_when_equity_csv_missing"
         >:: test_load_exn_raises_when_equity_csv_missing;
         "load_exn_raises_on_malformed_trades_row"
         >:: test_load_exn_raises_on_malformed_trades_row;
         "load_exn_raises_on_malformed_equity_row"
         >:: test_load_exn_raises_on_malformed_equity_row;
       ]

let () = run_test_tt_main suite
