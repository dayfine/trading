open OUnit2
open Core
open Matchers
open Rs
open Weinstein_types
open Types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let cfg = default_config
let days_per_week = 7

let make_bar date adjusted_close =
  {
    Daily_price.date = Date.of_string date;
    open_price = adjusted_close;
    high_price = adjusted_close;
    low_price = adjusted_close;
    close_price = adjusted_close;
    volume = 1000;
    adjusted_close;
  }

(** Build aligned weekly bars starting 2020-01-06 at the given prices. *)
let weekly_bars prices =
  let base = Date.of_string "2020-01-06" in
  List.mapi prices ~f:(fun i p ->
      make_bar (Date.to_string (Date.add_days base (i * days_per_week))) p)

let const_bars ?(n = 60) price = List.init n ~f:(fun _ -> price) |> weekly_bars

(* ------------------------------------------------------------------ *)
(* Delegation to Relative_strength                                      *)
(* ------------------------------------------------------------------ *)

let test_insufficient_data_returns_none _ =
  let stock = const_bars ~n:40 100.0 in
  let bench = const_bars ~n:40 100.0 in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    is_none

let test_exact_minimum_data _ =
  let stock = const_bars ~n:52 100.0 in
  let bench = const_bars ~n:52 100.0 in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    (is_some_and (field (fun r -> r.history) (size_is 1)))

let test_current_fields_populated _ =
  (* Verify result fields mirror the last point of the underlying RS history. *)
  let n = 60 in
  let stock =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 1.5)) |> weekly_bars
  in
  let bench =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 1.0)) |> weekly_bars
  in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    (is_some_and (fun result ->
         let last = List.last_exn result.history in
         assert_that result.current_rs (float_equal last.rs_value);
         assert_that result.current_normalized (float_equal last.rs_normalized)))

(* ------------------------------------------------------------------ *)
(* Trend classification                                                 *)
(* ------------------------------------------------------------------ *)

let test_positive_rising_trend _ =
  let n = 60 in
  let stock =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 2.0)) |> weekly_bars
  in
  let bench =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 1.0)) |> weekly_bars
  in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    (is_some_and (fun result ->
         match result.trend with
         | Positive_rising | Positive_flat | Bullish_crossover -> ()
         | other ->
             assert_failure
               (Printf.sprintf "Expected positive trend, got %s"
                  (show_rs_trend other))))

let test_negative_declining_trend _ =
  let n = 60 in
  let stock =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 0.2)) |> weekly_bars
  in
  let bench =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 2.0)) |> weekly_bars
  in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    (is_some_and (fun result ->
         match result.trend with
         | Negative_declining | Negative_improving | Bearish_crossover -> ()
         | other ->
             assert_failure
               (Printf.sprintf "Expected negative trend, got %s"
                  (show_rs_trend other))))

let test_bullish_crossover _ =
  (* Underperforming for first half, outperforming for second half → crossover *)
  let n = 80 in
  let stock =
    List.init n ~f:(fun i ->
        if i < 60 then 50.0 else 100.0 +. (Float.of_int (i - 60) *. 5.0))
    |> weekly_bars
  in
  let bench = const_bars ~n 100.0 in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    (is_some_and (fun result ->
         match result.trend with
         | Bullish_crossover | Positive_rising | Positive_flat -> ()
         | other ->
             assert_failure
               (Printf.sprintf "Expected bullish crossover, got %s"
                  (show_rs_trend other))))

(* ------------------------------------------------------------------ *)
(* flat_threshold config                                                *)
(* ------------------------------------------------------------------ *)

let test_flat_threshold_configurable _ =
  (* With a very tight threshold (1.0), even a tiny RS drop is NOT flat. *)
  let strict_cfg = { cfg with flat_threshold = 1.0 } in
  let n = 60 in
  let stock =
    List.init n ~f:(fun i ->
        if i < 55 then 100.0 +. (Float.of_int i *. 1.1)
        else 100.0 +. (Float.of_int i *. 0.9))
    |> weekly_bars
  in
  let bench =
    List.init n ~f:(fun i -> 100.0 +. Float.of_int i) |> weekly_bars
  in
  assert_that
    (analyze ~config:strict_cfg ~stock_bars:stock ~benchmark_bars:bench)
    (not_ is_none)

(* ------------------------------------------------------------------ *)
(* Purity                                                               *)
(* ------------------------------------------------------------------ *)

