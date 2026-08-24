open Core
open OUnit2
open Matchers
module Analytics = Monster_scan_lib.Monster_scan_analytics
module Bar = Types.Daily_price

(* Synthetic weekly series. Week [i] is dated [i] weeks after 2000-01-07 (a
   Friday), and every bar is a doji (o=h=l=c) so the prior-high level is exactly
   the prior close — the breakout arithmetic stays checkable by hand. *)
let _week0 = Date.of_string "2000-01-07"
let _week_date i = Date.add_days _week0 (i * 7)

let _bar ~week ~close ~volume =
  Bar.make ~date:(_week_date week) ~open_price:close ~high_price:close
    ~low_price:close ~close_price:close ~volume ~adjusted_close:close ()

let _series ~n ~close ~volume =
  Array.init n ~f:(fun i -> _bar ~week:i ~close:(close i) ~volume:(volume i))

let _lookback = Analytics.default_params.breakout_lookback_weeks

(* 76 weeks: a 40-week flat base at 100, then +2/week. Only week 70 carries
   expanded volume, so it is the only week that can clear the volume gate. *)
let _base_weeks_count = 40
let _breakout_week = 70
let _flat_close = 100.0
let _weekly_step = 2.0
let _quiet_volume = 1_000
let _loud_volume = 5_000

let _rising_close i =
  if i < _base_weeks_count then _flat_close
  else _flat_close +. (_weekly_step *. Float.of_int (i - _base_weeks_count + 1))

let _breakout_series () =
  _series ~n:76 ~close:_rising_close ~volume:(fun i ->
      if i = _breakout_week then _loud_volume else _quiet_volume)

let _scan bars =
  Analytics.scan ~params:Analytics.default_params
    ~stage_config:Stage.default_config ~bars

let _features_at bars idx =
  Analytics.features_at ~params:Analytics.default_params
    ~stage_config:Stage.default_config ~bars ~idx

(* The volume gate is the only thing separating week 70 from the 30 other
   new-high weeks around it, so "exactly one breakout, at week 70" pins both the
   price test and the volume test at once. *)
let test_scan_fires_on_the_constructed_week _ =
  assert_that
    (_scan (_breakout_series ()))
    (elements_are
       [
         all_of
           [
             field
               (fun (b : Analytics.breakout) -> b.week_date)
               (equal_to (_week_date _breakout_week));
             field
               (fun (b : Analytics.breakout) -> b.close)
               (float_equal (_rising_close _breakout_week));
             field
               (fun (b : Analytics.breakout) -> b.features.prior_high)
               (float_equal (_rising_close (_breakout_week - 1)));
             field
               (fun (b : Analytics.breakout) ->
                 Analytics.stage_label b.features.stage)
               (equal_to "Stage2");
           ];
       ])

(* A new high on quiet volume is not a breakout: same series, volume flattened. *)
let test_scan_requires_volume_confirmation _ =
  let bars =
    _series ~n:76 ~close:_rising_close ~volume:(fun _ -> _quiet_volume)
  in
  assert_that (_scan bars) (size_is 0)

(* Same closes, but volume ramps to [_ramp_volume] over the last four weeks
   before the breakout. That makes the book's 4-week denominator numerically
   distinct from the 26-week one, so the two ratio tests below cannot both pass
   on a single welded window. *)
let _ramp_weeks = 4
let _ramp_volume = 2_000

let _ramped_volume_series () =
  _series ~n:76 ~close:_rising_close ~volume:(fun i ->
      if i = _breakout_week then _loud_volume
      else if i >= _breakout_week - _ramp_weeks then _ramp_volume
      else _quiet_volume)

let _vol_ratio_at bars idx ~vol_lookback_weeks =
  Analytics.features_at
    ~params:{ Analytics.default_params with vol_lookback_weeks }
    ~stage_config:Stage.default_config ~bars ~idx
  |> Option.map ~f:(fun (f : Analytics.features) -> f.vol_ratio)

(* Book basis (weinstein-book-reference.md §4.2): the denominator is the mean of
   the prior FOUR weeks, all of which sit in the ramp. *)
