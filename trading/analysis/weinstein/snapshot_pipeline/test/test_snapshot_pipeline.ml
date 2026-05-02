open OUnit2
open Core
open Matchers
module Pipeline = Snapshot_pipeline.Pipeline
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

(* Build a deterministic synthetic price series. Linear ramp [start, start+step,
   start+2*step, ...] gives every indicator a closed-form value, which is
   exactly what the pinned-value tests need. *)
let _make_bar ~date ~close =
  {
    Types.Daily_price.date;
    open_price = close;
    high_price = close +. 1.0;
    low_price = close -. 1.0;
    close_price = close;
    volume = 1_000_000;
    adjusted_close = close;
  }

let _date_seq ~start ~n = List.init n ~f:(fun i -> Date.add_days start i)

let _ramp_bars ~n ~start ~step =
  let dates = _date_seq ~start:(Date.of_string "2024-01-02") ~n in
  List.mapi dates ~f:(fun i d ->
      _make_bar ~date:d ~close:(start +. (Float.of_int i *. step)))

let _ohlcv_only_schema =
  Snapshot_schema.create
    ~fields:Snapshot_schema.[ EMA_50; SMA_50; ATR_14; RSI_14 ]

(* SMA_50 of a 50-element ramp [100, 101, ..., 149] is mean = 124.5 at day 49. *)
let test_sma_50_pinned _ =
  let bars = _ramp_bars ~n:50 ~start:100.0 ~step:1.0 in
  let result =
    Pipeline.build_for_symbol ~symbol:"FOO" ~bars ~schema:_ohlcv_only_schema ()
  in
  let last_sma =
    Result.bind result ~f:(fun rows ->
        match List.last rows with
        | None -> Status.error_internal "no rows"
        | Some r -> (
            match Snapshot.get r Snapshot_schema.SMA_50 with
            | None -> Status.error_internal "no SMA_50"
            | Some v -> Ok v))
  in
  assert_that last_sma (is_ok_and_holds (float_equal 124.5))

(* On a flat-price series (all 100.0), EMA_50 at day 49 = 100.0 (warmup is the
   simple mean of the first 50 closes). *)
let test_ema_50_flat_series _ =
  let bars = _ramp_bars ~n:50 ~start:100.0 ~step:0.0 in
  let result =
    Pipeline.build_for_symbol ~symbol:"FOO" ~bars ~schema:_ohlcv_only_schema ()
  in
  let last_ema =
    Result.bind result ~f:(fun rows ->
        match List.last rows with
        | None -> Status.error_internal "no rows"
        | Some r -> (
            match Snapshot.get r Snapshot_schema.EMA_50 with
            | None -> Status.error_internal "no EMA_50"
            | Some v -> Ok v))
  in
  assert_that last_ema (is_ok_and_holds (float_equal 100.0))

(* On a flat-price series, RSI_14 at day 14 has avg_gain = avg_loss = 0,
   triggering the "no losses" branch → RSI = 100.0. *)
let test_rsi_14_flat_series _ =
  let bars = _ramp_bars ~n:15 ~start:50.0 ~step:0.0 in
  let result =
    Pipeline.build_for_symbol ~symbol:"FOO" ~bars ~schema:_ohlcv_only_schema ()
  in
  let last_rsi =
    Result.bind result ~f:(fun rows ->
        match List.last rows with
        | None -> Status.error_internal "no rows"
        | Some r -> (
            match Snapshot.get r Snapshot_schema.RSI_14 with
            | None -> Status.error_internal "no RSI_14"
            | Some v -> Ok v))
  in
  assert_that last_rsi (is_ok_and_holds (float_equal 100.0))

(* On a strictly ascending ramp, RSI saturates near 100 (only gains, no losses).
   The test pins RSI = 100.0 at day 14. *)
