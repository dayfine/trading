open OUnit2
open Core
open Trading_simulation.Simulator

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
    symbols = [ "AAPL" ];
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
  (* Verify by stepping - first step should return Stepped with start date *)
  match step sim with
  | Ok (Stepped (_, result)) ->
      assert_equal (date_of_string "2024-01-02") result.date
  | Ok (Completed _) -> assert_failure "Expected Stepped on first step"
  | Error _ -> assert_failure "Expected step to succeed"

let test_create_with_empty_prices _ =
  let sim = create ~config:sample_config ~deps:{ prices = [] } in
  (* Should still work - empty prices is valid for stub *)
  match step sim with
  | Ok (Stepped (_, result)) ->
      assert_equal (date_of_string "2024-01-02") result.date
  | Ok (Completed _) -> assert_failure "Expected Stepped"
  | Error _ -> assert_failure "Expected step to succeed"

(* ==================== step tests ==================== *)

let test_step_advances_date _ =
  let sim = create ~config:sample_config ~deps:sample_deps in
  match step sim with
  | Ok (Stepped (sim', step_result)) -> (
      assert_equal (date_of_string "2024-01-02") step_result.date;
      assert_equal [] step_result.trades;
      (* Second step should be on next date *)
      match step sim' with
      | Ok (Stepped (_, result2)) ->
          assert_equal (date_of_string "2024-01-03") result2.date
      | _ -> assert_failure "Expected second step to succeed")
  | Ok (Completed _) -> assert_failure "Expected Stepped, got Completed"
  | Error _ -> assert_failure "Expected step to succeed"

let test_step_returns_completed_when_done _ =
  let config =
    {
      sample_config with
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-02";
    }
  in
  let sim = create ~config ~deps:sample_deps in
  match step sim with
  | Ok (Completed _portfolio) -> () (* expected *)
  | Ok (Stepped _) -> assert_failure "Expected Completed, got Stepped"
  | Error _ -> assert_failure "Expected step to succeed with Completed"

(* ==================== run tests ==================== *)

let test_run_completes_simulation _ =
  let sim = create ~config:sample_config ~deps:sample_deps in
  match run sim with
  | Ok (steps, _portfolio) ->
      (* start=Jan 2, end=Jan 5 -> steps for Jan 2, 3, 4 = 3 steps *)
      assert_equal 3 (List.length steps);
      (* Verify dates are in order *)
      let dates = List.map steps ~f:(fun s -> s.date) in
      assert_equal
        [
          date_of_string "2024-01-02";
          date_of_string "2024-01-03";
          date_of_string "2024-01-04";
        ]
        dates
  | Error e ->
      assert_failure (Printf.sprintf "Expected run to succeed: %s" e.message)

let test_run_on_already_complete _ =
  let config =
    {
      sample_config with
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-02";
    }
  in
  let sim = create ~config ~deps:sample_deps in
  match run sim with
  | Ok (steps, _portfolio) -> assert_equal 0 (List.length steps)
  | Error _ -> assert_failure "Expected run to succeed with empty steps"

(* ==================== Test Suite ==================== *)

let suite =
  "Simulator Tests"
  >::: [
         (* create *)
         "create returns simulator" >:: test_create_returns_simulator;
         "create with empty prices" >:: test_create_with_empty_prices;
         (* step *)
         "step advances date" >:: test_step_advances_date;
         "step returns Completed when done"
         >:: test_step_returns_completed_when_done;
         (* run *)
         "run completes simulation" >:: test_run_completes_simulation;
         "run on already complete" >:: test_run_on_already_complete;
       ]

let () = run_test_tt_main suite