let test_vol_ratio_uses_the_book_four_week_denominator _ =
  assert_that
    (_vol_ratio_at (_ramped_volume_series ()) _breakout_week
       ~vol_lookback_weeks:Analytics.default_params.vol_lookback_weeks)
    (is_some_and
       (float_equal (Float.of_int _loud_volume /. Float.of_int _ramp_volume)))

(* Overriding the volume window alone moves only the denominator: 26 weeks of
   which the last four are the ramp and the rest are quiet. *)
let test_vol_ratio_honours_an_overridden_window _ =
  let weeks = Analytics.default_params.breakout_lookback_weeks in
  let mean =
    Float.of_int
      (((weeks - _ramp_weeks) * _quiet_volume) + (_ramp_weeks * _ramp_volume))
    /. Float.of_int weeks
  in
  assert_that
    (_vol_ratio_at (_ramped_volume_series ()) _breakout_week
       ~vol_lookback_weeks:weeks)
    (is_some_and (float_equal (Float.of_int _loud_volume /. mean)))

(* 10 weeks at 50, then 40 at 100. At the last index the trailing-window median
   is 100 and the band is +/-15, so the walk back counts every 100-week and
   stops at the last 50-week. *)
let test_base_weeks_counts_consecutive_in_band_weeks _ =
  let low_weeks = 10 and total = 50 in
  let bars =
    _series ~n:total
      ~close:(fun i -> if i < low_weeks then 50.0 else _flat_close)
      ~volume:(fun _ -> _quiet_volume)
  in
  let last = total - 1 in
  assert_that (_features_at bars last)
    (is_some_and
       (field
          (fun (f : Analytics.features) -> f.base_weeks)
          (equal_to (last - low_weeks))))

let test_features_declines_a_short_window _ =
  let bars =
    _series ~n:76 ~close:_rising_close ~volume:(fun _ -> _quiet_volume)
  in
  assert_that (_features_at bars (_lookback - 1)) is_none

let _forward_run bars ~idx ~fwd_weeks =
  Analytics.forward_run_at
    ~params:{ Analytics.default_params with fwd_weeks }
    ~bars ~idx

(* Closes rise monotonically, so the max over the horizon is its last bar and
   [weeks_to_max] equals the horizon. *)
let test_forward_run_measures_the_horizon_max _ =
  let bars = _breakout_series () in
  let fwd_weeks = 5 in
  let entry = _rising_close _breakout_week in
  let peak = _rising_close (_breakout_week + fwd_weeks) in
  assert_that
    (_forward_run bars ~idx:_breakout_week ~fwd_weeks)
    (all_of
       [
         field
           (fun (r : Analytics.forward_run) -> r.fwd_max_close)
           (float_equal peak);
         field
           (fun (r : Analytics.forward_run) -> r.fwd_run_pct)
           (float_equal (((peak /. entry) -. 1.0) *. 100.0));
         field
           (fun (r : Analytics.forward_run) -> r.weeks_to_max)
           (equal_to fwd_weeks);
       ])

(* The horizon is clipped to the end of the series; at the last bar there is no
   forward bar at all. *)
let test_forward_run_at_the_last_bar_is_empty _ =
  let bars = _breakout_series () in
  assert_that
    (_forward_run bars ~idx:(Array.length bars - 1) ~fwd_weeks:52)
    (field (fun (r : Analytics.forward_run) -> r.weeks_to_max) (equal_to 0))

(* Two series that agree bar-for-bar through [_breakout_week] and then diverge
   as violently as the type allows: one plateaus far above, the other collapses
   on a huge volume spike. Every decision-time quantity must be blind to the
   difference; the forward run must not be. *)
let _plateau_close = 500.0
let _crash_close = 10.0
let _spike_volume = 50_000

let _divergent_series ~tail_close ~tail_volume =
  _series ~n:76
    ~close:(fun i ->
      if i <= _breakout_week then _rising_close i else tail_close)
    ~volume:(fun i ->
      if i < _breakout_week then _quiet_volume
      else if i = _breakout_week then _loud_volume
      else tail_volume)

let _rising_tail () =
  _divergent_series ~tail_close:_plateau_close ~tail_volume:_quiet_volume

let _crashing_tail () =
  _divergent_series ~tail_close:_crash_close ~tail_volume:_spike_volume

