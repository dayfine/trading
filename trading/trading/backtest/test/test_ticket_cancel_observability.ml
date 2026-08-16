(** End-to-end regression for the G1 half of
    [dev/notes/ticket-death-on-cash-2026-08-16.md]: a resting entry ticket whose
    fill the {b portfolio} rejects must reach the [trade_audit.sexp] sink.

    Before this, {!Trading_simulation.Simulator._process_fills_and_cancels}
    computed its [CancelEntry] transitions and applied them {i locally}, while
    [_notify_transitions] only ever saw {!Trading_simulation.Margin_runner}'s
    output. The rejection cancels therefore never reached
    {!Backtest.Trade_audit.record_transitions}, so
    {!Backtest.Ticket_lifecycle.ticket_age_weeks_at_cancel} was written
    {b zero times in a whole run}: on a 2.5-year top-3000 diagnostic, 234
    placements resolved to 166 fills + 7 open and {b 61 (26%) nothing at all}. A
    reader could not tell "still resting at end of run" from "killed by a cash
    collision", which is exactly the question the AXTI 2025-06-27 ticket posed.

    The fixture is the minimum that reproduces it: one ticket sized past the
    portfolio's cash, so the engine fills it and
    {!Trading_simulation.Cancel_handler.apply_trades_best_effort} refuses it.

    Same wiring as {!Backtest.Panel_runner._make_simulator} and the sibling
    [test_trade_audit_external_exits.ml] — both [Stop_log.record_transitions]
    and [Trade_audit.record_transitions] composed onto one [on_transitions]
    closure — so what this asserts is what production writes. *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
module Position = Trading_strategy.Position
module Strategy_interface = Trading_strategy.Strategy_interface
module Cancel_handler = Trading_simulation.Cancel_handler
module TA = Backtest.Trade_audit
module TL = Backtest.Ticket_lifecycle

let _date s = Date.of_string s
let _symbol = "AAPL"
let _position_id = "AAPL-wein-1"
let _entry_date = _date "2024-01-02"

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

let _bars =
  [ "2024-01-02"; "2024-01-03"; "2024-01-04"; "2024-01-05" ]
  |> List.map ~f:(fun d -> _make_bar ~date:(_date d) ~close:100.0)

let _commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 }

let _config ~initial_cash =
  {
    Trading_simulation_types.Simulator_types.start_date = _date "2024-01-02";
    end_date = _date "2024-01-05";
    initial_cash;
    commission = _commission;
    strategy_cadence = Types.Cadence.Daily;
  }

(* One-shot strategy: emits a single [CreateEntering] for [quantity] shares on
   its first call with a bar, then holds passively. Whether that entry survives
   is entirely a function of [quantity] against the portfolio's cash, which is
   what each test below varies. *)
let _one_shot_strategy ~quantity : (module Strategy_interface.STRATEGY) =
  let entered = ref false in
  let module S : Strategy_interface.STRATEGY = struct
    let name = "OneShot"

    let on_market_close ~get_price ~get_indicator:_ ~portfolio:_ =
      if !entered then Ok { Strategy_interface.transitions = [] }
      else
        match get_price _symbol with
        | None -> Ok { Strategy_interface.transitions = [] }
        | Some (bar : Types.Daily_price.t) ->
            entered := true;
            Ok
              {
                Strategy_interface.transitions =
                  [
                    {
                      Position.position_id = _position_id;
                      date = bar.date;
                      kind =
                        CreateEntering
                          {
                            symbol = _symbol;
                            side = Position.Long;
                            target_quantity = quantity;
                            entry_price = bar.close_price;
                            reasoning =
                              TechnicalSignal
                                {
                                  indicator = "ticket-cancel-observability";
                                  description = "test entry";
                                };
                          };
                    };
                  ];
              }
  end
  in
  (module S)

(* The placement-time lifecycle record the real [Audit_recorder] would have
   written, anchored on the ticket's own placement date so a later cancel has
   something to measure an age against. *)
let _placement_lifecycle : TL.t =
  {
    placement_date = _entry_date;
    ticket_age_weeks_at_cancel = None;
    cancel_reason = None;
    ticket_age_weeks_at_fill = None;
    fill_volume = None;
    freshness_basis = TL.Ma_cross;
    sized_down_wide_stop = false;
    triple_confirmation =
      {
        breakout_volume_multiple = None;
        rs_zero_cross = false;
        in_base_advance_pct = None;
      };
  }

