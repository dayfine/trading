(** The stop level a bar is checked against is the level in force BEFORE that
    bar (issue #2961).

    [sim_stop_exit_fill_on_trigger_bar] fills a stop exit against the very bar
    that tripped it, at the [stop_price] the exit carries. That is only
    look-ahead-free if [stop_price] was set before the bar — i.e. if
    {!Weinstein_stops.update} tests the hit against the incoming state and does
    not first raise the trail using the same bar. These tests pin that for all
    three states: on a hit, the event's [stop_level] is the incoming level and
    the returned state is the incoming state, unchanged. ([Stops_runner] then
    builds the exit from that pre-advance state.)

    Bar T: open 100, high 100.5, low 95, close 99 — a long with a 96 stop. *)

open OUnit2
open Core
open Trading_base.Types
open Weinstein_types
open Weinstein_stops
open Matchers

let bar_t =
  Types.Daily_price.
    {
      date = Date.of_string "2024-01-04";
      open_price = 100.0;
      high_price = 100.5;
      low_price = 95.0;
      close_price = 99.0;
      volume = 1_000_000;
      adjusted_close = 99.0;
      active_through = None;
    }

let stage2 = Stage2 { weeks_advancing = 4; late = false }

let update_on_bar_t state =
  update ~config:default_config ~side:Long ~state ~current_bar:bar_t
    ~ma_value:90.0 ~ma_direction:Rising ~stage:stage2

(* Every state's hit is (incoming state, Stop_hit at the incoming level). *)
let assert_hit_at_pre_bar_level state =
  assert_that (update_on_bar_t state)
    (equal_to
       ((state, Stop_hit { trigger_price = 95.0; stop_level = 96.0 })
         : stop_state * stop_event))

let test_initial_state _ =
  assert_hit_at_pre_bar_level
    (Initial { stop_level = 96.0; reference_level = 97.0 })

(* A trailing state primed with a trend extreme bar T's close does not reach,
   so the hit — not a trail update — decides the outcome. *)
let test_trailing_state _ =
  assert_hit_at_pre_bar_level
    (Trailing
       {
         stop_level = 96.0;
         last_correction_extreme = 97.0;
         last_trend_extreme = 110.0;
         ma_at_last_adjustment = 88.0;
         correction_count = 1;
         correction_observed_since_reset = true;
       })

let test_tightened_state _ =
  assert_hit_at_pre_bar_level
    (Tightened
       { stop_level = 96.0; last_correction_extreme = 120.0; reason = "test" })

let suite =
  "stop_hit_level_in_force"
  >::: [
         "Initial: hit at the pre-bar level" >:: test_initial_state;
         "Trailing: hit at the pre-bar level" >:: test_trailing_state;
         "Tightened: hit at the pre-bar level" >:: test_tightened_state;
       ]

let () = run_test_tt_main suite
