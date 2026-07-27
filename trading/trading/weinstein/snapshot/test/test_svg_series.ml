(** Tests for {!Svg_series} — weekly aggregation and the simple moving average.

    These are the series-preparation half of what the report charts draw; the
    geometry half is {!Svg_chart}, tested in [test_svg_chart.ml]. Keeping them
    apart is why neither file has to be read to understand the other.

    The moving average is exercised end to end through {!Svg_chart.render} in
    [test_svg_chart.ml] (where its projected coordinates are pinned); the tests
    here pin its ALIGNMENT contract — same length as the input, [None] until
    [period] values are behind a position — which the coordinate tests take for
    granted. *)

open Core
open OUnit2
open Matchers
module Svg_series = Weinstein_snapshot.Svg_series

(* ------- Weekly aggregation ------- *)

(* Bars are addressed by absolute date rather than by offset, because which WEEK
   a bar lands in is the thing under test. *)
let _dated ?(volume = 100) ?high ?low date price : Types.Daily_price.t =
  Types.Daily_price.make ~date:(Date.of_string date) ~open_price:price
    ~high_price:(Option.value high ~default:price)
    ~low_price:(Option.value low ~default:price)
    ~close_price:price ~volume ~adjusted_close:price ()

let _bar_date (b : Types.Daily_price.t) = b.date
let _bar_open (b : Types.Daily_price.t) = b.open_price
let _bar_high (b : Types.Daily_price.t) = b.high_price
let _bar_low (b : Types.Daily_price.t) = b.low_price
let _bar_close (b : Types.Daily_price.t) = b.close_price
let _bar_volume (b : Types.Daily_price.t) = b.volume

let test_weekly_bars_of_empty_is_empty _ =
  assert_that (Svg_series.weekly_bars []) (elements_are [])

let test_weekly_bars_folds_one_trading_week _ =
  (* Mon 2020-01-06 .. Fri 2020-01-10. Open comes from Monday, close from
     Friday, the extremes from the whole week, volume is the sum, and the bar is
     DATED at the Friday — not at the Monday, so a Friday-close series ends on
     its own Friday. *)
  let week =
    [
      _dated ~volume:1 "2020-01-06" 10.0;
      _dated ~volume:2 ~high:25.0 "2020-01-07" 20.0;
      _dated ~volume:4 ~low:3.0 "2020-01-08" 15.0;
      _dated ~volume:8 "2020-01-09" 12.0;
      _dated ~volume:16 "2020-01-10" 18.0;
    ]
  in
  assert_that
    (Svg_series.weekly_bars week)
    (elements_are
       [
         all_of
           [
             field _bar_date (equal_to (Date.of_string "2020-01-10"));
             field _bar_open (float_equal 10.0);
             field _bar_high (float_equal 25.0);
             field _bar_low (float_equal 3.0);
             field _bar_close (float_equal 18.0);
             field _bar_volume (equal_to 31);
           ];
       ])

let test_weekly_bars_split_across_the_weekend _ =
  (* Fri + Sat + Sun belong to the SAME ISO week (the week's Monday is
     2020-01-06); the following Monday opens a new one. *)
  let bars =
    [
      _dated "2020-01-10" 10.0;
      _dated "2020-01-11" 11.0;
      _dated "2020-01-12" 12.0;
      _dated "2020-01-13" 13.0;
    ]
  in
  assert_that
    (Svg_series.weekly_bars bars)
    (elements_are
       [
         field _bar_close (float_equal 12.0);
         field _bar_close (float_equal 13.0);
       ])

let test_weekly_bars_keep_a_year_straddling_week_together _ =
  (* Mon 2019-12-30 .. Thu 2020-01-02 are one ISO week. Keying on a
     (year, week-number) pair would split them; keying on the week's Monday does
     not. *)
  let bars =
    [
      _dated "2019-12-30" 10.0;
      _dated "2019-12-31" 11.0;
      _dated "2020-01-01" 12.0;
      _dated "2020-01-02" 13.0;
      _dated "2020-01-06" 14.0;
    ]
  in
  assert_that
    (Svg_series.weekly_bars bars)
    (elements_are
       [
         field _bar_close (float_equal 13.0);
         field _bar_close (float_equal 14.0);
       ])

(* ------- Simple moving average ------- *)

let test_sma_is_aligned_to_the_input _ =
  (* Same length as the input, [None] until [period] values sit behind a
     position: at period 3 the means are (1+2+3)/3 and (2+3+4)/3. Alignment is
     what lets a caller plot the average against the same x-slots as the series;
     an implementation that returned only the defined tail would shift the whole
     overlay left. *)
  assert_that
    (Svg_series.sma ~period:3 [ 1.0; 2.0; 3.0; 4.0 ])
    (elements_are
       [
         is_none;
         is_none;
         is_some_and (float_equal 2.0);
         is_some_and (float_equal 3.0);
       ])

let test_sma_period_longer_than_the_input_is_all_none _ =
  assert_that
    (Svg_series.sma ~period:5 [ 1.0; 2.0 ])
    (elements_are [ is_none; is_none ])

let test_sma_non_positive_period_is_all_none _ =
  (* There is no average of nothing. [Svg_chart.render] additionally normalises
     a non-positive [?ma_period] to the omitted case, so this branch is the
     defensive half of that contract. *)
  assert_that
    (Svg_series.sma ~period:0 [ 1.0; 2.0 ])
    (elements_are [ is_none; is_none ]);
  assert_that
    (Svg_series.sma ~period:(-1) [ 1.0; 2.0 ])
    (elements_are [ is_none; is_none ])

let test_sma_of_empty_is_empty _ =
  assert_that (Svg_series.sma ~period:3 []) (elements_are [])

let suite =
  "svg_series"
  >::: [
         "weekly_bars_of_empty_is_empty" >:: test_weekly_bars_of_empty_is_empty;
         "weekly_bars_folds_one_trading_week"
         >:: test_weekly_bars_folds_one_trading_week;
         "weekly_bars_split_across_the_weekend"
         >:: test_weekly_bars_split_across_the_weekend;
         "weekly_bars_keep_a_year_straddling_week_together"
         >:: test_weekly_bars_keep_a_year_straddling_week_together;
         "sma_is_aligned_to_the_input" >:: test_sma_is_aligned_to_the_input;
         "sma_period_longer_than_the_input_is_all_none"
         >:: test_sma_period_longer_than_the_input_is_all_none;
         "sma_non_positive_period_is_all_none"
         >:: test_sma_non_positive_period_is_all_none;
         "sma_of_empty_is_empty" >:: test_sma_of_empty_is_empty;
       ]

let () = run_test_tt_main suite
