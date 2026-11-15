(** Anti-drift pins for the Friday demo.

    {!Friday_pipeline.run} calls the strategy's Friday functions one by one so
    it can show what each stage did; [on_market_close] calls them as one. If the
    two were ever wired differently, the demo would describe a strategy that
    does not exist. These tests run both on the same fixture and the same
    warmed-up state and require the same orders, and then check that the trace's
    display-only columns (ranking cut, stop measurements, stages, cash) agree
    with what the strategy itself recorded, and that the demo config differs
    from the default only where the trace says so. *)

open OUnit2
open Core
open Matchers
module Fixture = Friday_demo.Friday_demo_fixture
module Pipeline = Friday_demo.Friday_pipeline
module Trace = Friday_demo.Friday_trace
module Position = Trading_strategy.Position

let _trace = lazy (Fixture.trace ())
let _no_indicator _symbol _name _period _cadence = None

(* The strategy's own Friday: the same warm-up, then [on_market_close]. *)
let _on_market_close () =
  let inputs = Fixture.inputs () in
  let state = Pipeline.warm_up inputs ~fridays:Fixture.warmup_fridays in
  let (module S) = Pipeline.strategy inputs ~state in
  match
    S.on_market_close
      ~get_price:(Pipeline.price_on inputs.bar_reader Fixture.demo_friday)
      ~get_indicator:_no_indicator ~portfolio:inputs.portfolio
  with
  | Ok out -> (out.transitions, !(state.stop_states))
  | Error e -> assert_failure (Status.show e)

(* Every transition the strategy emits, as an order: anything that is not an
   entry would be a stage the demo does not show. *)
let _as_order ~stop_states (t : Position.transition) =
  match t.kind with
  | CreateEntering e ->
      Some
        ( e.symbol,
          e.side,
          e.target_quantity,
          e.entry_price,
          Option.map
            (Map.find stop_states e.symbol)
            ~f:Weinstein_stops.get_stop_level )
  | _ -> None

let _demo_order (o : Trace.order) =
  Some (o.symbol, o.side, o.quantity, o.trigger, o.stop)

let test_orders_match_on_market_close _ =
  let transitions, stop_states = _on_market_close () in
  let trace = Lazy.force _trace in
  assert_that
    (List.map transitions ~f:(_as_order ~stop_states))
    (all_of [ not_ is_empty; equal_to (List.map trace.orders ~f:_demo_order) ])

(* The ranking is re-sorted for display; the strategy's own top-N order is the
   walk's. The printer draws a side's cut line where its admitted rows end, so
   per side the rows printed above the line must be the walk's names in the
   walk's order, and no admitted row may be printed below it. *)
let _sides = [ Trading_base.Types.Long; Short ]

let _on_side side side_of rows =
  List.filter rows ~f:(fun r ->
      Trading_base.Types.equal_position_side (side_of r) side)

let _printed_cut (ranking : Trace.ranked_row list) side =
  let above, below =
    List.split_while
      (_on_side side (fun (r : Trace.ranked_row) -> r.side) ranking)
      ~f:(fun r -> r.above_cut)
  in
  ( List.map above ~f:(fun r -> r.ticker),
    List.exists below ~f:(fun r -> r.above_cut) )

let _walk_names (walk : Trace.walk_row list) side =
  ( List.map
      (_on_side side (fun (w : Trace.walk_row) -> w.candidate.side) walk)
      ~f:(fun w -> w.candidate.ticker),
    false )

let test_ranking_cut_is_the_walk _ =
  let trace = Lazy.force _trace in
  assert_that trace.walk (not_ is_empty);
  assert_that
    (List.map _sides ~f:(_printed_cut trace.ranking))
    (equal_to (List.map _sides ~f:(_walk_names trace.walk)))

(* The stop shown for a skipped name comes from [gate_stop]; for every placed
   name it must equal the trigger and stop the walk actually installed. *)
let _gate_of (w : Trace.walk_row) =
  Option.map w.gate
    ~f:(fun (g : Weinstein_strategy.Entry_stop_width_order.gate_stop) ->
      (w.candidate.ticker, g.entry, Some g.stop))

let _placed (w : Trace.walk_row) = Option.is_some w.entry

let test_gate_stop_matches_placed_ticket _ =
  let trace = Lazy.force _trace in
  assert_that
    (List.filter_map trace.walk ~f:(fun w ->
         if _placed w then Some (_gate_of w) else None))
    (equal_to
       (List.map trace.orders ~f:(fun (o : Trace.order) ->
            Some (o.symbol, o.trigger, o.stop))))

(* The stage columns are recomputed for display; for every analysed stock they
   (stage, MA, slope, weeks above the MA, transition) must be the stage result
   the screen's own analysis carried. The long cascade sees every analysed
   stock, in universe order. *)
let _shown_stage (r : Trace.ticker_row) =
  match r.pre_screen with
  | Analysed -> Some (r.ticker, r.stage)
  | Not_stage_2_or_4 | Sector_blocked -> None

let _screened_stage (d : Weinstein_strategy.Audit_recorder.cascade_drop) =
  Option.some_if
    (Trading_base.Types.equal_position_side d.side Long)
    (d.outcome.ticker, d.analysis.stage)

let test_displayed_stage_matches_screen _ =
  let trace = Lazy.force _trace in
  assert_that
    (List.filter_map trace.tickers ~f:_shown_stage)
    (all_of
       [
         not_ is_empty;
         equal_to (List.filter_map trace.cascade ~f:_screened_stage);
       ])

(* The walk's running cash is rebuilt for display; after the last name it must
   be the starting cash less what the orders cost at their triggers. *)
let test_cash_after_walk_is_order_cost _ =
  let trace = Lazy.force _trace in
  let cost =
    List.sum
      (module Float)
      trace.orders
      ~f:(fun (o : Trace.order) -> o.quantity *. o.trigger)
  in
  assert_that
    (Option.map (List.last trace.walk) ~f:(fun (w : Trace.walk_row) ->
         w.cash_after))
    (is_some_and (float_equal (trace.setup.cash -. cost)))

(* The trace marks a quoted value as a demo setting only where it differs from
   the strategy default, and says every other value is the default. That holds
   only while the demo changes nothing else: undoing its three settings (and its
   sector ETFs) must give back the default config. *)
let test_demo_config_is_default_but_three _ =
  let module C = Weinstein_strategy.Weinstein_strategy_config in
  let demo = Fixture.config in
  let default =
    C.default_config ~universe:demo.universe ~index_symbol:demo.indices.primary
  in
  let undone =
    {
      demo with
      sector_etfs = default.sector_etfs;
      require_structural_stop = default.require_structural_stop;
      screening_config =
        {
          demo.screening_config with
          max_buy_candidates = default.screening_config.max_buy_candidates;
          tiebreak_seed = default.screening_config.tiebreak_seed;
        };
    }
  in
  assert_that (C.sexp_of_config undone) (equal_to (C.sexp_of_config default))

let suite =
  "friday_demo"
  >::: [
         "orders match on_market_close" >:: test_orders_match_on_market_close;
         "ranking cut is the walk" >:: test_ranking_cut_is_the_walk;
         "gate stop matches placed ticket"
         >:: test_gate_stop_matches_placed_ticket;
         "displayed stage matches screen"
         >:: test_displayed_stage_matches_screen;
         "cash after the walk is the order cost"
         >:: test_cash_after_walk_is_order_cost;
         "demo config is the default but three settings"
         >:: test_demo_config_is_default_but_three;
       ]

let () = run_test_tt_main suite
