(** Pins the committed NYSE breadth fixture under [trading/test_data/breadth/] —
    the files every backtest chain reads via [TRADING_DATA_DIR]. Issue #3238:
    the fixture once held one 1965-03-01 row and then 2017-01-02 onwards, so the
    A-D indicators sat frozen for 2000-2016 in every 26y run.

    The fixture is located by walking up from the test's cwd (dune copies it
    into [_build/default/test_data/breadth/] via the stanza's [deps]), so the
    test reads the committed files regardless of [TRADING_DATA_DIR]. *)

open OUnit2
open Core
open Matchers

(* 14 calendar days can hold at most 10 trading days: asserting no calendar gap
   wider than this asserts no hole of more than 10 trading days. *)
let _max_gap_calendar_days = 14
let _max_walk_up = 8
let _window_start = Date.of_string "1998-01-01"
let _window_end = Date.of_string "2020-02-10"

let _fixture_data_dir () =
  let rec walk dir tries_left =
    let candidate = Filename.concat dir "test_data" in
    let probe = Filename.concat candidate "breadth/nyse_advn.csv" in
    if Stdlib.Sys.file_exists probe then Some candidate
    else if tries_left = 0 then None
    else
      let parent = Filename.dirname dir in
      if String.equal parent dir then None else walk parent (tries_left - 1)
  in
  match walk (Stdlib.Sys.getcwd ()) _max_walk_up with
  | Some d -> d
  | None -> assert_failure "test_data/breadth/nyse_advn.csv not found above cwd"

let _window_gaps bars =
  Weinstein_strategy.Ad_bars.gaps_in_window bars ~start_date:_window_start
    ~end_date:_window_end ~max_gap_days:_max_gap_calendar_days

let test_fixture_composed_has_no_gap _ =
  let data_dir = _fixture_data_dir () in
  assert_that
    (_window_gaps (Weinstein_strategy.Ad_bars.load ~data_dir))
    is_empty

let test_fixture_unicorn_alone_has_no_gap _ =
  let data_dir = _fixture_data_dir () in
  assert_that
    (_window_gaps (Weinstein_strategy.Ad_bars.Unicorn.load ~data_dir))
    is_empty

let _raw_date raw =
  Date.of_string
    (sprintf "%s-%s-%s"
       (String.sub raw ~pos:0 ~len:4)
       (String.sub raw ~pos:4 ~len:2)
       (String.sub raw ~pos:6 ~len:2))

let _is_non_trading date =
  (match Date.day_of_week date with
    | Day_of_week.Sat | Day_of_week.Sun -> true
    | _ -> false)
  || Weinstein_strategy.Exchange_calendar.is_closed date

(* Every "<file> <date>" row on or after [start] that falls on a weekend or a
   scheduled NYSE holiday. *)
let _non_trading_rows ~data_dir ~start file =
  In_channel.read_lines
    (Filename.concat (Filename.concat data_dir "breadth") file)
  |> List.filter_map ~f:(fun line ->
      let date = _raw_date (List.hd_exn (String.split line ~on:',')) in
      if Date.( >= ) date start && _is_non_trading date then
        Some (sprintf "%s %s" file (Date.to_string date))
      else None)

(* Exchange_calendar's holiday rules cover 2000 onwards. Pre-2000 rows
   deliberately remain unchecked; midweek exceptional closures (2007-01-02,
   2018-12-05) are outside the calendar and were removed by hand (README.md).
   Read both raw CSVs so unpaired rows and zero-count placeholders cannot
   disappear through the Unicorn loader. *)
let test_fixture_calendar _ =
  let start = Date.of_string "2000-01-01" in
  let data_dir = _fixture_data_dir () in
  assert_that
    (List.concat_map
       [ "nyse_advn.csv"; "nyse_decln.csv" ]
       ~f:(_non_trading_rows ~data_dir ~start))
    is_empty

let suite =
  "ad_bars_fixture"
  >::: [
         "fixture: NYSE calendar from 2000 onwards" >:: test_fixture_calendar;
         "fixture: composed breadth has no gap over 1998-2020"
         >:: test_fixture_composed_has_no_gap;
         "fixture: Unicorn breadth alone has no gap over 1998-2020"
         >:: test_fixture_unicorn_alone_has_no_gap;
       ]

let () = run_test_tt_main suite
