open OUnit2
open Core
open Trading_strategy
open Matchers

let date = Date.of_string "2024-01-15"

let test_create_entering_records_symbol _ =
  let log = Backtest.Stop_log.create () in
  Backtest.Stop_log.record_transitions log
    [
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          CreateEntering
            {
              symbol = "AAPL";
              side = Long;
              target_quantity = 100.0;
              entry_price = 150.0;
              reasoning = ManualDecision { description = "test" };
            };
      };
    ];
  let infos = Backtest.Stop_log.get_stop_infos log in
  assert_that infos
    (elements_are
       [
         all_of
           [
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.position_id)
               (equal_to "AAPL-wein-1");
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.symbol)
               (equal_to "AAPL");
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.entry_stop)
               is_none;
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.exit_trigger)
               is_none;
           ];
       ])

let test_entry_complete_records_stop _ =
  let log = Backtest.Stop_log.create () in
  Backtest.Stop_log.record_transitions log
    [
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          CreateEntering
            {
              symbol = "AAPL";
              side = Long;
              target_quantity = 100.0;
              entry_price = 150.0;
              reasoning = ManualDecision { description = "test" };
            };
      };
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          EntryComplete
            {
              risk_params =
                {
                  stop_loss_price = Some 142.50;
                  take_profit_price = None;
                  max_hold_days = None;
                };
            };
      };
    ];
  let infos = Backtest.Stop_log.get_stop_infos log in
  assert_that infos
    (elements_are
       [
         all_of
           [
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.entry_stop)
               (is_some_and (float_equal 142.50));
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.exit_stop)
               (is_some_and (float_equal 142.50));
           ];
       ])

let test_update_risk_params_updates_stop _ =
  let log = Backtest.Stop_log.create () in
  Backtest.Stop_log.record_transitions log
    [
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          CreateEntering
            {
              symbol = "AAPL";
              side = Long;
              target_quantity = 100.0;
              entry_price = 150.0;
              reasoning = ManualDecision { description = "test" };
            };
      };
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          EntryComplete
            {
              risk_params =
                {
                  stop_loss_price = Some 142.50;
                  take_profit_price = None;
                  max_hold_days = None;
                };
            };
      };
    ];
  Backtest.Stop_log.record_transitions log
    [
      {
        Position.position_id = "AAPL-wein-1";
        date = Date.of_string "2024-01-22";
        kind =
          UpdateRiskParams
            {
              new_risk_params =
                {
                  stop_loss_price = Some 148.00;
                  take_profit_price = None;
                  max_hold_days = None;
                };
            };
      };
    ];
  let infos = Backtest.Stop_log.get_stop_infos log in
  assert_that infos
    (elements_are
       [
         all_of
           [
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.entry_stop)
               (is_some_and (float_equal 142.50));
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.exit_stop)
               (is_some_and (float_equal 148.00));
           ];
       ])

let test_trigger_exit_records_trigger _ =
  let log = Backtest.Stop_log.create () in
  Backtest.Stop_log.record_transitions log
    [
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          CreateEntering
            {
              symbol = "AAPL";
              side = Long;
              target_quantity = 100.0;
              entry_price = 150.0;
              reasoning = ManualDecision { description = "test" };
            };
      };
      {
        Position.position_id = "AAPL-wein-1";
        date;
        kind =
          EntryComplete
            {
              risk_params =
                {
                  stop_loss_price = Some 142.50;
                  take_profit_price = None;
                  max_hold_days = None;
                };
            };
      };
    ];
  Backtest.Stop_log.record_transitions log
    [
      {
        Position.position_id = "AAPL-wein-1";
        date = Date.of_string "2024-02-01";
        kind =
          TriggerExit
            {
              exit_reason =
                StopLoss
                  {
                    stop_price = 142.50;
                    actual_price = 141.80;
                    loss_percent = 5.47;
                  };
              exit_price = 141.80;
            };
      };
    ];
  let infos = Backtest.Stop_log.get_stop_infos log in
  assert_that infos
    (elements_are
       [
         field
           (fun (i : Backtest.Stop_log.stop_info) -> i.exit_trigger)
           (is_some_and
              (equal_to
                 (Backtest.Stop_log.Stop_loss
                    { stop_price = 142.50; actual_price = 141.80 }
                   : Backtest.Stop_log.exit_trigger)));
       ])

let test_wrapper_passes_through _ =
  let log = Backtest.Stop_log.create () in
  let transitions =
    [
      {
        Position.position_id = "TEST-1";
        date;
        kind =
          CreateEntering
            {
              symbol = "TEST";
              side = Long;
              target_quantity = 100.0;
              entry_price = 50.0;
              reasoning = ManualDecision { description = "test" };
            };
      };
    ]
  in
  let module Inner = struct
    let name = "TestStrategy"

    let on_market_close ~get_price:_ ~get_indicator:_ ~portfolio:_ =
      Ok { Strategy_interface.transitions }
  end in
  let wrapped =
    Backtest.Strategy_wrapper.wrap ~stop_log:log
      (module Inner : Strategy_interface.STRATEGY)
  in
  let module W = (val wrapped : Strategy_interface.STRATEGY) in
  let result =
    W.on_market_close
      ~get_price:(fun _ -> None)
      ~get_indicator:(fun _ _ _ _ -> None)
      ~portfolio:
        {
          Portfolio_view.cash = 100000.0;
          positions = Map.empty (module String);
        }
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (o : Strategy_interface.output) -> List.length o.transitions)
          (equal_to 1)));
  assert_that
    (Backtest.Stop_log.get_stop_infos log)
    (elements_are
       [
         all_of
           [
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.position_id)
               (equal_to "TEST-1");
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.symbol)
               (equal_to "TEST");
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.entry_stop)
               is_none;
             field
               (fun (i : Backtest.Stop_log.stop_info) -> i.exit_trigger)
               is_none;
           ];
       ])

let test_wrapper_handles_error _ =
  let log = Backtest.Stop_log.create () in
  let module Inner = struct
    let name = "FailStrategy"

    let on_market_close ~get_price:_ ~get_indicator:_ ~portfolio:_ =
      Error (Status.internal_error "test error")
  end in
  let wrapped =
    Backtest.Strategy_wrapper.wrap ~stop_log:log
      (module Inner : Strategy_interface.STRATEGY)
  in
  let module W = (val wrapped : Strategy_interface.STRATEGY) in
  let result =
    W.on_market_close
      ~get_price:(fun _ -> None)
      ~get_indicator:(fun _ _ _ _ -> None)
      ~portfolio:
        {
          Portfolio_view.cash = 100000.0;
          positions = Map.empty (module String);
        }
  in
  assert_that result is_error;
  assert_that (Backtest.Stop_log.get_stop_infos log) (size_is 0)

let suite =
  "Stop_log"
  >::: [
         "create_entering records symbol"
         >:: test_create_entering_records_symbol;
         "entry_complete records stop" >:: test_entry_complete_records_stop;
         "update_risk_params updates stop"
         >:: test_update_risk_params_updates_stop;
         "trigger_exit records trigger" >:: test_trigger_exit_records_trigger;
         "wrapper passes through" >:: test_wrapper_passes_through;
         "wrapper handles error" >:: test_wrapper_handles_error;
       ]

let () = run_test_tt_main suite
