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

(** Convenience wrapper: single-symbol position + stage + price, returns the
    runner's transitions. [buffer_pct] defaults to a 5% tighten. *)
let run_single ?(buffer_pct = 0.05) ?(is_screening_day = true) ?stop ~stage
    ~close ~current_date ?(side = Trading_base.Types.Long) () =
  let pos = make_holding_pos ~side ?stop "AAPL" ~entry:100.0 ~date:friday in
  let positions = String.Map.singleton "AAPL" pos in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL" ~data:stage;
  Late_stage2_stop_runner.update ~buffer_pct ~is_screening_day ~positions
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
(* Test 3 — never-lowered: existing stop above candidate is preserved   *)
(* ------------------------------------------------------------------ *)

(** Candidate = 120 * 0.95 = 114. An existing stop already at 116 is higher, so
    the runner must NOT lower it — no transition is emitted. *)
let test_existing_higher_stop_not_lowered _ =
  let transitions =
    run_single ~buffer_pct:0.05 ~stop:116.0 ~stage:late_stage2 ~close:120.0
      ~current_date:friday ()
  in
  assert_that transitions is_empty

(** Candidate = 120 * 0.95 = 114. An existing stop at 110 is lower, so the
    runner raises it to 114. *)
let test_existing_lower_stop_raised _ =
  let transitions =
    run_single ~buffer_pct:0.05 ~stop:110.0 ~stage:late_stage2 ~close:120.0
      ~current_date:friday ()
  in
  assert_that transitions (elements_are [ raises_stop_to "AAPL" 114.0 ])

(* ------------------------------------------------------------------ *)
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
      ~positions:String.Map.empty ~get_price:(get_price_of [])
      ~prior_stages:(Hashtbl.create (module String))
      ~current_date:friday
  in
  assert_that transitions is_empty

let test_missing_stage_no_op _ =
  let pos = make_holding_pos "AAPL" ~entry:100.0 ~date:friday in
  let positions = String.Map.singleton "AAPL" pos in
  let transitions =
    Late_stage2_stop_runner.update ~buffer_pct:0.05 ~is_screening_day:true
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
         "non_friday_no_op" >:: test_non_friday_no_op;
         "short_side_no_tighten" >:: test_short_side_no_tighten;
         "empty_positions_no_op" >:: test_empty_positions_no_op;
         "missing_stage_no_op" >:: test_missing_stage_no_op;
         "missing_price_no_op" >:: test_missing_price_no_op;
       ]

let () = run_test_tt_main suite
