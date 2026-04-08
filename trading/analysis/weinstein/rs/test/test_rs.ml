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

(** Stock falls 20% while benchmark rises 10% over 60 weeks.
    Unambiguous underperformance — RS must be [Negative_declining]. *)
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

let suite =
  "rs_tests"
  >::: [
         "insufficient_data_returns_none"
         >:: test_insufficient_data_returns_none;
         "exact_minimum_data" >:: test_exact_minimum_data;
         "current_fields_populated" >:: test_current_fields_populated;
         "positive_rising_trend" >:: test_positive_rising_trend;
         "negative_declining_trend" >:: test_negative_declining_trend;
         "stock_falling_benchmark_rising" >:: test_stock_falling_benchmark_rising;
         "bullish_crossover" >:: test_bullish_crossover;
         "flat_threshold_configurable" >:: test_flat_threshold_configurable;
         "pure_same_inputs_same_output" >:: test_pure_same_inputs_same_output;
       ]

let () = run_test_tt_main suite
