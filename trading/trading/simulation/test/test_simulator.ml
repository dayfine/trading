open OUnit2
open Core
open Trading_simulation

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
  Sim_types.
    {
      start_date = date_of_string "2024-01-02";
      end_date = date_of_string "2024-01-05";
      initial_cash = 10000.0;
      symbols = [ "AAPL" ];
      commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 };
    }

let sample_prices =
  [
    Sim_types.
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
              ~open_price:157.0 ~high:160.0 ~low:155.0 ~close:159.0
              ~volume:900000;
          ];
      };
  ]

(* ==================== create tests ==================== *)

let test_create_succeeds _ =
  let result = Simulator.create ~config:sample_config ~prices:sample_prices in
  match result with
  | Ok sim ->
      assert_equal (date_of_string "2024-01-02") (Simulator.current_date sim);
      assert_bool "Should not be complete" (not (Simulator.is_complete sim))
  | Error _ -> assert_failure "Expected create to succeed"

let test_create_with_empty_prices _ =
  let result = Simulator.create ~config:sample_config ~prices:[] in
  match result with
  | Ok sim ->
      (* Still succeeds - empty prices is valid for stub *)
      assert_equal (date_of_string "2024-01-02") (Simulator.current_date sim)
  | Error _ ->
      assert_failure "Expected create to succeed even with empty prices"

(* ==================== step tests ==================== *)

let test_step_advances_date _ =
  let sim =
    match Simulator.create ~config:sample_config ~prices:sample_prices with
    | Ok s -> s
    | Error _ -> assert_failure "Failed to create simulator"
  in
  match Simulator.step sim with
  | Ok (sim', step_result) ->
      assert_equal (date_of_string "2024-01-02") step_result.date;
      assert_equal (date_of_string "2024-01-03") (Simulator.current_date sim');
      assert_equal [] step_result.trades
  | Error _ -> assert_failure "Expected step to succeed"

let test_step_errors_when_complete _ =
  let config =
    Sim_types.
      {
        sample_config with
        start_date = date_of_string "2024-01-02";
        end_date = date_of_string "2024-01-02";
      }
  in
  let sim =
    match Simulator.create ~config ~prices:sample_prices with
    | Ok s -> s
    | Error _ -> assert_failure "Failed to create simulator"
  in
  match Simulator.step sim with
  | Ok _ -> assert_failure "Expected step to fail when complete"
  | Error status ->
      assert_bool "Error message should mention complete"
        (String.is_substring status.message ~substring:"complete")

(* ==================== run tests ==================== *)

let test_run_completes_simulation _ =
  let sim =
    match Simulator.create ~config:sample_config ~prices:sample_prices with
    | Ok s -> s
    | Error _ -> assert_failure "Failed to create simulator"
  in
  match Simulator.run sim with
  | Ok result ->
      (* start=Jan 2, end=Jan 5 -> steps for Jan 2, 3, 4 = 3 steps *)
      assert_equal 3 (List.length result.steps)
  | Error e ->
      assert_failure (Printf.sprintf "Expected run to succeed: %s" e.message)

let test_run_on_already_complete _ =
  let config =
    Sim_types.
      {
        sample_config with
        start_date = date_of_string "2024-01-02";
        end_date = date_of_string "2024-01-02";
      }
  in
  let sim =
    match Simulator.create ~config ~prices:sample_prices with
    | Ok s -> s
    | Error _ -> assert_failure "Failed to create simulator"
  in
  match Simulator.run sim with
  | Ok result -> assert_equal 0 (List.length result.steps)
  | Error _ -> assert_failure "Expected run to succeed with empty steps"

(* ==================== is_complete tests ==================== *)

let test_is_complete_false_initially _ =
  let sim =
    match Simulator.create ~config:sample_config ~prices:sample_prices with
    | Ok s -> s
    | Error _ -> assert_failure "Failed to create simulator"
  in
  assert_bool "Should not be complete initially"
    (not (Simulator.is_complete sim))

let test_is_complete_true_at_end _ =
  let config =
    Sim_types.
      {
        sample_config with
        start_date = date_of_string "2024-01-02";
        end_date = date_of_string "2024-01-02";
      }
  in
  let sim =
    match Simulator.create ~config ~prices:sample_prices with
    | Ok s -> s
    | Error _ -> assert_failure "Failed to create simulator"
  in
  assert_bool "Should be complete when start >= end" (Simulator.is_complete sim)

(* ==================== Test Suite ==================== *)

let suite =
  "Simulator Tests"
  >::: [
         (* create *)
         "create succeeds" >:: test_create_succeeds;
         "create with empty prices" >:: test_create_with_empty_prices;
         (* step *)
         "step advances date" >:: test_step_advances_date;
         "step errors when complete" >:: test_step_errors_when_complete;
         (* run *)
         "run completes simulation" >:: test_run_completes_simulation;
         "run on already complete" >:: test_run_on_already_complete;
         (* is_complete *)
         "is_complete false initially" >:: test_is_complete_false_initially;
         "is_complete true at end" >:: test_is_complete_true_at_end;
       ]

let () = run_test_tt_main suite
