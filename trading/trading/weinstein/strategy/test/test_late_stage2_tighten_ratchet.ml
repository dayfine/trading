(** End-to-end pins for the late-Stage-2 stop tighten (issue #2998, #2997
    follow-up): once {!Late_stage2_stop_runner.update} has written a tightened
    level into [stop_states], no later {!Stops_runner.update} tick may lower it,
    and a bar crossing it exits the position.

    Driven at the component level — {!Stops_runner.update} then
    {!Late_stage2_stop_runner.update} on each Friday, sharing one [stop_states]
    ref and one [prior_stages] table, in the order
    [Weinstein_strategy._process_market_day] runs them (stops pass first, the
    tighten dial later in the same tick). A full [Weinstein_strategy] run would
    need an index series, macro inputs and an entry to fill before any of this
    is reachable, none of which bears on the ratchet. The bars are real weekly
    bars behind a {!Bar_reader}, so every stage (including the [late] flag) is
    produced by the stage classifier, not asserted by hand. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* ------------------------------------------------------------------ *)
(* Fixture                                                              *)
(* ------------------------------------------------------------------ *)

(** Friday of week [i] (week 0 = 2024-01-05). One bar per week, so each bar is
    its own weekly bar. *)
let week_date i = Date.add_days (Date.of_string "2024-01-05") (7 * i)

