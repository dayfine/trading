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

(** Run a test function multiple times (for randomized tests) *)
let run_n_times n f =
  for _ = 1 to n do
    f ()
  done

(** Check all basic properties that every generated path should satisfy *)
let check_basic_properties ~bar ?(expected_length_min = 4)
    ?(expected_length_max = Int.max_value) path =
  (* All prices stay within OHLC bounds *)
  assert_that (all_in_bounds path bar) (equal_to true);
  (* Path visits all OHLC prices *)
  assert_that (visits_all_ohlc path bar) (equal_to true);
  (* First point is open, last point is close *)
  (match (List.hd path, List.last path) with
  | Some first, Some last ->
      assert_that first.price (float_equal bar.open_price);
      assert_that last.price (float_equal bar.close_price)
  | _ -> assert_failure "Path should have at least 2 points");
  (* Path length is in expected range *)
  let path_length = List.length path in
  assert_that
    (path_length >= expected_length_min && path_length <= expected_length_max)
    (equal_to true)

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

let test_generate_path_basic_properties _ =
  (* Merged test: checks all basic properties (bounds, OHLC visits, endpoints, length) *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  (* Run multiple times due to randomness *)
  run_n_times 10 (fun () ->
      let path = generate_path bar in
      check_basic_properties ~bar ~expected_length_min:380
        ~expected_length_max:400 path)

let test_generate_path_narrow_range _ =
  (* Test with very narrow range (almost doji) *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:100.5 ~low_price:99.5
      ~close_price:100.0
  in
  run_n_times 10 (fun () ->
      let path = generate_path bar in
      check_basic_properties ~bar ~expected_length_min:380
        ~expected_length_max:400 path)

let test_generate_path_wide_range _ =
  (* Test with wide range (high volatility) *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:130.0 ~low_price:70.0
      ~close_price:110.0
  in
  run_n_times 10 (fun () ->
      let path = generate_path bar in
      check_basic_properties ~bar ~expected_length_min:380
        ~expected_length_max:400 path)

let test_generate_path_upward_bar _ =
  (* Upward bar: close > open *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:98.0
      ~close_price:108.0
  in
  run_n_times 10 (fun () ->
      let path = generate_path bar in
      check_basic_properties ~bar ~expected_length_min:380
        ~expected_length_max:400 path)

let test_generate_path_downward_bar _ =
  (* Downward bar: close < open *)
  let bar =
    make_bar "AAPL" ~open_price:108.0 ~high_price:110.0 ~low_price:98.0
      ~close_price:100.0
  in
  run_n_times 10 (fun () ->
      let path = generate_path bar in
      check_basic_properties ~bar ~expected_length_min:380
        ~expected_length_max:400 path)

(** {1 Configuration Tests} *)

let test_custom_config_affects_granularity _ =
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let config =
    {
      profile = Uniform;
      total_points = 30;
      seed = Some 42;
      degrees_of_freedom = 4.0;
    }
  in
  let path = generate_path ~config bar in
  (* With 30 total points, should have ~30-35 points including waypoints *)
  check_basic_properties ~bar ~expected_length_min:25 ~expected_length_max:40
    path

(** {1 Deterministic Tests with Fixed Seeds} *)

let test_deterministic_path_with_seed _ =
  (* Same seed should produce identical paths with explicit values *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let config =
    {
      profile = Uniform;
      total_points = 10;
      seed = Some 12345;
      degrees_of_freedom = 4.0;
    }
  in
  let path = generate_path ~config bar in
  (* Expected path values for seed=12345, total_points=10, df=4.0 with Student's t
     After removing default_bar_resolution indirection *)
  let expected : intraday_path =
    [
      { price = 100.0 };
      { price = 100.86187228911206 };
      { price = 102.40592847455183 };
      { price = 103.76781747465134 };
      { price = 106.35315965230939 };
      { price = 108.0731149431833 };
      { price = 109.94664616190269 };
      { price = 110.0 };
      { price = 95.0 };
      { price = 95.0 };
      { price = 100.10734547267361 };
      { price = 104.09730483755989 };
      { price = 105.0 };
    ]
  in
  assert_equal path expected;
  (* Also check basic properties *)
  check_basic_properties ~bar ~expected_length_min:13 ~expected_length_max:13
    path

let test_different_seeds_produce_different_paths _ =
  (* Different seed should produce different path from seed=12345 *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let config =
    {
      profile = Uniform;
      total_points = 10;
      seed = Some 99999;
      degrees_of_freedom = 4.0;
    }
  in
  let path = generate_path ~config bar in
  (* This is the expected path from seed=12345 (from test above) *)
  let path_from_seed_12345 : intraday_path =
    [
      { price = 100.0 };
      { price = 100.86187228911206 };
      { price = 102.40592847455183 };
      { price = 103.76781747465134 };
      { price = 106.35315965230939 };
      { price = 108.0731149431833 };
      { price = 109.94664616190269 };
      { price = 110.0 };
      { price = 95.0 };
      { price = 95.0 };
      { price = 100.10734547267361 };
      { price = 104.09730483755989 };
      { price = 105.0 };
    ]
  in
  (* Paths should be different (at least one point differs) *)
  let paths_differ =
    not
      (List.equal
         (fun (p1 : path_point) (p2 : path_point) ->
           Float.(p1.price = p2.price))
         path path_from_seed_12345)
  in
  assert_that paths_differ (equal_to true);
  (* Also check basic properties *)
  check_basic_properties ~bar ~expected_length_min:13 ~expected_length_max:13
    path

let test_distribution_profiles_with_seeds _ =
  (* Test that different profiles all produce valid paths *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let test_profile profile =
    let config =
      { profile; total_points = 20; seed = Some 42; degrees_of_freedom = 4.0 }
    in
    let path = generate_path ~config bar in
    check_basic_properties ~bar ~expected_length_min:15 ~expected_length_max:25
      path
  in
  (* Test all distribution profiles *)
  test_profile Uniform;
  test_profile UShaped;
  test_profile JShaped;
  test_profile ReverseJ

let test_default_config_produces_390_points _ =
  (* Default config should produce ~390 points total *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let path = generate_path bar in
  (* With default config (total_points = 390), should produce ~390 points *)
  check_basic_properties ~bar ~expected_length_min:380 ~expected_length_max:400
    path

(** {1 Edge Case Tests for Small total_points} *)

let test_total_points_4_returns_waypoints_only _ =
  (* With total_points <= 4, should return exactly 4 waypoints (O,H,L,C or O,L,H,C) *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  let config =
    {
      profile = Uniform;
      total_points = 4;
      seed = Some 42;
      degrees_of_freedom = 4.0;
    }
  in
  let path = generate_path ~config bar in
  (* With seed=42, produces O→H→L→C ordering *)
  let expected : intraday_path =
    [
      { price = 100.0 }; { price = 110.0 }; { price = 95.0 }; { price = 105.0 };
    ]
  in
  assert_equal path expected;
  (* Also check basic properties *)
  check_basic_properties ~bar ~expected_length_min:4 ~expected_length_max:4 path

let test_total_points_small_values _ =
  (* Test that small values (5, 6) work correctly with exact expectations *)
  let bar =
    make_bar "AAPL" ~open_price:100.0 ~high_price:110.0 ~low_price:95.0
      ~close_price:105.0
  in
  (* Test total_points = 5 *)
  let config5 =
    {
      profile = Uniform;
      total_points = 5;
      seed = Some 42;
      degrees_of_freedom = 4.0;
    }
  in
  let path5 = generate_path ~config:config5 bar in
  let expected5 : intraday_path =
    [
      { price = 100.0 };
      { price = 106.61732993746411 };
      { price = 109.91210066439501 };
      { price = 110.0 };
      { price = 95.0 };
      { price = 95.0 };
      { price = 104.9266536207159 };
      { price = 105.0 };
    ]
  in
  assert_equal path5 expected5;
  check_basic_properties ~bar ~expected_length_min:8 ~expected_length_max:8
    path5;
  (* Test total_points = 6 *)
  let config6 =
    {
      profile = Uniform;
      total_points = 6;
      seed = Some 42;
      degrees_of_freedom = 4.0;
    }
  in
  let path6 = generate_path ~config:config6 bar in
  let expected6 : intraday_path =
    [
      { price = 100.0 };
      { price = 106.47641348279585 };
      { price = 109.91975925183237 };
      { price = 110.0 };
      { price = 95.0 };
      { price = 95.0 };
      { price = 99.922686127778562 };
      { price = 105.17759472119232 };
      { price = 105.0 };
    ]
  in
  assert_equal path6 expected6;
  check_basic_properties ~bar ~expected_length_min:9 ~expected_length_max:9
    path6

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
         "generate_path: basic properties"
         >:: test_generate_path_basic_properties;
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
         (* Edge case tests *)
         "total_points = 4 returns waypoints only"
         >:: test_total_points_4_returns_waypoints_only;
         "small total_points values (5, 6)" >:: test_total_points_small_values;
       ]

let () = run_test_tt_main suite
