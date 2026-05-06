(** Buy-and-Hold benchmark strategy tests. *)

open OUnit2
open Core
open Trading_strategy
open Matchers

let date_of_string = Date.of_string

(** Apply a [CreateEntering] transition into the positions map — the engine
    would normally do this. Keyed by [Position.id] (the unique [position_id]
    string), matching what [Trading_simulation.Simulator._apply_transitions]
    does. The strategy must look up by [pos.symbol] not by map key — see #882,
    where keying by symbol masked a re-entry bug that only surfaced when the
    simulator keyed by [position_id]. *)
let apply_create_entering positions transition =
  match Position.create_entering transition with
  | Ok p -> Map.set positions ~key:p.Position.id ~data:p
  | Error err -> assert_failure ("CreateEntering failed: " ^ Status.show err)

let run_strategy strategy ~market_data ~portfolio =
  let get_price = Test_helpers.Mock_market_data.get_price market_data in
  let get_indicator _ _ _ _ = None in
  let module S = (val strategy : Strategy_interface.STRATEGY) in
  S.on_market_close ~get_price ~get_indicator ~portfolio

(** Mock market with one symbol at one fixed close price for [days] days. *)
let make_flat_market ~symbol ~start ~price ~days =
  let prices =
    Test_helpers.Price_generators.make_price_sequence ~symbol ~start_date:start
      ~days ~base_price:price ~trend:(Test_helpers.Price_generators.Uptrend 0.0)
      ~volatility:0.0
  in
  Test_helpers.Mock_market_data.create
    ~data:[ (symbol, prices) ]
    ~ema_periods:[] ~current_date:start

type entry_view = string * Position.position_side * float * float
(** [(symbol, side, target_quantity, entry_price)] tuple extracted from a
    [CreateEntering] kind — flat so it escapes the inline-record pattern. *)

let _entry_view (kind : Position.transition_kind) : entry_view option =
  match kind with
  | CreateEntering { symbol; side; target_quantity; entry_price; reasoning = _ }
    ->
      Some (symbol, side, target_quantity, entry_price)
  | _ -> None

let entry_view_of_transition (t : Position.transition) = _entry_view t.kind

(** Compose the standard "exactly one CreateEntering transition with this
    extracted view" matcher. *)
let single_entry_matcher (expected : entry_view) =
  field
    (fun (out : Strategy_interface.output) -> out.transitions)
    (elements_are
       [ field entry_view_of_transition (is_some_and (equal_to expected)) ])

let no_transitions_matcher =
  field (fun (out : Strategy_interface.output) -> out.transitions) is_empty

let make_strategy ?symbol () =
  match symbol with
  | None -> Bah_benchmark_strategy.make Bah_benchmark_strategy.default_config
  | Some s -> Bah_benchmark_strategy.make { symbol = s }

let make_portfolio ~cash = { Portfolio_view.cash; positions = String.Map.empty }

(* ===================== Tests ===================== *)

let date = date_of_string "2024-01-02"

(** Day 1 with default SPY config: $10,000 / $100.00 close = 100 whole shares;
    verify symbol, side, quantity, and entry price together. *)
let test_default_day_one_entry _ =
  let symbol = Bah_benchmark_strategy.default_symbol in
  let market = make_flat_market ~symbol ~start:date ~price:100.0 ~days:1 in
  let result =
    run_strategy (make_strategy ()) ~market_data:market
      ~portfolio:(make_portfolio ~cash:10_000.0)
  in
  assert_that result
    (is_ok_and_holds
       (single_entry_matcher (symbol, Position.Long, 100.0, 100.0)))

(** Day 1 sizing rounds down: $10,000 / $333.33 = 30.0003 → 30 whole shares. *)
let test_floors_share_count _ =
  let market =
    make_flat_market ~symbol:"SPY" ~start:date ~price:333.33 ~days:1
  in
  let result =
    run_strategy (make_strategy ()) ~market_data:market
      ~portfolio:(make_portfolio ~cash:10_000.0)
  in
  assert_that result
    (is_ok_and_holds
       (single_entry_matcher ("SPY", Position.Long, 30.0, 333.33)))

(** Custom symbol: the strategy buys what's configured, not the default. *)
let test_custom_symbol _ =
  let symbol = "QQQ" in
  let market = make_flat_market ~symbol ~start:date ~price:400.0 ~days:1 in
  let result =
    run_strategy (make_strategy ~symbol ()) ~market_data:market
      ~portfolio:(make_portfolio ~cash:10_000.0)
  in
  assert_that result
    (is_ok_and_holds
       (single_entry_matcher (symbol, Position.Long, 25.0, 400.0)))

(** Day 2+ with the position already in [portfolio.positions]: no transitions
    emitted. The strategy must not double-enter or rebalance. *)
let test_no_transitions_after_entry _ =
  let symbol = Bah_benchmark_strategy.default_symbol in
  let market = make_flat_market ~symbol ~start:date ~price:100.0 ~days:5 in
  let strategy = make_strategy () in
  (* Day 1: emit + apply the entry to build a portfolio that holds SPY. *)
  let day_one =
    run_strategy strategy ~market_data:market
      ~portfolio:(make_portfolio ~cash:10_000.0)
  in
  let transitions =
    match day_one with
    | Ok out -> out.transitions
    | Error err -> assert_failure ("Day 1 failed: " ^ Status.show err)
  in
  let positions =
    List.fold transitions ~init:String.Map.empty ~f:apply_create_entering
  in
  (* Day 2: advance the clock, present the held portfolio, expect no-op. *)
  let market_day_two =
    Test_helpers.Mock_market_data.advance market
      ~date:(date_of_string "2024-01-03")
  in
  let result =
    run_strategy strategy ~market_data:market_day_two
      ~portfolio:{ Portfolio_view.cash = 0.0; positions }
  in
  assert_that result (is_ok_and_holds no_transitions_matcher)

(** Edge case: no price for the configured symbol → no transition (silent wait,
    no error). *)
let test_no_price_no_transition _ =
  let market =
    Test_helpers.Mock_market_data.create ~data:[] ~ema_periods:[]
      ~current_date:date
  in
  let result =
    run_strategy (make_strategy ()) ~market_data:market
      ~portfolio:(make_portfolio ~cash:10_000.0)
  in
  assert_that result (is_ok_and_holds no_transitions_matcher)

(** Edge case: cash insufficient for one share → no transition. *)
let test_insufficient_cash _ =
  let symbol = Bah_benchmark_strategy.default_symbol in
  let market = make_flat_market ~symbol ~start:date ~price:400.0 ~days:1 in
  let result =
    run_strategy (make_strategy ()) ~market_data:market
      ~portfolio:(make_portfolio ~cash:50.0)
  in
  assert_that result (is_ok_and_holds no_transitions_matcher)

let suite =
  "Bah_benchmark_strategy"
  >::: [
         "default day-1 entry" >:: test_default_day_one_entry;
         "floors share count" >:: test_floors_share_count;
         "custom symbol" >:: test_custom_symbol;
         "no transitions after entry" >:: test_no_transitions_after_entry;
         "no price no transition" >:: test_no_price_no_transition;
         "insufficient cash no transition" >:: test_insufficient_cash;
       ]

let () = run_test_tt_main suite
