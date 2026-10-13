(** Tests for [sim_stop_beats_margin_cover] precedence (issue #3206).

    With trigger-bar stop fills armed, a strategy [StopLoss] exit whose stop
    level traded on the position's own bar beats a same-position margin
    transition (short maintenance cover, long maintenance reduce): the stop is a
    resting order that fills intraday (book §5.7), the maintenance check runs on
    the close. Pins {!Margin_runner.tick} and
    {!Margin_runner.drop_margin_exits_for_traded_stops}: short and long sides,
    the default-off case (margin wins, unchanged since #1266), and a stop the
    bar did not reach. *)

open OUnit2
open Core
open Matchers
module Margin_config = Trading_portfolio.Margin_config
module Portfolio = Trading_portfolio.Portfolio
module Portfolio_margin = Trading_portfolio.Portfolio_margin
module Position = Trading_strategy.Position
module Margin_runner = Trading_simulation.Margin_runner

let _date_d = Date.of_string "2024-01-05"
let _on_config = { Margin_config.default_config with enabled = true }

let _bar ~symbol ~low ~high ~close =
  {
    Trading_engine.Types.symbol;
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
  }

let _transition position_id kind =
  { Position.position_id; date = _date_d; kind }

let _stop_exit ~stop_price position_id =
  _transition position_id
    (Position.TriggerExit
       {
         exit_reason =
           Position.StopLoss
             { stop_price; actual_price = stop_price; loss_percent = -10.0 };
         exit_price = stop_price;
       })

let _margin_exit position_id =
  _transition position_id
    (Position.TriggerExit
       {
         exit_reason =
           Position.StrategySignal
             { label = "margin_call"; detail = Some "entry_avg_cost=10" };
         exit_price = 15.0;
       })

(* Holding position of [side]; map key = symbol = position_id. *)
let _holding ~symbol ~side ~entry ~qty =
  let t kind = _transition symbol kind in
  let ok = function
    | Ok p -> p
    | Error _ -> assert_failure "position setup failed"
  in
  let open Position in
  let p =
    create_entering
      (t
         (CreateEntering
            {
              symbol;
              side;
              target_quantity = qty;
              entry_price = entry;
              reasoning =
                TechnicalSignal { indicator = "3206"; description = "setup" };
            }))
    |> ok
  in
  let p =
    apply_transition p
      (t (EntryFill { filled_quantity = qty; fill_price = entry }))
    |> ok
  in
  apply_transition p
    (t
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> ok

let _positions side =
  Map.of_alist_exn
    (module String)
    [ ("X", _holding ~symbol:"X" ~side ~entry:10.0 ~qty:100.0) ]

(* Short sold at $10, 50% IM / 25% MM: cover trigger is $12, a $15 mark breaches. *)
let _short_portfolio () =
  match
    Portfolio_margin.apply_trades_with_margin ~margin_config:_on_config
      (Portfolio.create ~initial_cash:30_000.0 ())
      [
        {
          Trading_base.Types.id = "s";
          order_id = "s";
          symbol = "X";
          side = Trading_base.Types.Sell;
          quantity = 100.0;
          price = 10.0;
          commission = 0.0;
          timestamp = Time_ns_unix.now ();
        };
      ]
  with
  | Ok p -> p
  | Error err -> assert_failure ("short portfolio: " ^ Status.show err)

(* The bar breaches maintenance at the close ($15) and traded up to [high]. *)
let _tick ~stop_beats_margin_cover ~stop_price ~high =
  snd
    (Margin_runner.tick ~margin_config:_on_config
       ~long_margin_rate_annual_pct:0.0 ~maintenance_long_pct:0.0
       ~stop_beats_margin_cover ~portfolio:(_short_portfolio ())
       ~positions:(_positions Position.Short)
       ~today_bars:[ _bar ~symbol:"X" ~low:10.0 ~high ~close:15.0 ]
       ~date:_date_d
       ~strategy_transitions:[ _stop_exit ~stop_price "X" ])

let _is_stop_loss =
  field
    (fun (t : Position.transition) -> t.kind)
    (matching ~msg:"TriggerExit StopLoss"
       (function
         | Position.TriggerExit { exit_reason = Position.StopLoss _; _ } ->
             Some ()
         | _ -> None)
       (equal_to ()))

let _is_margin_call =
  field
    (fun (t : Position.transition) -> t.kind)
    (matching ~msg:"TriggerExit margin_call"
       (function
         | Position.TriggerExit
             { exit_reason = Position.StrategySignal { label; _ }; _ }
           when String.equal label "margin_call" ->
             Some ()
         | _ -> None)
       (equal_to ()))

let test_short_stop_traded_beats_margin_cover _ =
  assert_that
    (_tick ~stop_beats_margin_cover:true ~stop_price:12.0 ~high:15.0)
    (elements_are [ _is_stop_loss ])

let test_default_off_margin_cover_wins _ =
  assert_that
    (_tick ~stop_beats_margin_cover:false ~stop_price:12.0 ~high:15.0)
    (elements_are [ _is_margin_call ])

let test_armed_but_stop_not_reached_margin_wins _ =
  (* Stop at 20 against a bar that only reached 15: no resting-stop fill. *)
  assert_that
    (_tick ~stop_beats_margin_cover:true ~stop_price:20.0 ~high:15.0)
    (elements_are [ _is_margin_call ])

let _drop ~side ~stop_price ~low ~high =
  Margin_runner.drop_margin_exits_for_traded_stops
    ~strategy_transitions:[ _stop_exit ~stop_price "X" ]
    ~margin_trans:[ _margin_exit "X"; _margin_exit "OTHER" ]
    ~positions:(_positions side)
    ~today_bars:[ _bar ~symbol:"X" ~low ~high ~close:(low +. 1.0) ]

let _position_ids = List.map ~f:(fun (t : Position.transition) -> t.position_id)

let test_long_stop_traded_drops_margin_transition _ =
  (* Long stop 90 (Sell); the bar's low 85 traded through it. OTHER has no
     strategy stop, so its margin transition passes through. *)
  assert_that
    (_position_ids
       (_drop ~side:Position.Long ~stop_price:90.0 ~low:85.0 ~high:95.0))
    (elements_are [ equal_to "OTHER" ])

let test_long_stop_not_traded_keeps_margin_transition _ =
  assert_that
    (_position_ids
       (_drop ~side:Position.Long ~stop_price:90.0 ~low:92.0 ~high:95.0))
    (elements_are [ equal_to "X"; equal_to "OTHER" ])

let suite =
  "margin_stop_precedence"
  >::: [
         "short_stop_traded_beats_margin_cover"
         >:: test_short_stop_traded_beats_margin_cover;
         "default_off_margin_cover_wins" >:: test_default_off_margin_cover_wins;
         "armed_but_stop_not_reached_margin_wins"
         >:: test_armed_but_stop_not_reached_margin_wins;
         "long_stop_traded_drops_margin_transition"
         >:: test_long_stop_traded_drops_margin_transition;
         "long_stop_not_traded_keeps_margin_transition"
         >:: test_long_stop_not_traded_keeps_margin_transition;
       ]

let () = run_test_tt_main suite
