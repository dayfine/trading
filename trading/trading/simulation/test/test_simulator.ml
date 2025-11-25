open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers

let date_of_string s = Date.of_string s

let make_daily_price ~date ~open_price ~high ~low ~close ~volume =
  Types.Daily_price.
    {
      date;
      open_price;
      high_price = high;
      low_price = low;
      close_price = close;
      volume;
      adjusted_close = close;
    }

let sample_config =
  {
    start_date = date_of_string "2024-01-02";
    end_date = date_of_string "2024-01-05";
    initial_cash = 10000.0;
    commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 };
  }

let sample_prices =
  [
    {
      symbol = "AAPL";
      prices =
        [
          make_daily_price
            ~date:(date_of_string "2024-01-02")
            ~open_price:150.0 ~high:155.0 ~low:149.0 ~close:154.0
            ~volume:1000000;
          make_daily_price
            ~date:(date_of_string "2024-01-03")
            ~open_price:154.0 ~high:158.0 ~low:153.0 ~close:157.0
            ~volume:1200000;
          make_daily_price
            ~date:(date_of_string "2024-01-04")
            ~open_price:157.0 ~high:160.0 ~low:155.0 ~close:159.0 ~volume:900000;
        ];
    };
  ]

let sample_deps = { prices = sample_prices }

(* Helper to create expected step_result for comparison *)
let make_expected_step_result ~date ~portfolio ~trades =
  { date; portfolio; trades }

(* Custom matchers for step_outcome *)
let is_stepped f = function
  | Stepped (sim', result) -> f (sim', result)
  | Completed _ -> assert_failure "Expected Stepped, got Completed"

let is_completed f = function
  | Completed portfolio -> f portfolio
  | Stepped _ -> assert_failure "Expected Completed, got Stepped"

(* ==================== create tests ==================== *)

let test_create_returns_simulator _ =
  let sim = create ~config:sample_config ~deps:sample_deps in
  let expected_portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
  in
  let expected_result =
    make_expected_step_result
      ~date:(date_of_string "2024-01-02")
      ~portfolio:expected_portfolio ~trades:[]
  in
  assert_that (step sim)
    (is_ok_and_holds
       (is_stepped (fun (_, result) -> assert_equal expected_result result)))

let test_create_with_empty_prices _ =
  let sim = create ~config:sample_config ~deps:{ prices = [] } in
  let expected_portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
  in
  let expected_result =
    make_expected_step_result
      ~date:(date_of_string "2024-01-02")
      ~portfolio:expected_portfolio ~trades:[]
  in
  assert_that (step sim)
    (is_ok_and_holds
       (is_stepped (fun (_, result) -> assert_equal expected_result result)))

(* ==================== step tests ==================== *)

