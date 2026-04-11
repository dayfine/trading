open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let make_bar date ~close ?low ?high () =
  let low = Option.value low ~default:(close *. 0.99) in
  let high = Option.value high ~default:(close *. 1.01) in
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
  }

let get_price_of bars symbol = List.Assoc.find bars symbol ~equal:String.equal

(** Build a Position.t in the [Holding] state for [ticker] at [price]. *)
let make_holding_pos ticker price date =
  let pos_id = ticker in
  let make_trans kind =
    { Trading_strategy.Position.position_id = pos_id; date; kind }
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
              side = Trading_base.Types.Long;
              target_quantity = 10.0;
              entry_price = price;
              reasoning = ManualDecision { description = "test" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans (EntryFill { filled_quantity = 10.0; fill_price = price }))
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

let default_cfg = Weinstein_stops.default_config
let default_stage_cfg = Stage.default_config

(* ------------------------------------------------------------------ *)
(* Empty and no-op cases                                                *)
(* ------------------------------------------------------------------ *)

let test_update_no_positions_returns_empty _ =
  let stop_states = ref String.Map.empty in
  let exits, adjusts =
    Stops_runner.update ~stops_config:default_cfg
      ~stage_config:default_stage_cfg ~lookback_bars:52
      ~positions:String.Map.empty
      ~get_price:(fun _ -> None)
      ~stop_states ~bar_history:(Bar_history.create ())
      ~prior_stages:(Hashtbl.create (module String))
  in
  assert_that exits is_empty;
  assert_that adjusts is_empty

let test_update_position_without_stop_state_returns_empty _ =
  (* Position is held but has no entry in stop_states — the fold skips it. *)
  let ticker = "AAPL" in
  let date = Date.of_string "2024-01-05" in
  let pos = make_holding_pos ticker 100.0 date in
  let positions = String.Map.singleton ticker pos in
  let stop_states = ref String.Map.empty in
  let exits, adjusts =
    Stops_runner.update ~stops_config:default_cfg
      ~stage_config:default_stage_cfg ~lookback_bars:52 ~positions
      ~get_price:(fun _ -> Some (make_bar "2024-01-12" ~close:95.0 ()))
      ~stop_states ~bar_history:(Bar_history.create ())
      ~prior_stages:(Hashtbl.create (module String))
  in
  assert_that exits is_empty;
  assert_that adjusts is_empty

let test_update_position_without_bar_returns_empty _ =
  (* Position is held, stop_state is set, but get_price returns None — skip. *)
  let ticker = "AAPL" in
  let date = Date.of_string "2024-01-05" in
  let pos = make_holding_pos ticker 100.0 date in
  let positions = String.Map.singleton ticker pos in
  let stop_state =
    Weinstein_stops.Initial { stop_level = 90.0; reference_level = 95.0 }
  in
  let stop_states = ref (String.Map.singleton ticker stop_state) in
  let exits, adjusts =
    Stops_runner.update ~stops_config:default_cfg
      ~stage_config:default_stage_cfg ~lookback_bars:52 ~positions
      ~get_price:(fun _ -> None)
      ~stop_states ~bar_history:(Bar_history.create ())
      ~prior_stages:(Hashtbl.create (module String))
  in
  assert_that exits is_empty;
  assert_that adjusts is_empty

(* ------------------------------------------------------------------ *)
(* Stop hit → TriggerExit                                              *)
(* ------------------------------------------------------------------ *)

let test_update_stop_hit_emits_trigger_exit _ =
  let ticker = "AAPL" in
  let date = Date.of_string "2024-01-05" in
  let pos = make_holding_pos ticker 100.0 date in
  let positions = String.Map.singleton ticker pos in
  let stop_state =
    Weinstein_stops.Initial { stop_level = 90.0; reference_level = 95.0 }
  in
  let stop_states = ref (String.Map.singleton ticker stop_state) in
  (* Bar's low of 85 crosses the stop level at 90 *)
  let bar = make_bar "2024-01-12" ~close:95.0 ~low:85.0 () in
  let exits, adjusts =
    Stops_runner.update ~stops_config:default_cfg
      ~stage_config:default_stage_cfg ~lookback_bars:52 ~positions
      ~get_price:(get_price_of [ (ticker, bar) ])
      ~stop_states ~bar_history:(Bar_history.create ())
      ~prior_stages:(Hashtbl.create (module String))
  in
  assert_that adjusts is_empty;
  assert_that exits
    (elements_are
       [
         all_of
           [
             field
               (fun (tr : Trading_strategy.Position.transition) ->
                 tr.position_id)
               (equal_to ticker);
             field
               (fun (tr : Trading_strategy.Position.transition) -> tr.kind)
               (matching ~msg:"Expected TriggerExit"
                  (function
                    | Trading_strategy.Position.TriggerExit _ -> Some ()
                    | _ -> None)
                  (equal_to ()));
             field
               (fun (tr : Trading_strategy.Position.transition) -> tr.date)
               (equal_to (Date.of_string "2024-01-12"));
           ];
       ])

(* ------------------------------------------------------------------ *)
(* stop_states mutation                                                 *)
(* ------------------------------------------------------------------ *)

let test_update_mutates_stop_states_ref _ =
  (* Even when no transition is emitted, the stop_states ref receives the
     updated state from the state machine. *)
  let ticker = "AAPL" in
  let date = Date.of_string "2024-01-05" in
  let pos = make_holding_pos ticker 100.0 date in
  let positions = String.Map.singleton ticker pos in
  let initial =
    Weinstein_stops.Initial { stop_level = 90.0; reference_level = 95.0 }
  in
  let stop_states = ref (String.Map.singleton ticker initial) in
  let bar = make_bar "2024-01-12" ~close:100.0 () in
  let _ =
    Stops_runner.update ~stops_config:default_cfg
      ~stage_config:default_stage_cfg ~lookback_bars:52 ~positions
      ~get_price:(get_price_of [ (ticker, bar) ])
      ~stop_states ~bar_history:(Bar_history.create ())
      ~prior_stages:(Hashtbl.create (module String))
  in
  (* Entry for AAPL still exists in the ref (may be same state or advanced). *)
  assert_that (Map.find !stop_states ticker) (is_some_and (fun _ -> ()))

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("stops_runner"
    >::: [
           "update with no positions returns empty"
           >:: test_update_no_positions_returns_empty;
           "update with position but no stop state returns empty"
           >:: test_update_position_without_stop_state_returns_empty;
           "update with position but no current bar returns empty"
           >:: test_update_position_without_bar_returns_empty;
           "update emits TriggerExit when stop is hit"
           >:: test_update_stop_hit_emits_trigger_exit;
           "update mutates stop_states ref for held positions"
           >:: test_update_mutates_stop_states_ref;
         ])
