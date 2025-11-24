open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers

let date_of_string s = Date.of_string s

(** Helper to create a daily price *)
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

(* ==================== create tests ==================== *)

let test_create_returns_simulator _ =
  let sim = create ~config:sample_config ~deps:sample_deps in
  assert_ok_with ~msg:"First step should succeed" (step sim) ~f:(function
    | Stepped (_, result) ->
        assert_equal (date_of_string "2024-01-02") result.date
    | Completed _ -> assert_failure "Expected Stepped on first step")

let test_create_with_empty_prices _ =
  let sim = create ~config:sample_config ~deps:{ prices = [] } in
  assert_ok_with ~msg:"Step with empty prices should succeed" (step sim)
    ~f:(function
    | Stepped (_, result) ->
        assert_equal (date_of_string "2024-01-02") result.date
    | Completed _ -> assert_failure "Expected Stepped")

(* ==================== step tests ==================== *)

let test_step_advances_date _ =
  let sim = create ~config:sample_config ~deps:sample_deps in
  assert_ok_with ~msg:"First step should succeed" (step sim) ~f:(function
    | Stepped (sim', step_result) ->
        assert_equal (date_of_string "2024-01-02") step_result.date;
        assert_equal [] step_result.trades;
        assert_ok_with ~msg:"Second step should succeed" (step sim')
          ~f:(function
          | Stepped (_, result2) ->
              assert_equal (date_of_string "2024-01-03") result2.date
          | Completed _ -> assert_failure "Expected Stepped on second step")
    | Completed _ -> assert_failure "Expected Stepped, got Completed")

let test_step_returns_completed_when_done _ =
  let config =
    {
      sample_config with
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-02";
    }
  in
  let sim = create ~config ~deps:sample_deps in
  assert_ok_with ~msg:"Step should return Completed" (step sim) ~f:(function
    | Completed _portfolio -> ()
    | Stepped _ -> assert_failure "Expected Completed, got Stepped")

(* ==================== run tests ==================== *)

let test_run_completes_simulation _ =
  let sim = create ~config:sample_config ~deps:sample_deps in
  assert_ok_with ~msg:"Run should succeed" (run sim)
    ~f:(fun (steps, _portfolio) ->
      assert_equal ~msg:"Should have 3 steps" 3 (List.length steps);
      let dates = List.map steps ~f:(fun s -> s.date) in
      assert_equal ~msg:"Dates should be in order"
        [
          date_of_string "2024-01-02";
          date_of_string "2024-01-03";
          date_of_string "2024-01-04";
        ]
        dates)

let test_run_on_already_complete _ =
  let config =
    {
      sample_config with
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-02";
    }
  in
  let sim = create ~config ~deps:sample_deps in
  assert_ok_with ~msg:"Run on complete should succeed" (run sim)
    ~f:(fun (steps, _portfolio) ->
      assert_equal ~msg:"Should have 0 steps" 0 (List.length steps))

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
       ]

let () = run_test_tt_main suite
