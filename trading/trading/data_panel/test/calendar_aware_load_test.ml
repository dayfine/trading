(** Calendar-aware [Ohlcv_panels.load_from_csv_calendar] test.

    Two symbols start on different dates against a 5-day calendar. The CSV-
    aware load must align rows by date so that days the symbol didn't trade
    leave NaN cells. Compare to [load_from_csv] which sequentially walks each
    symbol's CSV — that misalignment is the bug this test pins. *)

open OUnit2
open Core
open Matchers
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module BA2 = Bigarray.Array2

let _make_idx universe =
  match Symbol_index.create ~universe with
  | Ok t -> t
  | Error err -> assert_failure err.Status.message

let _make_price ~date_str ~close () : Types.Daily_price.t =
  {
    date = Date.of_string date_str;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    volume = 1_000;
    adjusted_close = close;
  }

let _write_csv ~data_dir ~symbol prices =
  let storage =
    match Csv.Csv_storage.create ~data_dir symbol with
    | Ok s -> s
    | Error err ->
        assert_failure
          (Printf.sprintf "csv create failed: %s" err.Status.message)
  in
  match Csv.Csv_storage.save storage prices with
  | Ok () -> ()
  | Error err ->
      assert_failure (Printf.sprintf "csv save failed: %s" err.Status.message)

(* The calendar is the universe trading axis. Two symbols, one starting on
   day 0 (calendar.(0)) and one starting on day 2 (calendar.(2)), must each
   land their close prices on the matching calendar columns. The
   later-starting symbol's day-0 and day-1 cells must remain NaN. *)
let test_two_symbols_different_start_dates _ =
  let data_dir = Fpath.v (Core_unix.mkdtemp "/tmp/data_panel_cal_load_") in
  let calendar =
    [|
      Date.of_string "2024-01-02";
      Date.of_string "2024-01-03";
      Date.of_string "2024-01-04";
      Date.of_string "2024-01-05";
      Date.of_string "2024-01-08";
    |]
  in
  let aapl_prices =
    [
      _make_price ~date_str:"2024-01-02" ~close:100.0 ();
      _make_price ~date_str:"2024-01-03" ~close:101.0 ();
      _make_price ~date_str:"2024-01-04" ~close:102.0 ();
      _make_price ~date_str:"2024-01-05" ~close:103.0 ();
      _make_price ~date_str:"2024-01-08" ~close:104.0 ();
    ]
  in
  (* MSFT starts on calendar day 2 (2024-01-04). *)
  let msft_prices =
    [
      _make_price ~date_str:"2024-01-04" ~close:200.0 ();
      _make_price ~date_str:"2024-01-05" ~close:201.0 ();
      _make_price ~date_str:"2024-01-08" ~close:202.0 ();
    ]
  in
  _write_csv ~data_dir ~symbol:"AAPL" aapl_prices;
  _write_csv ~data_dir ~symbol:"MSFT" msft_prices;
  let idx = _make_idx [ "AAPL"; "MSFT" ] in
  let result = Ohlcv_panels.load_from_csv_calendar idx ~data_dir ~calendar in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field Ohlcv_panels.n (equal_to 2);
            field Ohlcv_panels.n_days (equal_to 5);
            (* AAPL row 0: every column populated. *)
            field
              (fun pp -> BA2.get (Ohlcv_panels.close pp) 0 0)
              (float_equal 100.0);
            field
              (fun pp -> BA2.get (Ohlcv_panels.close pp) 0 4)
              (float_equal 104.0);
            (* MSFT row 1: cols 0 and 1 NaN, col 2 = 200, col 4 = 202. *)
            field
              (fun pp -> Float.is_nan (BA2.get (Ohlcv_panels.close pp) 1 0))
              (equal_to true);
            field
              (fun pp -> Float.is_nan (BA2.get (Ohlcv_panels.close pp) 1 1))
              (equal_to true);
            field
              (fun pp -> BA2.get (Ohlcv_panels.close pp) 1 2)
              (float_equal 200.0);
            field
              (fun pp -> BA2.get (Ohlcv_panels.close pp) 1 3)
              (float_equal 201.0);
            field
              (fun pp -> BA2.get (Ohlcv_panels.close pp) 1 4)
              (float_equal 202.0);
          ]))

let test_csv_dates_outside_calendar_skipped _ =
  let data_dir = Fpath.v (Core_unix.mkdtemp "/tmp/data_panel_cal_skip_") in
  (* Calendar covers only 2024-01-03 and 2024-01-05. The 2024-01-04 bar in the
     CSV must be skipped (date not in calendar). *)
  let calendar =
    [| Date.of_string "2024-01-03"; Date.of_string "2024-01-05" |]
  in
  let prices =
    [
      _make_price ~date_str:"2024-01-03" ~close:101.0 ();
      _make_price ~date_str:"2024-01-04" ~close:102.0 ();
      _make_price ~date_str:"2024-01-05" ~close:103.0 ();
    ]
  in
  _write_csv ~data_dir ~symbol:"AAPL" prices;
  let idx = _make_idx [ "AAPL" ] in
  let result = Ohlcv_panels.load_from_csv_calendar idx ~data_dir ~calendar in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun pp -> BA2.get (Ohlcv_panels.close pp) 0 0)
              (float_equal 101.0);
            field
              (fun pp -> BA2.get (Ohlcv_panels.close pp) 0 1)
              (float_equal 103.0);
          ]))

let test_missing_csv_leaves_row_nan _ =
  let data_dir = Fpath.v (Core_unix.mkdtemp "/tmp/data_panel_cal_miss_") in
  let calendar =
    [| Date.of_string "2024-01-03"; Date.of_string "2024-01-05" |]
  in
  let idx = _make_idx [ "GOOG" ] in
  let result = Ohlcv_panels.load_from_csv_calendar idx ~data_dir ~calendar in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun pp -> Float.is_nan (BA2.get (Ohlcv_panels.close pp) 0 0))
              (equal_to true);
            field
              (fun pp -> Float.is_nan (BA2.get (Ohlcv_panels.close pp) 0 1))
              (equal_to true);
          ]))

let suite =
  "Calendar-aware load_from_csv tests"
  >::: [
         "test_two_symbols_different_start_dates"
         >:: test_two_symbols_different_start_dates;
         "test_csv_dates_outside_calendar_skipped"
         >:: test_csv_dates_outside_calendar_skipped;
         "test_missing_csv_leaves_row_nan" >:: test_missing_csv_leaves_row_nan;
       ]

let () = run_test_tt_main suite
