(** The tightening trigger behind a [Tightened] stop: one case per branch of the
    state machine's tightening test, each driven through the real
    {!Weinstein_stops.update} and recorded with
    {!Weinstein_stops.Stop_decision.make} exactly as the strategy's stops runner
    does. The reason string the machine writes is pinned alongside, so typing
    the trigger provably changed no recorded state. *)

open OUnit2
open Core
open Trading_base.Types
open Weinstein_types
open Weinstein_stops
open Matchers
module D = Stop_decision
module T = Tighten_trigger

let _bar ~day ~low ~high ~close =
  Types.Daily_price.
    {
      date = Date.add_days (Date.of_string "2024-01-05") day;
      open_price = close;
      high_price = high;
      low_price = low;
      close_price = close;
      volume = 1_000_000;
      adjusted_close = close;
      active_through = None;
    }

let _seed_bar = _bar ~day:0 ~low:99.0 ~high:101.0 ~close:100.0
let _next_bar = _bar ~day:1 ~low:100.0 ~high:102.0 ~close:101.0

(* One update from [Initial] on [bar] with the given side / stage / MA
   direction, recorded as a decision. A long's stop sits at 90 and a short's
   at 110, so neither is hit and the tightening test decides the step. *)
let _decide ?(bar = _seed_bar) ?state ~side ~stage ~ma_direction () =
  let stop = match side with Long -> 90.0 | Short -> 110.0 in
  let before =
    Option.value state
      ~default:(Initial { stop_level = stop; reference_level = stop })
  in
  let after, event =
    update ~config:default_config ~side ~state:before ~current_bar:bar
      ~ma_value:95.0 ~ma_direction ~stage
  in
  ( D.make ~config:default_config ~side ~position_id:"AAA-wein-1"
      { D.before; after; event; bar; ma_value = 95.0 },
    event )

let stage1 = Stage1 { weeks_in_base = 4 }
let stage2 = Stage2 { weeks_advancing = 4; late = false }
let stage3 = Stage3 { weeks_topping = 1 }
let stage4 = Stage4 { weeks_declining = 4 }

