open OUnit2
open Core
open Matchers
module Resistance_sketch = Snapshot_pipeline.Resistance_sketch
module Weekly_prefix = Snapshot_pipeline.Weekly_prefix
module Pipeline = Snapshot_pipeline.Pipeline
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

let _bar ~date ?(close = 5.0) ?high ?low () =
  {
    Types.Daily_price.date;
    open_price = close;
    high_price = Option.value high ~default:(close +. 1.0);
    low_price = Option.value low ~default:(close -. 1.0);
    close_price = close;
    volume = 1_000;
    adjusted_close = close;
    active_through = None;
  }

(* Monday anchor so calendar weeks align with ISO weeks. *)
let _week_start = Date.of_string "2000-01-03"

(* Day [d] (0-4, Mon-Fri) of week [w]. *)
let _day ~w ~d = Date.add_days _week_start ((7 * w) + d)

(* [n_weeks] Mon-Fri weeks of bars. Every bar of week [w] carries the same
   (high, low) from [week_shape w], so the weekly aggregate's high/low are
   exactly the override regardless of how the production week-bucketing
   groups the days (it splits at calendar-year boundaries, so week COUNTS
   must never be hand-derived from [n_weeks] in assertions). *)
let _weeks_bars ~n_weeks ~week_shape =
  List.init n_weeks ~f:(fun w ->
      let high, low = Option.value (week_shape w) ~default:(6.0, 4.0) in
      List.init 5 ~f:(fun d -> _bar ~date:(_day ~w ~d) ~high ~low ()))
  |> List.concat

let _compute bars =
  let bars_arr = Array.of_list bars in
  let weekly_prefix = Weekly_prefix.build bars_arr in
  (Resistance_sketch.compute ~weekly_prefix ~bars_arr, weekly_prefix, bars_arr)

(* Reference max over the trailing [lookback] weekly bars at [day_idx],
   straight from [Weekly_prefix.window_for_day] — the independent oracle the
   deque-based sliding max must agree with. *)
let _reference_max weekly_prefix ~day_idx ~lookback =
  Weekly_prefix.window_for_day weekly_prefix ~day_idx ~lookback
  |> List.map ~f:(fun (b : Types.Daily_price.t) -> b.high_price)
  |> List.max_elt ~compare:Float.compare
  |> Option.value ~default:Float.nan

(* A week-0 spike must age out of the 130-week window by the last day of a
   131-calendar-week series (the window is at most 130 weekly bars, and
   year-boundary splits only ADD weekly bars, pushing the spike out even
   earlier) while the 260/520 horizons still see it. Every sampled day is
   also checked against the brute-force oracle for all three horizons. *)
let test_rolling_max_windows_and_eviction _ =
  let spike = 1_000.0 in
  let week_shape w = if w = 0 then Some (spike, 4.0) else None in
  let sketch, weekly_prefix, bars_arr =
    _compute (_weeks_bars ~n_weeks:131 ~week_shape)
  in
  let n = Array.length bars_arr in
  let last = n - 1 in
  let sampled = List.init (n / 37) ~f:(fun k -> k * 37) @ [ last ] in
  let columns =
    [
      (sketch.max_high_130w, 130);
      (sketch.max_high_260w, 260);
      (sketch.max_high_520w, 520);
    ]
  in
  let oracle_mismatches =
    List.count (List.cartesian_product sampled columns)
      ~f:(fun (i, (col, lookback)) ->
        let expected = _reference_max weekly_prefix ~day_idx:i ~lookback in
        Float.(abs (col.(i) -. expected) > 1e-9))
  in
  assert_that
    (oracle_mismatches, sketch.max_high_130w.(last), sketch.max_high_260w.(last))
    (all_of
       [
         field (fun (m, _, _) -> m) (equal_to 0);
         field (fun (_, b, _) -> b) (float_equal 6.0);
         field (fun (_, _, c) -> c) (float_equal spike);
       ])

let test_bars_seen_counts_weeks _ =
  let sketch, weekly_prefix, bars_arr =
    _compute (_weeks_bars ~n_weeks:131 ~week_shape:(fun _ -> None))
  in
  let last = Array.length bars_arr - 1 in
  let total_weekly_bars =
    Weekly_prefix.window_for_day weekly_prefix ~day_idx:last ~lookback:100_000
    |> List.length
  in
  assert_that
    (sketch.bars_seen.(0), sketch.bars_seen.(last))
    (all_of
       [
         field (fun (a, _) -> a) (float_equal 1.0);
         field (fun (_, b) -> b) (float_equal (Float.of_int total_weekly_bars));
       ])

(* Histogram semantics at the final day (anchor close = 10). Every bar of a
   week carries the week's (high, low), so the weekly aggregate is exact:
   - week 0: high 12, low 11 -> mid 11.5, 20*log2(1.15) ~ 4.03 -> bucket 4
   - week 1: high 25, low 24 -> mid 24.5, more than 2x above -> dropped
   - week 2: high 10.5, low 8 -> mid 9.25 below anchor -> dropped
   - week 3: high 10.2, low 10.0 -> mid 10.1, 20*log2(1.01) ~ 0.29 -> bucket 0
   - week 4 (partial): high = close = 10, not above anchor -> no count *)
