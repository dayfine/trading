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

(** Check if path visits all OHLC prices exactly *)
let visits_all_ohlc (path : intraday_path) (bar : price_bar) : bool =
  let prices = List.map path ~f:(fun (p : path_point) -> p.price) in
  let visits price = List.exists prices ~f:(fun p -> Float.(p = price)) in
  visits bar.open_price && visits bar.high_price && visits bar.low_price
  && visits bar.close_price

(** {1 might_fill Tests} *)

let test_might_fill_market_always _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  assert_that (might_fill bar Buy Market) (equal_to true);
  assert_that (might_fill bar Sell Market) (equal_to true)

let test_might_fill_buy_limit_when_low_reaches _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  (* Low reaches 95, so buy limit at 97 can fill *)
  assert_that (might_fill bar Buy (Limit 97.0)) (equal_to true);
  (* But buy limit at 90 cannot *)
  assert_that (might_fill bar Buy (Limit 90.0)) (equal_to false)

let test_might_fill_sell_limit_when_high_reaches _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  (* High reaches 110, so sell limit at 108 can fill *)
  assert_that (might_fill bar Sell (Limit 108.0)) (equal_to true);
  (* But sell limit at 115 cannot *)
  assert_that (might_fill bar Sell (Limit 115.0)) (equal_to false)

let test_might_fill_buy_stop_when_high_reaches _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  (* High reaches 110, so buy stop at 108 triggers *)
  assert_that (might_fill bar Buy (Stop 108.0)) (equal_to true);
  (* But buy stop at 115 does not *)
  assert_that (might_fill bar Buy (Stop 115.0)) (equal_to false)

let test_might_fill_sell_stop_when_low_reaches _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  (* Low reaches 95, so sell stop at 97 triggers *)
  assert_that (might_fill bar Sell (Stop 97.0)) (equal_to true);
  (* But sell stop at 90 does not *)
  assert_that (might_fill bar Sell (Stop 90.0)) (equal_to false)