(* Pins the module's headline contract: [features] reads bars at [<= idx] only.
   Widening any window in the implementation to include bars after [idx] — most
   obviously the prefix slice handed to the stage classifier — moves [ma30] and
   [stage] here and fails this test. *)
let test_features_are_invariant_to_bars_after_idx _ =
  let expected =
    Option.value_exn
      (_features_at (_rising_tail ()) _breakout_week)
      ~message:"rising-tail series must yield features at the breakout week"
  in
  assert_that
    (_features_at (_crashing_tail ()) _breakout_week)
    (is_some_and
       (all_of
          [
            field
              (fun (f : Analytics.features) -> f.prior_high)
              (float_equal expected.prior_high);
            field
              (fun (f : Analytics.features) -> f.vol_ratio)
              (float_equal expected.vol_ratio);
            field
              (fun (f : Analytics.features) -> f.ma30)
              (float_equal expected.ma30);
            field
              (fun (f : Analytics.features) -> f.base_weeks)
              (equal_to expected.base_weeks);
            field
              (fun (f : Analytics.features) -> Analytics.stage_label f.stage)
              (equal_to (Analytics.stage_label expected.stage));
          ]))

(* The other half of the same contract: the hindsight side really does read the
   future, so the invariance above is a property of [features_at] specifically
   and not of a series pair that happens to look alike. *)
let test_forward_run_does_read_bars_after_idx _ =
  let fwd_weeks = 5 in
  assert_that
    (_forward_run (_rising_tail ()) ~idx:_breakout_week ~fwd_weeks)
    (field
       (fun (r : Analytics.forward_run) -> r.fwd_max_close)
       (float_equal _plateau_close));
  assert_that
    (_forward_run (_crashing_tail ()) ~idx:_breakout_week ~fwd_weeks)
    (field
       (fun (r : Analytics.forward_run) -> r.fwd_max_close)
       (float_equal _crash_close))

(* The pairs join: a mid-week date resolves to that week's close, a week-end
   date resolves to itself, and a date past the series resolves to nothing. *)
let test_index_for_date_snaps_into_the_containing_week _ =
  let bars = _breakout_series () in
  let mid_week = Date.add_days (_week_date 5) (-3) in
  assert_that
    (Analytics.index_for_date ~bars ~date:mid_week)
    (is_some_and (equal_to 5))

let test_index_for_date_is_exact_on_a_week_end _ =
  let bars = _breakout_series () in
  assert_that
    (Analytics.index_for_date ~bars ~date:(_week_date 5))
    (is_some_and (equal_to 5))

let test_index_for_date_after_the_series_is_none _ =
  let bars = _breakout_series () in
  assert_that (Analytics.index_for_date ~bars ~date:(_week_date 500)) is_none

let suite =
  "monster_scan_analytics"
  >::: [
         "scan fires on the constructed week"
         >:: test_scan_fires_on_the_constructed_week;
         "scan requires volume confirmation"
         >:: test_scan_requires_volume_confirmation;
         "vol_ratio uses the book four-week denominator"
         >:: test_vol_ratio_uses_the_book_four_week_denominator;
         "vol_ratio honours an overridden window"
         >:: test_vol_ratio_honours_an_overridden_window;
         "features are invariant to bars after idx"
         >:: test_features_are_invariant_to_bars_after_idx;
         "forward run does read bars after idx"
         >:: test_forward_run_does_read_bars_after_idx;
         "base_weeks counts consecutive in-band weeks"
         >:: test_base_weeks_counts_consecutive_in_band_weeks;
         "features declines a short window"
         >:: test_features_declines_a_short_window;
         "forward run measures the horizon max"
         >:: test_forward_run_measures_the_horizon_max;
         "forward run at the last bar is empty"
         >:: test_forward_run_at_the_last_bar_is_empty;
         "index_for_date snaps into the containing week"
         >:: test_index_for_date_snaps_into_the_containing_week;
         "index_for_date is exact on a week end"
         >:: test_index_for_date_is_exact_on_a_week_end;
         "index_for_date after the series is none"
         >:: test_index_for_date_after_the_series_is_none;
       ]

let () = run_test_tt_main suite
