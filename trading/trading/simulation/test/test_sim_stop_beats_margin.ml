(** Simulator-level two-arm test for [stop_beats_margin_cover] (issue #3206).

    A short (10 sh, sold at 100 on Wed 01-03) carries a 110 buy-stop. Bar T (Thu
    01-04) opens 100, trades up to 125 (through the stop) and closes 125, which
    also breaches the short's maintenance margin at the close. The strategy
    stands in for the stops pass and emits the [StopLoss] exit on bar T, so the
    same step carries a strategy stop AND a margin cover for one position.

    - Default (margin wins, #1266): the cover is a Market order at T+1's open
      (126), dated Fri 01-05.
    - [stop_beats_margin_cover] with trigger-bar fills armed: the stop fills on
      bar T, between the stop (110) and the high (125).
    - [stop_beats_margin_cover] WITHOUT trigger-bar fills: inert, next open. *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
open Test_helpers

let _date s = Date.of_string s
let _trigger_date = "2024-01-04"
let _commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 }

let _bar ~date ~open_price ~high ~low ~close =
  Types.Daily_price.
    {
      date = _date date;
      open_price;
      high_price = high;
      low_price = low;
      close_price = close;
      volume = 1_000_000;
      adjusted_close = close;
      active_through = None;
    }

let _prices =
  [
    _bar ~date:"2024-01-02" ~open_price:100.0 ~high:101.0 ~low:99.0 ~close:100.0;
    _bar ~date:"2024-01-03" ~open_price:100.0 ~high:101.0 ~low:99.0 ~close:100.0;
    _bar ~date:_trigger_date ~open_price:100.0 ~high:125.0 ~low:99.0
      ~close:125.0;
    _bar ~date:"2024-01-05" ~open_price:126.0 ~high:127.0 ~low:125.0
      ~close:126.0;
  ]

let _stop_loss =
  Trading_strategy.Position.StopLoss
    { stop_price = 110.0; actual_price = 125.0; loss_percent = 0.0 }

(* Shorts AAPL on the first call; on bar T's close, while [Holding], emits the
   stop-loss [TriggerExit]. *)
module Scripted_short : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : unit -> unit
end = struct
  let name = "ScriptedShortStop"
  let entered = ref false
  let exited = ref false

  let reset () =
    entered := false;
    exited := false

  let _trans ~date kind =
    { Trading_strategy.Position.position_id = "AAPL-1"; date; kind }

  let _entry () =
    _trans ~date:(_date "2024-01-02")
      (CreateEntering
         {
           symbol = "AAPL";
           side = Short;
           target_quantity = 10.0;
           entry_price = 100.0;
           reasoning = ManualDecision { description = "stop beats margin" };
         })

  let _exit () =
    _trans ~date:(_date _trigger_date)
      (TriggerExit { exit_reason = _stop_loss; exit_price = 125.0 })

  let _holding_on_trigger_bar ~get_price pos =
    (match Trading_strategy.Position.get_state pos with
      | Holding _ -> true
      | _ -> false)
    &&
    match get_price "AAPL" with
    | Some (bar : Types.Daily_price.t) ->
        Date.equal bar.date (_date _trigger_date)
    | None -> false

  let on_market_close ~get_price ~get_indicator:_
      ~(portfolio : Trading_strategy.Portfolio_view.t) =
    let emit transitions =
      Ok { Trading_strategy.Strategy_interface.transitions }
    in
    match Map.find portfolio.positions "AAPL-1" with
    | None when not !entered ->
        entered := true;
        emit [ _entry () ]
    | Some pos when (not !exited) && _holding_on_trigger_bar ~get_price pos ->
        exited := true;
        emit [ _exit () ]
    | Some _ | None -> emit []
end

(* Steps Tue 01-02 .. Fri 01-05 ([end_date] exclusive). *)
let _config =
  {
    start_date = _date "2024-01-02";
    end_date = _date "2024-01-06";
    initial_cash = 100_000.0;
    commission = _commission;
    strategy_cadence = Types.Cadence.Daily;
  }

let _run_exn ~name ~sim_stop_exit_fill_on_trigger_bar ~stop_beats_margin_cover =
  Scripted_short.reset ();
  with_test_data name
    [ ("AAPL", _prices) ]
    ~f:(fun data_dir ->
      let deps =
        create_deps ~symbols:[ "AAPL" ] ~data_dir
          ~strategy:(module Scripted_short)
          ~commission:_commission
          ~margin_config:
            {
              Trading_portfolio.Margin_config.default_config with
              enabled = true;
            }
          ~sim_stop_exit_fill_on_trigger_bar ~stop_beats_margin_cover ()
      in
      match run (create_exn ~config:_config ~deps) with
      | Error err -> failwith ("run failed: " ^ Status.show err)
      | Ok result -> result)

(* (step date, buy price) for every cover fill. *)
let _cover_fills result =
  List.concat_map result.steps ~f:(fun s ->
      List.filter_map s.trades ~f:(fun (t : Trading_base.Types.trade) ->
          match t.side with
          | Buy -> Some (Date.to_string s.date, t.price)
          | Sell -> None))

let _is_fill ~date price_matcher =
  all_of [ field fst (equal_to date); field snd price_matcher ]

let test_default_margin_cover_fills_at_the_next_open _ =
  let result =
    _run_exn ~name:"stop_beats_margin_default"
      ~sim_stop_exit_fill_on_trigger_bar:true ~stop_beats_margin_cover:false
  in
  assert_that (_cover_fills result)
    (elements_are [ _is_fill ~date:"2024-01-05" (float_equal 126.0) ])

let test_armed_stop_fills_on_the_trigger_bar _ =
  let result =
    _run_exn ~name:"stop_beats_margin_armed"
      ~sim_stop_exit_fill_on_trigger_bar:true ~stop_beats_margin_cover:true
  in
  assert_that (_cover_fills result)
    (elements_are
       [
         _is_fill ~date:_trigger_date
           (is_between (module Float_ord) ~low:110.0 ~high:125.0);
       ])

let test_inert_without_trigger_bar_fills _ =
  let result =
    _run_exn ~name:"stop_beats_margin_no_fill_model"
      ~sim_stop_exit_fill_on_trigger_bar:false ~stop_beats_margin_cover:true
  in
  assert_that (_cover_fills result)
    (elements_are [ _is_fill ~date:"2024-01-05" (float_equal 126.0) ])

let suite =
  "sim_stop_beats_margin"
  >::: [
         "default margin cover fills at the next open"
         >:: test_default_margin_cover_fills_at_the_next_open;
         "armed stop fills on the trigger bar"
         >:: test_armed_stop_fills_on_the_trigger_bar;
         "inert without trigger-bar fills"
         >:: test_inert_without_trigger_bar_fills;
       ]

let () = run_test_tt_main suite
