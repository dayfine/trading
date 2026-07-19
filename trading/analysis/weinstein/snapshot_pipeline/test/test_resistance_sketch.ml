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

(* Count index positions where two float arrays differ in their IEEE-754 bit
   pattern (so [nan] matches [nan] and [-0.0] differs from [0.0]) — the
   bit-exact do-no-harm / split-parity gate. Length mismatch is [Int.max_value]
   so it never reads as 0. *)
let _bit_mismatches a b =
  if Array.length a <> Array.length b then Int.max_value
  else
    Array.foldi a ~init:0 ~f:(fun i acc x ->
        if Int64.equal (Int64.bits_of_float x) (Int64.bits_of_float b.(i)) then
          acc
        else acc + 1)

let _sketch_bit_mismatches (a : Resistance_sketch.t) (b : Resistance_sketch.t) =
  let cols =
    [
      (a.max_high_130w, b.max_high_130w);
      (a.max_high_260w, b.max_high_260w);
      (a.max_high_520w, b.max_high_520w);
      (a.bars_seen, b.bars_seen);
    ]
  in
  let col_mm =
    List.sum (module Int) cols ~f:(fun (x, y) -> _bit_mismatches x y)
  in
  let hist_mm =
    Array.foldi a.hist ~init:0 ~f:(fun k acc row ->
        acc + _bit_mismatches row b.hist.(k))
  in
  col_mm + hist_mm

(* Trailing-window slice of a full-series sketch — the independent oracle
   [compute_windowed] must reproduce. *)
let _slice_sketch (s : Resistance_sketch.t) ~offset ~len : Resistance_sketch.t =
  let slice arr = Array.sub arr ~pos:offset ~len in
  {
    Resistance_sketch.max_high_130w = slice s.max_high_130w;
    max_high_260w = slice s.max_high_260w;
    max_high_520w = slice s.max_high_520w;
    bars_seen = slice s.bars_seen;
    hist = Array.map s.hist ~f:slice;
  }

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
  (* All five weeks are age < 130 at the final day, so per-bucket the SUM over
     age bands reproduces the pre-lever-f age-blind histogram. *)
  let counts =
    List.init Snapshot_schema.n_hist_buckets ~f:(fun bucket ->
        List.sum
          (module Float)
          (List.init Snapshot_schema.n_age_bands ~f:Fn.id)
          ~f:(fun band ->
            sketch.hist.((band * Snapshot_schema.n_hist_buckets) + bucket).(last)))
  in
  let expected =
    List.init Snapshot_schema.n_hist_buckets ~f:(fun k ->
        if k = 0 || k = 4 then float_equal 1.0 else float_equal 0.0)
  in
  assert_that counts (elements_are expected)

(* Age banding (lever f): a resistance spike at week 0 of a 200-week series is
   ~200 weeks old at the final day, so it lands in the 130-520w age band (band
   3) — the histogram now MEASURES old supply the pre-lever-f 130w window
   dropped. Non-spike weeks have high = close (5), so they are gated out
   ([weekly_high > anchor] fails). Recent bands (0-2) are therefore empty and
   band 3 holds exactly the one spike bar. *)
let test_age_bands_separate_old_supply _ =
  let week_shape w =
    if w = 0 then Some (7.0, 6.0) (* mid 6.5 over anchor 5 -> bucket 7 *)
    else Some (5.0, 4.0)
    (* high = anchor -> not counted *)
  in
  let sketch, _, bars_arr = _compute (_weeks_bars ~n_weeks:200 ~week_shape) in
  let last = Array.length bars_arr - 1 in
  let n_buckets = Snapshot_schema.n_hist_buckets in
  let band_total band =
    List.sum
      (module Float)
      (List.init n_buckets ~f:Fn.id)
      ~f:(fun bucket -> sketch.hist.((band * n_buckets) + bucket).(last))
  in
  let recent_total = List.sum (module Float) [ 0; 1; 2 ] ~f:band_total in
  assert_that
    (recent_total, band_total 3, sketch.hist.((3 * n_buckets) + 7).(last))
    (all_of
       [
         field (fun (r, _, _) -> r) (float_equal 0.0);
         field (fun (_, s, _) -> s) (float_equal 1.0);
         field (fun (_, _, b) -> b) (float_equal 1.0);
       ])

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

(* Split-parity: splitting a series into (deep, window) then feeding both to
   [compute_windowed] reproduces the full-series sketch sliced to the window,
   bit-for-bit. The split is Wednesday of week 20 (raw index 5*20+2) so the deep
   tail and the window head share one ISO week — the boundary re-merge is
   exercised, not just a clean week edge. *)
let test_split_parity_bit_identical _ =
  let bars =
    _weeks_bars ~n_weeks:200 ~week_shape:(fun w ->
        if w = 5 then Some (50.0, 40.0) else None)
  in
  let full_arr = Array.of_list bars in
  let split = (5 * 20) + 2 in
  let deep = Array.sub full_arr ~pos:0 ~len:split in
  let window =
    Array.sub full_arr ~pos:split ~len:(Array.length full_arr - split)
  in
  let windowed =
    Resistance_sketch.compute_windowed ~deep_bars:deep ~bars_arr:window
  in
  let full_sketch =
    Resistance_sketch.compute
      ~weekly_prefix:(Weekly_prefix.build full_arr)
      ~bars_arr:full_arr
  in
  let expected =
    _slice_sketch full_sketch ~offset:split ~len:(Array.length window)
  in
  assert_that (_sketch_bit_mismatches windowed expected) (equal_to 0)