let test_rsi_14_ascending_ramp _ =
  let bars = _ramp_bars ~n:15 ~start:100.0 ~step:1.0 in
  let result =
    Pipeline.build_for_symbol ~symbol:"FOO" ~bars ~schema:_ohlcv_only_schema ()
  in
  let last_rsi =
    Result.bind result ~f:(fun rows ->
        match List.last rows with
        | None -> Status.error_internal "no rows"
        | Some r -> (
            match Snapshot.get r Snapshot_schema.RSI_14 with
            | None -> Status.error_internal "no RSI_14"
            | Some v -> Ok v))
  in
  assert_that last_rsi (is_ok_and_holds (float_equal 100.0))

(* On a constant-step ramp where every TR = step + 2 (high-low offset of 2,
   step forward of 1 → TR = max(2, |1-1|, |-1-1|) = 2.0), ATR = 2.0. *)
let test_atr_14_constant_tr _ =
  let bars = _ramp_bars ~n:15 ~start:100.0 ~step:1.0 in
  let result =
    Pipeline.build_for_symbol ~symbol:"FOO" ~bars ~schema:_ohlcv_only_schema ()
  in
  let last_atr =
    Result.bind result ~f:(fun rows ->
        match List.last rows with
        | None -> Status.error_internal "no rows"
        | Some r -> (
            match Snapshot.get r Snapshot_schema.ATR_14 with
            | None -> Status.error_internal "no ATR_14"
            | Some v -> Ok v))
  in
  assert_that last_atr (is_ok_and_holds (float_equal 2.0))

(* Warmup: SMA_50 at days < 49 is NaN. *)
let test_sma_50_warmup_is_nan _ =
  let bars = _ramp_bars ~n:30 ~start:100.0 ~step:1.0 in
  let result =
    Pipeline.build_for_symbol ~symbol:"FOO" ~bars ~schema:_ohlcv_only_schema ()
  in
  let row_count =
    Result.map result ~f:(fun rows ->
        List.count rows ~f:(fun r ->
            match Snapshot.get r Snapshot_schema.SMA_50 with
            | Some v -> Float.is_nan v
            | None -> false))
  in
  assert_that row_count (is_ok_and_holds (equal_to 30))

(* Result list length matches input bar count. *)
let test_row_count_matches_bars _ =
  let bars = _ramp_bars ~n:20 ~start:100.0 ~step:1.0 in
  let result =
    Pipeline.build_for_symbol ~symbol:"FOO" ~bars ~schema:_ohlcv_only_schema ()
  in
  assert_that result (is_ok_and_holds (size_is 20))

(* Empty input → empty result, no error. *)
let test_empty_bars_returns_empty _ =
  assert_that
    (Pipeline.build_for_symbol ~symbol:"FOO" ~bars:[]
       ~schema:Snapshot_schema.default ())
    (is_ok_and_holds is_empty)

(* Empty symbol → invalid argument. *)
let test_empty_symbol_rejected _ =
  assert_that
    (Pipeline.build_for_symbol ~symbol:"" ~bars:[]
       ~schema:Snapshot_schema.default ())
    (is_error_with Status.Invalid_argument)

(* Without benchmark, RS_line and Macro_composite are NaN for every day. *)
let test_rs_macro_nan_without_benchmark _ =
  let bars = _ramp_bars ~n:60 ~start:100.0 ~step:1.0 in
  let result =
    Pipeline.build_for_symbol ~symbol:"FOO" ~bars
      ~schema:Snapshot_schema.default ()
  in
  let all_nan =
    Result.map result ~f:(fun rows ->
        List.for_all rows ~f:(fun r ->
            let rs =
              Option.value (Snapshot.get r Snapshot_schema.RS_line) ~default:0.0
            in
            let macro =
              Option.value
                (Snapshot.get r Snapshot_schema.Macro_composite)
                ~default:0.0
            in
            Float.is_nan rs && Float.is_nan macro))
  in
  assert_that all_nan (is_ok_and_holds (equal_to true))

(* Date stamping: row [i]'s [date] equals input bar [i]'s date. *)
let test_dates_carry_through _ =
  let bars = _ramp_bars ~n:5 ~start:100.0 ~step:1.0 in
  let expected_dates = List.map bars ~f:(fun b -> b.date) in
  let result =
    Pipeline.build_for_symbol ~symbol:"FOO" ~bars ~schema:_ohlcv_only_schema ()
  in
  let actual_dates =
    Result.map result ~f:(fun rows ->
        List.map rows ~f:(fun (r : Snapshot.t) -> r.date))
  in
  assert_that actual_dates (is_ok_and_holds (equal_to expected_dates))

