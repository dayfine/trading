open OUnit2
open Core
open Trading_engine.Types
open Trading_engine.Price_path
open Trading_base.Types
open Matchers

(** {1 Test Helpers} *)

let make_bar symbol ~open_price ~high_price ~low_price ~close_price =
  { symbol; open_price; high_price; low_price; close_price }

(** Check if all path points stay within OHLC bounds *)
let all_in_bounds (path : intraday_path) (bar : price_bar) : bool =
  List.for_all path ~f:(fun (point : path_point) ->
      Float.(point.price >= bar.low_price && point.price <= bar.high_price))

(** Check if path visits all OHLC prices (within small tolerance) *)
let visits_all_ohlc (path : intraday_path) (bar : price_bar) ~epsilon : bool =
  let prices = List.map path ~f:(fun (p : path_point) -> p.price) in
  let visits price =
    List.exists prices ~f:(fun p -> Float.(abs (p -. price) < epsilon))
  in
  visits bar.open_price && visits bar.high_price && visits bar.low_price
  && visits bar.close_price

(** Check that path times are monotonically increasing *)
let is_monotonic (path : intraday_path) : bool =
  let rec check = function
    | [] | [ _ ] -> true
    | (p1 : path_point) :: (p2 : path_point) :: rest ->
        Float.(p1.fraction_of_day <= p2.fraction_of_day) && check (p2 :: rest)
  in
  check path

(** {1 can_fill Tests} *)

let test_can_fill_market_always _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  assert_bool "Buy Market should always fill" (can_fill bar Buy Market);
  assert_bool "Sell Market should always fill" (can_fill bar Sell Market)

let test_can_fill_buy_limit_when_low_reaches _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  (* Low reaches 95, so buy limit at 97 can fill *)
  assert_bool "Buy limit at 97 should fill" (can_fill bar Buy (Limit 97.0));
  (* But buy limit at 90 cannot *)
  assert_bool "Buy limit at 90 should not fill"
    (not (can_fill bar Buy (Limit 90.0)))

let test_can_fill_sell_limit_when_high_reaches _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  (* High reaches 110, so sell limit at 108 can fill *)
  assert_bool "Sell limit at 108 should fill" (can_fill bar Sell (Limit 108.0));
  (* But sell limit at 115 cannot *)
  assert_bool "Sell limit at 115 should not fill"
    (not (can_fill bar Sell (Limit 115.0)))

let test_can_fill_buy_stop_when_high_reaches _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  (* High reaches 110, so buy stop at 108 triggers *)
  assert_bool "Buy stop at 108 should trigger" (can_fill bar Buy (Stop 108.0));
  (* But buy stop at 115 does not *)
  assert_bool "Buy stop at 115 should not trigger"
    (not (can_fill bar Buy (Stop 115.0)))

let test_can_fill_sell_stop_when_low_reaches _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  (* Low reaches 95, so sell stop at 97 triggers *)
  assert_bool "Sell stop at 97 should trigger" (can_fill bar Sell (Stop 97.0));
  (* But sell stop at 90 does not *)
  assert_bool "Sell stop at 90 should not trigger"
    (not (can_fill bar Sell (Stop 90.0)))

