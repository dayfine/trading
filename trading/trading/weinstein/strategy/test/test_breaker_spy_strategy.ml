open OUnit2
open Core
open Matchers
module Breaker = Weinstein_strategy.Breaker_spy_strategy
module Bar_reader = Weinstein_strategy.Bar_reader
module Strategy_interface = Trading_strategy.Strategy_interface
module Portfolio_view = Trading_strategy.Portfolio_view
module Position = Trading_strategy.Position

let symbol = "SPY"

(* One daily bar; open/high/low default around close. *)
let make_bar date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close *. 1.01;
    low_price = close *. 0.99;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(* [base_friday] is a Friday; [friday i] is the i-th consecutive Friday. Dating
   each bar on a distinct Friday makes ISO-week aggregation in [weekly_bars_for]
   yield exactly one weekly bar per element, whose close is that Friday's close —
   the same trick [test_spy_only_weinstein_strategy.ml] uses. *)
let base_friday = Date.of_string "2020-01-03"
let friday i = Date.add_days base_friday (7 * i)

(* Daily bars, one per consecutive Friday, from a close trajectory. *)
let bars_of_closes (closes : float list) : Types.Daily_price.t list =
  List.mapi closes ~f:(fun i c -> make_bar (friday i) ~close:c)

let bar_reader_of bars = Bar_reader.of_in_memory_bars [ (symbol, bars) ]

let make_portfolio ~cash ?position () : Portfolio_view.t =
  let positions =
    match position with
    | None -> String.Map.empty
    | Some (p : Position.t) -> String.Map.singleton p.id p
  in
  { cash; positions }

