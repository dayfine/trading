(** Unit tests for [Backtest_optimal.Optimal_summary].

    Pins the metric values on small seeded round-trip lists. Covers:
    - Empty input -> zero summary with infinite profit factor.
    - Two-winner / one-loser fixture pinning every aggregated metric.
    - Drawdown over a deliberately drawdown-shaped equity curve.
    - Round-trips on the same exit-Friday batched into one equity step.

    All tests follow [.claude/rules/test-patterns.md] discipline. *)

open OUnit2
open Core
open Matchers
module S = Backtest_optimal.Optimal_summary
module OT = Backtest_optimal.Optimal_types

let _date d = Date.of_string d

(** Build a synthetic [optimal_round_trip] from the few fields the summary
    actually reads — [pnl_dollars], [r_multiple], [exit_week]. The remaining
    fields are stubbed with reasonable defaults. *)
let make_round_trip ?(symbol = "AAPL") ?(side = Trading_base.Types.Long)
    ?(entry_week = _date "2024-01-19") ?(entry_price = 100.0)
    ?(exit_week = _date "2024-02-16") ?(exit_price = 110.0)
    ?(exit_trigger = OT.End_of_run) ?(shares = 10.0)
    ?(initial_risk_dollars = 100.0) ?(pnl_dollars = 100.0) ?(r_multiple = 1.0)
    ?(cascade_grade = Weinstein_types.B) ?(passes_macro = true) () :
    OT.optimal_round_trip =
  {
    symbol;
    side;
    entry_week;
    entry_price;
    exit_week;
    exit_price;
    exit_trigger;
    shares;
    initial_risk_dollars;
    pnl_dollars;
    r_multiple;
    cascade_grade;
    passes_macro;
  }

(* ------------------------------------------------------------------ *)
(* Empty                                                               *)
(* ------------------------------------------------------------------ *)

let test_empty_summary _ =
  let result =
    S.summarize ~starting_cash:100_000.0 ~variant:OT.Constrained []
  in
  assert_that result
    (all_of
       [
         field
           (fun (s : OT.optimal_summary) -> s.total_round_trips)
           (equal_to 0);
         field (fun (s : OT.optimal_summary) -> s.winners) (equal_to 0);
         field (fun (s : OT.optimal_summary) -> s.losers) (equal_to 0);
         field
           (fun (s : OT.optimal_summary) -> s.total_return_pct)
           (float_equal 0.0);
         field
           (fun (s : OT.optimal_summary) -> s.win_rate_pct)
           (float_equal 0.0);
         field
           (fun (s : OT.optimal_summary) -> s.avg_r_multiple)
           (float_equal 0.0);
         field
           (fun (s : OT.optimal_summary) -> s.profit_factor)
           (equal_to Float.infinity);
         field
           (fun (s : OT.optimal_summary) -> s.max_drawdown_pct)
           (float_equal 0.0);
         field
           (fun (s : OT.optimal_summary) -> s.variant)
           (equal_to OT.Constrained);
       ])

(* ------------------------------------------------------------------ *)
(* 2 winners + 1 loser pin                                              *)
(* ------------------------------------------------------------------ *)

let test_seeded_three_round_trips _ =
  (* Two winners at +200 and +500 (sum 700), one loser at -100. With
     starting_cash = 10_000, total_return_pct = 600 / 10_000 = 0.06. Profit
     factor = 700 / 100 = 7.0. avg_r_multiple = (1 + 5 + (-1)) / 3 = 5/3.
     Equity curve (sorted by exit_week below): 10000 -> 10200 (+200) ->
     10100 (-100) -> 10600 (+500). Peak so far = 10200 then 10200 then
     10600. Trough below 10200 = 10100. Drawdown = (10200-10100)/10200 ≈
     0.00980392. *)
  let r1 =
    make_round_trip ~symbol:"WIN1" ~exit_week:(_date "2024-02-02")
      ~pnl_dollars:200.0 ~r_multiple:1.0 ()
  in
  let r2 =
    make_round_trip ~symbol:"LOSE" ~exit_week:(_date "2024-02-09")
      ~pnl_dollars:(-100.0) ~r_multiple:(-1.0) ()
  in
  let r3 =
    make_round_trip ~symbol:"WIN2" ~exit_week:(_date "2024-02-16")
      ~pnl_dollars:500.0 ~r_multiple:5.0 ()
  in
  let result =
    S.summarize ~starting_cash:10_000.0 ~variant:OT.Relaxed_macro [ r1; r2; r3 ]
  in
  assert_that result
    (all_of
       [
         field
           (fun (s : OT.optimal_summary) -> s.total_round_trips)
           (equal_to 3);
         field (fun (s : OT.optimal_summary) -> s.winners) (equal_to 2);
         field (fun (s : OT.optimal_summary) -> s.losers) (equal_to 1);
         field
           (fun (s : OT.optimal_summary) -> s.total_return_pct)
           (float_equal ~epsilon:1e-9 0.06);
         field
           (fun (s : OT.optimal_summary) -> s.win_rate_pct)
           (float_equal ~epsilon:1e-9 (2.0 /. 3.0));
         field
           (fun (s : OT.optimal_summary) -> s.avg_r_multiple)
           (float_equal ~epsilon:1e-9 (5.0 /. 3.0));
         field
           (fun (s : OT.optimal_summary) -> s.profit_factor)
           (float_equal ~epsilon:1e-9 7.0);
         field
           (fun (s : OT.optimal_summary) -> s.max_drawdown_pct)
           (float_equal ~epsilon:1e-9 (100.0 /. 10_200.0));
         field
           (fun (s : OT.optimal_summary) -> s.variant)
           (equal_to OT.Relaxed_macro);
       ])

