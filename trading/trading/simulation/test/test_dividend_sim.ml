(** Simulator wiring for dividend crediting (#3137 part 2).

    Scenario: flat $50 bars 2024-01-02 .. 2024-01-09; the strategy submits a
    100-share AAPL entry on its first call (01-02), which fills on the next bar
    (01-03), and records the cash it is handed on every call. Dividends: $1.00
    ex 01-03 (the fill day) and $0.25 ex 01-05.

    - The 01-03 dividend is NOT paid: crediting runs before the day's fills, so
      a buy that fills on the ex-date was not held when the step started.
    - The 01-05 dividend IS paid (100 x 0.25 = $25), and the strategy's cash on
      01-05 is already $25 above its cash on 01-04: credited before the strategy
      call.
    - Default (no crediting) adds no metric key, and an armed run whose symbol
      has no dividends is step-for-step identical to it. *)

open OUnit2
open Core
open Matchers
open Trading_simulation.Simulator
open Test_helpers
module Dividend_crediting = Trading_simulation_dividends.Dividend_crediting
module Metric_types = Trading_simulation_types.Metric_types
module Strategy_interface = Trading_strategy.Strategy_interface

let _date = Date.of_string

let _bar d : Types.Daily_price.t =
  {
    date = _date d;
    open_price = 50.0;
    high_price = 50.0;
    low_price = 50.0;
    close_price = 50.0;
    adjusted_close = 50.0;
    volume = 1_000_000;
    active_through = None;
  }

let _bars =
  List.map
    [
      "2024-01-02";
      "2024-01-03";
      "2024-01-04";
      "2024-01-05";
      "2024-01-08";
      "2024-01-09";
    ]
    ~f:_bar

let _config =
  {
    Trading_simulation_types.Simulator_types.start_date = _date "2024-01-02";
    end_date = _date "2024-01-10";
    initial_cash = 100_000.0;
    commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 };
    strategy_cadence = Types.Cadence.Daily;
  }

let _entry (bar : Types.Daily_price.t) =
  let open Trading_strategy.Position in
  {
    position_id = "AAPL-hold";
    date = bar.date;
    kind =
      CreateEntering
        {
          symbol = "AAPL";
          side = Long;
          target_quantity = 100.0;
          entry_price = bar.close_price;
          reasoning =
            TechnicalSignal { indicator = "test"; description = "hold" };
        };
  }

(* Buys 100 AAPL on its first call, then holds; records (date, cash seen). *)
let _recording_strategy seen : (module Strategy_interface.STRATEGY) =
  let module S : Strategy_interface.STRATEGY = struct
    let name = "BuyHoldRecordCash"

    let on_market_close ~get_price ~get_indicator:_ ~portfolio =
      match get_price "AAPL" with
      | None -> Ok { Strategy_interface.transitions = [] }
      | Some (bar : Types.Daily_price.t) ->
          let first = List.is_empty !seen in
          seen :=
            (bar.date, portfolio.Trading_strategy.Portfolio_view.cash) :: !seen;
          Ok
            {
              Strategy_interface.transitions =
                (if first then [ _entry bar ] else []);
            }
  end
  in
  (module S)

let _dividends =
  [ ("AAPL", [ ("2024-01-03", 1.0); ("2024-01-05", 0.25) ]) ]
  |> List.map ~f:(fun (sym, divs) ->
      ( sym,
        List.map divs ~f:(fun (d, amt) : Corporate_actions.dividend ->
            {
              ex_date = _date d;
              unadjusted_amount = Some amt;
              adjusted_amount = amt;
            }) ))

let _crediting table =
  Dividend_crediting.create
    ~load:(fun sym ->
      match List.Assoc.find table sym ~equal:String.equal with
      | Some d -> Ok d
      | None -> Status.error_not_found sym)
    ~start_date:_config.start_date