let test_can_fill_stop_limit_requires_both _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  (* Buy stop-limit: stop at 102, limit at 108 - both reachable *)
  assert_bool "Stop-limit with both reachable should fill"
    (can_fill bar Buy (StopLimit (102.0, 108.0)));
  (* Buy stop-limit: stop at 115, limit at 120 - stop doesn't trigger *)
  assert_bool "Stop-limit with no trigger should not fill"
    (not (can_fill bar Buy (StopLimit (115.0, 120.0))));
  (* Sell stop-limit: stop at 97, limit at 93 - both reachable *)
  assert_bool "Sell stop-limit with both reachable should fill"
    (can_fill bar Sell (StopLimit (97.0, 93.0)));
  (* Sell stop-limit: stop at 90, limit at 85 - stop doesn't trigger *)
  assert_bool "Sell stop-limit with no trigger should not fill"
    (not (can_fill bar Sell (StopLimit (90.0, 85.0))))

(** {1 Path Generation Tests} *)

let test_generate_path_stays_in_bounds _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  (* Run multiple times due to randomness *)
  for _ = 1 to 10 do
    let path = generate_path bar in
    assert_bool "Path should stay within OHLC bounds" (all_in_bounds path bar)
  done

let test_generate_path_visits_all_ohlc _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  (* Run multiple times due to randomness *)
  for _ = 1 to 10 do
    let path = generate_path bar in
    (* Allow small epsilon for Brownian noise near waypoints *)
    assert_bool "Path should visit all OHLC points"
      (visits_all_ohlc path bar ~epsilon:0.5)
  done

let test_generate_path_is_monotonic _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  for _ = 1 to 10 do
    let path = generate_path bar in
    assert_bool "Path times should be monotonically increasing"
      (is_monotonic path)
  done

let test_generate_path_starts_at_open_ends_at_close _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  for _ = 1 to 10 do
    let path = generate_path bar in
    match (List.hd path, List.last path) with
    | Some first, Some last ->
        assert_that first.fraction_of_day (float_equal 0.0);
        assert_that last.fraction_of_day (float_equal 1.0);
        (* Open and close should be exact *)
        assert_that first.price (float_equal bar.open_price);
        assert_that last.price (float_equal bar.close_price)
    | _ -> assert_failure "Path should have at least 2 points"
  done

let test_generate_path_has_many_points _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let path = generate_path bar in
  (* With 100 points per segment and 3 segments, should have ~300+ points *)
  let path_length = List.length path in
  assert_bool
    (Printf.sprintf "Path should have many points (got %d)" path_length)
    (path_length > 200)

let test_generate_path_narrow_range _ =
  (* Test with very narrow range (almost doji) *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:100.5 ~low_price:99.5
      ~close_price:100.0
  in
  for _ = 1 to 10 do
    let path = generate_path bar in
    assert_bool "Narrow range path should stay in bounds"
      (all_in_bounds path bar);
    assert_bool "Narrow range path should be monotonic" (is_monotonic path)
  done

let test_generate_path_wide_range _ =
  (* Test with wide range (high volatility) *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:130.0 ~low_price:70.0
      ~close_price:110.0
  in
  for _ = 1 to 10 do
    let path = generate_path bar in
    assert_bool "Wide range path should stay in bounds" (all_in_bounds path bar);
    assert_bool "Wide range path should be monotonic" (is_monotonic path);
    assert_bool "Wide range path should visit all OHLC"
      (visits_all_ohlc path bar ~epsilon:2.0)
  done

let test_generate_path_upward_bar _ =
  (* Upward bar: close > open *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:98.0
      ~close_price:108.0
  in
  for _ = 1 to 10 do
    let path = generate_path bar in
    assert_bool "Upward bar path should stay in bounds"
      (all_in_bounds path bar);
    assert_bool "Upward bar path should visit all OHLC"
      (visits_all_ohlc path bar ~epsilon:0.5)
  done

let test_generate_path_downward_bar _ =
  (* Downward bar: close < open *)
  let bar =
    make_bar "AAPL" ~open_price:108.0 ~high_price:110.0 ~low_price:98.0
      ~close_price:100.0
  in
  for _ = 1 to 10 do
    let path = generate_path bar in
    assert_bool "Downward bar path should stay in bounds"
      (all_in_bounds path bar);
    assert_bool "Downward bar path should visit all OHLC"
      (visits_all_ohlc path bar ~epsilon:0.5)
  done

(** {1 Configuration Tests} *)

let test_custom_config_affects_granularity _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let config = { profile = Uniform; points_per_segment = 10 } in
  let path = generate_path ~config bar in
  (* With 10 points per segment and 3 segments, should have ~30+ points *)
  let path_length = List.length path in
  assert_bool
    (Printf.sprintf "Path should have > 20 points (got %d)" path_length)
    (path_length > 20);
  assert_bool
    (Printf.sprintf "Path should have < 50 points (got %d)" path_length)
    (path_length < 50)

(** {1 Test Suite} *)

let suite =
  "Price Path Tests"
  >::: [
         (* can_fill tests *)
         "can_fill: market always" >:: test_can_fill_market_always;
         "can_fill: buy limit when low reaches"
         >:: test_can_fill_buy_limit_when_low_reaches;
         "can_fill: sell limit when high reaches"
         >:: test_can_fill_sell_limit_when_high_reaches;
         "can_fill: buy stop when high reaches"
         >:: test_can_fill_buy_stop_when_high_reaches;
         "can_fill: sell stop when low reaches"
         >:: test_can_fill_sell_stop_when_low_reaches;
         "can_fill: stop-limit requires both"
         >:: test_can_fill_stop_limit_requires_both;
         (* Path generation tests *)
         "generate_path: stays in bounds" >:: test_generate_path_stays_in_bounds;
         "generate_path: visits all OHLC"
         >:: test_generate_path_visits_all_ohlc;
         "generate_path: times monotonic" >:: test_generate_path_is_monotonic;
         "generate_path: starts at open, ends at close"
         >:: test_generate_path_starts_at_open_ends_at_close;
         "generate_path: has many points" >:: test_generate_path_has_many_points;
         "generate_path: narrow range" >:: test_generate_path_narrow_range;
         "generate_path: wide range" >:: test_generate_path_wide_range;
         "generate_path: upward bar" >:: test_generate_path_upward_bar;
         "generate_path: downward bar" >:: test_generate_path_downward_bar;
         (* Configuration tests *)
         "custom config affects granularity"
         >:: test_custom_config_affects_granularity;
       ]

let () = run_test_tt_main suite
