open OUnit2
open Core
open Portfolio_risk

let test_snapshot_empty _ =
  let snap = snapshot ~cash:100000.0 ~positions:[] in
  assert_equal ~printer:string_of_float 100000.0 snap.total_value;
  assert_equal ~printer:string_of_float 100000.0 snap.cash;
  assert_equal ~printer:string_of_float 1.0 snap.cash_pct;
  assert_equal ~printer:string_of_float 0.0 snap.long_exposure;
  assert_equal ~printer:string_of_float 0.0 snap.short_exposure;
  assert_equal 0 snap.position_count

let test_snapshot_long_only _ =
  let positions = [ ("AAPL", 100.0, 150.0); ("MSFT", 50.0, 200.0) ] in
  let snap = snapshot ~cash:50000.0 ~positions in
  assert_equal ~printer:string_of_float 75000.0 snap.total_value;
  assert_equal ~printer:string_of_float 25000.0 snap.long_exposure;
  assert_equal ~printer:string_of_float 0.0 snap.short_exposure;
  assert_equal 2 snap.position_count;
  assert_bool "long_pct approx 1/3"
    Float.(abs (snap.long_exposure_pct -. (1.0 /. 3.0)) < 1e-6)

let test_snapshot_with_short _ =
  let positions = [ ("AAPL", 100.0, 150.0); ("TSLA", -50.0, 200.0) ] in
  let snap = snapshot ~cash:80000.0 ~positions in
  assert_equal ~printer:string_of_float 85000.0 snap.total_value;
  assert_equal ~printer:string_of_float 15000.0 snap.long_exposure;
  assert_equal ~printer:string_of_float 10000.0 snap.short_exposure;
  assert_equal 2 snap.position_count

let test_snapshot_with_sectors _ =
  let positions =
    [ ("AAPL", 100.0, 150.0); ("MSFT", 50.0, 200.0); ("AMZN", 20.0, 180.0) ]
  in
  let sectors = [ ("AAPL", "Tech"); ("MSFT", "Tech"); ("AMZN", "Tech") ] in
  let snap = snapshot_with_sectors ~cash:50000.0 ~positions ~sectors in
  assert_equal 3 snap.position_count;
  let tech_count =
    List.Assoc.find snap.sector_counts ~equal:String.equal "Tech"
  in
  assert_equal (Some 3) tech_count

let test_position_size_basic _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:100000.0
      ~entry_price:50.0 ~stop_price:45.0 ()
  in
  assert_equal ~printer:string_of_int 200 result.shares;
  assert_equal ~printer:string_of_float 10000.0 result.position_value;
  assert_equal ~printer:string_of_float 1000.0 result.risk_amount;
  assert_bool "position_pct ~= 0.10"
    Float.(abs (result.position_pct -. 0.10) < 1e-6)

let test_position_size_rounds_down _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:100000.0
      ~entry_price:47.0 ~stop_price:44.50 ()
  in
  assert_equal ~printer:string_of_int 400 result.shares

let test_position_size_invalid_stop _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:100000.0
      ~entry_price:50.0 ~stop_price:50.0 ()
  in
  assert_equal 0 result.shares;
  assert_equal ~printer:string_of_float 0.0 result.position_value

let test_position_size_big_winner _ =
  let result =
    compute_position_size ~config:default_config ~portfolio_value:100000.0
      ~entry_price:50.0 ~stop_price:45.0 ~big_winner:true ()
  in
  assert_equal ~printer:string_of_int 300 result.shares

let make_snap ?(cash = 80000.0) ?(long_exp = 15000.0) ?(short_exp = 0.0)
    ?(positions = 3) ?(sectors = []) () =
  let total = cash +. long_exp -. short_exp in
  {
    total_value = total;
    cash;
    cash_pct = (if Float.( > ) total 0.0 then cash /. total else 0.0);
    long_exposure = long_exp;
    long_exposure_pct =
      (if Float.( > ) total 0.0 then long_exp /. total else 0.0);
    short_exposure = short_exp;
    short_exposure_pct =
      (if Float.( > ) total 0.0 then short_exp /. total else 0.0);
    position_count = positions;
    sector_counts = sectors;
  }

let test_check_limits_ok _ =
  let snap = make_snap () in
  let result =
    check_limits ~config:default_config ~snapshot:snap ~proposed_side:`Long
      ~proposed_value:5000.0 ~proposed_sector:"Tech"
  in
  assert_equal (Result.Ok ()) result

let test_check_limits_max_positions _ =
  let snap = make_snap ~positions:20 () in
  let result =
    check_limits ~config:default_config ~snapshot:snap ~proposed_side:`Long
      ~proposed_value:5000.0 ~proposed_sector:"Tech"
  in
  match result with
  | Error [ Max_positions_exceeded 20 ] -> ()
  | _ -> assert_failure "Expected Max_positions_exceeded violation"