(* Returns the run result and the strategy's (date, cash) record, oldest first. *)
let _run ~test_name ?dividends () =
  let seen = ref [] in
  let result =
    with_test_data test_name
      [ ("AAPL", _bars) ]
      ~f:(fun data_dir ->
        let deps =
          create_deps ~symbols:[ "AAPL" ] ~data_dir
            ~strategy:(_recording_strategy seen) ~commission:_config.commission
            ?dividends ()
        in
        run (create_exn ~config:_config ~deps))
  in
  (result, List.rev !seen)

let _cash_on seen d = List.Assoc.find seen (_date d) ~equal:Date.equal

let _dividend_keys =
  Metric_types.
    [
      DividendIncomeTotal;
      DividendPaidShortTotal;
      DividendSkippedNoAmountCount;
      DividendMissingFileCount;
    ]

let test_credited_before_strategy_not_on_fill_day _ =
  let result, seen =
    _run ~test_name:"dividend_sim_armed" ~dividends:(_crediting _dividends) ()
  in
  let delta =
    Option.map2
      (_cash_on seen "2024-01-05")
      (_cash_on seen "2024-01-04")
      ~f:Float.( - )
  in
  assert_that (result, delta)
    (pair
       (is_ok_and_holds
          (field
             (fun (r : run_result) -> r.metrics)
             (all_of
                [
                  contains_entry Metric_types.DividendIncomeTotal
                    (float_equal 25.0);
                  contains_entry Metric_types.DividendPaidShortTotal
                    (float_equal 0.0);
                  contains_entry Metric_types.DividendMissingFileCount
                    (float_equal 0.0);
                ])))
       (is_some_and (float_equal 25.0)))

(* A position sold by a fill ON the ex-date was held when that step started,
   so it still receives the dividend. *)
let _exit_strategy () : (module Strategy_interface.STRATEGY) =
  let module S : Strategy_interface.STRATEGY = struct
    let name = "BuyThenExitOnEve"

    let on_market_close ~get_price ~get_indicator:_ ~portfolio:_ =
      match get_price "AAPL" with
      | None -> Ok { Strategy_interface.transitions = [] }
      | Some (bar : Types.Daily_price.t) ->
          let first = Date.equal bar.date _config.start_date in
          let exit_tr =
            {
              Trading_strategy.Position.position_id = "AAPL-hold";
              date = bar.date;
              kind =
                TriggerExit
                  {
                    exit_reason =
                      Trading_strategy.Position.SignalReversal
                        { description = "exit before ex-date" };
                    exit_price = 50.0;
                  };
            }
          in
          Ok
            {
              Strategy_interface.transitions =
                (if first then [ _entry bar ]
                 else if Date.equal bar.date (_date "2024-01-04") then
                   [ exit_tr ]
                 else []);
            }
  end
  in
  (module S)

let _sell_dates (r : run_result) =
  List.filter_map r.steps ~f:(fun (s : step_result) ->
      if
        List.exists s.trades ~f:(fun t ->
            match t.Trading_base.Types.side with Sell -> true | Buy -> false)
      then Some s.date
      else None)

let test_sale_filling_on_ex_date_still_paid _ =
  let divs : Corporate_actions.dividend list =
    [
      {
        ex_date = _date "2024-01-05";
        unadjusted_amount = Some 0.25;
        adjusted_amount = 0.25;
      };
    ]
  in
  let result =
    with_test_data "dividend_sim_sale_on_ex_date"
      [ ("AAPL", _bars) ]
      ~f:(fun data_dir ->
        let deps =
          create_deps ~symbols:[ "AAPL" ] ~data_dir
            ~strategy:(_exit_strategy ()) ~commission:_config.commission
            ~dividends:(_crediting [ ("AAPL", divs) ])
            ()
        in
        run (create_exn ~config:_config ~deps))
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (r : run_result) -> r.metrics)
              (contains_entry Metric_types.DividendIncomeTotal
                 (float_equal 25.0));
            field
              (fun (r : run_result) ->
                r.final_portfolio.Trading_portfolio.Portfolio.current_cash)
              (float_equal 100_025.0);
            field
              (fun (r : run_result) -> r.final_portfolio.positions)
              (elements_are []);
            field _sell_dates (elements_are [ equal_to (_date "2024-01-05") ]);
          ]))

(* Per-step (portfolio summary, value). Whole [step_result]s are not compared:
   [orders_submitted] carry wall-clock created_at / updated_at from
   Trading_orders that differ between two runs (trades are equal, restamped by
   Fill_date_stamp). *)
let _marks (r : run_result) =
  List.map r.steps ~f:(fun (s : step_result) ->
      (s.portfolio, s.portfolio_value))

let _equal_mark (p1, v1) (p2, v2) =
  Trading_simulation_types.Portfolio_summary.equal p1 p2 && Float.equal v1 v2

let test_default_off_identical_and_no_keys _ =
  let default, _ = _run ~test_name:"dividend_sim_default" () in
  let armed_empty, _ =
    _run ~test_name:"dividend_sim_armed_empty"
      ~dividends:(_crediting [ ("AAPL", []) ])
      ()
  in
  let default = ok_or_fail_status default
  and armed_empty = ok_or_fail_status armed_empty in
  assert_that
    ( List.count _dividend_keys ~f:(Map.mem default.metrics),
      List.equal _equal_mark (_marks default) (_marks armed_empty),
      Float.equal default.final_portfolio.current_cash
        armed_empty.final_portfolio.current_cash )
    (equal_to (0, true, true))

let suite =
  "dividend_sim"
  >::: [
         "credited before the strategy call, not on the fill day"
         >:: test_credited_before_strategy_not_on_fill_day;
         "default off: identical outputs and no new keys"
         >:: test_default_off_identical_and_no_keys;
         "sale filling on ex-date still paid"
         >:: test_sale_filling_on_ex_date_still_paid;
       ]

let () = run_test_tt_main suite
