open Core
open OUnit2
open Matchers
module PE = Decision_grading.Post_exit

(* A weekly bar one [week_offset] weeks after a fixed Monday anchor. OHLC are
   spelled out per test; volume / adjusted_close are irrelevant to Post_exit and
   fixed to dummies. *)
let anchor = Date.of_string "2020-01-06"

let bar ~week_offset ~high ~low ~close =
  Types.Daily_price.make
    ~date:(Date.add_days anchor (week_offset * 7))
    ~open_price:close ~high_price:high ~low_price:low ~close_price:close
    ~volume:1000 ~adjusted_close:close ()

let exit_date = anchor
let single h = List.hd_exn h

(* Monotonically rising long: exit at 100, price climbs to 130 over 4 weeks
   (closes 100,110,120,130). For h=4 the window is all four bars.
   continuation = (130-100)/100 = 0.30; MFE from max high 131 = 0.31; MAE from
   min low (the exit bar's own low 99) = (99-100)/100 = -0.01. *)
let rising_bars =
  [
    bar ~week_offset:0 ~high:101.0 ~low:99.0 ~close:100.0;
    bar ~week_offset:1 ~high:111.0 ~low:100.0 ~close:110.0;
    bar ~week_offset:2 ~high:121.0 ~low:110.0 ~close:120.0;
    bar ~week_offset:3 ~high:131.0 ~low:120.0 ~close:130.0;
  ]

let test_rising_long _ =
  assert_that
    (single
       (PE.post_exit_metrics ~side:Long ~exit_price:100.0 ~exit_date
          ~bars:rising_bars ~horizons_weeks:[ 4 ]))
    (all_of
       [
         field (fun r -> r.PE.horizon_weeks) (equal_to 4);
         field (fun r -> r.PE.continuation_pct) (float_equal 0.30);
         field (fun r -> r.PE.post_exit_max_favorable_pct) (float_equal 0.31);
         field (fun r -> r.PE.post_exit_max_adverse_pct) (float_equal (-0.01));
       ])

(* Monotonically falling long: exit at 100, price drops to 70 over 4 weeks
   (closes 100,90,80,70). continuation = (70-100)/100 = -0.30 (dodged a drop).
   MFE from max high (exit bar high 101) = 0.01; MAE from min low 69 = -0.31. *)
let falling_bars =
  [
    bar ~week_offset:0 ~high:101.0 ~low:99.0 ~close:100.0;
    bar ~week_offset:1 ~high:100.0 ~low:89.0 ~close:90.0;
    bar ~week_offset:2 ~high:90.0 ~low:79.0 ~close:80.0;
    bar ~week_offset:3 ~high:80.0 ~low:69.0 ~close:70.0;
  ]

let test_falling_long _ =
  assert_that
    (single
       (PE.post_exit_metrics ~side:Long ~exit_price:100.0 ~exit_date
          ~bars:falling_bars ~horizons_weeks:[ 4 ]))
    (all_of
       [
         field (fun r -> r.PE.continuation_pct) (float_equal (-0.30));
         field (fun r -> r.PE.post_exit_max_favorable_pct) (float_equal 0.01);
         field (fun r -> r.PE.post_exit_max_adverse_pct) (float_equal (-0.31));
       ])

(* Choppy long: exit at 100; goes up to 120 then back to 95 (closes
   100,120,95). continuation to last close = (95-100)/100 = -0.05. MFE from max
   high 122 = 0.22; MAE from min low 94 = -0.06. Both excursions non-trivial. *)
let choppy_bars =
  [
    bar ~week_offset:0 ~high:101.0 ~low:99.0 ~close:100.0;
    bar ~week_offset:1 ~high:122.0 ~low:108.0 ~close:120.0;
    bar ~week_offset:2 ~high:118.0 ~low:94.0 ~close:95.0;
  ]

let test_choppy_long _ =
  assert_that
    (single
       (PE.post_exit_metrics ~side:Long ~exit_price:100.0 ~exit_date
          ~bars:choppy_bars ~horizons_weeks:[ 4 ]))
    (all_of
       [
         field (fun r -> r.PE.continuation_pct) (float_equal (-0.05));
         field (fun r -> r.PE.post_exit_max_favorable_pct) (float_equal 0.22);
         field (fun r -> r.PE.post_exit_max_adverse_pct) (float_equal (-0.06));
       ])

(* Short side on the SAME rising series. A short that exited at 100 while price
   then rose is the "move continued in the direction we wanted to stay in" only
   if we read with the sign flipped: continuation = -(130-100)/100 = -0.30
   (price rose = bad for a short = negative continuation). Favourable for a
   short is a drop (min low 99) -> -(99-100)/100 = 0.01; adverse is the rise
   (max high 131 over the 4 bars) -> -(131-100)/100 = -0.31. *)
let test_short_sign_flip _ =
  assert_that
    (single
       (PE.post_exit_metrics ~side:Short ~exit_price:100.0 ~exit_date
          ~bars:rising_bars ~horizons_weeks:[ 4 ]))
    (all_of
       [
         field (fun r -> r.PE.continuation_pct) (float_equal (-0.30));
         field (fun r -> r.PE.post_exit_max_favorable_pct) (float_equal 0.01);
         field (fun r -> r.PE.post_exit_max_adverse_pct) (float_equal (-0.31));
       ])

(* Multiple horizons in one call on the rising series.
   h=1: window = bars within 7 days = exit bar + week-1 bar (closes 100,110).
        continuation = (110-100)/100 = 0.10; MFE from max high 111 = 0.11;
        MAE from min low 99 = -0.01.
   h=2: + week-2 bar (close 120). continuation = 0.20; MFE high 121 = 0.21.
   h=4: full series as in test_rising_long (0.30 / 0.30). *)
let test_multiple_horizons _ =
  assert_that
    (PE.post_exit_metrics ~side:Long ~exit_price:100.0 ~exit_date
       ~bars:rising_bars ~horizons_weeks:[ 1; 2; 4 ])
    (elements_are
       [
         all_of
           [
             field (fun r -> r.PE.horizon_weeks) (equal_to 1);
             field (fun r -> r.PE.continuation_pct) (float_equal 0.10);
             field
               (fun r -> r.PE.post_exit_max_favorable_pct)
               (float_equal 0.11);
           ];
         all_of
           [
             field (fun r -> r.PE.horizon_weeks) (equal_to 2);
             field (fun r -> r.PE.continuation_pct) (float_equal 0.20);
             field
               (fun r -> r.PE.post_exit_max_favorable_pct)
               (float_equal 0.21);
           ];
         all_of
           [
             field (fun r -> r.PE.horizon_weeks) (equal_to 4);
             field (fun r -> r.PE.continuation_pct) (float_equal 0.30);
           ];
       ])

(* A horizon beyond the data: 26 weeks but only 4 bars (last at week 3). The
   window still contains all 4 bars (they fall within 26*7 days), so this is NOT
   an empty window — it equals the h=4 result. Use a horizon whose lower bound
   excludes everything instead: pass an empty bar list. *)
let test_horizon_beyond_data_uses_available_bars _ =
  assert_that
    (single
       (PE.post_exit_metrics ~side:Long ~exit_price:100.0 ~exit_date
          ~bars:rising_bars ~horizons_weeks:[ 26 ]))
    (all_of
       [
         field (fun r -> r.PE.horizon_weeks) (equal_to 26);
         field (fun r -> r.PE.continuation_pct) (float_equal 0.30);
       ])

(* Empty bars -> every field 0.0, horizon label preserved. *)
let test_empty_bars _ =
  assert_that
    (single
       (PE.post_exit_metrics ~side:Long ~exit_price:100.0 ~exit_date ~bars:[]
          ~horizons_weeks:[ 13 ]))
    (all_of
       [
         field (fun r -> r.PE.horizon_weeks) (equal_to 13);
         field (fun r -> r.PE.continuation_pct) (float_equal 0.0);
         field (fun r -> r.PE.post_exit_max_favorable_pct) (float_equal 0.0);
         field (fun r -> r.PE.post_exit_max_adverse_pct) (float_equal 0.0);
       ])

(* All bars strictly before exit_date -> filtered out -> empty window -> 0.0. *)
let test_all_bars_before_exit _ =
  let before =
    [
      bar ~week_offset:(-2) ~high:200.0 ~low:190.0 ~close:195.0;
      bar ~week_offset:(-1) ~high:210.0 ~low:198.0 ~close:205.0;
    ]
  in
  assert_that
    (single
       (PE.post_exit_metrics ~side:Long ~exit_price:100.0 ~exit_date
          ~bars:before ~horizons_weeks:[ 4 ]))
    (all_of
       [
         field (fun r -> r.PE.continuation_pct) (float_equal 0.0);
         field (fun r -> r.PE.post_exit_max_favorable_pct) (float_equal 0.0);
       ])

(* exit_price = 0.0 guard -> all fields 0.0 for every horizon. *)
let test_exit_price_zero_guard _ =
  assert_that
    (PE.post_exit_metrics ~side:Long ~exit_price:0.0 ~exit_date
       ~bars:rising_bars ~horizons_weeks:[ 4; 13 ])
    (elements_are
       [
         all_of
           [
             field (fun r -> r.PE.horizon_weeks) (equal_to 4);
             field (fun r -> r.PE.continuation_pct) (float_equal 0.0);
             field (fun r -> r.PE.post_exit_max_favorable_pct) (float_equal 0.0);
             field (fun r -> r.PE.post_exit_max_adverse_pct) (float_equal 0.0);
           ];
         all_of
           [
             field (fun r -> r.PE.horizon_weeks) (equal_to 13);
             field (fun r -> r.PE.continuation_pct) (float_equal 0.0);
           ];
       ])

(* The bar exactly on exit_date IS included: with only that one bar (close 108),
   continuation = (108-100)/100 = 0.08. If it were excluded the window would be
   empty and continuation would be 0.0 instead. *)
let test_exit_date_bar_included _ =
  let only_exit_bar =
    [ bar ~week_offset:0 ~high:110.0 ~low:98.0 ~close:108.0 ]
  in
  assert_that
    (single
       (PE.post_exit_metrics ~side:Long ~exit_price:100.0 ~exit_date
          ~bars:only_exit_bar ~horizons_weeks:[ 4 ]))
    (all_of
       [
         field (fun r -> r.PE.continuation_pct) (float_equal 0.08);
         field (fun r -> r.PE.post_exit_max_favorable_pct) (float_equal 0.10);
         field (fun r -> r.PE.post_exit_max_adverse_pct) (float_equal (-0.02));
       ])

(* Unsorted input is sorted internally: shuffle the rising series, expect the
   same h=4 result as test_rising_long. *)
let test_unsorted_input _ =
  let shuffled = List.rev rising_bars in
  assert_that
    (single
       (PE.post_exit_metrics ~side:Long ~exit_price:100.0 ~exit_date
          ~bars:shuffled ~horizons_weeks:[ 4 ]))
    (all_of
       [
         field (fun r -> r.PE.continuation_pct) (float_equal 0.30);
         field (fun r -> r.PE.post_exit_max_adverse_pct) (float_equal (-0.01));
       ])

let suite =
  "post_exit"
  >::: [
         "rising_long" >:: test_rising_long;
         "falling_long" >:: test_falling_long;
         "choppy_long" >:: test_choppy_long;
         "short_sign_flip" >:: test_short_sign_flip;
         "multiple_horizons" >:: test_multiple_horizons;
         "horizon_beyond_data" >:: test_horizon_beyond_data_uses_available_bars;
         "empty_bars" >:: test_empty_bars;
         "all_bars_before_exit" >:: test_all_bars_before_exit;
         "exit_price_zero_guard" >:: test_exit_price_zero_guard;
         "exit_date_bar_included" >:: test_exit_date_bar_included;
         "unsorted_input" >:: test_unsorted_input;
       ]

let () = run_test_tt_main suite