let test_check_limits_long_exposure _ =
  let snap = make_snap ~cash:15000.0 ~long_exp:85000.0 () in
  let result =
    check_limits ~config:default_config ~snapshot:snap ~proposed_side:`Long
      ~proposed_value:10000.0 ~proposed_sector:"Tech"
  in
  match result with
  | Error vs ->
      assert_bool "contains long exposure violation"
        (List.exists vs ~f:(function
          | Long_exposure_exceeded _ -> true
          | _ -> false))
  | Ok () -> assert_failure "Expected long exposure violation"

let test_check_limits_cash_minimum _ =
  let snap = make_snap ~cash:12000.0 ~long_exp:88000.0 () in
  let result =
    check_limits ~config:default_config ~snapshot:snap ~proposed_side:`Long
      ~proposed_value:5000.0 ~proposed_sector:"Tech"
  in
  match result with
  | Error vs ->
      assert_bool "contains cash minimum violation"
        (List.exists vs ~f:(function
          | Cash_below_minimum _ -> true
          | _ -> false))
  | Ok () -> assert_failure "Expected cash minimum violation"

let test_check_limits_sector_concentration _ =
  let sectors = [ ("Tech", 5) ] in
  let snap = make_snap ~sectors () in
  let result =
    check_limits ~config:default_config ~snapshot:snap ~proposed_side:`Long
      ~proposed_value:5000.0 ~proposed_sector:"Tech"
  in
  match result with
  | Error vs ->
      assert_bool "contains sector concentration violation"
        (List.exists vs ~f:(function
          | Sector_concentration ("Tech", 6) -> true
          | _ -> false))
  | Ok () -> assert_failure "Expected sector concentration violation"

let test_check_limits_multiple_violations _ =
  let snap = make_snap ~positions:20 ~cash:5000.0 ~long_exp:95000.0 () in
  let result =
    check_limits ~config:default_config ~snapshot:snap ~proposed_side:`Long
      ~proposed_value:10000.0 ~proposed_sector:"Tech"
  in
  match result with
  | Error vs -> assert_bool "multiple violations" (List.length vs >= 2)
  | Ok () -> assert_failure "Expected violations"

let test_check_limits_short_side _ =
  let snap = make_snap ~short_exp:28000.0 ~long_exp:0.0 () in
  let result =
    check_limits ~config:default_config ~snapshot:snap ~proposed_side:`Short
      ~proposed_value:10000.0 ~proposed_sector:"Finance"
  in
  match result with
  | Error vs ->
      assert_bool "contains short exposure violation"
        (List.exists vs ~f:(function
          | Short_exposure_exceeded _ -> true
          | _ -> false))
  | Ok () -> assert_failure "Expected short exposure violation"

let test_deriving _ =
  let _ = show_portfolio_snapshot (make_snap ()) in
  let _ =
    show_sizing_result
      {
        shares = 100;
        position_value = 5000.0;
        position_pct = 0.05;
        risk_amount = 500.0;
      }
  in
  let _ = show_config default_config in
  let _ = show_limit_violation (Max_positions_exceeded 20) in
  assert_bool "configs equal" (equal_config default_config default_config)

let suite =
  "portfolio_risk"
  >::: [
         "snapshot_empty" >:: test_snapshot_empty;
         "snapshot_long_only" >:: test_snapshot_long_only;
         "snapshot_with_short" >:: test_snapshot_with_short;
         "snapshot_with_sectors" >:: test_snapshot_with_sectors;
         "position_size_basic" >:: test_position_size_basic;
         "position_size_rounds_down" >:: test_position_size_rounds_down;
         "position_size_invalid_stop" >:: test_position_size_invalid_stop;
         "position_size_big_winner" >:: test_position_size_big_winner;
         "check_limits_ok" >:: test_check_limits_ok;
         "check_limits_max_positions" >:: test_check_limits_max_positions;
         "check_limits_long_exposure" >:: test_check_limits_long_exposure;
         "check_limits_cash_minimum" >:: test_check_limits_cash_minimum;
         "check_limits_sector_concentration"
         >:: test_check_limits_sector_concentration;
         "check_limits_multiple_violations"
         >:: test_check_limits_multiple_violations;
         "check_limits_short_side" >:: test_check_limits_short_side;
         "deriving" >:: test_deriving;
       ]

let () = run_test_tt_main suite
