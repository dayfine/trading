(** Anti-drift pins for the Friday demo.

    {!Friday_pipeline.run} calls the strategy's Friday functions one by one so
    it can show what each stage did; [on_market_close] calls them as one. If the
    two were ever wired differently, the demo would describe a strategy that
    does not exist. These tests run both on the same fixture and the same
    warmed-up state and require the same orders, and then check that the trace's
    display-only columns (ranking order, stop measurements, stages) agree with
    what the strategy itself recorded. *)

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
   walk's. The names above the cut must be the walk's, in the walk's order. *)
let test_ranking_cut_is_the_walk _ =
  let trace = Lazy.force _trace in
  assert_that
    (List.filter_map trace.ranking ~f:(fun (r : Trace.ranked_row) ->
         Option.some_if r.above_cut r.ticker))
    (equal_to
       (List.map trace.walk ~f:(fun (w : Trace.walk_row) -> w.candidate.ticker)))

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

(* The stage column is recomputed for display; for every analysed stock it
   must be the stage the screen's own analysis carried. The long cascade sees
   every analysed stock, in universe order. *)
let _shown_stage (r : Trace.ticker_row) =
  match r.pre_screen with
  | Analysed -> Some (r.ticker, r.stage.stage)
  | Not_stage_2_or_4 | Sector_blocked -> None

let _screened_stage (d : Weinstein_strategy.Audit_recorder.cascade_drop) =
  Option.some_if
    (Trading_base.Types.equal_position_side d.side Long)
    (d.outcome.ticker, d.analysis.stage.stage)

let test_displayed_stage_matches_screen _ =
  let trace = Lazy.force _trace in
  assert_that
    (List.filter_map trace.tickers ~f:_shown_stage)
    (all_of
       [
         not_ is_empty;
         equal_to (List.filter_map trace.cascade ~f:_screened_stage);
       ])

let suite =
  "friday_demo"
  >::: [
         "orders match on_market_close" >:: test_orders_match_on_market_close;
         "ranking cut is the walk" >:: test_ranking_cut_is_the_walk;
         "gate stop matches placed ticket"
         >:: test_gate_stop_matches_placed_ticket;
         "displayed stage matches screen"
         >:: test_displayed_stage_matches_screen;
       ]

let () = run_test_tt_main suite
