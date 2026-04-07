open OUnit2
open Core
open Matchers
open Weinstein_order_gen
open Trading_base.Types

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let as_of = Date.of_string "2024-01-01"

(** Build a Position.t in Holding state. *)
let make_holding_position ~ticker ~side ~quantity ~entry_price =
  let create_tr =
    {
      Trading_strategy.Position.position_id = ticker ^ "-1";
      date = as_of;
      kind =
        Trading_strategy.Position.CreateEntering
          {
            symbol = ticker;
            side;
            target_quantity = quantity;
            entry_price;
            reasoning =
              Trading_strategy.Position.TechnicalSignal
                { indicator = "Weinstein"; description = "Stage2 breakout" };
          };
    }
  in
  let pos =
    match Trading_strategy.Position.create_entering create_tr with
    | Ok p -> p
    | Error err -> failwith ("Failed to create position: " ^ Status.show err)
  in
  let fill_tr =
    {
      Trading_strategy.Position.position_id = ticker ^ "-1";
      date = as_of;
      kind =
        Trading_strategy.Position.EntryFill
          { filled_quantity = quantity; fill_price = entry_price };
    }
  in
  let pos =
    match Trading_strategy.Position.apply_transition pos fill_tr with
    | Ok p -> p
    | Error err -> failwith ("Failed to fill: " ^ Status.show err)
  in
  let complete_tr =
    {
      Trading_strategy.Position.position_id = ticker ^ "-1";
      date = as_of;
      kind =
        Trading_strategy.Position.EntryComplete
          {
            risk_params =
              {
                Trading_strategy.Position.stop_loss_price =
                  Some (entry_price *. 0.92);
                take_profit_price = None;
                max_hold_days = None;
              };
          };
    }
  in
  match Trading_strategy.Position.apply_transition pos complete_tr with
  | Ok p -> p
  | Error err -> failwith ("Failed to complete entry: " ^ Status.show err)

let positions_of entries =
  List.fold entries ~init:String.Map.empty ~f:(fun acc (ticker, pos) ->
      Map.set acc ~key:ticker ~data:pos)

let snapshot_with_value ~total_value ~positions_count =
  {
    Portfolio_risk.total_value;
    cash = total_value *. 0.5;
    cash_pct = 0.5;
    long_exposure = total_value *. 0.5;
    long_exposure_pct = 0.5;
    short_exposure = 0.0;
    short_exposure_pct = 0.0;
    position_count = positions_count;
    sector_counts = [];
  }

let risk_cfg = Portfolio_risk.default_config

(* ------------------------------------------------------------------ *)
(* from_candidates: empty candidates                                    *)
(* ------------------------------------------------------------------ *)

let test_from_candidates_empty _ =
  let snapshot = snapshot_with_value ~total_value:100000.0 ~positions_count:0 in
  let result = from_candidates ~candidates:[] ~snapshot ~config:risk_cfg in
  assert_that result is_empty

(* ------------------------------------------------------------------ *)
(* from_candidates: max positions limit excludes candidate             *)
(* ------------------------------------------------------------------ *)

let test_from_candidates_limit_excluded _ =
  (* Set up a full portfolio (max_positions = 20) *)
  let cfg = { risk_cfg with Portfolio_risk.max_positions = 1 } in
  let snapshot =
    {
      (snapshot_with_value ~total_value:100000.0 ~positions_count:1) with
      Portfolio_risk.position_count = 1;
    }
  in
  (* A rising bar series sufficient for a screener candidate *)
  let make_bar i p =
    let date = Date.add_days (Date.of_string "2020-01-06") (i * 7) in
    {
      Types.Daily_price.date;
      open_price = p;
      high_price = p *. 1.02;
      low_price = p *. 0.98;
      close_price = p;
      adjusted_close = p;
      volume = 3000;
    }
  in
  let bars =
    List.init 35 ~f:(fun i -> make_bar i (50.0 +. (Float.of_int i *. 2.0)))
  in
  let analysis =
    Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker:"AAPL"
      ~bars ~benchmark_bars:[]
      ~prior_stage:(Some (Weinstein_types.Stage1 { weeks_in_base = 12 }))
      ~as_of_date:as_of
  in
  let sector =
    {
      Screener.sector_name = "Tech";
      rating = Screener.Strong;
      stage = Weinstein_types.Stage2 { weeks_advancing = 5; late = false };
    }
  in
  let candidate =
    {
      Screener.ticker = "AAPL";
      analysis;
      sector;
      grade = Weinstein_types.A;
      score = 80;
      suggested_entry = 120.0;
      suggested_stop = 110.0;
      risk_pct = 0.083;
      swing_target = None;
      rationale = [ "Stage2 breakout"; "Strong volume" ];
    }
  in
  let result =
    from_candidates ~candidates:[ candidate ] ~snapshot ~config:cfg
  in
  assert_that result is_empty

