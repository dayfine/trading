(** Loader + point-in-time index for the daily universe-breadth series.

    Covers {!Breadth_bars.load} (CSV shape, header row, holiday rows, missing
    file) and {!Breadth_series_cache} (the [as_of] cutoff and the weekly-offset
    step over daily rows). *)

open Core
open OUnit2
open Matchers

let _date = Date.of_string

(* ------------------------------------------------------------------ *)
(* Fixtures                                                             *)
(* ------------------------------------------------------------------ *)

(** Write [lines] as [<dir>/breadth/synthetic_breadth_daily.csv] and return
    [dir], so a test can hand it straight to {!Breadth_bars.load} as
    [~data_dir]. *)
let _data_dir_with_rows lines =
  let dir = Core_unix.mkdtemp "/tmp/breadth_bars_test_" in
  Core_unix.mkdir (Filename.concat dir "breadth");
  let path =
    Filename.concat
      (Filename.concat dir "breadth")
      "synthetic_breadth_daily.csv"
  in
  Out_channel.write_lines path lines;
  dir

let _header = "date,n,n_above150,nh52,nl52,advances,declines"

(** One CSV row. Column order matches {!_header}. *)
let _row ~date ~n ~above ~nh ~nl =
  Printf.sprintf "%s,%d,%d,%d,%d,0,0" date n above nh nl

(** The bar a {!_row} with the same arguments must parse into. *)
let _bar ~date ~n ~above ~nh ~nl : Macro.breadth_bar =
  {
    date = _date date;
    universe_count = n;
    above_ma_count = above;
    new_highs = nh;
    new_lows = nl;
  }

(* ------------------------------------------------------------------ *)
(* Breadth_bars.load                                                    *)
(* ------------------------------------------------------------------ *)

let test_load_parses_rows_and_skips_header _ =
  let dir =
    _data_dir_with_rows
      [
        _header;
        _row ~date:"2020-01-03" ~n:2000 ~above:1200 ~nh:40 ~nl:10;
        _row ~date:"2020-01-06" ~n:2010 ~above:1000 ~nh:20 ~nl:30;
      ]
  in
  assert_that
    (Breadth_bars.load ~data_dir:dir)
    (elements_are
       [
         equal_to (_bar ~date:"2020-01-03" ~n:2000 ~above:1200 ~nh:40 ~nl:10);
         equal_to (_bar ~date:"2020-01-06" ~n:2010 ~above:1000 ~nh:20 ~nl:30);
       ])

(** The generator emits a row for every date any constituent traded, so market
    holidays surface as one- or two-symbol rows whose percentages are noise.
    They must not reach the cache: its weekly-offset step counts ROWS, so a
    stray holiday row would shift every lookback by one session. *)
let test_load_drops_holiday_rows _ =
  let dir =
    _data_dir_with_rows
      [
        _header;
        _row ~date:"2020-01-03" ~n:2000 ~above:1200 ~nh:40 ~nl:10;
        _row ~date:"2020-01-04" ~n:1 ~above:1 ~nh:0 ~nl:0;
        _row ~date:"2020-01-06" ~n:2010 ~above:1000 ~nh:20 ~nl:30;
      ]
  in
  assert_that
    (Breadth_bars.load ~data_dir:dir)
    (elements_are
       [
         field
           (fun (b : Macro.breadth_bar) -> b.date)
           (equal_to (_date "2020-01-03"));
         field
           (fun (b : Macro.breadth_bar) -> b.date)
           (equal_to (_date "2020-01-06"));
       ])

let test_load_sorts_ascending_and_skips_malformed _ =
  let dir =
    _data_dir_with_rows
      [
        _header;
        _row ~date:"2020-01-06" ~n:2010 ~above:1000 ~nh:20 ~nl:30;
        "not,a,valid,row";
        "2020-01-07,2000,abc,1,1,0,0";
        _row ~date:"2020-01-03" ~n:2000 ~above:1200 ~nh:40 ~nl:10;
      ]
  in
  assert_that
    (Breadth_bars.load ~data_dir:dir)
    (elements_are
       [
         field
           (fun (b : Macro.breadth_bar) -> b.date)
           (equal_to (_date "2020-01-03"));
         field
           (fun (b : Macro.breadth_bar) -> b.date)
           (equal_to (_date "2020-01-06"));
       ])

let test_load_missing_file_is_empty _ =
  let dir = Core_unix.mkdtemp "/tmp/breadth_bars_missing_" in
  assert_that (Breadth_bars.load ~data_dir:dir) (size_is 0)

