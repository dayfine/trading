(** Stop fill vs same-day margin exit precedence (issue #3206).

    With same-bar stop fills armed ([sim_stop_exit_fill_on_trigger_bar]), a
    [StopLoss] exit trades intraday on its trigger bar, before the close-time
    maintenance check. [sim_stop_fill_beats_margin_cover] lets that stop win a
    same-day collision with a margin exit for the same position; at its default
    ([false]) the #1266 precedence (margin wins) is unchanged. *)

open OUnit2
open Core
open Matchers
open Test_helpers
module Margin_config = Trading_portfolio.Margin_config
module Portfolio = Trading_portfolio.Portfolio
module Portfolio_margin = Trading_portfolio.Portfolio_margin
module Position = Trading_strategy.Position
module Strategy_interface = Trading_strategy.Strategy_interface
module Simulator = Trading_simulation.Simulator

let _date = Date.of_string
let _friday = _date "2024-01-05"
let _on_config = { Margin_config.default_config with enabled = true }

(* ------------------------------------------------------------------ *)
(* Tick-level fixtures                                                 *)
(* ------------------------------------------------------------------ *)

let _engine_bar ~symbol ~low ~high ~close =
  {
    Trading_engine.Types.symbol;
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
  }

(* A margin-enabled portfolio short 100 SQZ at $10. Under default 50% IM /
   25% MM the cover trigger is $12, so a $15 close breaches maintenance. *)
let _short_portfolio () =
  match
    Portfolio_margin.apply_trades_with_margin ~margin_config:_on_config
      (Portfolio.create ~initial_cash:30_000.0 ())
      [
        {
          Trading_base.Types.id = "t1";
          order_id = "o1";
          symbol = "SQZ";
          side = Trading_base.Types.Sell;
          quantity = 100.0;
          price = 10.0;
          commission = 0.0;
          timestamp = Time_ns_unix.epoch;
        };
      ]
  with
  | Ok p -> p
  | Error err -> assert_failure ("short portfolio: " ^ Status.show err)

let _unwrap = function Ok p -> p | Error _ -> assert_failure "setup failed"

(* Holding short Position.t for SQZ; position_id = symbol. *)
let _holding_short () =
  let tr kind = { Position.position_id = "SQZ"; date = _friday; kind } in
  let open Position in
  let entering =
    create_entering
      (tr
         (CreateEntering
            {
              symbol = "SQZ";
              side = Short;
              target_quantity = 100.0;
              entry_price = 10.0;
              reasoning =
                TechnicalSignal { indicator = "t"; description = "short" };
            }))
    |> _unwrap
  in
  let filled =
    apply_transition entering
      (tr (EntryFill { filled_quantity = 100.0; fill_price = 10.0 }))
    |> _unwrap
  in
  apply_transition filled
    (tr
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = Some 13.0;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> _unwrap

let _stop_exit ~stop_price =
  {
    Position.position_id = "SQZ";
    date = _friday;
    kind =
      Position.TriggerExit
        {
          exit_reason =
            Position.StopLoss
              { stop_price; actual_price = 15.0; loss_percent = -50.0 };
          exit_price = 15.0;
        };
  }

let _exit_label (t : Position.transition) =
  match t.kind with
  | Position.TriggerExit { exit_reason = StopLoss _; _ } -> "stop_loss"
  | Position.TriggerExit { exit_reason = StrategySignal { label; _ }; _ } ->
      label
  | _ -> "other"

(* One tick for SQZ closing at $15 (maintenance breached) with a strategy
   stop at [stop_price]; returns each surviving exit's label. *)
let _tick_labels ~stop_fill_beats_margin_cover ~stop_price ~high =
  let _portfolio, transitions =
    Trading_simulation.Margin_runner.tick ~stop_fill_beats_margin_cover
      ~margin_config:_on_config ~long_margin_rate_annual_pct:0.0
      ~maintenance_long_pct:0.0 ~portfolio:(_short_portfolio ())
      ~positions:(String.Map.singleton "SQZ" (_holding_short ()))
      ~today_bars:[ _engine_bar ~symbol:"SQZ" ~low:12.0 ~high ~close:15.0 ]
      ~date:_friday
      ~strategy_transitions:[ _stop_exit ~stop_price ]
  in
  List.map transitions ~f:_exit_label

let test_default_margin_cover_wins _ =
  assert_that
    (_tick_labels ~stop_fill_beats_margin_cover:false ~stop_price:13.0
       ~high:16.0)
    (elements_are [ equal_to "margin_call" ])

let test_armed_stop_traded_beats_margin_cover _ =
  assert_that
    (_tick_labels ~stop_fill_beats_margin_cover:true ~stop_price:13.0 ~high:16.0)
    (elements_are [ equal_to "stop_loss" ])

let test_armed_stop_not_reached_margin_still_wins _ =
  (* The stop at $17 is above the bar's $16 high: no same-bar fill, so the
     stop has no intraday claim and the margin cover keeps priority. *)
  assert_that
    (_tick_labels ~stop_fill_beats_margin_cover:true ~stop_price:17.0 ~high:16.0)
    (elements_are [ equal_to "margin_call" ])

let test_stop_fill_position_ids _ =
  let positions = String.Map.singleton "SQZ" (_holding_short ()) in
  let ids ~high =
    Trading_simulation.Trigger_bar_stop_fill.stop_fill_position_ids ~positions
      ~today_bars:[ _engine_bar ~symbol:"SQZ" ~low:12.0 ~high ~close:15.0 ]
      [ _stop_exit ~stop_price:13.0 ]
    |> Set.to_list
  in
  (* A short's stop is reached when the bar's high trades at or above it. *)
  assert_that
    (ids ~high:16.0, ids ~high:12.5)
    (all_of
       [
         field fst (elements_are [ equal_to "SQZ" ]);
         field snd (elements_are []);
       ])

(* ------------------------------------------------------------------ *)
(* End-to-end through the simulator                                    *)
(* ------------------------------------------------------------------ *)

let _flat_bar ~date ~close =
  Types.Daily_price.
    {
      date = _date date;
      open_price = close;
      high_price = close;
      low_price = close;
      close_price = close;
      adjusted_close = close;
      volume = 1_000_000;
      active_through = None;
    }

(* Short entered at $50; the $60 maintenance trigger and the $60 stop are both
   crossed by the 2024-01-05 (Friday) bar at $65, then $68 next open. *)
let _rising_bars =
  [
    _flat_bar ~date:"2024-01-02" ~close:50.0;
    _flat_bar ~date:"2024-01-03" ~close:52.0;
    _flat_bar ~date:"2024-01-04" ~close:58.0;
    _flat_bar ~date:"2024-01-05" ~close:65.0;
    _flat_bar ~date:"2024-01-08" ~close:68.0;
    _flat_bar ~date:"2024-01-09" ~close:70.0;
  ]

(* Shorts AAPL on the first call; emits a $60 [StopLoss] exit on the first
   close at or above $60. *)
let _short_then_stop_strategy () : (module Strategy_interface.STRATEGY) =
  let entered = ref false in
  let exited = ref false in
  let module S : Strategy_interface.STRATEGY = struct
    let name = "ShortThenStop"

    let _transition (bar : Types.Daily_price.t) kind =
      { Position.position_id = "AAPL-short"; date = bar.date; kind }

    let _entry bar =
      _transition bar
        (Position.CreateEntering
           {
             symbol = "AAPL";
             side = Position.Short;
             target_quantity = 100.0;
             entry_price = bar.close_price;
             reasoning =
               TechnicalSignal { indicator = "t"; description = "short" };
           })

    let _stop bar =
      _transition bar
        (Position.TriggerExit
           {
             exit_reason =
               StopLoss
                 {
                   stop_price = 60.0;
                   actual_price = bar.close_price;
                   loss_percent = -8.0;
                 };
             exit_price = bar.close_price;
           })

    let on_market_close ~get_price ~get_indicator:_ ~portfolio:_ =
      let transitions =
        match get_price "AAPL" with
        | None -> []
        | Some bar when not !entered ->
            entered := true;
            [ _entry bar ]
        | Some bar when (not !exited) && Float.(bar.close_price >= 60.0) ->
            exited := true;
            [ _stop bar ]
        | Some _ -> []
      in
      Ok { Strategy_interface.transitions }
  end
  in
  (module S)

(* The cover (Buy) fills, as (step date, price), of a run with trigger-bar
   stop fills armed and exits filled at the next fresh open (the Weinstein
   default [sim_exit_fill_next_open = true]). *)
let _cover_fill ~test_name ~stop_fill_beats_margin_cover =
  let config =
    {
      Trading_simulation_types.Simulator_types.start_date = _date "2024-01-02";
      end_date = _date "2024-01-10";
      initial_cash = 50_000.0;
      commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 };
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let result = ref None in
  with_test_data test_name
    [ ("AAPL", _rising_bars) ]
    ~f:(fun data_dir ->
      let deps =
        Simulator.create_deps ~symbols:[ "AAPL" ] ~data_dir
          ~strategy:(_short_then_stop_strategy ())
          ~commission:config.commission ~margin_config:_on_config
          ~sim_exit_fill_next_open:true ~sim_stop_exit_fill_on_trigger_bar:true
          ~sim_stop_fill_beats_margin_cover:stop_fill_beats_margin_cover ()
      in
      match Simulator.run (create_exn ~config ~deps) with
      | Ok r -> result := Some r
      | Error err -> assert_failure ("run failed: " ^ Status.show err));
  let r = Option.value_exn !result in
  List.concat_map r.steps ~f:(fun s ->
      List.filter_map s.trades ~f:(fun (t : Trading_base.Types.trade) ->
          if Trading_base.Types.equal_side t.side Buy then Some (s.date, t.price)
          else None))

let test_e2e_armed_stop_fills_on_trigger_bar _ =
  (* Flag on: the stop wins and fills on the 2024-01-05 trigger bar at its
     $65 open (the bar gapped through the $60 stop). *)
  assert_that
    (_cover_fill ~test_name:"stop_beats_margin_on"
       ~stop_fill_beats_margin_cover:true)
    (elements_are [ equal_to (_date "2024-01-05", 65.0) ])

let test_e2e_default_margin_cover_fills_next_open _ =
  (* Flag off (#1266): the margin cover wins and fills at the next open,
     2024-01-08 at $68. *)
  assert_that
    (_cover_fill ~test_name:"stop_beats_margin_off"
       ~stop_fill_beats_margin_cover:false)
    (elements_are [ equal_to (_date "2024-01-08", 68.0) ])

let suite =
  "Stop fill vs margin cover precedence (#3206)"
  >::: [
         "default: margin cover wins" >:: test_default_margin_cover_wins;
         "armed: stop traded on the bar beats margin cover"
         >:: test_armed_stop_traded_beats_margin_cover;
         "armed: stop not reached, margin cover still wins"
         >:: test_armed_stop_not_reached_margin_still_wins;
         "stop_fill_position_ids: short stop reached by the high"
         >:: test_stop_fill_position_ids;
         "e2e armed: stop fills on the trigger bar"
         >:: test_e2e_armed_stop_fills_on_trigger_bar;
         "e2e default: margin cover fills at the next open"
         >:: test_e2e_default_margin_cover_fills_next_open;
       ]

let () = run_test_tt_main suite