(* Symbol stamping: every produced row carries the requested symbol. *)
let test_symbol_carries_through _ =
  let bars = _ramp_bars ~n:5 ~start:100.0 ~step:1.0 in
  let result =
    Pipeline.build_for_symbol ~symbol:"BAR" ~bars ~schema:_ohlcv_only_schema ()
  in
  let all_bar =
    Result.map result ~f:(fun rows ->
        List.for_all rows ~f:(fun (r : Snapshot.t) ->
            String.equal r.symbol "BAR"))
  in
  assert_that all_bar (is_ok_and_holds (equal_to true))

(* Determinism: two builds of the same input yield byte-identical sexp dumps.
   Sexp comparison handles NaN cells losslessly (NaN renders to "NAN" both
   times) where a raw float [List.equal] would break on [nan <> nan]. *)
let test_determinism_two_builds _ =
  let bars = _ramp_bars ~n:30 ~start:100.0 ~step:0.5 in
  let build () =
    Pipeline.build_for_symbol ~symbol:"FOO" ~bars ~schema:_ohlcv_only_schema ()
  in
  let dump result =
    Result.map result ~f:(fun rows ->
        List.map rows ~f:(fun (r : Snapshot.t) ->
            Sexp.to_string ([%sexp_of: float array] r.values)))
  in
  let a = dump (build ()) in
  let b = dump (build ()) in
  assert_that a (equal_to b)

(* Schema with only the six OHLCV columns. Lets the OHLCV-pinned tests assert
   on values without simultaneously paying for indicator warmup. *)
let _ohlcv_columns_schema =
  Snapshot_schema.create
    ~fields:Snapshot_schema.[ Open; High; Low; Close; Volume; Adjusted_close ]

(* Hand-traceable bar with every OHLCV field at a distinct value, so each
   column read is independently observable. *)
let _make_distinct_bar ~date ~i =
  let f = Float.of_int i in
  {
    Types.Daily_price.date;
    open_price = 100.0 +. f;
    high_price = 110.0 +. f;
    low_price = 90.0 +. f;
    close_price = 105.0 +. f;
    volume = 1_000 + i;
    adjusted_close = 104.0 +. f;
  }

let _distinct_bars ~n =
  let dates = _date_seq ~start:(Date.of_string "2024-01-02") ~n in
  List.mapi dates ~f:(fun i d -> _make_distinct_bar ~date:d ~i)