(* The decision entered tightening and recorded [trigger], and the state
   machine's event carries the reason string it always has. *)
let _entered trigger ~reason =
  all_of
    [
      field (fun ((d : D.t), _) -> d.reason) (equal_to D.Entered_tightening);
      field
        (fun ((d : D.t), _) -> d.tighten_trigger)
        (is_some_and (equal_to trigger));
      field snd (equal_to (Entered_tightening { reason }));
    ]

let test_long_stage3 _ =
  assert_that
    (_decide ~side:Long ~stage:stage3 ~ma_direction:Rising ())
    (_entered T.Stage3_or_4 ~reason:"Stage 3/4 detected")

let test_long_stage4 _ =
  assert_that
    (_decide ~side:Long ~stage:stage4 ~ma_direction:Declining ())
    (_entered T.Stage3_or_4 ~reason:"Stage 3/4 detected")

let test_long_ma_flat_in_stage2 _ =
  assert_that
    (_decide ~side:Long ~stage:stage2 ~ma_direction:Flat ())
    (_entered T.Ma_flat_in_stage2 ~reason:"30-week MA flattening")

let test_long_ma_falling_in_stage2 _ =
  assert_that
    (_decide ~side:Long ~stage:stage2 ~ma_direction:Declining ())
    (_entered T.Ma_falling_in_stage2 ~reason:"30-week MA falling in Stage 2")

let test_short_stage1 _ =
  assert_that
    (_decide ~side:Short ~stage:stage1 ~ma_direction:Flat ())
    (_entered T.Stage1_or_2 ~reason:"Stage 1/2 detected")

let test_short_ma_rising_in_stage4 _ =
  assert_that
    (_decide ~side:Short ~stage:stage4 ~ma_direction:Rising ())
    (_entered T.Ma_rising_in_stage4 ~reason:"30-week MA rising in Stage 4")

let test_short_ma_flat_in_stage4 _ =
  assert_that
    (_decide ~side:Short ~stage:stage4 ~ma_direction:Flat ())
    (_entered T.Ma_flat_in_stage4 ~reason:"30-week MA flattening in Stage 4")

(* No tightening: a long in Stage 2 under a rising MA seeds trailing. *)
let test_untightened_step_has_no_trigger _ =
  assert_that
    (fst (_decide ~side:Long ~stage:stage2 ~ma_direction:Rising ()))
    (all_of
       [
         field (fun (d : D.t) -> d.reason) (equal_to D.Seeded_trailing);
         field (fun (d : D.t) -> d.tighten_trigger) is_none;
       ])

(* With [tighten_on_flat_ma] off, the MA branches never fire: the stop
   state machine distinguishes nothing beyond the stage there. *)
let test_flat_ma_branch_needs_config _ =
  let config = { default_config with tighten_on_flat_ma = false } in
  let state = Initial { stop_level = 90.0; reference_level = 90.0 } in
  let _, event =
    update ~config ~side:Long ~state ~current_bar:_seed_bar ~ma_value:95.0
      ~ma_direction:Flat ~stage:stage2
  in
  assert_that event (equal_to No_change)

(* Steps after the entry keep the trigger: the ratchet / hold rows on the
   [Tightened] state carry the trigger it was entered with. *)
let test_tightened_rows_keep_trigger _ =
  let entered, _ = _decide ~side:Long ~stage:stage2 ~ma_direction:Flat () in
  let state =
    Tightened
      {
        stop_level = entered.stop_after;
        last_correction_extreme = 99.0;
        reason = T.to_reason T.Ma_flat_in_stage2;
        swing_peak = None;
      }
  in
  assert_that
    (fst
       (_decide ~bar:_next_bar ~state ~side:Long ~stage:stage2
          ~ma_direction:Flat ()))
    (all_of
       [
         field (fun (d : D.t) -> d.state_before) (equal_to D.Tightened);
         field
           (fun (d : D.t) -> d.tighten_trigger)
           (is_some_and (equal_to T.Ma_flat_in_stage2));
       ])

(* A hand-built [Tightened] state with a reason the machine never writes. *)
let test_unknown_reason_has_no_trigger _ =
  let state =
    Tightened
      {
        stop_level = 90.0;
        last_correction_extreme = 99.0;
        reason = "hand-built";
        swing_peak = None;
      }
  in
  assert_that
    (fst (_decide ~state ~side:Long ~stage:stage2 ~ma_direction:Flat ()))
    (field (fun (d : D.t) -> d.tighten_trigger) is_none)

let test_reason_round_trip _ =
  assert_that
    (List.map T.all ~f:(fun t -> T.of_reason (T.to_reason t)))
    (equal_to (List.map T.all ~f:Option.some))

(* Stop decisions written before the field existed carry no
   [tighten_trigger]; they still parse, as [None]. *)
let test_old_sexp_reads_as_none _ =
  let d =
    D.t_of_sexp
      (Sexp.of_string
         "((date 2024-03-15) (position_id AAA-wein-1) (state_before Trailing) \
          (state_after Tightened) (stop_before 90) (stop_after 97.875) \
          (candidate ()) (correction_count_before 0) (correction_count 0) \
          (last_trend_extreme ()) (last_correction_extreme (99)) (ma_value 95) \
          (reason Entered_tightening))")
  in
  assert_that d (field (fun (d : D.t) -> d.tighten_trigger) is_none)

let test_sexp_round_trip_with_trigger _ =
  let d, _ = _decide ~side:Short ~stage:stage4 ~ma_direction:Rising () in
  assert_that (D.t_of_sexp (D.sexp_of_t d)) (equal_to d)

let suite =
  "Tighten_trigger"
  >::: [
         "long Stage 3" >:: test_long_stage3;
         "long Stage 4" >:: test_long_stage4;
         "long MA flat in Stage 2" >:: test_long_ma_flat_in_stage2;
         "long MA falling in Stage 2" >:: test_long_ma_falling_in_stage2;
         "short Stage 1" >:: test_short_stage1;
         "short MA rising in Stage 4" >:: test_short_ma_rising_in_stage4;
         "short MA flat in Stage 4" >:: test_short_ma_flat_in_stage4;
         "untightened step has no trigger"
         >:: test_untightened_step_has_no_trigger;
         "flat-MA branch needs config" >:: test_flat_ma_branch_needs_config;
         "tightened rows keep the trigger" >:: test_tightened_rows_keep_trigger;
         "unknown reason has no trigger" >:: test_unknown_reason_has_no_trigger;
         "reason round trip" >:: test_reason_round_trip;
         "old sexp reads as None" >:: test_old_sexp_reads_as_none;
         "sexp round trip with trigger" >:: test_sexp_round_trip_with_trigger;
       ]

let () = run_test_tt_main suite