let make_bar i ~close ?low () =
  {
    Types.Daily_price.date = week_date i;
    open_price = close;
    high_price = close *. 1.01;
    low_price = Option.value low ~default:(close *. 0.99);
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(** A 5-week MA keeps the fixture short. Weeks 0-10 rise 84 -> 124 (Stage 2, MA
    rising); weeks 11-14 roll over gently, which the classifier reads as
    [Stage2 { late = true }] from week 12 (MA-slope deceleration); week 15 is
    the first [Stage4] read. Week 16 is the exit bar: its low (115) crosses the
    tightened stop but sits far above the 90 entry stop. *)
let stage_config = { Stage.default_config with ma_period = 5 }

let closes =
  List.init 11 ~f:(fun i -> 84.0 +. (4.0 *. Float.of_int i))
  @ [ 123.0; 122.0; 121.0; 120.0; 119.0 ]

let exit_week = List.length closes

(** Week 13 dips intraweek to 116.5: above the 115.9 tightened stop (no hit),
    but low enough that the state machine's own [Tightened] candidate at week 15
    (116.5 * (1 - 0.01) = 115.335) sits BELOW 115.9 — so only the better-of rule
    in [_to_tightened] keeps the level from dropping. *)
let week13_low = 116.5

let bars =
  List.mapi closes ~f:(fun i close ->
      if i = 13 then make_bar i ~close ~low:week13_low ()
      else make_bar i ~close ())
  @ [ make_bar exit_week ~close:117.0 ~low:115.0 () ]

let bar_at i = List.nth_exn bars i
let bar_reader = lazy (Bar_reader.of_in_memory_bars [ ("AAPL", bars) ])
let buffer_pct = 0.05
let entry_stop = 90.0

(** Held long AAPL entered at week 11's close. *)
let holding_pos () =
  let date = week_date 11 in
  let make_trans kind =
    { Trading_strategy.Position.position_id = "AAPL"; date; kind }
  in
  let unwrap = function
    | Ok p -> p
    | Error _ -> OUnit2.assert_failure "position setup failed"
  in
  let open Trading_strategy.Position in
  let p =
    create_entering
      (make_trans
         (CreateEntering
            {
              symbol = "AAPL";
              side = Trading_base.Types.Long;
              target_quantity = 10.0;
              entry_price = 123.0;
              reasoning = ManualDecision { description = "test" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans (EntryFill { filled_quantity = 10.0; fill_price = 123.0 }))
    |> unwrap
  in
  apply_transition p
    (make_trans
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

let positions () = String.Map.singleton "AAPL" (holding_pos ())

let initial_states () =
  ref
    (String.Map.singleton "AAPL"
       (Weinstein_stops.Initial
          { stop_level = entry_stop; reference_level = entry_stop }))

let get_price_at i symbol =
  if String.equal symbol "AAPL" then Some (bar_at i) else None

let run_stops ~positions ~stop_states ~prior_stages i =
  Stops_runner.update ~stops_config:Weinstein_stops.default_config ~stage_config
    ~lookback_bars:52 ~positions ~get_price:(get_price_at i) ~stop_states
    ~bar_reader:(Lazy.force bar_reader) ~as_of:(week_date i) ~prior_stages ()

let run_tighten ~positions ~stop_states ~prior_stages i =
  Late_stage2_stop_runner.update ~buffer_pct ~is_screening_day:true ~stop_states
    ~positions ~get_price:(get_price_at i) ~prior_stages
    ~current_date:(week_date i)

type tick = {
  week : int;
  phase : string;
  level : float;
  exits : int;
  tightens : int;
}
(** What one weekly tick left behind: the phase + level of AAPL's stop state,
    and how many exits / tightens the two runners emitted. *)

let phase_of : Weinstein_stops.stop_state -> string = function
  | Initial _ -> "Initial"
  | Trailing _ -> "Trailing"
  | Tightened _ -> "Tightened"

let snapshot ~stop_states ~week ~exits ~tightens =
  let state = Map.find_exn !stop_states "AAPL" in
  {
    week;
    phase = phase_of state;
    level = Weinstein_stops.get_stop_level state;
    exits = List.length exits;
    tightens = List.length tightens;
  }

(** One Friday in strategy order: stops pass, then the tighten dial. *)
let run_week ~positions ~stop_states ~prior_stages week =
  let exits, _adjusts = run_stops ~positions ~stop_states ~prior_stages week in
  let tightens = run_tighten ~positions ~stop_states ~prior_stages week in
  snapshot ~stop_states ~week ~exits ~tightens

let tick_is ~week ~phase ~level ~exits ~tightens =
  all_of
    [
      field (fun t -> t.week) (equal_to week);
      field (fun t -> t.phase) (equal_to phase);
      field (fun t -> t.level) (float_equal level);
      field (fun t -> t.exits) (equal_to exits);
      field (fun t -> t.tightens) (equal_to tightens);
    ]

(* ------------------------------------------------------------------ *)
(* Fixture sanity: the classifier really reads late Stage 2 / Stage 4  *)
(* ------------------------------------------------------------------ *)

(** The stages the ratchet tests lean on come from the classifier, not a hand
    seed: weeks 12-14 are [Stage2 { late = true }], week 15 is [Stage4]. *)
let test_fixture_stages _ =
  let prior_stages = Hashtbl.create (module String) in
  let stages =
    List.map (List.range 11 16) ~f:(fun week ->
        let _ : _ =
          run_stops ~positions:(positions ()) ~stop_states:(initial_states ())
            ~prior_stages week
        in
        Hashtbl.find_exn prior_stages "AAPL")
  in
  assert_that stages
    (elements_are
       [
         matching ~msg:"week 11: Stage2, not late"
           (function
             | Weinstein_types.Stage2 { late = false; _ } -> Some () | _ -> None)
           (equal_to ());
         matching ~msg:"week 12: late Stage2"
           (function
             | Weinstein_types.Stage2 { late = true; _ } -> Some () | _ -> None)
           (equal_to ());
         matching ~msg:"week 13: late Stage2"
           (function
             | Weinstein_types.Stage2 { late = true; _ } -> Some () | _ -> None)
           (equal_to ());
         matching ~msg:"week 14: late Stage2"
           (function
             | Weinstein_types.Stage2 { late = true; _ } -> Some () | _ -> None)
           (equal_to ());
         matching ~msg:"week 15: Stage4"
           (function Weinstein_types.Stage4 _ -> Some () | _ -> None)
           (equal_to ());
       ])

(* ------------------------------------------------------------------ *)
(* Initial -> Trailing carries a tightened level                        *)
(* ------------------------------------------------------------------ *)

(** A tighten written into an [Initial] state survives the state machine's
    [Initial -> Trailing] advance: [_to_trailing] carries [stop_level] rather
    than re-deriving it. Week 12's tighten (122 * 0.95 = 115.9) is applied to
    the fresh [Initial] 90 stop before any stops pass; week 13's stops pass then
    moves it to [Trailing] at 115.9, not back to 90. *)
let test_initial_tighten_carried_into_trailing _ =
  let positions = positions () in
  let stop_states = initial_states () in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL"
    ~data:(Weinstein_types.Stage2 { weeks_advancing = 8; late = true });
  let tightens = run_tighten ~positions ~stop_states ~prior_stages 12 in
  let after_tighten = snapshot ~stop_states ~week:12 ~exits:[] ~tightens in
  let exits, _ = run_stops ~positions ~stop_states ~prior_stages 13 in
  let after_advance = snapshot ~stop_states ~week:13 ~exits ~tightens:[] in
  assert_that
    [ after_tighten; after_advance ]
    (elements_are
       [
         tick_is ~week:12 ~phase:"Initial" ~level:115.9 ~exits:0 ~tightens:1;
         tick_is ~week:13 ~phase:"Trailing" ~level:115.9 ~exits:0 ~tightens:0;
       ])

(* ------------------------------------------------------------------ *)
(* Weekly ticks never lower the tightened level; a cross exits          *)
(* ------------------------------------------------------------------ *)

(** Weekly ticks 12-15 in strategy order (stops pass, then the tighten dial):

    - week 12: stops pass advances [Initial 90 -> Trailing 90]; the classifier
      reads late Stage 2, so the dial tightens to 122 * 0.95 = 115.9.
    - weeks 13-14: still late Stage 2, but the candidates (114.95, 114.0) sit
      below 115.9 — no tighten; the [Trailing] tick keeps 115.9.
    - week 15: the classifier reads [Stage4], so the state machine enters
      [Tightened]. Its own candidate (the week-13 low 116.5 less the 1% trailing
      buffer = 115.335) is BELOW 115.9; [_to_tightened] keeps the better of the
      two, so the level stays at 115.9.

    Every tick's level is >= 115.9, and week 16's bar (low 115 < level, but far
    above the 90 entry stop) exits the position. *)
let test_weekly_ticks_never_lower_tightened_level _ =
  let positions = positions () in
  let stop_states = initial_states () in
  let prior_stages = Hashtbl.create (module String) in
  let ticks =
    List.map (List.range 12 16)
      ~f:(run_week ~positions ~stop_states ~prior_stages)
  in
  assert_that ticks
    (elements_are
       [
         tick_is ~week:12 ~phase:"Trailing" ~level:115.9 ~exits:0 ~tightens:1;
         tick_is ~week:13 ~phase:"Trailing" ~level:115.9 ~exits:0 ~tightens:0;
         tick_is ~week:14 ~phase:"Trailing" ~level:115.9 ~exits:0 ~tightens:0;
         tick_is ~week:15 ~phase:"Tightened" ~level:115.9 ~exits:0 ~tightens:0;
       ])

(** Continuation of the timeline above: after weeks 12-15, the week-16 bar whose
    low (115) crosses the tightened level exits the position through the
    ordinary {!Stops_runner.update} trigger. Without the tighten the live stop
    would still be 90 and this bar would not exit. *)
let test_crossing_bar_exits_after_ratchet _ =
  let positions = positions () in
  let stop_states = initial_states () in
  let prior_stages = Hashtbl.create (module String) in
  List.iter (List.range 12 16) ~f:(fun week ->
      let _ : tick = run_week ~positions ~stop_states ~prior_stages week in
      ());
  let exits, _adjusts =
    run_stops ~positions ~stop_states ~prior_stages exit_week
  in
  assert_that exits
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Trading_strategy.Position.transition) -> t.position_id)
               (equal_to "AAPL");
             field
               (fun (t : Trading_strategy.Position.transition) -> t.kind)
               (matching ~msg:"Expected TriggerExit"
                  (function
                    | Trading_strategy.Position.TriggerExit _ -> Some ()
                    | _ -> None)
                  (equal_to ()));
           ];
       ])

(* ------------------------------------------------------------------ *)
(* skip_ids: a same-tick stop exit can still be tightened (documented)  *)
(* ------------------------------------------------------------------ *)

(** The tighten dial runs over every held position, not the survivors of the
    stops pass (no [skip_ids]). A position whose stop fires this tick is still
    [Holding] in [positions], so when it reads late Stage 2 and the candidate
    beats its stop the dial emits an [UpdateRiskParams] for it and writes the
    level. That is harmless and pinned as documented behaviour: the exit already
    fired and the position leaves; the strategy's transition assembly
    ([Transition_assembly.assemble_output], not exported from the library, so
    not exercised here) drops adjusts for exited ids, so only the exit reaches
    the output. The [stop_states] write is left behind for the exiting position
    and is never read again.

    Here the Initial 90 stop is hit by a bar with low 85; the close (95) gives a
    candidate of 95 * 0.95 = 90.25 > 90. *)
let test_same_tick_exit_still_tightened _ =
  let bar =
    { (make_bar 12 ~close:95.0 ()) with Types.Daily_price.low_price = 85.0 }
  in
  let get_price symbol =
    if String.equal symbol "AAPL" then Some bar else None
  in
  let positions = positions () in
  let stop_states = initial_states () in
  let prior_stages = Hashtbl.create (module String) in
  let exits, _adjusts =
    Stops_runner.update ~stops_config:Weinstein_stops.default_config
      ~stage_config ~lookback_bars:52 ~positions ~get_price ~stop_states
      ~bar_reader:(Bar_reader.empty ()) ~as_of:(week_date 12) ~prior_stages ()
  in
  Hashtbl.set prior_stages ~key:"AAPL"
    ~data:(Weinstein_types.Stage2 { weeks_advancing = 8; late = true });
  let tightens =
    Late_stage2_stop_runner.update ~buffer_pct ~is_screening_day:true
      ~stop_states ~positions ~get_price ~prior_stages
      ~current_date:(week_date 12)
  in
  assert_that
    (exits, tightens, Map.find !stop_states "AAPL")
    (all_of
       [
         field (fun (e, _, _) -> List.length e) (equal_to 1);
         field
           (fun (_, t, _) ->
             List.map t ~f:(fun (tr : Trading_strategy.Position.transition) ->
                 tr.position_id))
           (elements_are [ equal_to "AAPL" ]);
         field
           (fun (_, _, s) -> Option.map s ~f:Weinstein_stops.get_stop_level)
           (is_some_and (float_equal 90.25));
       ])

let suite =
  "late_stage2_tighten_ratchet"
  >::: [
         "fixture_stages" >:: test_fixture_stages;
         "initial_tighten_carried_into_trailing"
         >:: test_initial_tighten_carried_into_trailing;
         "weekly_ticks_never_lower_tightened_level"
         >:: test_weekly_ticks_never_lower_tightened_level;
         "crossing_bar_exits_after_ratchet"
         >:: test_crossing_bar_exits_after_ratchet;
         "same_tick_exit_still_tightened"
         >:: test_same_tick_exit_still_tightened;
       ]

let () = run_test_tt_main suite