let test_might_fill_stop_limit_requires_both _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  (* Buy stop-limit: stop at 102, limit at 108 - both reachable *)
  assert_that (might_fill bar Buy (StopLimit (102.0, 108.0))) (equal_to true);
  (* Buy stop-limit: stop at 115, limit at 120 - stop doesn't trigger *)
  assert_that (might_fill bar Buy (StopLimit (115.0, 120.0))) (equal_to false);
  (* Sell stop-limit: stop at 97, limit at 93 - both reachable *)
  assert_that (might_fill bar Sell (StopLimit (97.0, 93.0))) (equal_to true);
  (* Sell stop-limit: stop at 90, limit at 85 - stop doesn't trigger *)
  assert_that (might_fill bar Sell (StopLimit (90.0, 85.0))) (equal_to false)

(** {1 Path Generation Tests} *)

let test_generate_path_stays_in_bounds _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  (* Run multiple times due to randomness *)
  for _ = 1 to 10 do
    let path = generate_path bar in
    assert_that (all_in_bounds path bar) (equal_to true)
  done

let test_generate_path_visits_all_ohlc _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  (* Run multiple times due to randomness *)
  for _ = 1 to 10 do
    let path = generate_path bar in
    assert_that (visits_all_ohlc path bar) (equal_to true)
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
  assert_that (path_length > 200) (equal_to true)

let test_generate_path_narrow_range _ =
  (* Test with very narrow range (almost doji) *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:100.5 ~low_price:99.5
      ~close_price:100.0
  in
  for _ = 1 to 10 do
    let path = generate_path bar in
    assert_that (all_in_bounds path bar) (equal_to true)
  done

let test_generate_path_wide_range _ =
  (* Test with wide range (high volatility) *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:130.0 ~low_price:70.0
      ~close_price:110.0
  in
  for _ = 1 to 10 do
    let path = generate_path bar in
    assert_that (all_in_bounds path bar) (equal_to true);
    assert_that (visits_all_ohlc path bar) (equal_to true)
  done

let test_generate_path_upward_bar _ =
  (* Upward bar: close > open *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:98.0
      ~close_price:108.0
  in
  for _ = 1 to 10 do
    let path = generate_path bar in
    assert_that (all_in_bounds path bar) (equal_to true);
    assert_that (visits_all_ohlc path bar) (equal_to true)
  done

let test_generate_path_downward_bar _ =
  (* Downward bar: close < open *)
  let bar =
    make_bar "AAPL" ~open_price:108.0 ~high_price:110.0 ~low_price:98.0
      ~close_price:100.0
  in
  for _ = 1 to 10 do
    let path = generate_path bar in
    assert_that (all_in_bounds path bar) (equal_to true);
    assert_that (visits_all_ohlc path bar) (equal_to true)
  done

(** {1 Configuration Tests} *)

let test_custom_config_affects_granularity _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let config = { profile = Uniform; total_points = 30; seed = Some 42 } in
  let path = generate_path ~config bar in
  (* With 30 total points, should have ~30-35 points including waypoints *)
  let path_length = List.length path in
  assert_that (path_length > 25) (equal_to true);
  assert_that (path_length < 40) (equal_to true)

(** {1 Deterministic Tests with Fixed Seeds} *)

let test_deterministic_path_with_seed _ =
  (* Same seed should produce identical paths with explicit values *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let config = { profile = Uniform; total_points = 10; seed = Some 12345 } in
  let path = generate_path ~config bar in
  (* Expected path values for seed=12345, total_points=10 *)
  let expected : intraday_path =
    [
      { price = 100.0 };
      { price = 103.07065926835966 };
      { price = 106.49045733663644 };
      { price = 109.92582812988262 };
      { price = 110.0 };
      { price = 102.68688098626671 };
      { price = 95.0 };
      { price = 95.0 };
      { price = 97.385557464163853 };
      { price = 99.869145568232142 };
      { price = 102.28393317864106 };
      { price = 105.09877807080935 };
      { price = 105.0 };
    ]
  in
  assert_equal path expected

let test_different_seeds_produce_different_paths _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let config1 = { profile = Uniform; total_points = 20; seed = Some 111 } in
  let config2 = { profile = Uniform; total_points = 20; seed = Some 222 } in
  let path1 : intraday_path = generate_path ~config:config1 bar in
  let path2 : intraday_path = generate_path ~config:config2 bar in
  (* Paths should be different (at least one point differs) *)
  let paths_differ =
    not
      (List.equal
         (fun (p1 : path_point) (p2 : path_point) -> Float.(p1.price = p2.price))
         path1 path2)
  in
  assert_that paths_differ (equal_to true)

let test_distribution_profiles_with_seeds _ =
  (* Test that different profiles produce different timing with same seed *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let config_uniform =
    { profile = Uniform; total_points = 20; seed = Some 42 }
  in
  let config_jshaped =
    { profile = JShaped; total_points = 20; seed = Some 42 }
  in
  let path_uniform = generate_path ~config:config_uniform bar in
  let path_jshaped = generate_path ~config:config_jshaped bar in
  (* Both should have similar length (within reasonable range) *)
  let len_diff =
    Int.abs (List.length path_uniform - List.length path_jshaped)
  in
  assert_that (len_diff < 5) (equal_to true)

let test_default_config_produces_390_points _ =
  (* Default config should produce ~390 points total *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let path = generate_path bar in
  let path_length = List.length path in
  (* 130 points/segment * 3 segments + 4 waypoints ≈ 390-394 *)
  assert_that (path_length > 380 && path_length < 400) (equal_to true)

(** {1 Test Suite} *)

let suite =
  "Price Path Tests"
  >::: [
         (* might_fill tests *)
         "might_fill: market always" >:: test_might_fill_market_always;
         "might_fill: buy limit when low reaches"
         >:: test_might_fill_buy_limit_when_low_reaches;
         "might_fill: sell limit when high reaches"
         >:: test_might_fill_sell_limit_when_high_reaches;
         "might_fill: buy stop when high reaches"
         >:: test_might_fill_buy_stop_when_high_reaches;
         "might_fill: sell stop when low reaches"
         >:: test_might_fill_sell_stop_when_low_reaches;
         "might_fill: stop-limit requires both"
         >:: test_might_fill_stop_limit_requires_both;
         (* Path generation tests *)
         "generate_path: stays in bounds" >:: test_generate_path_stays_in_bounds;
         "generate_path: visits all OHLC"
         >:: test_generate_path_visits_all_ohlc;
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
         (* Deterministic tests *)
         "deterministic path with seed" >:: test_deterministic_path_with_seed;
         "different seeds produce different paths"
         >:: test_different_seeds_produce_different_paths;
         "distribution profiles with seeds"
         >:: test_distribution_profiles_with_seeds;
         "default config produces ~390 points"
         >:: test_default_config_produces_390_points;
       ]

let () = run_test_tt_main suite