(* ------------------------------------------------------------------ *)
(* from_candidates: valid candidate produces StopLimit entry order     *)
(* ------------------------------------------------------------------ *)

let test_from_candidates_produces_stop_limit _ =
  let snapshot = snapshot_with_value ~total_value:100000.0 ~positions_count:0 in
  let sector =
    {
      Screener.sector_name = "Tech";
      rating = Screener.Neutral;
      stage = Weinstein_types.Stage2 { weeks_advancing = 5; late = false };
    }
  in
  let make_bar i p =
    let date = Date.add_days (Date.of_string "2020-01-06") (i * 7) in
    {
      Types.Daily_price.date;
      open_price = p;
      high_price = p *. 1.02;
      low_price = p *. 0.98;
      close_price = p;
      adjusted_close = p;
      volume = 3000;
    }
  in
  let bars =
    List.init 35 ~f:(fun i -> make_bar i (50.0 +. (Float.of_int i *. 2.0)))
  in
  let analysis =
    Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker:"AAPL"
      ~bars ~benchmark_bars:[]
      ~prior_stage:(Some (Weinstein_types.Stage1 { weeks_in_base = 12 }))
      ~as_of_date:as_of
  in
  let candidate =
    {
      Screener.ticker = "AAPL";
      analysis;
      sector;
      grade = Weinstein_types.B;
      score = 60;
      suggested_entry = 120.0;
      suggested_stop = 110.0;
      risk_pct = 0.083;
      swing_target = None;
      rationale = [ "Stage2 breakout" ];
    }
  in
  let result =
    from_candidates ~candidates:[ candidate ] ~snapshot ~config:risk_cfg
  in
  assert_that result
    (elements_are
       [
         (fun order ->
           assert_that order.ticker (equal_to "AAPL");
           assert_that order.side (equal_to Buy);
           assert_that order.order_type (equal_to (StopLimit (120.0, 120.0)));
           assert_that order.grade (is_some_and (equal_to Weinstein_types.B)));
       ])

(* ------------------------------------------------------------------ *)
(* from_stop_adjustments: Stop_raised events                           *)
(* ------------------------------------------------------------------ *)

let test_from_stop_adjustments_raised _ =
  let pos =
    make_holding_position ~ticker:"TSLA" ~side:Long ~quantity:100.0
      ~entry_price:250.0
  in
  let positions = positions_of [ ("TSLA", pos) ] in
  let adjustments =
    [
      ( "TSLA",
        Weinstein_stops.Stop_raised
          {
            old_level = 220.0;
            new_level = 235.0;
            reason = "correction low raised";
          } );
    ]
  in
  let result = from_stop_adjustments ~adjustments ~positions in
  assert_that result
    (elements_are
       [
         (fun order ->
           assert_that order.ticker (equal_to "TSLA");
           assert_that order.side (equal_to Sell);
           assert_that order.order_type (equal_to (Stop 235.0));
           assert_that order.shares (equal_to 100);
           assert_that order.grade is_none);
       ])

(* ------------------------------------------------------------------ *)
(* from_stop_adjustments: Stop_hit ignored                             *)
(* ------------------------------------------------------------------ *)

