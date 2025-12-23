open OUnit2
open Core
open Trading_simulation.Intent

let date_of_string s = Date.of_string s

let test_create_simple_intent _ =
  let intent =
    {
      id = "test-intent-1";
      created_date = date_of_string "2024-01-01";
      symbol = "AAPL";
      side = Trading_base.Types.Buy;
      goal = AbsoluteShares 100.0;
      execution =
        SingleOrder { price = 150.0; order_type = Trading_base.Types.Limit 150.0 };
      reasoning =
        {
          signal =
            TechnicalIndicator
              {
                indicator = "EMA";
                value = 148.0;
                threshold = 150.0;
                condition = "crossed above";
              };
          confidence = 0.8;
          description = "Price crossed above EMA(30)";
        };
      status = Active;
      expires_date = None;
    }
  in
  assert_equal "test-intent-1" intent.id;
  assert_equal "AAPL" intent.symbol;
  assert_equal Trading_base.Types.Buy intent.side

let test_intent_with_staged_entry _ =
  let intent =
    {
      id = "test-intent-2";
      created_date = date_of_string "2024-01-01";
      symbol = "MSFT";
      side = Trading_base.Types.Buy;
      goal = TargetPosition 200.0;
      execution =
        StagedEntry
          [
            {
              fraction = 0.5;
              price = 100.0;
              order_type = Trading_base.Types.Limit 100.0;
            };
            {
              fraction = 0.5;
              price = 95.0;
              order_type = Trading_base.Types.Limit 95.0;
            };
          ];
      reasoning =
        {
          signal =
            PriceAction
              { pattern = "breakout"; description = "Price broke resistance" };
          confidence = 0.75;
          description = "Staged entry at support levels";
        };
      status = Active;
      expires_date = Some (date_of_string "2024-01-10");
    }
  in
  match intent.execution with
  | StagedEntry orders ->
      assert_equal 2 (List.length orders);
      assert_equal 0.5 (List.hd_exn orders).fraction
  | _ -> assert_failure "Expected StagedEntry"

let test_intent_actions _ =
  let intent =
    {
      id = "intent-1";
      created_date = date_of_string "2024-01-01";
      symbol = "AAPL";
      side = Trading_base.Types.Buy;
      goal = AbsoluteShares 100.0;
      execution =
        SingleOrder { price = 150.0; order_type = Trading_base.Types.Limit 150.0 };
      reasoning =
        {
          signal =
            TechnicalIndicator
              {
                indicator = "EMA";
                value = 148.0;
                threshold = 150.0;
                condition = "crossed above";
              };
          confidence = 0.8;
          description = "Test intent";
        };
      status = Active;
      expires_date = None;
    }
  in
  let create_action = CreateIntent intent in
  let update_action =
    UpdateIntent
      {
        id = "intent-1";
        new_status =
          PartiallyFilled { filled_quantity = 50.0; remaining_quantity = 50.0 };
      }
  in
  let cancel_action =
    CancelIntent { id = "intent-1"; reason = "Market conditions changed" }
  in
  (match create_action with
  | CreateIntent i -> assert_equal "intent-1" i.id
  | UpdateIntent _ | CancelIntent _ -> assert_failure "Expected CreateIntent");
  (match update_action with
  | UpdateIntent { id; _ } -> assert_equal "intent-1" id
  | CreateIntent _ | CancelIntent _ -> assert_failure "Expected UpdateIntent");
  match cancel_action with
  | CancelIntent { id; reason } ->
      assert_equal "intent-1" id;
      assert_equal "Market conditions changed" reason
  | CreateIntent _ | UpdateIntent _ -> assert_failure "Expected CancelIntent"

let suite =
  "Intent Tests"
  >::: [
         "create simple intent" >:: test_create_simple_intent;
         "intent with staged entry" >:: test_intent_with_staged_entry;
         "intent actions" >:: test_intent_actions;
       ]

let () = run_test_tt_main suite