let test_pure_same_inputs_same_output _ =
  let n = 60 in
  let stock =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 1.5)) |> weekly_bars
  in
  let bench =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 1.0)) |> weekly_bars
  in
  let r1 =
    Option.value_exn
      (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
  in
  let r2 =
    Option.value_exn
      (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
  in
  assert_that r1.current_rs (float_equal r2.current_rs);
  assert_that r1.current_normalized (float_equal r2.current_normalized);
  assert_that r1.trend (equal_to (r2.trend : rs_trend))

(** Stock falls 20% while benchmark rises 10% over 60 weeks. Unambiguous
    underperformance — RS must be [Negative_declining]. *)
let test_stock_falling_benchmark_rising _ =
  let n = 60 in
  let benchmark =
    List.init n ~f:(fun i ->
        100.0 *. (1.0 +. (Float.of_int i *. 0.10 /. Float.of_int (n - 1))))
    |> weekly_bars
  in
  let stock =
    List.init n ~f:(fun i ->
        100.0 *. (1.0 -. (Float.of_int i *. 0.20 /. Float.of_int (n - 1))))
    |> weekly_bars
  in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:benchmark)
    (is_some_and (field (fun r -> r.trend) (equal_to Negative_declining)))

(* ------------------------------------------------------------------ *)
(* Parity: analyze (bar-list) vs analyze_with_callbacks                *)
(*                                                                      *)
(* Builds [get_stock_close] / [get_benchmark_close] / [get_date]       *)
(* callbacks externally over the same date-aligned series the wrapper  *)
(* would compute internally, then asserts that the two entry points    *)
(* produce bit-identical [result] records. Each scenario hits a        *)
(* different RS regime (positive, negative, near-zero, crossover) plus *)
(* the insufficient-data early-return.                                 *)
(* ------------------------------------------------------------------ *)

(** Build a [get_*] closure over a precomputed array, indexed in chronological
    order (oldest at index 0, newest at the end). [week_offset:0] returns the
    newest entry; offsets past the array's depth return [None]. Mirrors the
    indexing rules the wrapper uses internally. *)
let make_indexed (arr : 'a array) ~week_offset : 'a option =
  let n = Array.length arr in
  let idx = n - 1 - week_offset in
  if idx < 0 || idx >= n then None else Some arr.(idx)

(** Date.t Map of benchmark adjusted_close values, keyed on bar date. *)
let bench_map_of_bars (benchmark_bars : Daily_price.t list) =
  List.fold benchmark_bars ~init:Date.Map.empty ~f:(fun m b ->
      Map.set m ~key:b.Daily_price.date ~data:b.Daily_price.adjusted_close)

(** Build aligned (date, stock_close, bench_close) triples from the same join
    the wrapper uses, oldest first. *)
let aligned_triples ~stock_bars ~benchmark_bars =
  let bench_map = bench_map_of_bars benchmark_bars in
  List.filter_map stock_bars ~f:(fun bar ->
      Map.find bench_map bar.Daily_price.date
      |> Option.map ~f:(fun bench_close ->
          (bar.Daily_price.date, bar.Daily_price.adjusted_close, bench_close)))

(** Bit-identity matcher for [Rs.result]. Float fields use [equal_to] with
    [Poly.equal] (structural equality) so any drift — even a single ULP — fails
    the test. The [history] list is compared element-wise on every field. *)
let raw_rs_is_bit_identical (expected : raw_rs) : raw_rs matcher =
  all_of
    [
      field
        (fun (r : raw_rs) -> r.Relative_strength.date)
        (equal_to expected.Relative_strength.date);
      field
        (fun (r : raw_rs) -> r.Relative_strength.rs_value)
        (equal_to (expected.Relative_strength.rs_value : float));
      field
        (fun (r : raw_rs) -> r.Relative_strength.rs_normalized)
        (equal_to (expected.Relative_strength.rs_normalized : float));
    ]

let result_is_bit_identical (expected : Rs.result) : Rs.result matcher =
  all_of
    [
      field
        (fun (r : Rs.result) -> r.current_rs)
        (equal_to (expected.current_rs : float));
      field
        (fun (r : Rs.result) -> r.current_normalized)
        (equal_to (expected.current_normalized : float));
      field (fun (r : Rs.result) -> r.trend) (equal_to expected.trend);
      field
        (fun (r : Rs.result) -> r.history)
        (elements_are (List.map expected.history ~f:raw_rs_is_bit_identical));
    ]

(** Run both [Rs.analyze] and [Rs.analyze_with_callbacks] over the same input
    and assert the results match bit-for-bit. *)
let assert_parity ?(config = cfg) ~stock_bars ~benchmark_bars () =
  let aligned = aligned_triples ~stock_bars ~benchmark_bars |> Array.of_list in
  let stock_arr = Array.map aligned ~f:(fun (_, sc, _) -> sc) in
  let bench_arr = Array.map aligned ~f:(fun (_, _, bc) -> bc) in
  let date_arr = Array.map aligned ~f:(fun (d, _, _) -> d) in
  let from_bars = analyze ~config ~stock_bars ~benchmark_bars in
  let from_callbacks =
    analyze_with_callbacks ~config ~get_stock_close:(make_indexed stock_arr)
      ~get_benchmark_close:(make_indexed bench_arr)
      ~get_date:(make_indexed date_arr)
  in
  match (from_bars, from_callbacks) with
  | None, None -> ()
  | Some bars_result, Some cb_result ->
      assert_that cb_result (result_is_bit_identical bars_result)
  | None, Some _ ->
      assert_failure "bar-list returned None but callbacks returned Some"
  | Some _, None ->
      assert_failure "bar-list returned Some but callbacks returned None"

(** Positive RS: stock outperforms benchmark consistently across 100 weeks. *)
let test_parity_positive_rs _ =
  let n = 100 in
  let stock =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 2.0)) |> weekly_bars
  in
  let bench =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 1.0)) |> weekly_bars
  in
  assert_parity ~stock_bars:stock ~benchmark_bars:bench ()