let test_from_stop_adjustments_ignores_hit _ =
  let pos =
    make_holding_position ~ticker:"TSLA" ~side:Long ~quantity:50.0
      ~entry_price:200.0
  in
  let positions = positions_of [ ("TSLA", pos) ] in
  let adjustments =
    [
      ( "TSLA",
        Weinstein_stops.Stop_hit { trigger_price = 195.0; stop_level = 196.0 }
      );
    ]
  in
  let result = from_stop_adjustments ~adjustments ~positions in
  assert_that result is_empty

(* ------------------------------------------------------------------ *)
(* from_exits: Stop_hit events produce market exit orders              *)
(* ------------------------------------------------------------------ *)

let test_from_exits_stop_hit _ =
  let pos =
    make_holding_position ~ticker:"NVDA" ~side:Long ~quantity:30.0
      ~entry_price:500.0
  in
  let positions = positions_of [ ("NVDA", pos) ] in
  let exits =
    [
      ( "NVDA",
        Weinstein_stops.Stop_hit { trigger_price = 460.0; stop_level = 462.0 }
      );
    ]
  in
  let result = from_exits ~exits ~positions in
  assert_that result
    (elements_are
       [
         (fun order ->
           assert_that order.ticker (equal_to "NVDA");
           assert_that order.side (equal_to Sell);
           assert_that order.order_type (equal_to Market);
           assert_that order.shares (equal_to 30);
           assert_that order.grade is_none);
       ])

(* ------------------------------------------------------------------ *)
(* from_exits: short position uses Buy to cover                        *)
(* ------------------------------------------------------------------ *)

let test_from_exits_short_position _ =
  let pos =
    make_holding_position ~ticker:"XYZ" ~side:Short ~quantity:20.0
      ~entry_price:80.0
  in
  let positions = positions_of [ ("XYZ", pos) ] in
  let exits =
    [
      ( "XYZ",
        Weinstein_stops.Stop_hit { trigger_price = 88.0; stop_level = 87.0 } );
    ]
  in
  let result = from_exits ~exits ~positions in
  assert_that result
    (elements_are
       [
         (fun order ->
           assert_that order.ticker (equal_to "XYZ");
           assert_that order.side (equal_to Buy);
           assert_that order.order_type (equal_to Market));
       ])

(* ------------------------------------------------------------------ *)
(* from_exits: Stop_raised ignored                                     *)
(* ------------------------------------------------------------------ *)

let test_from_exits_ignores_raised _ =
  let pos =
    make_holding_position ~ticker:"AAPL" ~side:Long ~quantity:50.0
      ~entry_price:150.0
  in
  let positions = positions_of [ ("AAPL", pos) ] in
  let exits =
    [
      ( "AAPL",
        Weinstein_stops.Stop_raised
          { old_level = 130.0; new_level = 138.0; reason = "raised" } );
    ]
  in
  let result = from_exits ~exits ~positions in
  assert_that result is_empty

(* ------------------------------------------------------------------ *)
(* from_exits: unknown ticker ignored gracefully                       *)
(* ------------------------------------------------------------------ *)

let test_from_exits_unknown_ticker _ =
  let exits =
    [
      ( "UNKNOWN",
        Weinstein_stops.Stop_hit { trigger_price = 100.0; stop_level = 101.0 }
      );
    ]
  in
  let result = from_exits ~exits ~positions:String.Map.empty in
  assert_that result is_empty

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("weinstein_order_gen"
    >::: [
           "from_candidates_empty" >:: test_from_candidates_empty;
           "from_candidates_limit_excluded"
           >:: test_from_candidates_limit_excluded;
           "from_candidates_produces_stop_limit"
           >:: test_from_candidates_produces_stop_limit;
           "from_stop_adjustments_raised" >:: test_from_stop_adjustments_raised;
           "from_stop_adjustments_ignores_hit"
           >:: test_from_stop_adjustments_ignores_hit;
           "from_exits_stop_hit" >:: test_from_exits_stop_hit;
           "from_exits_short_position" >:: test_from_exits_short_position;
           "from_exits_ignores_raised" >:: test_from_exits_ignores_raised;
           "from_exits_unknown_ticker" >:: test_from_exits_unknown_ticker;
         ])