(* Build a Holding SPY position at [entry_price] / [entry_date]. *)
let make_holding ~entry_price ~entry_date ~quantity () : Position.t =
  let pos_id = symbol ^ "-breaker-spy-sleeve" in
  let make_trans kind =
    { Position.position_id = pos_id; date = entry_date; kind }
  in
  let unwrap = function
    | Ok p -> p
    | Error e ->
        OUnit2.assert_failure ("position setup failed: " ^ Status.show e)
  in
  let open Position in
  create_entering
    (make_trans
       (CreateEntering
          {
            symbol;
            side = Long;
            target_quantity = quantity;
            entry_price;
            reasoning = ManualDecision { description = "test" };
          }))
  |> unwrap
  |> fun p ->
  apply_transition p
    (make_trans
       (EntryFill { filled_quantity = quantity; fill_price = entry_price }))
  |> unwrap
  |> fun p ->
  apply_transition p
    (make_trans
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

let no_indicator : Strategy_interface.get_indicator_fn = fun _ _ _ _ -> None

let run_once (module M : Strategy_interface.STRATEGY) ~today_bar ~portfolio =
  M.on_market_close
    ~get_price:(fun s -> if String.equal s symbol then Some today_bar else None)
    ~get_indicator:no_indicator ~portfolio

(* ---- matchers ---------------------------------------------------------- *)

let is_long_entry =
  is_ok_and_holds
    (field
       (fun (o : Strategy_interface.output) -> o.transitions)
       (elements_are
          [
            field
              (fun (t : Position.transition) -> t.kind)
              (matching ~msg:"Expected CreateEntering Long"
                 (function
                   | Position.CreateEntering c -> Some (c.symbol, c.side)
                   | _ -> None)
                 (equal_to
                    ((symbol, Position.Long) : string * Position.position_side)));
          ]))

let is_exit_with_label label =
  is_ok_and_holds
    (field
       (fun (o : Strategy_interface.output) -> o.transitions)
       (elements_are
          [
            field
              (fun (t : Position.transition) -> t.kind)
              (matching ~msg:"Expected TriggerExit StrategySignal"
                 (function
                   | Position.TriggerExit e -> (
                       match e.exit_reason with
                       | Position.StrategySignal s -> Some s.label
                       | _ -> None)
                   | _ -> None)
                 (equal_to label));
          ]))

let is_no_transitions =
  is_ok_and_holds
    (field (fun (o : Strategy_interface.output) -> o.transitions) is_empty)

(* Close trajectories reused from the lib fixtures' shapes. *)
let flat_then_crash =
  List.init 56 ~f:(fun _ -> 100.0) @ [ 100.0; 96.0; 92.0; 88.0 ]

let crash_then_recover = flat_then_crash @ [ 95.0 ]
let rising = List.init 60 ~f:(fun i -> 50.0 +. (Float.of_int i *. 1.5))

(* A gentle sustained decline (grind) then a sharp recovery. The decline is
   shallow (< 4%/4wk) with the index below a falling 30-week MA for many weeks —
   the slow-grind signature — while staying above the 20% absolute floor. The
   recovery then lifts the index back above a turning 30-week MA. *)
let grind_then_recover =
  List.init 40 ~f:(fun i -> 100.0 -. (Float.of_int i *. 0.4))
  @ List.init 20 ~f:(fun j -> 84.4 +. (Float.of_int j *. 2.0))

let index_of ~closes ~offset = List.length closes - 1 - offset

(* ---- tests ------------------------------------------------------------- *)

let test_first_friday_deploys_when_flat _ =
  (* Fresh sleeve, flat, first Friday on a rising tape → default-in-market buy. *)
  let bars = bars_of_closes rising in
  let today = List.last_exn bars in
  let strat = Breaker.make ~bar_reader:(bar_reader_of bars) () in
  let result =
    run_once strat ~today_bar:today
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  assert_that result is_long_entry

let test_first_midweek_deploys_when_flat _ =
  (* Same fresh in-market default, but the first tradable bar is a Wednesday: the
     deploy still fires (it does not wait for the breaker's weekly step). *)
  let bars = bars_of_closes rising in
  let wed_bar = make_bar (Date.of_string "2020-01-01") ~close:50.0 in
  let strat = Breaker.make ~bar_reader:(bar_reader_of bars) () in
  let result =
    run_once strat ~today_bar:wed_bar
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  assert_that result is_long_entry

let test_fast_crash_friday_exits_when_holding _ =
  (* Holding into a fast-crash Friday (a ~12% 4-week drop, no A-D lead) → the
     breaker fires a fast-crash exit, sold to flat. *)
  let bars = bars_of_closes flat_then_crash in
  let today = List.last_exn bars in
  let pos =
    make_holding ~entry_price:100.0 ~entry_date:(friday 0) ~quantity:1000.0 ()
  in
  let strat = Breaker.make ~bar_reader:(bar_reader_of bars) () in
  let result =
    run_once strat ~today_bar:today
      ~portfolio:(make_portfolio ~cash:0.0 ~position:pos ())
  in
  assert_that result (is_exit_with_label "breaker_fast_crash")

let test_midweek_crash_does_not_evaluate_breaker _ =
  (* Holding; a violent DOWN day mid-week (Wednesday) → no breaker evaluation
     between Fridays, so no exit fires. Proves the weekly cadence / state carry. *)
  let bars = bars_of_closes flat_then_crash in
  let wed_crash = make_bar (Date.of_string "2020-01-01") ~close:40.0 in
  let pos =
    make_holding ~entry_price:100.0 ~entry_date:(friday 0) ~quantity:1000.0 ()
  in
  let strat = Breaker.make ~bar_reader:(bar_reader_of bars) () in
  let result =
    run_once strat ~today_bar:wed_crash
      ~portfolio:(make_portfolio ~cash:0.0 ~position:pos ())
  in
  assert_that result is_no_transitions

let test_fast_crash_then_recovery_reenters _ =
  (* One instance across two Fridays: the crash Friday exits (holding → flat),
     then a later Friday recovered > 5% off the post-exit low re-enters when
     flat. Exercises breaker-state persistence across ticks. *)
  let bars = bars_of_closes crash_then_recover in
  let crash_bar =
    List.nth_exn bars (index_of ~closes:crash_then_recover ~offset:1)
  in
  let recover_bar = List.last_exn bars in
  let pos =
    make_holding ~entry_price:100.0 ~entry_date:(friday 0) ~quantity:1000.0 ()
  in
  let strat = Breaker.make ~bar_reader:(bar_reader_of bars) () in
  let exit_result =
    run_once strat ~today_bar:crash_bar
      ~portfolio:(make_portfolio ~cash:0.0 ~position:pos ())
  in
  let reenter_result =
    run_once strat ~today_bar:recover_bar
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  assert_that
    (exit_result, reenter_result)
    (all_of
       [
         field (fun (e, _) -> e) (is_exit_with_label "breaker_fast_crash");
         field (fun (_, r) -> r) is_long_entry;
       ])

let test_slow_grind_exits_after_confirm _ =
  (* Three consecutive grind Fridays while holding: the first two hold (streak
     rising), the third fires the slow-grind exit. *)
  let bars = bars_of_closes grind_then_recover in
  let grind_friday k = List.nth_exn bars (37 + k) in
  let pos =
    make_holding ~entry_price:100.0 ~entry_date:(friday 0) ~quantity:1000.0 ()
  in
  let strat = Breaker.make ~bar_reader:(bar_reader_of bars) () in
  let holding_pf () = make_portfolio ~cash:0.0 ~position:pos () in
  let a1 =
    run_once strat ~today_bar:(grind_friday 0) ~portfolio:(holding_pf ())
  in
  let a2 =
    run_once strat ~today_bar:(grind_friday 1) ~portfolio:(holding_pf ())
  in
  let a3 =
    run_once strat ~today_bar:(grind_friday 2) ~portfolio:(holding_pf ())
  in
  assert_that (a1, a2, a3)
    (all_of
       [
         field (fun (x, _, _) -> x) is_no_transitions;
         field (fun (_, x, _) -> x) is_no_transitions;
         field (fun (_, _, x) -> x) (is_exit_with_label "breaker_slow_grind");
       ])

let test_slow_reentry_above_turning_ma _ =
  (* Continuation of the grind sequence on the SAME instance: after the grind
     exit, a Friday whose index has recovered above a turning 30-week MA
     re-enters when flat. *)
  let bars = bars_of_closes grind_then_recover in
  let grind_friday k = List.nth_exn bars (37 + k) in
  let recover_bar = List.last_exn bars in
  let pos =
    make_holding ~entry_price:100.0 ~entry_date:(friday 0) ~quantity:1000.0 ()
  in
  let strat = Breaker.make ~bar_reader:(bar_reader_of bars) () in
  let holding_pf () = make_portfolio ~cash:0.0 ~position:pos () in
  let _ =
    run_once strat ~today_bar:(grind_friday 0) ~portfolio:(holding_pf ())
  in
  let _ =
    run_once strat ~today_bar:(grind_friday 1) ~portfolio:(holding_pf ())
  in
  let exit_result =
    run_once strat ~today_bar:(grind_friday 2) ~portfolio:(holding_pf ())
  in
  let reenter_result =
    run_once strat ~today_bar:recover_bar
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  assert_that
    (exit_result, reenter_result)
    (all_of
       [
         field (fun (e, _) -> e) (is_exit_with_label "breaker_slow_grind");
         field (fun (_, r) -> r) is_long_entry;
       ])

let suite =
  "breaker_spy_strategy"
  >::: [
         "first Friday deploys when flat"
         >:: test_first_friday_deploys_when_flat;
         "first mid-week bar deploys when flat"
         >:: test_first_midweek_deploys_when_flat;
         "fast-crash Friday exits when holding"
         >:: test_fast_crash_friday_exits_when_holding;
         "mid-week crash does not evaluate breaker"
         >:: test_midweek_crash_does_not_evaluate_breaker;
         "fast crash then recovery re-enters"
         >:: test_fast_crash_then_recovery_reenters;
         "slow grind exits after confirm"
         >:: test_slow_grind_exits_after_confirm;
         "slow re-entry above turning MA" >:: test_slow_reentry_above_turning_ma;
       ]

let () = run_test_tt_main suite