(* OHLCV scalars at row [i] equal the input bar's fields verbatim — for
   {!Volume}, the input [int] is cast to [float]. Pin all six on a 30-bar
   fixture's last row (i = 29). *)
let test_ohlcv_columns_pinned_at_last_row _ =
  let bars = _distinct_bars ~n:30 in
  let result =
    Pipeline.build_for_symbol ~symbol:"FOO" ~bars ~schema:_ohlcv_columns_schema
      ()
  in
  let last_row =
    Result.bind result ~f:(fun rows ->
        match List.last rows with
        | None -> Status.error_internal "no rows"
        | Some r -> Ok r)
  in
  assert_that last_row
    (is_ok_and_holds
       (all_of
          [
            field
              (fun r -> Snapshot.get r Snapshot_schema.Open)
              (equal_to (Some 129.0));
            field
              (fun r -> Snapshot.get r Snapshot_schema.High)
              (equal_to (Some 139.0));
            field
              (fun r -> Snapshot.get r Snapshot_schema.Low)
              (equal_to (Some 119.0));
            field
              (fun r -> Snapshot.get r Snapshot_schema.Close)
              (equal_to (Some 134.0));
            field
              (fun r -> Snapshot.get r Snapshot_schema.Volume)
              (equal_to (Some 1029.0));
            field
              (fun r -> Snapshot.get r Snapshot_schema.Adjusted_close)
              (equal_to (Some 133.0));
          ]))

(* OHLCV columns must populate from row 0 — no warmup. Spot-check the first
   row of the same fixture. *)
let test_ohlcv_columns_populated_at_first_row _ =
  let bars = _distinct_bars ~n:30 in
  let result =
    Pipeline.build_for_symbol ~symbol:"FOO" ~bars ~schema:_ohlcv_columns_schema
      ()
  in
  let first_row =
    Result.bind result ~f:(fun rows ->
        match List.hd rows with
        | None -> Status.error_internal "no rows"
        | Some r -> Ok r)
  in
  assert_that first_row
    (is_ok_and_holds
       (all_of
          [
            field
              (fun r -> Snapshot.get r Snapshot_schema.Open)
              (equal_to (Some 100.0));
            field
              (fun r -> Snapshot.get r Snapshot_schema.High)
              (equal_to (Some 110.0));
            field
              (fun r -> Snapshot.get r Snapshot_schema.Low)
              (equal_to (Some 90.0));
            field
              (fun r -> Snapshot.get r Snapshot_schema.Close)
              (equal_to (Some 105.0));
            field
              (fun r -> Snapshot.get r Snapshot_schema.Volume)
              (equal_to (Some 1000.0));
            field
              (fun r -> Snapshot.get r Snapshot_schema.Adjusted_close)
              (equal_to (Some 104.0));
          ]))

(* Under the canonical 13-field default schema, OHLCV columns coexist with the
   indicator columns: indicator scalars stay in their original positions and
   OHLCV columns are populated alongside them on the same row. *)
let test_default_schema_carries_indicators_and_ohlcv _ =
  let bars = _distinct_bars ~n:50 in
  let result =
    Pipeline.build_for_symbol ~symbol:"FOO" ~bars
      ~schema:Snapshot_schema.default ()
  in
  let last_row =
    Result.bind result ~f:(fun rows ->
        match List.last rows with
        | None -> Status.error_internal "no rows"
        | Some r -> Ok r)
  in
  assert_that last_row
    (is_ok_and_holds
       (all_of
          [
            (* SMA_50 of adjusted_close = mean of [104.0 .. 153.0] = 128.5. *)
            field
              (fun r -> Snapshot.get r Snapshot_schema.SMA_50)
              (equal_to (Some 128.5));
            (* OHLCV columns mirror the last bar verbatim (i = 49). *)
            field
              (fun r -> Snapshot.get r Snapshot_schema.Open)
              (equal_to (Some 149.0));
            field
              (fun r -> Snapshot.get r Snapshot_schema.Adjusted_close)
              (equal_to (Some 153.0));
            field
              (fun r -> Snapshot.get r Snapshot_schema.Volume)
              (equal_to (Some 1049.0));
          ]))

let suite =
  "Snapshot_pipeline tests"
  >::: [
         "SMA_50 pinned" >:: test_sma_50_pinned;
         "EMA_50 flat series" >:: test_ema_50_flat_series;
         "RSI_14 flat series" >:: test_rsi_14_flat_series;
         "RSI_14 ascending ramp" >:: test_rsi_14_ascending_ramp;
         "ATR_14 constant TR" >:: test_atr_14_constant_tr;
         "SMA_50 warmup is NaN" >:: test_sma_50_warmup_is_nan;
         "row count matches bars" >:: test_row_count_matches_bars;
         "empty bars returns empty" >:: test_empty_bars_returns_empty;
         "empty symbol rejected" >:: test_empty_symbol_rejected;
         "RS / Macro NaN without benchmark"
         >:: test_rs_macro_nan_without_benchmark;
         "dates carry through" >:: test_dates_carry_through;
         "symbol carries through" >:: test_symbol_carries_through;
         "determinism two builds" >:: test_determinism_two_builds;
         "OHLCV columns pinned at last row"
         >:: test_ohlcv_columns_pinned_at_last_row;
         "OHLCV columns populated at first row"
         >:: test_ohlcv_columns_populated_at_first_row;
         "default schema carries indicators and OHLCV"
         >:: test_default_schema_carries_indicators_and_ohlcv;
       ]

let () = run_test_tt_main suite
