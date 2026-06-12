(** Unit tests for {!Warmup_trade_gate}.

    Pins the no-op-default contract and the suppression behaviour:

    - [suppress = false] (default) → identity: the transition list is returned
      unchanged, so every existing golden/baseline replays bit-identically.
    - [suppress = true] → [CreateEntering] transitions dated strictly before
      [start_date] are dropped (both long and short); those dated on/after
      [start_date] are retained; non-entry transitions (exits, fills, risk-param
      updates) are never dropped regardless of date.
    - [wrap_strategy] threads the gate through a strategy's output. *)

open OUnit2
open Core
open Trading_strategy
open Matchers

let start_date = Date.of_string "2010-01-01"
let before = Date.of_string "2009-06-26" (* in the warmup window *)
let after = Date.of_string "2010-03-01" (* in the measurement window *)

(* ------------------------------------------------------------------ *)
(* Transition builders — only the load-bearing fields vary.            *)
(* ------------------------------------------------------------------ *)

let entry ~position_id ~date ~side : Position.transition =
  {
    position_id;
    date;
    kind =
      Position.CreateEntering
        {
          symbol = position_id;
          side;
          target_quantity = 100.0;
          entry_price = 50.0;
          reasoning = Position.ManualDecision { description = "test" };
        };
  }

let exit_ ~position_id ~date : Position.transition =
  {
    position_id;
    date;
    kind =
      Position.TriggerExit
        {
          exit_reason =
            Position.StrategySignal { label = "exit"; detail = None };
          exit_price = 60.0;
        };
  }

let risk_update ~position_id ~date : Position.transition =
  {
    position_id;
    date;
    kind =
      Position.UpdateRiskParams
        {
          new_risk_params =
            {
              stop_loss_price = Some 45.0;
              take_profit_price = None;
              max_hold_days = None;
            };
        };
  }

let ids ts = List.map ts ~f:(fun (t : Position.transition) -> t.position_id)

(* ------------------------------------------------------------------ *)
(* filter_transitions                                                   *)
(* ------------------------------------------------------------------ *)

(** Default [suppress = false] is a no-op: even a warmup-dated entry survives.
*)
let test_suppress_false_is_noop _ =
  let transitions =
    [
      entry ~position_id:"WARMUP" ~date:before ~side:Long;
      entry ~position_id:"INWINDOW" ~date:after ~side:Long;
    ]
  in
  let result =
    Warmup_trade_gate.filter_transitions ~suppress:false ~start_date transitions
  in
  assert_that (ids result)
    (elements_are [ equal_to "WARMUP"; equal_to "INWINDOW" ])

(** [suppress = true] drops a warmup-dated entry, keeps an in-window entry. *)
let test_suppress_true_drops_warmup_entry _ =
  let transitions =
    [
      entry ~position_id:"WARMUP" ~date:before ~side:Long;
      entry ~position_id:"INWINDOW" ~date:after ~side:Long;
    ]
  in
  let result =
    Warmup_trade_gate.filter_transitions ~suppress:true ~start_date transitions
  in
  assert_that (ids result) (elements_are [ equal_to "INWINDOW" ])

(** Boundary is inclusive: an entry dated exactly on [start_date] is retained
    ([< start_date] drops, [>= start_date] keeps). *)
let test_boundary_entry_is_retained _ =
  let transitions =
    [ entry ~position_id:"BOUNDARY" ~date:start_date ~side:Long ]
  in
  let result =
    Warmup_trade_gate.filter_transitions ~suppress:true ~start_date transitions
  in
  assert_that (ids result) (elements_are [ equal_to "BOUNDARY" ])

(** Short warmup entries are suppressed too — the gate is side-agnostic. *)
let test_suppress_true_drops_warmup_short_entry _ =
  let transitions =
    [
      entry ~position_id:"WARMUP_SHORT" ~date:before ~side:Short;
      entry ~position_id:"INWINDOW_SHORT" ~date:after ~side:Short;
    ]
  in
  let result =
    Warmup_trade_gate.filter_transitions ~suppress:true ~start_date transitions
  in
  assert_that (ids result) (elements_are [ equal_to "INWINDOW_SHORT" ])

(** Non-entry transitions (exits, risk-param updates) dated in the warmup window
    are NEVER dropped — only [CreateEntering] is suppressed. *)
let test_non_entry_transitions_are_never_dropped _ =
  let transitions =
    [
      entry ~position_id:"WARMUP_ENTRY" ~date:before ~side:Long;
      exit_ ~position_id:"HELD" ~date:before;
      risk_update ~position_id:"HELD" ~date:before;
    ]
  in
  let result =
    Warmup_trade_gate.filter_transitions ~suppress:true ~start_date transitions
  in
  (* The warmup entry is dropped; the warmup-dated exit + risk-update survive. *)
  assert_that (ids result) (elements_are [ equal_to "HELD"; equal_to "HELD" ])

(* ------------------------------------------------------------------ *)
(* wrap_strategy                                                        *)
(* ------------------------------------------------------------------ *)

let stub_strategy transitions =
  (module struct
    let name = "Stub"

    let on_market_close ~get_price:_ ~get_indicator:_ ~portfolio:_ =
      Ok { Strategy_interface.transitions }
  end : Strategy_interface.STRATEGY)

let empty_portfolio : Portfolio_view.t =
  { Portfolio_view.cash = 100000.0; positions = Map.empty (module String) }

let run_wrapped ~suppress transitions =
  let module W =
    (val Warmup_trade_gate.wrap_strategy ~suppress ~start_date
           (stub_strategy transitions)
        : Strategy_interface.STRATEGY)
  in
  W.on_market_close
    ~get_price:(fun _ -> None)
    ~get_indicator:(fun _ _ _ _ -> None)
    ~portfolio:empty_portfolio

(** With [suppress = true] the wrapped strategy drops the warmup-dated entry but
    keeps the warmup-dated exit. *)
let test_wrap_suppress_true_drops_entry_keeps_exit _ =
  let transitions =
    [
      entry ~position_id:"WARMUP_ENTRY" ~date:before ~side:Long;
      exit_ ~position_id:"HELD" ~date:before;
    ]
  in
  assert_that
    (run_wrapped ~suppress:true transitions)
    (is_ok_and_holds
       (field
          (fun (o : Strategy_interface.output) -> ids o.transitions)
          (elements_are [ equal_to "HELD" ])))

(** With [suppress = false] the wrapped strategy is the identity: both the
    warmup-dated entry and exit pass through (the no-op default). *)
let test_wrap_suppress_false_is_identity _ =
  let transitions =
    [
      entry ~position_id:"WARMUP_ENTRY" ~date:before ~side:Long;
      exit_ ~position_id:"HELD" ~date:before;
    ]
  in
  assert_that
    (run_wrapped ~suppress:false transitions)
    (is_ok_and_holds
       (field
          (fun (o : Strategy_interface.output) -> ids o.transitions)
          (elements_are [ equal_to "WARMUP_ENTRY"; equal_to "HELD" ])))

let () =
  run_test_tt_main
    ("warmup_trade_gate"
    >::: [
           "suppress=false is a no-op" >:: test_suppress_false_is_noop;
           "suppress=true drops warmup entry"
           >:: test_suppress_true_drops_warmup_entry;
           "boundary entry on start_date is retained"
           >:: test_boundary_entry_is_retained;
           "suppress=true drops warmup short entry"
           >:: test_suppress_true_drops_warmup_short_entry;
           "non-entry transitions are never dropped"
           >:: test_non_entry_transitions_are_never_dropped;
           "wrap suppress=true drops entry keeps exit"
           >:: test_wrap_suppress_true_drops_entry_keeps_exit;
           "wrap suppress=false is identity"
           >:: test_wrap_suppress_false_is_identity;
         ])