(* ------------------------------------------------------------------ *)
(* Breadth_series_cache                                                 *)
(* ------------------------------------------------------------------ *)

(** 30 consecutive weekdays starting 2020-01-01, with [above_ma_count] equal to
    the row index so an offset lookup is directly readable as a percentage: row
    [i] has [pct_above = i] (universe of 100). *)
let _ramp_bars =
  List.init 30 ~f:(fun i ->
      {
        Macro.date = Date.add_days (_date "2020-01-01") i;
        universe_count = 100;
        above_ma_count = i;
        new_highs = 0;
        new_lows = 2 * i;
      })

let _ramp = Breadth_series_cache.of_daily_bars _ramp_bars

let test_offset_zero_is_newest_at_or_before_as_of _ =
  let pct_above, _ =
    Breadth_series_cache.callbacks_at _ramp ~as_of:(_date "2020-01-11")
  in
  (* 2020-01-01 is row 0, so 2020-01-11 is row 10. *)
  assert_that (pct_above ~week_offset:0) (is_some_and (float_equal 10.0))

(** The point-in-time guard: a Friday's macro read must never see a row dated
    after it. Pinned on the prefix length directly (the same contract
    [Macro_inputs]'s [*_at_or_before] helpers enforce for index and A-D inputs)
    as well as through the callback. *)
let test_as_of_never_reads_the_future _ =
  let as_of = _date "2020-01-11" in
  assert_that
    (Breadth_series_cache.Internal_for_test.count_at_or_before _ramp ~as_of)
    (equal_to 11)

(** [week_offset:k] steps back 5 rows per week: offset 4 from row 24 is row 4.
*)
let test_week_offset_steps_five_rows_per_week _ =
  let pct_above, _ =
    Breadth_series_cache.callbacks_at _ramp ~as_of:(_date "2020-01-25")
  in
  assert_that (pct_above ~week_offset:4) (is_some_and (float_equal 4.0))

let test_offset_before_series_start_is_none _ =
  let pct_above, _ =
    Breadth_series_cache.callbacks_at _ramp ~as_of:(_date "2020-01-05")
  in
  (* Row 4 is newest; offset 4 wants row -16. *)
  assert_that (pct_above ~week_offset:4) is_none

let test_as_of_before_series_start_is_none _ =
  let pct_above, new_lows =
    Breadth_series_cache.callbacks_at _ramp ~as_of:(_date "1999-01-01")
  in
  assert_that
    [ pct_above ~week_offset:0; new_lows ~week_offset:0 ]
    (elements_are [ is_none; is_none ])

let test_new_lows_pct_is_percent_of_universe _ =
  let _, new_lows =
    Breadth_series_cache.callbacks_at _ramp ~as_of:(_date "2020-01-11")
  in
  (* Row 10: new_lows = 20 of a 100-name universe. *)
  assert_that (new_lows ~week_offset:0) (is_some_and (float_equal 20.0))

let test_empty_series_is_inert _ =
  let pct_above, new_lows =
    Breadth_series_cache.callbacks_at
      (Breadth_series_cache.of_daily_bars [])
      ~as_of:(_date "2020-01-11")
  in
  assert_that
    [ pct_above ~week_offset:0; new_lows ~week_offset:0 ]
    (elements_are [ is_none; is_none ])

let suite =
  "breadth_series_cache"
  >::: [
         "load parses rows and skips the header"
         >:: test_load_parses_rows_and_skips_header;
         "load drops holiday (tiny-universe) rows"
         >:: test_load_drops_holiday_rows;
         "load sorts ascending and skips malformed rows"
         >:: test_load_sorts_ascending_and_skips_malformed;
         "load of a missing file returns []" >:: test_load_missing_file_is_empty;
         "week_offset 0 is the newest row at or before as_of"
         >:: test_offset_zero_is_newest_at_or_before_as_of;
         "as_of never reads a row dated after it"
         >:: test_as_of_never_reads_the_future;
         "week_offset steps 5 rows per week"
         >:: test_week_offset_steps_five_rows_per_week;
         "offset before the series start is None"
         >:: test_offset_before_series_start_is_none;
         "as_of before the series start is None"
         >:: test_as_of_before_series_start_is_none;
         "new_lows_pct is a percent of the universe"
         >:: test_new_lows_pct_is_percent_of_universe;
         "an empty series answers None everywhere"
         >:: test_empty_series_is_inert;
       ]

let () = run_test_tt_main suite
