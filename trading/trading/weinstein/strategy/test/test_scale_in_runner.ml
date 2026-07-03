(** Tests for {!Scale_in_runner} — gates, sizing, arbitration, and the
    default-off no-op contract of the scale-in add pass. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* ------------------------------------------------------------------ *)
(* Fixtures                                                             *)
(* ------------------------------------------------------------------ *)

let _entry_date = Date.of_string "2024-01-05" (* Friday *)
let _as_of = Date.of_string "2024-01-26" (* Friday, 3 weeks later *)

let _bar date ~close ?low ?high () =
  let low = Option.value low ~default:(close *. 0.99) in
  let high = Option.value high ~default:(close *. 1.01) in
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(* Weekly shape after a 100-breakout: advance, pullback touch, turn up while
   holding — the detector's positive pullback fixture. One daily bar per week
   is enough for the weekly aggregation. *)
let _pullback_bars =
  [
    _bar "2024-01-05" ~close:100.0 ();
    _bar "2024-01-12" ~close:108.0 ();
    _bar "2024-01-19" ~close:101.0 ~low:101.0 ();
    _bar "2024-01-26" ~close:105.0 ~low:102.0 ();
  ]

(* Steady advance, never touching the pullback zone: no Pullback signal. *)
let _no_touch_bars =
  [
    _bar "2024-01-05" ~close:100.0 ();
    _bar "2024-01-12" ~close:108.0 ~low:106.0 ();
    _bar "2024-01-19" ~close:112.0 ~low:110.0 ();
    _bar "2024-01-26" ~close:115.0 ~low:113.0 ();
  ]

