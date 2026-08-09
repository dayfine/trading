(** End-to-end regression for issue #2076: margin-driven exit reasons
    ([margin_call] / [buyin_stress] / [maintenance_reduce]) must also reach
    {!Backtest.Trade_audit} — the [trade_audit.sexp] sink — with a reason-only
    {!Backtest.Trade_audit.external_exit_decision}, the same way
    [trading/trading/simulation/test/test_margin_runner.ml] and
    [trading/trading/backtest/test/test_margin_exit_observability.ml] already
    pin the [trades.csv] / {!Backtest.Stop_log} sink for the same exits (#2057 /
    PR #2074).

    This file drives a real {!Trading_simulation.Simulator.run} with margin
    enabled and [on_transitions] wired to the EXACT composition
    {!Backtest.Panel_runner._make_simulator} uses in production — both
    [Stop_log.record_transitions] and [Trade_audit.record_transitions] on one
    closure — then asserts on {!Backtest.Trade_audit.get_audit_records}'s
    [external_exit] field, i.e. the value that ends up in [trade_audit.sexp].

    [Trade_audit.record_entry] is called directly on the collector before
    running (mirroring how the real [Audit_recorder] path would have already
    recorded an [entry_decision] for any position a margin exit later closes) —
    the synthetic one-shot strategy used here emits raw [Position.transition]s
    and does not itself carry an [Audit_recorder], so seeding the entry side
    directly is the correct minimal fixture; the actual entry-capture wiring is
    exercised elsewhere ([weinstein/strategy/test/test_exit_audit_capture.ml],
    [backtest/test/test_trade_audit_capture.ml]). *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
module Margin_config = Trading_portfolio.Margin_config
module Position = Trading_strategy.Position
module Strategy_interface = Trading_strategy.Strategy_interface
module TA = Backtest.Trade_audit

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
   [test_margin_exit_observability.ml:_make_one_shot_strategy]. *)
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
                            indicator = "trade-audit-external-exits-test";
                            description = "test entry";
                          };
                    };
              }
            in
            Ok { Strategy_interface.transitions = [ trans ] }
  end
  in
  (module S)

(* Minimal [entry_decision] fixture seeded directly on the collector — see
   module doc for why. Field values beyond [symbol] / [position_id] are
   arbitrary; [record_transitions]'s reason-only path only reads [symbol]. *)
let _seed_entry ~trade_audit ~symbol ~position_id ~entry_date =
  TA.record_entry trade_audit
    {
      symbol;
      entry_date;
      position_id;
      macro_trend = Weinstein_types.Bullish;
      macro_confidence = 0.7;
      macro_indicators = [];
      stage = Weinstein_types.Stage2 { weeks_advancing = 4; late = false };
      ma_direction = Weinstein_types.Rising;
      ma_slope_pct = 0.01;
      rs_trend = None;
      rs_value = None;
      volume_quality = None;
      volume_ratio = None;
      resistance_quality = None;
      support_quality = None;
      sector_name = "";
      sector_rating = Screener.Neutral;
      cascade_score = 0;
      cascade_grade = Weinstein_types.C;
      cascade_score_components = [];
      cascade_rationale = [];
      side = Trading_base.Types.Long;
      suggested_entry = 0.0;
      close_at_decision = None;
      ma_value = None;
      local_range_top = None;
      suggested_stop = 0.0;
      installed_stop = 0.0;
      stop_floor_kind = TA.Buffer_fallback;
      split_safe_basis = TA.Flag_off;
      risk_pct = 0.0;
      initial_position_value = 0.0;
      initial_risk_dollars = 0.0;
      alternatives_considered = [];
    }

(* Run a simulator with margin enabled, wiring [on_transitions] to the exact
   composition [Backtest.Panel_runner._make_simulator] uses in production:
   both [Stop_log.record_transitions] and [Trade_audit.record_transitions] on
   one closure, plus the [Backtest.Strategy_wrapper] interception. Returns the
   populated [trade_audit] collector. *)
let _run_and_collect_trade_audit ?(initial_long_margin_req = 1.0)
    ?(maintenance_long_pct = 0.0) ~test_name ~symbols_with_data ~strategy
    ~margin_config ~config ~position_id ~symbol ~entry_date () =
  let stop_log = Backtest.Stop_log.create () in
  let trade_audit = TA.create () in
  _seed_entry ~trade_audit ~symbol ~position_id ~entry_date;
  let wrapped_strategy = Backtest.Strategy_wrapper.wrap ~stop_log strategy in
  let on_transitions ts =
    Backtest.Stop_log.record_transitions stop_log ts;
    TA.record_transitions trade_audit ts
  in
  let result_ref = ref None in
  Test_helpers.with_test_data test_name symbols_with_data ~f:(fun data_dir ->
      let symbols = List.map symbols_with_data ~f:fst in
      let deps =
        create_deps ~symbols ~data_dir ~strategy:wrapped_strategy
          ~commission:config.commission ~margin_config ~initial_long_margin_req
          ~maintenance_long_pct ~on_transitions ()
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
  trade_audit

let _external_exit_trigger_for ~position_id trade_audit =
  TA.get_audit_records trade_audit
  |> List.find ~f:(fun (r : TA.audit_record) ->
      String.equal r.entry.position_id position_id)
  |> Option.bind ~f:(fun (r : TA.audit_record) -> r.external_exit)
  |> Option.map ~f:(fun (e : TA.external_exit_decision) -> e.exit_trigger)

let _assert_strategy_signal_label ~position_id ~expected_label trade_audit =
  assert_that
    (_external_exit_trigger_for ~position_id trade_audit)
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

(* Rising-price fixture from test_margin_runner.ml / test_margin_exit_
   observability.ml: entry at $50, climbs past the $60 maintenance trigger by
   day 4 (2024-01-05). *)
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

let test_trade_audit_records_margin_call_as_external_exit _ =
  let config =
    _config_for ~start_date:(_date "2024-01-02") ~end_date:(_date "2024-01-11")
      ~initial_cash:50_000.0
  in
  let strategy =
    _make_one_shot_strategy ~side:Position.Short ~symbol:"AAPL" ~quantity:100.0
      ~position_id:"AAPL-short"
  in
  let trade_audit =
    _run_and_collect_trade_audit ~test_name:"trade_audit_margin_call"
      ~symbols_with_data:[ ("AAPL", _aapl_rising_50_to_70) ]
      ~strategy ~margin_config:_on_config ~config ~position_id:"AAPL-short"
      ~symbol:"AAPL" ~entry_date:(_date "2024-01-02") ()
  in
  _assert_strategy_signal_label ~position_id:"AAPL-short"
    ~expected_label:"margin_call" trade_audit;
  (* No enriched [exit_] was ever recorded for this synthetic strategy — the
     margin exit is captured ONLY through the reason-only path. *)
  assert_that
    (TA.get_audit_records trade_audit
    |> List.find ~f:(fun (r : TA.audit_record) ->
        String.equal r.entry.position_id "AAPL-short"))
    (is_some_and (field (fun (r : TA.audit_record) -> r.exit_) is_none))

let suite =
  "trade_audit_external_exits"
  >::: [
         "trade_audit records margin_call as external_exit"
         >:: test_trade_audit_records_margin_call_as_external_exit;
       ]

let () = run_test_tt_main suite
