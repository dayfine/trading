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

let test_step_executes_market_order _ =
  let sim = create ~config:sample_config ~deps:sample_deps in
  (* Place a market order for AAPL *)
  let order_params =
    Trading_orders.Create_order.
      {
        symbol = "AAPL";
        side = Trading_base.Types.Buy;
        quantity = 10.0;
        order_type = Trading_base.Types.Market;
        time_in_force = Trading_orders.Types.GTC;
      }
  in
  let order =
    match Trading_orders.Create_order.create_order order_params with
    | Ok o -> o
    | Error err -> failwith ("Failed to create order: " ^ Status.show err)
  in
  submit_orders sim [ order ] |> ignore;
  (* Step should execute the market order *)
  match step sim with
  | Error err -> failwith ("Step failed: " ^ Status.show err)
  | Ok (Completed _) -> assert_failure "Expected Stepped, got Completed"
  | Ok (Stepped (_, result)) ->
      (* Verify that trades were generated *)
      assert_that result.trades (size_is 1);
      (* Verify portfolio was updated with the trade *)
      let expected_cash = 10000.0 -. (10.0 *. 150.0) -. 1.0 in
      (* 150.0 is open price, 1.0 is commission *)
      assert_that result.portfolio.current_cash (float_equal expected_cash);
      (* Verify position was created for AAPL *)
      let position =
        Trading_portfolio.Portfolio.get_position result.portfolio "AAPL"
      in
      assert_that position
        (is_some_and (fun (pos : Trading_portfolio.Types.portfolio_position) ->
             assert_that pos.symbol (equal_to "AAPL")))

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

(* ==================== Test Suite ==================== *)

let suite =
  "Simulator Tests"
  >::: [
         "create returns simulator" >:: test_create_returns_simulator;
         "create with empty prices" >:: test_create_with_empty_prices;
         "step executes market order" >:: test_step_executes_market_order;
         "step advances date" >:: test_step_advances_date;
         "step returns Completed when done"
         >:: test_step_returns_completed_when_done;
         "run completes simulation" >:: test_run_completes_simulation;
         "run on already complete" >:: test_run_on_already_complete;
       ]

let () = run_test_tt_main suite
