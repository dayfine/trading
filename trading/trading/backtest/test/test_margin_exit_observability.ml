(** End-to-end regression for issue #2057: margin-driven exit reasons
    ([margin_call] / [buyin_stress] / [maintenance_reduce]) must reach
    {!Backtest.Stop_log} — the collector [Result_writer] reads to populate
    [trades.csv]'s [exit_trigger] column — with the same fidelity as
    strategy-emitted [StrategySignal] exits.

    [trading/trading/simulation/test/test_margin_runner.ml] pins the same fix at
    the [Simulator.dependencies.on_transitions] hook directly (checking the raw
    [Position.transition] list). This file pins it one layer up, using the EXACT
    composition [Backtest.Panel_runner] wires in production —
    [Simulator.create_deps ~on_transitions:(Stop_log.record_transitions
     stop_log)] — and asserts on {!Backtest.Stop_log.get_stop_infos}'s
    [exit_trigger] field, i.e. the value [Result_writer] actually reads. A full
    [Runner.run_backtest] fixture (real Weinstein strategy config + universe +
    screener panels) is not needed to pin this: the bug is in the plumbing
    between the simulator and the collector, not in the Weinstein strategy or
    the margin math themselves (both already independently tested — see
    [test_margin_runner.ml] and [test_long_maintenance.ml]).

    Also pins the same-tick strategy/margin collision case (QC rework, PR
    #2074): [test_stop_log_records_margin_call_on_strategy_collision] proves the
    later [on_transitions] call overwrites the wrapper's stale strategy-side
    trigger with the winning margin label — see that test's header comment for
    why last-writer-wins is the correct semantic here, not a misattribution. *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
module Margin_config = Trading_portfolio.Margin_config
module Position = Trading_strategy.Position
module Strategy_interface = Trading_strategy.Strategy_interface

let _date s = Date.of_string s

let _make_bar ~date ~close =
  Types.Daily_price.
    {
      date;
      open_price = close;
      high_price = close;
      low_price = close;
      close_price = close;
      adjusted_close = close;
      volume = 1_000_000;
      active_through = None;
    }

let _commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 }

let _config_for ~start_date ~end_date ~initial_cash =
  {
    Trading_simulation_types.Simulator_types.start_date;
    end_date;
    initial_cash;
    commission = _commission;
    strategy_cadence = Types.Cadence.Daily;
  }

(* One-shot strategy: emits a single [CreateEntering] on its first call with a
   bar, then holds passively forever. Mirrors
   [test_margin_runner.ml:_make_one_shot_strategy]. *)
let _make_one_shot_strategy ~side ~symbol ~quantity ~position_id :
    (module Strategy_interface.STRATEGY) =
  let entered = ref false in
  let module S : Strategy_interface.STRATEGY = struct
    let name = "OneShot"

    let on_market_close ~get_price ~get_indicator:_ ~portfolio:_ =
      if !entered then Ok { Strategy_interface.transitions = [] }
      else
        match get_price symbol with
        | None -> Ok { Strategy_interface.transitions = [] }
        | Some (bar : Types.Daily_price.t) ->
            entered := true;
            let open Position in
            let trans =
              {
                position_id;
                date = bar.date;
                kind =
                  CreateEntering
                    {
                      symbol;
                      side;
                      target_quantity = quantity;
                      entry_price = bar.close_price;
                      reasoning =
                        TechnicalSignal
                          {
                            indicator = "margin-exit-observability-test";
                            description = "test entry";
                          };
                    };
              }
            in
            Ok { Strategy_interface.transitions = [ trans ] }
  end
  in
  (module S)

(* Run a simulator with margin enabled, wiring [on_transitions] to
   [Stop_log.record_transitions stop_log] exactly as
   [Backtest.Panel_runner._make_simulator] does, plus the
   [Backtest.Strategy_wrapper] interception, to prove the two recording paths
   compose correctly. Returns the populated [stop_log]. *)
let _run_and_collect_stop_log ?(initial_long_margin_req = 1.0)
    ?(maintenance_long_pct = 0.0) ~test_name ~symbols_with_data ~strategy
    ~margin_config ~config () =
  let stop_log = Backtest.Stop_log.create () in
  let wrapped_strategy = Backtest.Strategy_wrapper.wrap ~stop_log strategy in
  let result_ref = ref None in
  Test_helpers.with_test_data test_name symbols_with_data ~f:(fun data_dir ->
      let symbols = List.map symbols_with_data ~f:fst in
      let deps =
        create_deps ~symbols ~data_dir ~strategy:wrapped_strategy
          ~commission:config.commission ~margin_config ~initial_long_margin_req
          ~maintenance_long_pct
          ~on_transitions:(Backtest.Stop_log.record_transitions stop_log)
          ()
      in
      let sim =
        match create ~config ~deps with
        | Ok s -> s
        | Error e -> assert_failure ("create failed: " ^ Status.show e)
      in
      match run sim with
      | Ok r -> result_ref := Some r
      | Error err -> assert_failure ("simulation failed: " ^ Status.show err));
  ignore !result_ref;
  stop_log

let _exit_trigger_for ~position_id stop_log =
  Backtest.Stop_log.get_stop_infos stop_log
  |> List.find ~f:(fun (i : Backtest.Stop_log.stop_info) ->
      String.equal i.position_id position_id)
  |> Option.bind ~f:(fun (i : Backtest.Stop_log.stop_info) -> i.exit_trigger)

let _assert_strategy_signal_label ~position_id ~expected_label stop_log =
  assert_that
    (_exit_trigger_for ~position_id stop_log)
    (is_some_and
       (matching
          ~msg:("Strategy_signal " ^ expected_label)
          (function
            | Backtest.Stop_log.Strategy_signal { label; _ }
              when String.equal label expected_label ->
                Some ()
            | _ -> None)
          (equal_to ())))

let _on_config = { Margin_config.default_config with enabled = true }

(* Rising-price fixture from test_margin_runner.ml: entry at $50, climbs past
   the $60 maintenance trigger by day 4 (2024-01-05). *)
let _aapl_rising_50_to_70 =
  [
    _make_bar ~date:(_date "2024-01-02") ~close:50.0;
    _make_bar ~date:(_date "2024-01-03") ~close:52.0;
    _make_bar ~date:(_date "2024-01-04") ~close:58.0;
    _make_bar ~date:(_date "2024-01-05") ~close:65.0;
    _make_bar ~date:(_date "2024-01-08") ~close:68.0;
    _make_bar ~date:(_date "2024-01-09") ~close:70.0;
    _make_bar ~date:(_date "2024-01-10") ~close:70.0;
  ]

let test_stop_log_records_margin_call _ =
  let config =
    _config_for ~start_date:(_date "2024-01-02") ~end_date:(_date "2024-01-11")
      ~initial_cash:50_000.0
  in
  let strategy =
    _make_one_shot_strategy ~side:Position.Short ~symbol:"AAPL" ~quantity:100.0
      ~position_id:"AAPL-short"
  in
  let stop_log =
    _run_and_collect_stop_log ~test_name:"stop_log_margin_call"
      ~symbols_with_data:[ ("AAPL", _aapl_rising_50_to_70) ]
      ~strategy ~margin_config:_on_config ~config ()
  in
  _assert_strategy_signal_label ~position_id:"AAPL-short"
    ~expected_label:"margin_call" stop_log

let _aapl_flat_10 =
  List.map
    [
      "2024-01-02";
      "2024-01-03";
      "2024-01-04";
      "2024-01-05";
      "2024-01-08";
      "2024-01-09";
      "2024-01-10";
    ] ~f:(fun d -> _make_bar ~date:(_date d) ~close:10.0)

let _buyin_only_config =
  {
    Margin_config.default_config with
    Margin_config.short_buyin_stress_mode = true;
    short_buyin_htb_price_below = 20.0;
  }

let test_stop_log_records_buyin_stress _ =
  let config =
    _config_for ~start_date:(_date "2024-01-02") ~end_date:(_date "2024-01-10")
      ~initial_cash:50_000.0
  in
  let strategy =
    _make_one_shot_strategy ~side:Position.Short ~symbol:"AAPL" ~quantity:100.0
      ~position_id:"AAPL-short"
  in
  let stop_log =
    _run_and_collect_stop_log ~test_name:"stop_log_buyin_stress"
      ~symbols_with_data:[ ("AAPL", _aapl_flat_10) ]
      ~strategy ~margin_config:_buyin_only_config ~config ()
  in
  _assert_strategy_signal_label ~position_id:"AAPL-short"
    ~expected_label:"buyin_stress" stop_log

(* Flat-$50 fixture from test_margin_runner.ml, spanning Friday 2024-01-05. *)
let _aapl_flat_50 =
  List.map
    [
      "2024-01-02";
      "2024-01-03";
      "2024-01-04";
      "2024-01-05";
      "2024-01-08";
      "2024-01-09";
      "2024-01-10";
      "2024-01-11";
      "2024-01-12";
      "2024-01-15";
    ] ~f:(fun d -> _make_bar ~date:(_date d) ~close:50.0)

let test_stop_log_records_maintenance_reduce _ =
  let config =
    _config_for ~start_date:(_date "2024-01-02") ~end_date:(_date "2024-01-15")
      ~initial_cash:10_000.0
  in
  let strategy =
    _make_one_shot_strategy ~side:Position.Long ~symbol:"AAPL" ~quantity:300.0
      ~position_id:"AAPL-long"
  in
  let stop_log =
    _run_and_collect_stop_log ~initial_long_margin_req:0.5
      ~maintenance_long_pct:0.9 ~test_name:"stop_log_maintenance_reduce"
      ~symbols_with_data:[ ("AAPL", _aapl_flat_50) ]
      ~strategy ~margin_config:Margin_config.default_config ~config ()
  in
  _assert_strategy_signal_label ~position_id:"AAPL-long"
    ~expected_label:"maintenance_reduce" stop_log

(* ------------------------------------------------------------------ *)
(* Collision regression (QC rework, PR #2074): the PR body / a         *)
(* [panel_runner.ml] comment claim that on a same-tick strategy/margin *)
(* collision, the later [on_transitions] call correctly overwrites the *)
(* [Strategy_wrapper]-recorded stale strategy-side trigger with the     *)
(* winning margin label. That claim had zero test coverage — this test *)
(* pins it through the exact [Stop_log.record_transitions] composition *)
(* [Panel_runner] wires, reusing the collision fixture from             *)
(* [test_margin_runner.ml:_short_then_stop_strategy] /                  *)
(* [test_e2e_strategy_exit_collides_with_margin_call].                  *)
(*                                                                      *)
(* Why margin winning is the CORRECT semantic, not a misattribution:    *)
(* [Margin_runner.dedup_strategy_exits_for_margin] drops the strategy's *)
(* colliding [TriggerExit] from [strategy_transitions] entirely before  *)
(* [_apply_transitions] runs — so the strategy's stop-loss never        *)
(* executes; only margin's [TriggerExit] does. [Stop_log]'s exit_trigger*)
(* must reflect what actually closed the position, so the margin label  *)
(* overwriting the wrapper's premature (never-applied) strategy label   *)
(* is the right outcome, not a race. *)

(* Short entered at $50 on day 1; emits a stop-loss [TriggerExit] once
   price crosses [stop_trigger_price]. [stop_trigger_price = 60.0] is
   exactly the maintenance-margin trigger for a $50 short under default
   config (50% IM / 25% MM), so on the rising fixture (50->70) both the
   strategy's stop-loss and margin's maintenance call fire on the same
   bar (day 4, close $65). Mirrors
   [test_margin_runner.ml:_short_then_stop_strategy]. *)
let _short_then_stop_strategy ~symbol ~quantity ~position_id ~stop_trigger_price
    : (module Strategy_interface.STRATEGY) =
  let entered = ref false in
  let exited = ref false in
  let module S : Strategy_interface.STRATEGY = struct
    let name = "ShortThenStop"

    let on_market_close ~get_price ~get_indicator:_ ~portfolio:_ =
      match get_price symbol with
      | None -> Ok { Strategy_interface.transitions = [] }
      | Some (bar : Types.Daily_price.t) ->
          if not !entered then (
            entered := true;
            let open Position in
            let trans =
              {
                position_id;
                date = bar.date;
                kind =
                  CreateEntering
                    {
                      symbol;
                      side = Position.Short;
                      target_quantity = quantity;
                      entry_price = bar.close_price;
                      reasoning =
                        TechnicalSignal
                          {
                            indicator = "margin-exit-observability-collision";
                            description = "short for collision test";
                          };
                    };
              }
            in
            Ok { Strategy_interface.transitions = [ trans ] })
          else if (not !exited) && Float.(bar.close_price >= stop_trigger_price)
          then (
            exited := true;
            let open Position in
            let trans =
              {
                position_id;
                date = bar.date;
                kind =
                  TriggerExit
                    {
                      exit_reason =
                        StopLoss
                          {
                            stop_price = stop_trigger_price;
                            actual_price = bar.close_price;
                            loss_percent =
                              (stop_trigger_price -. bar.close_price)
                              /. stop_trigger_price *. 100.0;
                          };
                      exit_price = bar.close_price;
                    };
              }
            in
            Ok { Strategy_interface.transitions = [ trans ] })
          else Ok { Strategy_interface.transitions = [] }
  end
  in
  (module S)

let test_stop_log_records_margin_call_on_strategy_collision _ =
  let config =
    _config_for ~start_date:(_date "2024-01-02") ~end_date:(_date "2024-01-11")
      ~initial_cash:50_000.0
  in
  let strategy =
    _short_then_stop_strategy ~symbol:"AAPL" ~quantity:100.0
      ~position_id:"AAPL-short" ~stop_trigger_price:60.0
  in
  let stop_log =
    _run_and_collect_stop_log ~test_name:"stop_log_margin_strategy_collide"
      ~symbols_with_data:[ ("AAPL", _aapl_rising_50_to_70) ]
      ~strategy ~margin_config:_on_config ~config ()
  in
  (* Must be the margin label, NOT [Stop_loss] — proving [on_transitions]'s
     later call overwrote the wrapper's stale strategy-side trigger. *)
  _assert_strategy_signal_label ~position_id:"AAPL-short"
    ~expected_label:"margin_call" stop_log

let suite =
  "margin_exit_observability"
  >::: [
         "stop_log records margin_call" >:: test_stop_log_records_margin_call;
         "stop_log records buyin_stress" >:: test_stop_log_records_buyin_stress;
         "stop_log records maintenance_reduce"
         >:: test_stop_log_records_maintenance_reduce;
         "stop_log records margin_call on strategy collision (overwrites stale \
          strategy trigger)"
         >:: test_stop_log_records_margin_call_on_strategy_collision;
       ]

let () = run_test_tt_main suite