let _holding_pos ?(id = "AAPL-wein-t1") ?(quantity = 10.0) symbol =
  let make_trans kind =
    { Trading_strategy.Position.position_id = id; date = _entry_date; kind }
  in
  let unwrap = function
    | Ok p -> p
    | Error _ -> OUnit2.assert_failure "position setup failed"
  in
  let open Trading_strategy.Position in
  let p =
    create_entering
      (make_trans
         (CreateEntering
            {
              symbol;
              side = Trading_base.Types.Long;
              target_quantity = quantity;
              entry_price = 100.0;
              reasoning = ManualDecision { description = "test" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans
         (EntryFill { filled_quantity = quantity; fill_price = 100.0 }))
    |> unwrap
  in
  apply_transition p
    (make_trans
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = Some 95.0;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

let _macro trend : Macro.result =
  {
    index_stage =
      {
        stage = Weinstein_types.Stage2 { weeks_advancing = 8; late = false };
        ma_value = 100.0;
        ma_direction = Weinstein_types.Rising;
        ma_slope_pct = 0.01;
        transition = None;
        above_ma_count = 8;
      };
    indicators = [];
    trend;
    confidence = 0.80;
    regime_changed = false;
    rationale = [ "fixture" ];
  }

type _fixture = {
  config : Weinstein_strategy_config.config;
  positions : Trading_strategy.Position.t String.Map.t;
  portfolio : Trading_strategy.Portfolio_view.t;
  get_price : string -> Types.Daily_price.t option;
  bar_reader : Bar_reader.t;
  prior_stages : Weinstein_types.stage Hashtbl.M(String).t;
  prior_stage_ma_values : float Hashtbl.M(String).t;
  stop_states : Weinstein_stops.stop_state String.Map.t ref;
  scale_in_added : int Hashtbl.M(String).t;
}

(* One sole Long Holding on AAPL, all gates open, pullback signal armed. *)
let _fixture ?(bars = _pullback_bars) ?(stage_late = false) ?(ma_value = 100.0)
    ?(enable = true) () =
  let config =
    let base =
      Weinstein_strategy_config.default_config ~universe:[ "AAPL" ]
        ~index_symbol:"SPY"
    in
    {
      base with
      enable_scale_in = enable;
      scale_in_config =
        { Scale_in_detector.default_config with initial_entry_fraction = 0.5 };
    }
  in
  let pos = _holding_pos "AAPL" in
  let positions = String.Map.singleton pos.Trading_strategy.Position.id pos in
  let portfolio =
    { Trading_strategy.Portfolio_view.cash = 100_000.0; positions }
  in
  let current_bar = List.last_exn bars in
  let get_price = function "AAPL" -> Some current_bar | _ -> None in
  let bar_reader = Bar_reader.of_in_memory_bars [ ("AAPL", bars) ] in
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:"AAPL"
    ~data:(Weinstein_types.Stage2 { weeks_advancing = 4; late = stage_late });
  let prior_stage_ma_values = Hashtbl.create (module String) in
  Hashtbl.set prior_stage_ma_values ~key:"AAPL" ~data:ma_value;
  let stop_states =
    ref
      (String.Map.singleton "AAPL"
         (Weinstein_stops.Initial { stop_level = 95.0; reference_level = 100.0 }))
  in
  {
    config;
    positions;
    portfolio;
    get_price;
    bar_reader;
    prior_stages;
    prior_stage_ma_values;
    stop_states;
    scale_in_added = Hashtbl.create (module String);
  }

let _run ?(macro_trend = Weinstein_types.Bullish) ?(is_screening_day = true)
    ?(halted = false) (f : _fixture) =
  Scale_in_runner.run ~config:f.config ~positions:f.positions
    ~portfolio:f.portfolio ~get_price:f.get_price ~bar_reader:f.bar_reader
    ~prior_stages:f.prior_stages ~prior_stage_ma_values:f.prior_stage_ma_values
    ~stop_states:f.stop_states ~scale_in_added:f.scale_in_added
    ~macro_result_opt:(Some (_macro macro_trend))
    ~is_screening_day ~halted ~current_date:_as_of

(* ------------------------------------------------------------------ *)
(* Tests                                                                *)
(* ------------------------------------------------------------------ *)

let test_pullback_hold_emits_sibling_add _ =
  (* PV = 100k cash + 10sh x 105 = 101,050. Add risk = 1% x (1 - 0.5) x PV =
     505.25; stop distance = 105 - 95 = 10 -> 50 shares @ 105 = $5,250. *)
  let f = _fixture () in
  let transitions, cash = _run f in
  assert_that cash (float_equal 5250.0);
  assert_that (Hashtbl.find f.scale_in_added "AAPL") (is_some_and (equal_to 1));
  assert_that transitions
    (elements_are
       [
         field
           (fun (tr : Trading_strategy.Position.transition) -> tr.kind)
           (matching ~msg:"Expected a sibling CreateEntering add"
              (function
                | Trading_strategy.Position.CreateEntering e ->
                    Some (e.symbol, e.side, e.target_quantity, e.entry_price)
                | _ -> None)
              (equal_to ("AAPL", Trading_base.Types.Long, 50.0, 105.0)));
       ])

let test_disabled_flag_is_no_op _ =
  let f = _fixture ~enable:false () in
  let transitions, cash = _run f in
  assert_that (transitions, cash) (equal_to ([], 0.0))

let test_no_signal_no_add _ =
  let f = _fixture ~bars:_no_touch_bars () in
  let transitions, _ = _run f in
  assert_that transitions is_empty

let test_bearish_macro_blocks_add _ =
  let f = _fixture () in
  let transitions, _ = _run ~macro_trend:Weinstein_types.Bearish f in
  assert_that transitions is_empty

let test_late_stage2_blocks_add _ =
  let f = _fixture ~stage_late:true () in
  let transitions, _ = _run f in
  assert_that transitions is_empty

let test_extended_above_ma_blocks_add _ =
  (* MA 80, close 105 -> 31% above > 15% gate. *)
  let f = _fixture ~ma_value:80.0 () in
  let transitions, _ = _run f in
  assert_that transitions is_empty

let test_add_budget_exhausted_blocks_add _ =
  let f = _fixture () in
  Hashtbl.set f.scale_in_added ~key:"AAPL" ~data:1;
  let transitions, _ = _run f in
  assert_that transitions is_empty

let test_sibling_in_flight_disarms_symbol _ =
  (* A second position on the symbol (the add already Entering) disarms it. *)
  let f = _fixture () in
  let sibling = _holding_pos ~id:"AAPL-wein-t2" ~quantity:5.0 "AAPL" in
  let positions =
    Map.set f.positions ~key:sibling.Trading_strategy.Position.id ~data:sibling
  in
  let transitions, _ = _run { f with positions } in
  assert_that transitions is_empty

let test_off_friday_is_no_op _ =
  let f = _fixture () in
  let transitions, cash = _run ~is_screening_day:false f in
  assert_that (transitions, cash) (equal_to ([], 0.0))

let test_halted_is_no_op _ =
  let f = _fixture () in
  let transitions, cash = _run ~halted:true f in
  assert_that (transitions, cash) (equal_to ([], 0.0))

let test_insufficient_cash_rejects_add_whole _ =
  (* The arbitration guard (plan §3.3, no partial adds): with only $100 cash
     the signalled add's full cost cannot fit — the cash gate must reject it
     outright, consuming zero cash AND zero add budget (the symbol stays
     add-eligible for a later, funded Friday). *)
  let f = _fixture () in
  let portfolio =
    { f.portfolio with Trading_strategy.Portfolio_view.cash = 100.0 }
  in
  let transitions, cash = _run { f with portfolio } in
  assert_that (transitions, cash) (equal_to ([], 0.0));
  assert_that (Hashtbl.find f.scale_in_added "AAPL") is_none

let test_stop_at_or_above_price_blocks_add _ =
  (* No defined risk: a stop at/above the current close blocks the add —
     sizing off a non-positive stop distance is never attempted (Weinstein
     spine: risk is defined by the stop). *)
  let f = _fixture () in
  let stop_states =
    ref
      (String.Map.singleton "AAPL"
         (Weinstein_stops.Initial
            { stop_level = 106.0; reference_level = 108.0 }))
  in
  let transitions, cash = _run { f with stop_states } in
  assert_that (transitions, cash) (equal_to ([], 0.0))

let test_per_name_cap_exhausted_sizes_zero _ =
  (* Existing sibling notional already over max_position_pct_long (500 sh x
     105 = 52,500 vs cap 0.30 x PV 152,500 = 45,750) -> cap_left = 0 -> zero
     shares -> no add. *)
  let f = _fixture () in
  let pos = _holding_pos ~quantity:500.0 "AAPL" in
  let positions = String.Map.singleton pos.Trading_strategy.Position.id pos in
  let portfolio =
    { Trading_strategy.Portfolio_view.cash = 100_000.0; positions }
  in
  let transitions, _ = _run { f with positions; portfolio } in
  assert_that transitions is_empty

let suite =
  "scale_in_runner"
  >::: [
         "pullback hold emits sibling add"
         >:: test_pullback_hold_emits_sibling_add;
         "disabled flag is a no-op" >:: test_disabled_flag_is_no_op;
         "no signal, no add" >:: test_no_signal_no_add;
         "bearish macro blocks add" >:: test_bearish_macro_blocks_add;
         "late Stage 2 blocks add" >:: test_late_stage2_blocks_add;
         "extension gate blocks add" >:: test_extended_above_ma_blocks_add;
         "add budget exhausted blocks add"
         >:: test_add_budget_exhausted_blocks_add;
         "sibling in flight disarms symbol"
         >:: test_sibling_in_flight_disarms_symbol;
         "off-Friday is a no-op" >:: test_off_friday_is_no_op;
         "halted is a no-op" >:: test_halted_is_no_op;
         "insufficient cash rejects the add whole"
         >:: test_insufficient_cash_rejects_add_whole;
         "stop at/above price blocks add (no defined risk)"
         >:: test_stop_at_or_above_price_blocks_add;
         "per-name cap exhausted sizes to zero"
         >:: test_per_name_cap_exhausted_sizes_zero;
       ]

let () = run_test_tt_main suite
