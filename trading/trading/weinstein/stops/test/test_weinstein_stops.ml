open OUnit2
open Core
open Trading_base.Types
open Weinstein_stops
open Matchers

(* ---- Test helpers ---- *)

let make_bar ?(open_price = 100.0) ?(high_price = 105.0) ?(low_price = 95.0)
    ?(close_price = 102.0) ?(volume = 1000000) ?(adjusted_close = 102.0) () =
  Types.Daily_price.
    {
      date = Date.of_string "2024-01-01";
      open_price;
      high_price;
      low_price;
      close_price;
      volume;
      adjusted_close;
    }

let cfg = default_config

(* ---- compute_initial_stop tests ---- *)
(* Long: raw_stop = reference_level * (1 - min_correction_pct/2) = reference_level * 0.96
   Short: raw_stop = reference_level * (1 + min_correction_pct/2) = reference_level * 1.04
   A round-number nudge is applied after: stop placed just outside the nearest half-dollar. *)

let test_compute_initial_stop_long _ =
  (* Long: reference_level=50.0 → raw_stop=48.0 → nudged to 47.875 (below 48.0) *)
  assert_that
    (compute_initial_stop ~config:cfg ~side:Long ~reference_level:50.0)
    (equal_to (Initial { stop_level = 47.875; reference_level = 50.0 } : stop_state))

let test_compute_initial_stop_nudge_at_whole_number _ =
  (* Long: reference_level=52.1 → raw_stop=50.016 — just above 50.0 → nudged to 49.875 *)
  assert_that
    (get_stop_level
       (compute_initial_stop ~config:cfg ~side:Long ~reference_level:52.1))
    (float_equal 49.875)

let test_compute_initial_stop_nudge_at_half_dollar _ =
  (* Long: reference_level=52.65 → raw_stop=50.544 — just above 50.5 → nudged to 50.375 *)
  assert_that
    (get_stop_level
       (compute_initial_stop ~config:cfg ~side:Long ~reference_level:52.65))
    (float_equal 50.375)

let test_compute_initial_stop_no_nudge _ =
  (* Long: reference_level=52.4 → raw_stop≈50.304 — not within 0.125 of any half-dollar → no nudge *)
  let stop =
    get_stop_level
      (compute_initial_stop ~config:cfg ~side:Long ~reference_level:52.4)
  in
  assert_that stop
    (all_of
       [
         (fun s -> assert_that Float.(s > 50.25) (equal_to true));
         (fun s -> assert_that Float.(s < 50.35) (equal_to true));
       ])

let test_compute_initial_stop_short _ =
  (* Short: reference_level=50.0 → raw_stop=52.0 → nudged to 52.125 (above 52.0) *)
  assert_that
    (compute_initial_stop ~config:cfg ~side:Short ~reference_level:50.0)
    (equal_to (Initial { stop_level = 52.125; reference_level = 50.0 } : stop_state))

(* ---- check_stop_hit tests ---- *)

let test_check_stop_hit_long _ =
  let state = Initial { stop_level = 45.0; reference_level = 47.0 } in
  assert_that
    (check_stop_hit ~state ~side:Long ~bar:(make_bar ~low_price:44.0 ()))
    (equal_to true);
  assert_that
    (check_stop_hit ~state ~side:Long ~bar:(make_bar ~low_price:45.0 ()))
    (equal_to true);
  assert_that
    (check_stop_hit ~state ~side:Long ~bar:(make_bar ~low_price:46.0 ()))
    (equal_to false)

let test_check_stop_hit_short _ =
  let state = Initial { stop_level = 55.0; reference_level = 53.0 } in
  assert_that
    (check_stop_hit ~state ~side:Short ~bar:(make_bar ~high_price:56.0 ()))
    (equal_to true);
  assert_that
    (check_stop_hit ~state ~side:Short ~bar:(make_bar ~high_price:55.0 ()))
    (equal_to true);
  assert_that
    (check_stop_hit ~state ~side:Short ~bar:(make_bar ~high_price:54.0 ()))
    (equal_to false)

(* ---- get_stop_level tests ---- *)

let test_get_stop_level_initial _ =
  assert_that
    (get_stop_level (Initial { stop_level = 45.0; reference_level = 47.0 }))
    (float_equal 45.0)

let test_get_stop_level_trailing _ =
  let state =
    Trailing
      {
        stop_level = 48.0;
        last_correction_extreme = 46.0;
        last_trend_extreme = 55.0;
        ma_at_last_adjustment = 50.0;
        correction_count = 1;
      }
  in
  assert_that (get_stop_level state) (float_equal 48.0)

let test_get_stop_level_tightened _ =
  let state =
    Tightened
      { stop_level = 52.0; last_correction_extreme = 51.0; reason = "test" }
  in
  assert_that (get_stop_level state) (float_equal 52.0)

(* ---- show/eq derivations ---- *)

let test_deriving _ =
  let state = Initial { stop_level = 45.0; reference_level = 47.0 } in
  let _ = show_stop_state state in
  let event = Stop_hit { trigger_price = 44.0; stop_level = 45.0 } in
  let _ = show_stop_event event in
  let _ = show_config default_config in
  assert_that state (equal_to (state : stop_state));
  assert_that event (equal_to (event : stop_event))

let suite =
  "weinstein_stops"
  >::: [
         "initial_stop_long" >:: test_compute_initial_stop_long;
         "initial_stop_nudge_whole"
         >:: test_compute_initial_stop_nudge_at_whole_number;
         "initial_stop_nudge_half"
         >:: test_compute_initial_stop_nudge_at_half_dollar;
         "initial_stop_no_nudge" >:: test_compute_initial_stop_no_nudge;
         "initial_stop_short" >:: test_compute_initial_stop_short;
         "check_stop_hit_long" >:: test_check_stop_hit_long;
         "check_stop_hit_short" >:: test_check_stop_hit_short;
         "get_stop_level_initial" >:: test_get_stop_level_initial;
         "get_stop_level_trailing" >:: test_get_stop_level_trailing;
         "get_stop_level_tightened" >:: test_get_stop_level_tightened;
         "deriving" >:: test_deriving;
       ]

let () = run_test_tt_main suite