(* ------------------------------------------------------------------ *)
(* Drawdown shape — sustained drawdown over multiple Fridays            *)
(* ------------------------------------------------------------------ *)

let test_drawdown_over_multiple_fridays _ =
  (* +1000, +500, then -800, -400. Equity: 10000 -> 11000 -> 11500 -> 10700
     -> 10300. Peak 11500, trough 10300, drawdown = 1200/11500. *)
  let rt1 =
    make_round_trip ~symbol:"A" ~exit_week:(_date "2024-01-05")
      ~pnl_dollars:1_000.0 ()
  in
  let rt2 =
    make_round_trip ~symbol:"B" ~exit_week:(_date "2024-01-12")
      ~pnl_dollars:500.0 ()
  in
  let rt3 =
    make_round_trip ~symbol:"C" ~exit_week:(_date "2024-01-19")
      ~pnl_dollars:(-800.0) ~r_multiple:(-1.0) ()
  in
  let rt4 =
    make_round_trip ~symbol:"D" ~exit_week:(_date "2024-01-26")
      ~pnl_dollars:(-400.0) ~r_multiple:(-1.0) ()
  in
  let result =
    S.summarize ~starting_cash:10_000.0 ~variant:OT.Constrained
      [ rt1; rt2; rt3; rt4 ]
  in
  assert_that result
    (field
       (fun (s : OT.optimal_summary) -> s.max_drawdown_pct)
       (float_equal ~epsilon:1e-9 (1_200.0 /. 11_500.0)))

(* ------------------------------------------------------------------ *)
(* Same-day batching                                                    *)
(* ------------------------------------------------------------------ *)

let test_same_exit_day_batched _ =
  (* Two round-trips exit on the same Friday: +500 and -300. Net effect on
     equity = +200, applied as one step. No intermediate trough below the
     starting peak — drawdown = 0. *)
  let rt1 =
    make_round_trip ~symbol:"A" ~exit_week:(_date "2024-01-05")
      ~pnl_dollars:500.0 ()
  in
  let rt2 =
    make_round_trip ~symbol:"B" ~exit_week:(_date "2024-01-05")
      ~pnl_dollars:(-300.0) ~r_multiple:(-1.0) ()
  in
  let result =
    S.summarize ~starting_cash:10_000.0 ~variant:OT.Constrained [ rt1; rt2 ]
  in
  assert_that result
    (all_of
       [
         field
           (fun (s : OT.optimal_summary) -> s.max_drawdown_pct)
           (float_equal 0.0);
         field
           (fun (s : OT.optimal_summary) -> s.total_return_pct)
           (float_equal ~epsilon:1e-9 0.02);
       ])

(* ------------------------------------------------------------------ *)
(* No losers => infinite profit factor                                  *)
(* ------------------------------------------------------------------ *)

let test_no_losers_infinite_profit_factor _ =
  let rt =
    make_round_trip ~symbol:"A" ~exit_week:(_date "2024-01-05")
      ~pnl_dollars:500.0 ()
  in
  let result =
    S.summarize ~starting_cash:10_000.0 ~variant:OT.Constrained [ rt ]
  in
  assert_that result
    (field
       (fun (s : OT.optimal_summary) -> s.profit_factor)
       (equal_to Float.infinity))

(* ------------------------------------------------------------------ *)
(* Test suite                                                          *)
(* ------------------------------------------------------------------ *)

let suite =
  "Optimal_summary"
  >::: [
         "empty round-trip list -> zero summary" >:: test_empty_summary;
         "seeded 2 winners + 1 loser pin" >:: test_seeded_three_round_trips;
         "drawdown over multiple Fridays"
         >:: test_drawdown_over_multiple_fridays;
         "same-day round-trips batched into one equity step"
         >:: test_same_exit_day_batched;
         "no losers => infinite profit factor"
         >:: test_no_losers_infinite_profit_factor;
       ]

let () = run_test_tt_main suite
