(** Simulator-level tests for [sim_stop_exit_fill_on_trigger_bar] (issue #2961).

    A held long carries a 96 stop. Bar T (Thu 2024-01-04) opens 100, trades down
    to 95 and closes 99; bar T+1 (Fri 01-05) opens 98. The strategy stands in
    for the stops pass: on bar T it emits the [TriggerExit] the stops pass would
    ([StopLoss { stop_price = 96; actual_price = 95 }]).

    - OFF (the default): the exit is a Market order filled at T+1's open (98).
    - ON: the exit fills on step T itself, against bar T, at the first intraday
      path price through the stop — between the bar's low (95) and the stop
      (96).
    - ON, gap: bar T opens 94, already below the stop — the fill is the open.
    - ON, a non-stop exit ([SignalReversal]) or a force-liquidation breaker exit
      ([StrategySignal "force_liquidation"]): unchanged, next open. *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
open Test_helpers

let date_of_string s = Date.of_string s

let make_daily_price ~date ~open_price ~high ~low ~close =
  Types.Daily_price.
    {
      date = date_of_string date;
      open_price;
      high_price = high;
      low_price = low;
      close_price = close;
      volume = 1_000_000;
      adjusted_close = close;
      active_through = None;
    }

(* Zero costs so a fill price is the path price exactly. *)
let sample_commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 }
let trigger_date = "2024-01-04"

(* Tue: signal; Wed: entry fills at 100; Thu: bar T; Fri: bar T+1 (open 98). *)
let prices ~t_open ~t_low =
  [
    make_daily_price ~date:"2024-01-02" ~open_price:100.0 ~high:101.0 ~low:99.0
      ~close:100.0;
    make_daily_price ~date:"2024-01-03" ~open_price:100.0 ~high:101.0 ~low:99.0
      ~close:100.0;
    make_daily_price ~date:trigger_date ~open_price:t_open ~high:100.5
      ~low:t_low ~close:99.0;
    make_daily_price ~date:"2024-01-05" ~open_price:98.0 ~high:99.0 ~low:97.0
      ~close:98.0;
  ]

let stop_loss =
  Trading_strategy.Position.StopLoss
    { stop_price = 96.0; actual_price = 95.0; loss_percent = 0.0 }

(* Enters AAPL on the first call; on bar T's close, while [Holding], emits one
   [TriggerExit] carrying [exit_reason]. *)
module Scripted_exit : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : Trading_strategy.Position.exit_reason -> unit
end = struct
  let name = "ScriptedStopExit"
  let entered = ref false
  let exited = ref false
  let reason = ref stop_loss

  let reset r =
    entered := false;
    exited := false;
    reason := r

  let _entry =
    {
      Trading_strategy.Position.position_id = "AAPL-1";
      date = date_of_string "2024-01-02";
      kind =
        CreateEntering
          {
            symbol = "AAPL";
            side = Long;
            target_quantity = 10.0;
            entry_price = 100.0;
            reasoning = ManualDecision { description = "stop fill test" };
          };
    }

  let _exit () =
    {
      Trading_strategy.Position.position_id = "AAPL-1";
      date = date_of_string trigger_date;
      kind = TriggerExit { exit_reason = !reason; exit_price = 95.0 };
    }

  let _is_holding pos =
    match Trading_strategy.Position.get_state pos with
    | Holding _ -> true
    | _ -> false

  let _on_trigger_bar ~get_price =
    match get_price "AAPL" with
    | Some (bar : Types.Daily_price.t) ->
        Date.equal bar.date (date_of_string trigger_date)
    | None -> false

  let on_market_close ~get_price ~get_indicator:_
      ~(portfolio : Trading_strategy.Portfolio_view.t) =
    let emit transitions =
      Ok { Trading_strategy.Strategy_interface.transitions }
    in
    match Map.find portfolio.positions "AAPL-1" with
    | None when not !entered ->
        entered := true;
        emit [ _entry ]
    | Some pos
      when (not !exited) && _is_holding pos && _on_trigger_bar ~get_price ->
        exited := true;
        emit [ _exit () ]
    | Some _ | None -> emit []
end

(* Steps Tue 01-02 .. Fri 01-05 ([end_date] exclusive). *)
let config =
  {
    start_date = date_of_string "2024-01-02";
    end_date = date_of_string "2024-01-06";
    initial_cash = 100_000.0;
    commission = sample_commission;
    strategy_cadence = Types.Cadence.Daily;
  }

let run_exn ~name ?(t_open = 100.0) ?(t_low = 95.0) ?(exit_reason = stop_loss)
    ~sim_stop_exit_fill_on_trigger_bar () =
  Scripted_exit.reset exit_reason;
  with_test_data name
    [ ("AAPL", prices ~t_open ~t_low) ]
    ~f:(fun data_dir ->
      let deps =
        create_deps ~symbols:[ "AAPL" ] ~data_dir
          ~strategy:(module Scripted_exit)
          ~commission:sample_commission ~sim_stop_exit_fill_on_trigger_bar ()
      in
      match run (create_exn ~config ~deps) with
      | Error err -> failwith ("run failed: " ^ Status.show err)
      | Ok result -> result)

(* (step date, sell price) for every sell fill. *)
let sell_fills result =
  List.concat_map result.steps ~f:(fun s ->
      List.filter_map s.trades ~f:(fun (t : Trading_base.Types.trade) ->
          match t.side with
          | Sell -> Some (Date.to_string s.date, t.price)
          | Buy -> None))

let is_fill ~date price_matcher =
  all_of [ field fst (equal_to date); field snd price_matcher ]

let test_off_fills_the_stop_exit_at_the_next_open _ =
  let result =
    run_exn ~name:"stop_trigger_bar_off"
      ~sim_stop_exit_fill_on_trigger_bar:false ()
  in
  assert_that (sell_fills result)
    (elements_are [ is_fill ~date:"2024-01-05" (float_equal 98.0) ])

(* The fill lies inside bar T at or below the stop: the engine's stop rule
   fills at the first path point through 96, which the bar's 95 low bounds. *)
let test_on_fills_the_stop_exit_on_the_trigger_bar _ =
  let result =
    run_exn ~name:"stop_trigger_bar_on" ~sim_stop_exit_fill_on_trigger_bar:true
      ()
  in
  assert_that (sell_fills result)
    (elements_are
       [
         is_fill ~date:trigger_date
           (is_between (module Float_ord) ~low:95.0 ~high:96.0);
       ])

let test_on_gap_below_the_stop_fills_at_the_open _ =
  let result =
    run_exn ~name:"stop_trigger_bar_gap" ~t_open:94.0 ~t_low:93.0
      ~sim_stop_exit_fill_on_trigger_bar:true ()
  in
  assert_that (sell_fills result)
    (elements_are [ is_fill ~date:trigger_date (float_equal 94.0) ])

let test_on_leaves_a_non_stop_exit_at_the_next_open _ =
  let result =
    run_exn ~name:"stop_trigger_bar_signal"
      ~exit_reason:(SignalReversal { description = "not a stop" })
      ~sim_stop_exit_fill_on_trigger_bar:true ()
  in
  assert_that (sell_fills result)
    (elements_are [ is_fill ~date:"2024-01-05" (float_equal 98.0) ])

(* The force-liquidation breaker emits [StrategySignal "force_liquidation"]
   (since 2026-09-14), not [StopLoss], so its exits keep the next-open fill. *)
let test_on_leaves_a_breaker_exit_at_the_next_open _ =
  let result =
    run_exn ~name:"stop_trigger_bar_breaker"
      ~exit_reason:
        (StrategySignal { label = "force_liquidation"; detail = Some "test" })
      ~sim_stop_exit_fill_on_trigger_bar:true ()
  in
  assert_that (sell_fills result)
    (elements_are [ is_fill ~date:"2024-01-05" (float_equal 98.0) ])

(* The same-bar fill closes the position on step T: the run ends flat, with
   the cash the 10 shares fetched (no position left to mark). *)
let test_on_closes_the_position_on_the_trigger_step _ =
  let result =
    run_exn ~name:"stop_trigger_bar_flat" ~t_open:94.0 ~t_low:93.0
      ~sim_stop_exit_fill_on_trigger_bar:true ()
  in
  assert_that result.final_portfolio
    (all_of
       [
         field
           (fun (p : Trading_portfolio.Portfolio.t) -> List.length p.positions)
           (equal_to 0);
         field
           (fun (p : Trading_portfolio.Portfolio.t) -> p.current_cash)
           (float_equal (100_000.0 -. 1_000.0 +. 940.0));
       ])

let suite =
  "sim_stop_exit_fill_on_trigger_bar"
  >::: [
         "OFF fills the stop exit at the next open"
         >:: test_off_fills_the_stop_exit_at_the_next_open;
         "ON fills the stop exit on the trigger bar"
         >:: test_on_fills_the_stop_exit_on_the_trigger_bar;
         "ON, a gap below the stop fills at the open"
         >:: test_on_gap_below_the_stop_fills_at_the_open;
         "ON leaves a non-stop exit at the next open"
         >:: test_on_leaves_a_non_stop_exit_at_the_next_open;
         "ON leaves a breaker exit at the next open"
         >:: test_on_leaves_a_breaker_exit_at_the_next_open;
         "ON closes the position on the trigger step"
         >:: test_on_closes_the_position_on_the_trigger_step;
       ]

let () = run_test_tt_main suite
