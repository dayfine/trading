open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let make_bar date ~close =
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = close;
    high_price = close *. 1.01;
    low_price = close *. 0.99;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

let late_stage2 = Weinstein_types.Stage2 { weeks_advancing = 12; late = true }
let early_stage2 = Weinstein_types.Stage2 { weeks_advancing = 5; late = false }
let stage1 = Weinstein_types.Stage1 { weeks_in_base = 4 }
let stage3 = Weinstein_types.Stage3 { weeks_topping = 1 }
let stage4 = Weinstein_types.Stage4 { weeks_declining = 2 }
let friday = Date.of_string "2024-01-05" (* Friday *)
let monday = Date.of_string "2024-01-08" (* Monday *)

(** Build a Holding {!Position.t} for [ticker] at [entry], optionally carrying
    an existing trailing stop at [?stop]. Mirrors the helper in
    [test_stage3_force_exit_runner.ml], adding the stop so the never-lowered
    invariant can be exercised. *)
let make_holding_pos ?(side = Trading_base.Types.Long) ?stop ticker ~entry ~date
    =
  let make_trans kind =
    { Trading_strategy.Position.position_id = ticker; date; kind }
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
              symbol = ticker;
              side;
              target_quantity = 10.0;
              entry_price = entry;
              reasoning = ManualDecision { description = "test" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans (EntryFill { filled_quantity = 10.0; fill_price = entry }))
    |> unwrap
  in
  apply_transition p
    (make_trans
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = stop;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

let get_price_of bars symbol = List.Assoc.find bars symbol ~equal:String.equal

(** Live stop state for AAPL at [level]. Defaults to an [Initial] stop at 90 —
    below every candidate the tests produce, so the tighten can fire unless a
    test sets a higher level. *)
let initial_stop ?(level = 90.0) () : Weinstein_stops.stop_state =
  Initial { stop_level = level; reference_level = level }

let stop_states_of state = ref (String.Map.singleton "AAPL" state)

(** Convenience wrapper: single-symbol position + stage + price, returns the
    runner's transitions. [buffer_pct] defaults to a 5% tighten. [?stop] is the
    position's [risk_params] stop; [?stop_states] is the live stop state the
    runner compares against and writes (default: an [Initial] stop at 90). *)
let run_single ?(buffer_pct = 0.05) ?(is_screening_day = true) ?stop
    ?(stop_states = stop_states_of (initial_stop ())) ~stage ~close
    ~current_date ?(side = Trading_base.Types.Long) () =
  let pos = make_holding_pos ~side ?stop "AAPL" ~entry:100.0 ~date:friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:stage;
  Late_stage2_stop_runner.update ~buffer_pct ~is_screening_day ~stop_states
    ~positions
    ~get_price:(get_price_of [ ("AAPL", make_bar "2024-01-05" ~close) ])
    ~prior_stages ~current_date

(** Matcher for an [UpdateRiskParams] transition raising [symbol]'s stop to
    [expected_stop]. *)
let raises_stop_to symbol expected_stop =
  all_of
    [
      field
        (fun (t : Trading_strategy.Position.transition) -> t.position_id)
        (equal_to symbol);
      matching ~msg:"Expected UpdateRiskParams with a stop"
        (function
          | Trading_strategy.Position.
              { kind = UpdateRiskParams { new_risk_params }; _ } ->
              new_risk_params.stop_loss_price
          | _ -> None)
        (float_equal expected_stop);
    ]

(* ------------------------------------------------------------------ *)
(* Test 1 — late Stage 2 long with no stop: tighten to close*(1-buffer) *)
(* ------------------------------------------------------------------ *)

(** A held late-Stage-2 long with no existing stop gets a tighten transition.
    With close=120 and a 5% buffer the new stop is 120*0.95 = 114, which is
    above the prior stop (none) and below the close by exactly the buffer. *)
let test_late_stage2_raises_stop _ =
  let transitions =
    run_single ~buffer_pct:0.05 ~stage:late_stage2 ~close:120.0
      ~current_date:friday ()
  in
  assert_that transitions (elements_are [ raises_stop_to "AAPL" 114.0 ])

(* ------------------------------------------------------------------ *)
(* Test 1b — tighten lands strictly below close (sanity on the band)    *)
(* ------------------------------------------------------------------ *)

(** The tightened stop sits strictly below the current close (114 < 120): the
    runner never raises the stop above the bar it is reacting to. *)
let test_tighten_below_close _ =
  let transitions =
    run_single ~buffer_pct:0.05 ~stage:late_stage2 ~close:120.0
      ~current_date:friday ()
  in
  let stop_of = function
    | Trading_strategy.Position.
        { kind = UpdateRiskParams { new_risk_params }; _ } ->
        new_risk_params.stop_loss_price
    | _ -> None
  in
  assert_that
    (List.hd transitions |> Option.bind ~f:stop_of)
    (is_some_and (lt (module Float_ord) 120.0))

(* ------------------------------------------------------------------ *)
(* Test 2 — control: non-late / other stages produce no transition      *)
(* ------------------------------------------------------------------ *)

let test_early_stage2_no_tighten _ =
  let transitions =
    run_single ~stage:early_stage2 ~close:120.0 ~current_date:friday ()
  in
  assert_that transitions is_empty

let test_stage1_no_tighten _ =
  let transitions =
    run_single ~stage:stage1 ~close:120.0 ~current_date:friday ()
  in
  assert_that transitions is_empty

let test_stage3_no_tighten _ =
  let transitions =
    run_single ~stage:stage3 ~close:120.0 ~current_date:friday ()
  in
  assert_that transitions is_empty

let test_stage4_no_tighten _ =
  let transitions =
    run_single ~stage:stage4 ~close:120.0 ~current_date:friday ()
  in
  assert_that transitions is_empty

(* ------------------------------------------------------------------ *)
(* Test 3 — never-lowered: compared against the live stop state         *)
(* ------------------------------------------------------------------ *)

(** Candidate = 120 * 0.95 = 114. A live stop already at 116 is higher, so the
    runner must NOT lower it — no transition is emitted. *)
let test_existing_higher_stop_not_lowered _ =
  let transitions =
    run_single ~buffer_pct:0.05 ~stop:116.0
      ~stop_states:(stop_states_of (initial_stop ~level:116.0 ()))
      ~stage:late_stage2 ~close:120.0 ~current_date:friday ()
  in
  assert_that transitions is_empty

(** Candidate = 120 * 0.95 = 114. A live stop at 110 is lower, so the runner
    raises it to 114. *)
let test_existing_lower_stop_raised _ =
  let transitions =
    run_single ~buffer_pct:0.05
      ~stop_states:(stop_states_of (initial_stop ~level:110.0 ()))
      ~stage:late_stage2 ~close:120.0 ~current_date:friday ()
  in
  assert_that transitions (elements_are [ raises_stop_to "AAPL" 114.0 ])

(** Issue #2983: the comparison reads the stop STATE, not [risk_params]. A
    Weinstein holding's [risk_params] stop is [None] until its first raise, and
    the state machine can tighten without touching [risk_params]. Here the state
    already sits at 116 while [risk_params] has no stop: the old [None -> true]
    branch would have "tightened" to 114 (a lowering in effect); the runner must
    emit nothing. *)
let test_compares_against_state_not_risk_params _ =
  let transitions =
    run_single ~buffer_pct:0.05
      ~stop_states:(stop_states_of (initial_stop ~level:116.0 ()))
      ~stage:late_stage2 ~close:120.0 ~current_date:friday ()
  in
  assert_that transitions is_empty

(** A holding with no entry in [stop_states] has no enforceable stop to tighten,
    so the runner emits nothing. *)
let test_missing_stop_state_no_op _ =
  let transitions =
    run_single ~stop_states:(ref String.Map.empty) ~stage:late_stage2
      ~close:120.0 ~current_date:friday ()
  in
  assert_that transitions is_empty

(** Issue #2983: the tightened level is written into [stop_states], keeping the
    state-machine phase and its tracking fields; only [stop_level] moves. *)
let test_writes_tightened_level_into_state _ =
  let trailing : Weinstein_stops.stop_state =
    Trailing
      {
        stop_level = 110.0;
        last_correction_extreme = 105.0;
        last_trend_extreme = 125.0;
        ma_at_last_adjustment = 100.0;
        correction_count = 1;
        correction_observed_since_reset = true;
      }
  in
  let stop_states = stop_states_of trailing in
  let _transitions : Trading_strategy.Position.transition list =
    run_single ~buffer_pct:0.05 ~stop_states ~stage:late_stage2 ~close:120.0
      ~current_date:friday ()
  in
  assert_that
    (Map.find !stop_states "AAPL")
    (is_some_and
       (equal_to
          (Trailing
             {
               stop_level = 114.0;
               last_correction_extreme = 105.0;
               last_trend_extreme = 125.0;
               ma_at_last_adjustment = 100.0;
               correction_count = 1;
               correction_observed_since_reset = true;
             }
            : Weinstein_stops.stop_state)))

(** Issue #2983 acceptance test: the tightened stop must actually fire. After
    the runner tightens 90 -> 114, a later bar whose low (113.5) crosses 114 but
    stays far above the old 90 stop triggers the stop check on the live state.
    Before the fix the state stayed at 90 and this bar did not trigger. *)
let test_tightened_level_triggers_exit _ =
  let stop_states = stop_states_of (initial_stop ~level:90.0 ()) in
  let _transitions : Trading_strategy.Position.transition list =
    run_single ~buffer_pct:0.05 ~stop_states ~stage:late_stage2 ~close:120.0
      ~current_date:friday ()
  in
  let next_bar =
    {
      (make_bar "2024-01-08" ~close:116.0) with
      Types.Daily_price.low_price = 113.5;
    }
  in
  assert_that
    (Map.find !stop_states "AAPL"
    |> Option.map ~f:(fun state ->
        Weinstein_stops.check_stop_hit ~state ~side:Trading_base.Types.Long
          ~bar:next_bar ()))
    (is_some_and (equal_to true))

(* Test 4 — cadence + side + empty controls                             *)
(* ------------------------------------------------------------------ *)

let test_non_friday_no_op _ =
  let transitions =
    run_single ~is_screening_day:false ~stage:late_stage2 ~close:120.0
      ~current_date:monday ()
  in
  assert_that transitions is_empty

let test_short_side_no_tighten _ =
  let transitions =
    run_single ~side:Trading_base.Types.Short ~stage:late_stage2 ~close:120.0
      ~current_date:friday ()
  in
  assert_that transitions is_empty

let test_empty_positions_no_op _ =
  let transitions =
    Late_stage2_stop_runner.update ~buffer_pct:0.05 ~is_screening_day:true
      ~stop_states:(ref String.Map.empty) ~positions:String.Map.empty
      ~get_price:(get_price_of [])
      ~prior_stages:(Hashtbl.create (module String))
      ~current_date:friday
  in
  assert_that transitions is_empty

let test_missing_stage_no_op _ =
  let pos = make_holding_pos "AAPL" ~entry:100.0 ~date:friday in
  let positions = String.Map.singleton "AAPL" pos in
  let transitions =
    Late_stage2_stop_runner.update ~buffer_pct:0.05 ~is_screening_day:true
      ~stop_states:(stop_states_of (initial_stop ()))
      ~positions
      ~get_price:(get_price_of [ ("AAPL", make_bar "2024-01-05" ~close:120.0) ])
      ~prior_stages:(Hashtbl.create (module String))
      ~current_date:friday
  in
  assert_that transitions is_empty

let test_missing_price_no_op _ =
  let pos = make_holding_pos "AAPL" ~entry:100.0 ~date:friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:late_stage2;
  let transitions =
    Late_stage2_stop_runner.update ~buffer_pct:0.05 ~is_screening_day:true
      ~stop_states:(stop_states_of (initial_stop ()))
      ~positions ~get_price:(get_price_of []) ~prior_stages ~current_date:friday
  in
  assert_that transitions is_empty

let suite =
  "late_stage2_stop_runner"
  >::: [
         "late_stage2_raises_stop" >:: test_late_stage2_raises_stop;
         "tighten_below_close" >:: test_tighten_below_close;
         "early_stage2_no_tighten" >:: test_early_stage2_no_tighten;
         "stage1_no_tighten" >:: test_stage1_no_tighten;
         "stage3_no_tighten" >:: test_stage3_no_tighten;
         "stage4_no_tighten" >:: test_stage4_no_tighten;
         "existing_higher_stop_not_lowered"
         >:: test_existing_higher_stop_not_lowered;
         "existing_lower_stop_raised" >:: test_existing_lower_stop_raised;
         "compares_against_state_not_risk_params"
         >:: test_compares_against_state_not_risk_params;
         "missing_stop_state_no_op" >:: test_missing_stop_state_no_op;
         "writes_tightened_level_into_state"
         >:: test_writes_tightened_level_into_state;
         "tightened_level_triggers_exit" >:: test_tightened_level_triggers_exit;
         "non_friday_no_op" >:: test_non_friday_no_op;
         "short_side_no_tighten" >:: test_short_side_no_tighten;
         "empty_positions_no_op" >:: test_empty_positions_no_op;
         "missing_stage_no_op" >:: test_missing_stage_no_op;
         "missing_price_no_op" >:: test_missing_price_no_op;
       ]

let () = run_test_tt_main suite
