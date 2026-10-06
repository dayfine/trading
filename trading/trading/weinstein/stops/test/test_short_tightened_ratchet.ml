(** #3145 — [short_tightened_ratchet_follows_decline]: a short [Tightened] stop
    follows the decline down instead of freezing.

    ADSK-wein-314 shape (short-only Phase A, soTs): the short was tightened at
    41.75 in 2008-06 and held there for 137 decisions while the close fell 39.25
    → 11.78. Off (default), the anchor is a running max of highs, so the
    candidate never drops below the stop and the stop never moves. On, the
    anchor is the running min of highs: the buy-stop is lowered to
    [min_high *. 1.005] (nudged) as each lower high prints, and a bounce that
    does not take out the stop never raises it (book §6.3, Ch. 7: trail the
    short's buy-stop down as the stock declines). Longs are unaffected. *)

open OUnit2
open Core
open Trading_base.Types
open Weinstein_types
open Weinstein_stops
open Matchers

let as_of = Date.of_string "2008-06-03"

let bar ~low ~high ~close =
  Types.Daily_price.
    {
      date = as_of;
      open_price = close;
      high_price = high;
      low_price = low;
      close_price = close;
      volume = 1_000_000;
      adjusted_close = close;
      active_through = None;
    }

let tightened ~stop_level ~anchor =
  Tightened
    {
      stop_level;
      last_correction_extreme = anchor;
      reason = "Stage 3 detected";
      swing_peak = None;
    }

(* Fold [update] over [tape] ((low, high, close) per bar); stop level after
   each bar. The MA / stage inputs are inert for a [Tightened] state. *)
let stop_levels ~config ~side ~state tape =
  List.folding_map tape ~init:state ~f:(fun state (low, high, close) ->
      let state, _event =
        update ~config ~side ~state ~current_bar:(bar ~low ~high ~close)
          ~ma_value:45.0 ~ma_direction:Declining
          ~stage:(Stage4 { weeks_declining = 4 })
      in
      (state, get_stop_level state))

let follows_off =
  { default_config with short_tightened_ratchet_follows_decline = false }

let follows_on =
  { default_config with short_tightened_ratchet_follows_decline = true }

(* Falling highs 39 → 30 → 20, a bounce to a 20.05 high (still under the
   stop), then a 12 high. Each high is below the prior bar's stop, so no bar
   triggers. *)
let adsk_decline =
  [
    (37.0, 39.0, 38.0);
    (28.0, 30.0, 29.0);
    (18.5, 20.0, 19.0);
    (19.0, 20.05, 20.0);
    (11.5, 12.0, 11.78);
  ]

let adsk_short = tightened ~stop_level:41.75 ~anchor:41.75

(** Default: the short Tightened stop is frozen at 41.75 through the whole
    decline — today's behaviour, bit-identical. *)
let test_short_tightened_frozen_when_off _ =
  assert_that
    (stop_levels ~config:follows_off ~side:Short ~state:adsk_short adsk_decline)
    (elements_are (List.init 5 ~f:(fun _ -> float_equal 41.75)))

(** On: lowered on each lower high (39 * 1.005 = 39.195, 30.15, 20.1), held on
    the bounce (never raised), then lowered again to 12.06. *)
let test_short_tightened_lowered_across_decline _ =
  assert_that
    (stop_levels ~config:follows_on ~side:Short ~state:adsk_short adsk_decline)
    (elements_are
       [
         float_equal 39.195;
         float_equal 30.15;
         float_equal 20.1;
         float_equal 20.1;
         float_equal 12.06;
       ])

(** On: a rally that takes out the lowered stop triggers it — the buy-stop is
    live at its new level, not at the stale 41.75. *)
let test_short_tightened_triggers_at_lowered_level _ =
  let state, event =
    List.fold
      [ (28.0, 30.0, 29.0); (29.5, 31.0, 30.8) ]
      ~init:(adsk_short, No_change)
      ~f:(fun (state, _) (low, high, close) ->
        update ~config:follows_on ~side:Short ~state
          ~current_bar:(bar ~low ~high ~close) ~ma_value:45.0
          ~ma_direction:Declining
          ~stage:(Stage4 { weeks_declining = 4 }))
  in
  assert_that
    (get_stop_level state, event)
    (pair (float_equal 30.15)
       (matching ~msg:"Expected Stop_hit"
          (function Stop_hit { stop_level; _ } -> Some stop_level | _ -> None)
          (float_equal 30.15)))

(** Longs are untouched: the flag only rewires the short anchor. *)
let test_long_tightened_unaffected _ =
  let long_state = tightened ~stop_level:80.0 ~anchor:85.0 in
  let tape = [ (88.0, 92.0, 90.0); (91.0, 96.0, 95.0); (84.0, 90.0, 86.0) ] in
  let run config = stop_levels ~config ~side:Long ~state:long_state tape in
  assert_that (run follows_on) (equal_to (run follows_off))

let () =
  run_test_tt_main
    ("short_tightened_ratchet"
    >::: [
           "#3145: short Tightened stop frozen when off"
           >:: test_short_tightened_frozen_when_off;
           "#3145: short Tightened stop lowered across a decline"
           >:: test_short_tightened_lowered_across_decline;
           "#3145: short Tightened stop triggers at the lowered level"
           >:: test_short_tightened_triggers_at_lowered_level;
           "#3145: long Tightened path unaffected"
           >:: test_long_tightened_unaffected;
         ])