(** Negative RS: stock underperforms benchmark across 100 weeks. *)
let test_parity_negative_rs _ =
  let n = 100 in
  let stock =
    List.init n ~f:(fun i ->
        100.0 *. (1.0 -. (Float.of_int i *. 0.30 /. Float.of_int (n - 1))))
    |> weekly_bars
  in
  let bench =
    List.init n ~f:(fun i ->
        100.0 *. (1.0 +. (Float.of_int i *. 0.20 /. Float.of_int (n - 1))))
    |> weekly_bars
  in
  assert_parity ~stock_bars:stock ~benchmark_bars:bench ()

(** Near-zero RS movement: stock and benchmark move identically. *)
let test_parity_near_zero_rs _ =
  let n = 80 in
  let stock = const_bars ~n 100.0 in
  let bench = const_bars ~n 100.0 in
  assert_parity ~stock_bars:stock ~benchmark_bars:bench ()

(** Bullish crossover: stock underperforms then outperforms. *)
let test_parity_crossover _ =
  let n = 80 in
  let stock =
    List.init n ~f:(fun i ->
        if i < 60 then 50.0 else 100.0 +. (Float.of_int (i - 60) *. 5.0))
    |> weekly_bars
  in
  let bench = const_bars ~n 100.0 in
  assert_parity ~stock_bars:stock ~benchmark_bars:bench ()

(** Insufficient data: fewer aligned bars than [rs_ma_period]. Both paths take
    the [None] early-return. *)
let test_parity_insufficient_data _ =
  let stock = const_bars ~n:30 100.0 in
  let bench = const_bars ~n:30 100.0 in
  assert_parity ~stock_bars:stock ~benchmark_bars:bench ()

(** Exact-minimum data: aligned bars equal [rs_ma_period]. Edge of the
    [n < rs_ma_period] guard. *)
let test_parity_exact_minimum_data _ =
  let n = 52 in
  let stock =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 0.5)) |> weekly_bars
  in
  let bench =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 0.4)) |> weekly_bars
  in
  assert_parity ~stock_bars:stock ~benchmark_bars:bench ()

let suite =
  "rs_tests"
  >::: [
         "insufficient_data_returns_none"
         >:: test_insufficient_data_returns_none;
         "exact_minimum_data" >:: test_exact_minimum_data;
         "current_fields_populated" >:: test_current_fields_populated;
         "positive_rising_trend" >:: test_positive_rising_trend;
         "negative_declining_trend" >:: test_negative_declining_trend;
         "stock_falling_benchmark_rising"
         >:: test_stock_falling_benchmark_rising;
         "bullish_crossover" >:: test_bullish_crossover;
         "flat_threshold_configurable" >:: test_flat_threshold_configurable;
         "pure_same_inputs_same_output" >:: test_pure_same_inputs_same_output;
         "parity_positive_rs" >:: test_parity_positive_rs;
         "parity_negative_rs" >:: test_parity_negative_rs;
         "parity_near_zero_rs" >:: test_parity_near_zero_rs;
         "parity_crossover" >:: test_parity_crossover;
         "parity_insufficient_data" >:: test_parity_insufficient_data;
         "parity_exact_minimum_data" >:: test_parity_exact_minimum_data;
       ]

let () = run_test_tt_main suite