(* bars_seen honesty: with 550 weeks of deep history before the window, the
   first emitted row reports the capped true depth (520), not the window-relative
   count (1) it would report with no deep feed. *)
let test_deep_bars_seen_honesty _ =
  let full = _weeks_bars ~n_weeks:600 ~week_shape:(fun _ -> None) in
  let full_arr = Array.of_list full in
  let split = 5 * 550 in
  let deep = Array.sub full_arr ~pos:0 ~len:split in
  let window =
    Array.sub full_arr ~pos:split ~len:(Array.length full_arr - split)
  in
  let with_deep =
    Resistance_sketch.compute_windowed ~deep_bars:deep ~bars_arr:window
  in
  let without_deep =
    Resistance_sketch.compute_windowed ~deep_bars:[||] ~bars_arr:window
  in
  assert_that
    (with_deep.bars_seen.(0), without_deep.bars_seen.(0))
    (all_of
       [
         field (fun (a, _) -> a) (float_equal 520.0);
         field (fun (_, b) -> b) (float_equal 1.0);
       ])

(* The 13 non-sketch columns are the do-no-harm gate: supplying deep_bars must
   leave every EMA/SMA/ATR/RSI/Stage/RS/Macro/OHLCV/Adjusted cell bit-identical
   to the no-deep build (a golden drift here is a rejected PR). *)
let _basis_fields =
  Snapshot_schema.
    [
      EMA_50;
      SMA_50;
      ATR_14;
      RSI_14;
      Stage;
      RS_line;
      Macro_composite;
      Open;
      High;
      Low;
      Close;
      Volume;
      Adjusted_close;
    ]

let _row_basis_mismatches r1 r2 =
  List.count _basis_fields ~f:(fun field ->
      match (Snapshot.get r1 field, Snapshot.get r2 field) with
      | Some a, Some b ->
          not (Int64.equal (Int64.bits_of_float a) (Int64.bits_of_float b))
      | None, None -> false
      | _ -> true)

let _rows_basis_mismatches r1s r2s =
  if List.length r1s <> List.length r2s then Int.max_value
  else
    List.fold2_exn r1s r2s ~init:0 ~f:(fun acc r1 r2 ->
        acc + _row_basis_mismatches r1 r2)

let test_deep_bars_basis_guard _ =
  let window_start = Date.of_string "2010-01-04" in
  let window =
    List.init 260 ~f:(fun i ->
        _bar
          ~date:(Date.add_days window_start i)
          ~close:(100.0 +. Float.of_int (i mod 11))
          ())
  in
  let deep =
    List.init 520 ~f:(fun i ->
        _bar
          ~date:(Date.add_days (Date.of_string "2007-01-01") i)
          ~close:(80.0 +. Float.of_int (i mod 7))
          ())
  in
  let benchmark =
    List.init 260 ~f:(fun i ->
        _bar
          ~date:(Date.add_days window_start i)
          ~close:(200.0 +. Float.of_int (i mod 5))
          ())
  in
  let with_deep =
    Pipeline.build_for_symbol ~symbol:"FOO" ~bars:window ~deep_bars:deep
      ~schema:Snapshot_schema.default ~benchmark_bars:benchmark ()
  in
  let expected_rows =
    match
      Pipeline.build_for_symbol ~symbol:"FOO" ~bars:window
        ~schema:Snapshot_schema.default ~benchmark_bars:benchmark ()
    with
    | Ok rows -> rows
    | Error err -> failwith (Status.show err)
  in
  assert_that with_deep
    (is_ok_and_holds
       (field
          (fun rows -> _rows_basis_mismatches rows expected_rows)
          (equal_to 0)))

(* Deep whose last bar lands ON the window's first day overlaps -> Error. *)
let test_deep_overlap_errors _ =
  let window =
    List.init 20 ~f:(fun i ->
        _bar ~date:(Date.add_days (Date.of_string "2010-01-04") i) ())
  in
  let deep =
    List.init 20 ~f:(fun i ->
        _bar ~date:(Date.add_days (Date.of_string "2009-12-16") i) ())
  in
  let rows =
    Pipeline.build_for_symbol ~symbol:"FOO" ~bars:window ~deep_bars:deep
      ~schema:Snapshot_schema.default ()
  in
  assert_that rows is_error

let suite =
  "Resistance_sketch tests"
  >::: [
         "rolling max windows and eviction"
         >:: test_rolling_max_windows_and_eviction;
         "bars_seen counts weeks" >:: test_bars_seen_counts_weeks;
         "histogram buckets" >:: test_histogram_buckets;
         "age bands separate old supply" >:: test_age_bands_separate_old_supply;
         "corrupt close degrades to NaN" >:: test_corrupt_close_degrades_to_nan;
         "virgin parity with v1 mapper" >:: test_virgin_parity_with_v1_mapper;
         "pipeline populates sketch columns"
         >:: test_pipeline_populates_sketch_columns;
         "split parity bit-identical" >:: test_split_parity_bit_identical;
         "deep bars_seen honesty" >:: test_deep_bars_seen_honesty;
         "deep bars basis guard (13 columns)" >:: test_deep_bars_basis_guard;
         "deep overlap errors" >:: test_deep_overlap_errors;
       ]

let () = run_test_tt_main suite