(* Minimal [entry_decision] seeded straight onto the collector, mirroring
   [test_trade_audit_external_exits.ml]: the synthetic strategy carries no
   [Audit_recorder], and the entry-capture wiring is pinned elsewhere. Only
   [symbol] / [position_id] / [ticket_lifecycle] are read here. *)
let _seed_entry trade_audit =
  TA.record_entry trade_audit
    {
      symbol = _symbol;
      entry_date = _entry_date;
      position_id = _position_id;
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
      suggested_entry = 100.0;
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
      ticket_lifecycle = Some _placement_lifecycle;
      alternatives_considered = [];
    }

(* Drive a real [Simulator.run] with the production [on_transitions]
   composition and return the drained lifecycle record for the one ticket. *)
let _lifecycle_after_run ~test_name ~initial_cash ~quantity =
  let stop_log = Backtest.Stop_log.create () in
  let trade_audit = TA.create () in
  _seed_entry trade_audit;
  let strategy =
    Backtest.Strategy_wrapper.wrap ~stop_log (_one_shot_strategy ~quantity)
  in
  let on_transitions ts =
    Backtest.Stop_log.record_transitions stop_log ts;
    TA.record_transitions trade_audit ts
  in
  Test_helpers.with_test_data test_name
    [ (_symbol, _bars) ]
    ~f:(fun data_dir ->
      let deps =
        create_deps ~symbols:[ _symbol ] ~data_dir ~strategy
          ~commission:_commission ~on_transitions ()
      in
      let sim =
        match create ~config:(_config ~initial_cash) ~deps with
        | Ok s -> s
        | Error e -> assert_failure ("create failed: " ^ Status.show e)
      in
      match run sim with
      | Ok _ -> ()
      | Error err -> assert_failure ("simulation failed: " ^ Status.show err));
  TA.get_audit_records trade_audit
  |> List.find ~f:(fun (r : TA.audit_record) ->
      String.equal r.entry.position_id _position_id)
  |> Option.bind ~f:(fun (r : TA.audit_record) -> r.entry.ticket_lifecycle)

(** A ticket the portfolio cannot fund resolves {b in the artifact}: the cancel
    age is stamped, and the reason names the cause as the fill rejection rather
    than either strategy-side clock. Ordering 1,000 shares at $100 against
    $5,000 of cash is the whole fixture. *)
let test_portfolio_rejected_fill_records_a_cancel _ =
  assert_that
    (_lifecycle_after_run ~test_name:"ticket_cancel_rejected"
       ~initial_cash:5_000.0 ~quantity:1_000.0)
    (is_some_and
       (all_of
          [
            field
              (fun (l : TL.t) -> l.ticket_age_weeks_at_cancel)
              (is_some_and (equal_to 0));
            field
              (fun (l : TL.t) -> l.cancel_reason)
              (is_some_and (equal_to Cancel_handler.portfolio_rejection_reason));
            field (fun (l : TL.t) -> l.ticket_age_weeks_at_fill) is_none;
          ]))

(** The negative control, and the reason this is a regression test rather than a
    tautology: the same ticket sized {i within} the portfolio's cash fills, and
    no cancel is recorded. Without this, a change that stamped a cancel on every
    ticket would pass the assertion above. *)
let test_affordable_fill_records_no_cancel _ =
  assert_that
    (_lifecycle_after_run ~test_name:"ticket_cancel_affordable"
       ~initial_cash:1_000_000.0 ~quantity:1_000.0)
    (is_some_and
       (all_of
          [
            field (fun (l : TL.t) -> l.ticket_age_weeks_at_cancel) is_none;
            field (fun (l : TL.t) -> l.cancel_reason) is_none;
          ]))

let suite =
  "ticket cancel observability"
  >::: [
         "a portfolio-rejected fill records a cancel in trade_audit"
         >:: test_portfolio_rejected_fill_records_a_cancel;
         "an affordable fill records no cancel"
         >:: test_affordable_fill_records_no_cancel;
       ]

let () = run_test_tt_main suite
