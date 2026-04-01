open OUnit2
open Core
open Matchers
open Relative_strength
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
(* Insufficient data                                                    *)
(* ------------------------------------------------------------------ *)

let test_insufficient_data_returns_none _ =
  let stock = const_bars ~n:40 100.0 in
  let bench = const_bars ~n:40 100.0 in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    is_none

let test_exact_minimum_returns_one_point _ =
  (* Exactly rs_ma_period (52) bars → one history point *)
  let stock = const_bars ~n:52 100.0 in
  let bench = const_bars ~n:52 100.0 in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    (is_some_and (fun history -> assert_that history (size_is 1)))

(* ------------------------------------------------------------------ *)
(* RS ratio computation                                                 *)
(* ------------------------------------------------------------------ *)

let test_equal_prices_gives_rs_value_1 _ =
  (* Stock and benchmark move identically → rs_value = 1.0 always *)
  let prices = List.init 60 ~f:(fun i -> 100.0 +. Float.of_int i) in
  let bars = weekly_bars prices in
  assert_that
    (analyze ~config:cfg ~stock_bars:bars ~benchmark_bars:bars)
    (is_some_and (fun history ->
         assert_that (List.last_exn history).rs_value
           (float_equal ~epsilon:1e-6 1.0)))

let test_outperforming_stock_rs_value_above_1 _ =
  let n = 60 in
  let stock =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 2.0)) |> weekly_bars
  in
  let bench =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 1.0)) |> weekly_bars
  in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    (is_some_and
       (field
          (fun history -> (List.last_exn history).rs_value)
          (gt (module Float_ord) 1.0)))

let test_underperforming_stock_rs_value_below_1 _ =
  let n = 60 in
  let bench =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 2.0)) |> weekly_bars
  in
  let stock =
    List.init n ~f:(fun i -> 100.0 +. (Float.of_int i *. 1.0)) |> weekly_bars
  in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    (is_some_and
       (field
          (fun history -> (List.last_exn history).rs_value)
          (lt (module Float_ord) 1.0)))

(* ------------------------------------------------------------------ *)
(* Normalized RS (Mansfield zero line)                                  *)
(* ------------------------------------------------------------------ *)

let test_constant_rs_normalized_near_1 _ =
  (* RS is always 1.0, so rs_value / MA(rs_value) = 1.0 *)
  let prices = List.init 60 ~f:(fun i -> 100.0 +. (Float.of_int i *. 0.5)) in
  let bars = weekly_bars prices in
  assert_that
    (analyze ~config:cfg ~stock_bars:bars ~benchmark_bars:bars)
    (is_some_and (fun history ->
         assert_that (List.last_exn history).rs_normalized
           (float_equal ~epsilon:0.01 1.0)))

let test_history_length _ =
  (* n bars with period p → n - p + 1 history points *)
  let n = 60 in
  let bars = const_bars ~n 100.0 in
  assert_that
    (analyze ~config:cfg ~stock_bars:bars ~benchmark_bars:bars)
    (is_some_and (fun history ->
         assert_that history (size_is (n - cfg.rs_ma_period + 1))))

(* ------------------------------------------------------------------ *)
(* Date alignment                                                       *)
(* ------------------------------------------------------------------ *)

let test_mismatched_dates_uses_intersection _ =
  let n = 60 in
  let bench = const_bars ~n 100.0 in
  let extra_start = Date.of_string "2018-01-01" in
  let extra =
    List.init 10 ~f:(fun i ->
        make_bar
          (Date.to_string (Date.add_days extra_start (i * days_per_week)))
          90.0)
  in
  let stock = extra @ const_bars ~n 100.0 in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    (is_some_and (fun _ -> ()))

let test_history_sorted_chronologically _ =
  let n = 60 in
  let stock =
    List.init n ~f:(fun i -> 100.0 +. Float.of_int i) |> weekly_bars
  in
  let bench = const_bars ~n 100.0 in
  assert_that
    (analyze ~config:cfg ~stock_bars:stock ~benchmark_bars:bench)
    (is_some_and (fun history ->
         let dates = List.map history ~f:(fun r -> r.date) in
         let sorted = List.sort dates ~compare:Date.compare in
         assert_that dates (equal_to (sorted : Date.t list))))

let suite =
  "relative_strength_tests"
  >::: [
         "insufficient_data_returns_none"
         >:: test_insufficient_data_returns_none;
         "exact_minimum_returns_one_point"
         >:: test_exact_minimum_returns_one_point;
         "equal_prices_gives_rs_value_1" >:: test_equal_prices_gives_rs_value_1;
         "outperforming_stock_rs_value_above_1"
         >:: test_outperforming_stock_rs_value_above_1;
         "underperforming_stock_rs_value_below_1"
         >:: test_underperforming_stock_rs_value_below_1;
         "constant_rs_normalized_near_1" >:: test_constant_rs_normalized_near_1;
         "history_length" >:: test_history_length;
         "mismatched_dates_uses_intersection"
         >:: test_mismatched_dates_uses_intersection;
         "history_sorted_chronologically"
         >:: test_history_sorted_chronologically;
       ]

let () = run_test_tt_main suite