let test_step_advances_date _ =
  let sim = create ~config:sample_config ~deps:sample_deps in
  let expected_portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
  in
  let expected_result1 =
    make_expected_step_result
      ~date:(date_of_string "2024-01-02")
      ~portfolio:expected_portfolio ~trades:[]
  in
  let expected_result2 =
    make_expected_step_result
      ~date:(date_of_string "2024-01-03")
      ~portfolio:expected_portfolio ~trades:[]
  in
  assert_that (step sim)
    (is_ok_and_holds
       (is_stepped (fun (sim', result1) ->
            assert_equal expected_result1 result1;
            assert_that (step sim')
              (is_ok_and_holds
                 (is_stepped (fun (_, result2) ->
                      assert_equal expected_result2 result2))))))

let test_step_returns_completed_when_done _ =
  let config =
    {
      sample_config with
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-02";
    }
  in
  let sim = create ~config ~deps:sample_deps in
  let expected_portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
  in
  assert_that (step sim)
    (is_ok_and_holds
       (is_completed (fun portfolio ->
            assert_equal expected_portfolio portfolio)))

(* ==================== run tests ==================== *)

let test_run_completes_simulation _ =
  let sim = create ~config:sample_config ~deps:sample_deps in
  let expected_portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
  in
  let expected_steps =
    [
      make_expected_step_result
        ~date:(date_of_string "2024-01-02")
        ~portfolio:expected_portfolio ~trades:[];
      make_expected_step_result
        ~date:(date_of_string "2024-01-03")
        ~portfolio:expected_portfolio ~trades:[];
      make_expected_step_result
        ~date:(date_of_string "2024-01-04")
        ~portfolio:expected_portfolio ~trades:[];
    ]
  in
  assert_that (run sim)
    (is_ok_and_holds (fun (steps, final_portfolio) ->
         assert_equal expected_steps steps;
         assert_equal expected_portfolio final_portfolio))

let test_run_on_already_complete _ =
  let config =
    {
      sample_config with
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-02";
    }
  in
  let sim = create ~config ~deps:sample_deps in
  let expected_portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:10000.0 ()
  in
  assert_that (run sim)
    (is_ok_and_holds (fun (steps, final_portfolio) ->
         assert_that steps (size_is 0);
         assert_equal expected_portfolio final_portfolio))

(* ==================== order execution tests ==================== *)

let make_order ~id ~symbol ~side ~order_type ~quantity () =
  Trading_orders.Types.
    {
      id;
      symbol;
      side;
      order_type;
      quantity;
      time_in_force = GTC;
      status = Pending;
      filled_quantity = 0.0;
      avg_fill_price = None;
      created_at = Time_ns_unix.now ();
      updated_at = Time_ns_unix.now ();
    }

let test_submit_market_order_executes_next_step _ =
  let sim = create ~config:sample_config ~deps:sample_deps in
  let open Trading_base.Types in
  (* Submit a market buy order *)
  let order =
    make_order ~id:"order1" ~symbol:"AAPL" ~side:Buy ~order_type:Market
      ~quantity:10.0 ()
  in
  let sim', statuses = submit_orders sim [ order ] in
  (* Check order submitted successfully *)
  assert_that (List.hd_exn statuses) is_ok;
  (* Step the simulation - order should execute at open price (150.0) *)
  assert_that (step sim')
    (is_ok_and_holds
       (is_stepped (fun (_, result) ->
            (* Should have 1 trade *)
            assert_that result.trades (size_is 1);
            let trade = List.hd_exn result.trades in
            assert_that trade.symbol (equal_to "AAPL");
            assert_that trade.side (equal_to Buy);
            assert_that trade.quantity (float_equal 10.0);
            (* Market orders execute at open price *)
            assert_that trade.price (float_equal 150.0);
            (* Commission: max(0.01 * 10, 1.0) = 1.0 *)
            assert_that trade.commission (float_equal 1.0);
            (* Portfolio should be updated *)
            let expected_cash = 10000.0 -. (150.0 *. 10.0) -. 1.0 in
            let (portfolio : Trading_portfolio.Portfolio.t) =
              result.portfolio
            in
            assert_that portfolio.current_cash (float_equal expected_cash))))

let test_submit_limit_buy_order_executes_when_price_met _ =
  let sim = create ~config:sample_config ~deps:sample_deps in
  let open Trading_base.Types in
  (* Submit a limit buy order at 152.0 *)
  let order =
    make_order ~id:"order1" ~symbol:"AAPL" ~side:Buy ~order_type:(Limit 152.0)
      ~quantity:10.0 ()
  in
  let sim', statuses = submit_orders sim [ order ] in
  assert_that (List.hd_exn statuses) is_ok;
  (* Step - order should execute because open (150.0) <= limit (152.0) *)
  assert_that (step sim')
    (is_ok_and_holds
       (is_stepped (fun (_, result) ->
            (* Should have 1 trade *)
            assert_that result.trades (size_is 1);
            let trade = List.hd_exn result.trades in
            (* Should fill at open price (150.0) which is better than limit *)
            assert_that trade.price (float_equal 150.0))))

let test_limit_order_does_not_execute_when_price_not_met _ =
  let sim = create ~config:sample_config ~deps:sample_deps in
  let open Trading_base.Types in
  (* Submit a limit buy order at 148.0 - below the low (149.0) *)
  let order =
    make_order ~id:"order1" ~symbol:"AAPL" ~side:Buy ~order_type:(Limit 148.0)
      ~quantity:10.0 ()
  in
  let sim', statuses = submit_orders sim [ order ] in
  assert_that (List.hd_exn statuses) is_ok;
  (* Step - order should NOT execute *)
  assert_that (step sim')
    (is_ok_and_holds
       (is_stepped (fun (_, result) ->
            (* Should have no trades *)
            assert_that result.trades (size_is 0);
            (* Portfolio unchanged *)
            let (portfolio : Trading_portfolio.Portfolio.t) =
              result.portfolio
            in
            assert_that portfolio.current_cash (float_equal 10000.0))))

let test_run_with_order_execution _ =
  let sim = create ~config:sample_config ~deps:sample_deps in
  let open Trading_base.Types in
  (* Submit multiple orders *)
  let order1 =
    make_order ~id:"order1" ~symbol:"AAPL" ~side:Buy ~order_type:Market
      ~quantity:10.0 ()
  in
  let order2 =
    make_order ~id:"order2" ~symbol:"AAPL" ~side:Sell ~order_type:(Limit 158.0)
      ~quantity:5.0 ()
  in
  let sim', _ = submit_orders sim [ order1; order2 ] in
  (* Run the full simulation *)
  assert_that (run sim')
    (is_ok_and_holds (fun (steps, final_portfolio) ->
         (* Should have 3 steps (2024-01-02, 03, 04) *)
         assert_that steps (size_is 3);
         (* First step: Market buy executes *)
         let step1 = List.nth_exn steps 0 in
         assert_that step1.trades (size_is 1);
         (* Second step: Limit sell should execute at 158.0 *)
         let step2 = List.nth_exn steps 1 in
         assert_that step2.trades (size_is 1);
         let sell_trade = List.hd_exn step2.trades in
         assert_that sell_trade.side (equal_to Sell);
         (* Third step: No more orders *)
         let step3 = List.nth_exn steps 2 in
         assert_that step3.trades (size_is 0);
         (* Final portfolio should reflect all trades *)
         let (portfolio : Trading_portfolio.Portfolio.t) = final_portfolio in
         (* After buying and selling, cash should have changed from initial *)
         assert_bool "Portfolio cash should have changed"
           (Float.( <> ) portfolio.current_cash 10000.0)))

(* ==================== Test Suite ==================== *)

let suite =
  "Simulator Tests"
  >::: [
         "create returns simulator" >:: test_create_returns_simulator;
         "create with empty prices" >:: test_create_with_empty_prices;
         "step advances date" >:: test_step_advances_date;
         "step returns Completed when done"
         >:: test_step_returns_completed_when_done;
         "run completes simulation" >:: test_run_completes_simulation;
         "run on already complete" >:: test_run_on_already_complete;
         "submit market order executes next step"
         >:: test_submit_market_order_executes_next_step;
         "submit limit buy order executes when price met"
         >:: test_submit_limit_buy_order_executes_when_price_met;
         "limit order does not execute when price not met"
         >:: test_limit_order_does_not_execute_when_price_not_met;
         "run with order execution" >:: test_run_with_order_execution;
       ]

let () = run_test_tt_main suite