let test_histogram_buckets _ =
  let anchor = 10.0 in
  let week_shape = function
    | 0 -> (12.0, 11.0)
    | 1 -> (25.0, 24.0)
    | 2 -> (10.5, 8.0)
    | 3 -> (10.2, 10.0)
    | _ -> (anchor, 9.0)
  in
  let bars =
    List.init 5 ~f:(fun w ->
        let high, low = week_shape w in
        List.init 5 ~f:(fun d ->
            _bar ~date:(_day ~w ~d) ~close:anchor ~high ~low ()))
    |> List.concat
  in
  let sketch, _, _ = _compute bars in
  let last = (5 * 5) - 1 in
  let counts =
    List.init Snapshot_schema.n_hist_buckets ~f:(fun k ->
        sketch.hist.(k).(last))
  in
  let expected =
    List.init Snapshot_schema.n_hist_buckets ~f:(fun k ->
        if k = 0 || k = 4 then float_equal 1.0 else float_equal 0.0)
  in
  assert_that counts (elements_are expected)

let test_corrupt_close_degrades_to_nan _ =
  let bars =
    List.init 5 ~f:(fun d ->
        let date = _day ~w:0 ~d in
        if d = 2 then _bar ~date ~close:0.0 ~high:1.0 ~low:0.0 ()
        else _bar ~date ())
  in
  let sketch, _, _ = _compute bars in
  assert_that
    ( Float.is_nan sketch.max_high_130w.(2),
      Float.is_nan sketch.bars_seen.(2),
      Float.is_nan sketch.hist.(0).(2),
      Float.is_nan sketch.max_high_130w.(1) )
    (equal_to (true, true, true, false))

(* Virgin parity against the v1 AUTHORITY ([Resistance.analyze]) over the
   same weekly window: v1 is virgin iff no weekly high strictly exceeds the
   breakout, so the sketch-derived test [breakout >= max_high_520w] must
   agree at breakouts below, exactly AT (the tie), and above the window max. *)
let test_virgin_parity_with_v1_mapper _ =
  let spike = 130.0 in
  let week_shape w = if w = 10 then Some (spike, 100.0) else None in
  let sketch, weekly_prefix, bars_arr =
    _compute (_weeks_bars ~n_weeks:60 ~week_shape)
  in
  let last = Array.length bars_arr - 1 in
  let weekly_window =
    Weekly_prefix.window_for_day weekly_prefix ~day_idx:last ~lookback:520
  in
  let as_of_date = bars_arr.(last).Types.Daily_price.date in
  let breakouts = [ spike -. 10.0; spike; spike +. 10.0 ] in
  let agreements =
    List.count breakouts ~f:(fun breakout_price ->
        let v1 =
          Resistance.analyze ~config:Resistance.default_config
            ~bars:weekly_window ~breakout_price ~as_of_date
        in
        let v1_virgin =
          match v1.quality with
          | Weinstein_types.Virgin_territory -> true
          | _ -> false
        in
        let sketch_virgin =
          Float.(breakout_price >= sketch.max_high_520w.(last))
        in
        Bool.equal v1_virgin sketch_virgin)
  in
  assert_that agreements (equal_to (List.length breakouts))

(* End-to-end: the default schema's sketch columns are populated by
   [Pipeline.build_for_symbol]. 10 consecutive calendar days from Tue
   2024-01-02 span ISO weeks 1-2, so the last row has 2 weekly bars. *)
let test_pipeline_populates_sketch_columns _ =
  let dates = List.init 10 ~f:(Date.add_days (Date.of_string "2024-01-02")) in
  let bars =
    List.mapi dates ~f:(fun i d ->
        _bar ~date:d ~close:(100.0 +. Float.of_int i) ())
  in
  let rows =
    Pipeline.build_for_symbol ~symbol:"FOO" ~bars
      ~schema:Snapshot_schema.default ()
  in
  let last_row_fields =
    Result.bind rows ~f:(fun rows ->
        match List.last rows with
        | None -> Status.error_internal "no rows"
        | Some r ->
            Ok
              ( Snapshot.get r Snapshot_schema.Res_bars_seen,
                Snapshot.get r Snapshot_schema.Res_max_high_520w ))
  in
  assert_that last_row_fields
    (is_ok_and_holds
       (all_of
          [
            field (fun (a, _) -> a) (is_some_and (float_equal 2.0));
            field (fun (_, b) -> b) (is_some_and (float_equal 110.0));
          ]))

let suite =
  "Resistance_sketch tests"
  >::: [
         "rolling max windows and eviction"
         >:: test_rolling_max_windows_and_eviction;
         "bars_seen counts weeks" >:: test_bars_seen_counts_weeks;
         "histogram buckets" >:: test_histogram_buckets;
         "corrupt close degrades to NaN" >:: test_corrupt_close_degrades_to_nan;
         "virgin parity with v1 mapper" >:: test_virgin_parity_with_v1_mapper;
         "pipeline populates sketch columns"
         >:: test_pipeline_populates_sketch_columns;
       ]

let () = run_test_tt_main suite
