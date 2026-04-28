(** Unit tests for [Backtest_optimal.Optimal_portfolio_filler].

    Covers, per plan §PR-3 test list:
    - Concurrent-position cap forces lower-rank candidate skip.
    - Sector cap forces skip even when ranking allows.
    - Cash exhaustion forces skip.
    - Two simultaneous candidates ranked by R-multiple (ordering pin).
    - End-of-run forces close-out for any still-open position.
    - Plus baselines: empty input, variant filtering, skip-already-held.

    All tests follow [.claude/rules/test-patterns.md] discipline: one
    [assert_that] per value, no nested asserts inside callbacks, [field] /
    [all_of] / [elements_are] for composition. *)

open OUnit2
open Core
open Matchers
module F = Backtest_optimal.Optimal_portfolio_filler
module OT = Backtest_optimal.Optimal_types

(* ------------------------------------------------------------------ *)
(* Builders                                                             *)
(* ------------------------------------------------------------------ *)

let _date d = Date.of_string d

(** Build a synthetic [candidate_entry]. Optional parameters let each test
    override only the fields it cares about. *)
let make_candidate ?(symbol = "AAPL") ?(entry_week = _date "2024-01-19")
    ?(side = Trading_base.Types.Long) ?(entry_price = 100.0)
    ?(suggested_stop = 90.0) ?(risk_pct = 0.10)
    ?(sector = "Information Technology") ?(cascade_grade = Weinstein_types.B)
    ?(passes_macro = true) () : OT.candidate_entry =
  {
    symbol;
    entry_week;
    side;
    entry_price;
    suggested_stop;
    risk_pct;
    sector;
    cascade_grade;
    passes_macro;
  }

(** Build a synthetic [scored_candidate]. The R-multiple is given directly so
    each test can pin sort ordering without driving it through arithmetic.
    [exit_price] is derived from [r_multiple] so [pnl_dollars] in the produced
    round-trip is sign-consistent with [r_multiple]. *)
let make_scored ?(symbol = "AAPL") ?(entry_week = _date "2024-01-19")
    ?(side = Trading_base.Types.Long) ?(entry_price = 100.0)
    ?(suggested_stop = 90.0) ?(sector = "Information Technology")
    ?(passes_macro = true) ?(exit_week_offset_weeks = 4) ?(r_multiple = 2.0)
    ?(exit_trigger = OT.End_of_run) () : OT.scored_candidate =
  let initial_risk_per_share = Float.abs (entry_price -. suggested_stop) in
  let raw_return_pct = r_multiple *. (initial_risk_per_share /. entry_price) in
  let exit_price =
    match side with
    | Trading_base.Types.Long -> entry_price *. (1.0 +. raw_return_pct)
    | Short -> entry_price *. (1.0 -. raw_return_pct)
  in
  let exit_week = Date.add_days entry_week (7 * exit_week_offset_weeks) in
  let entry =
    make_candidate ~symbol ~entry_week ~side ~entry_price ~suggested_stop
      ~risk_pct:(initial_risk_per_share /. entry_price)
      ~sector ~passes_macro ()
  in
  {
    entry;
    exit_week;
    exit_price;
    exit_trigger;
    raw_return_pct;
    hold_weeks = exit_week_offset_weeks;
    initial_risk_per_share;
    r_multiple;
  }

(* ------------------------------------------------------------------ *)
(* Empty / variant filter                                              *)
(* ------------------------------------------------------------------ *)

let test_fill_empty _ =
  let result =
    F.fill ~config:F.default_config
      { candidates = []; variant = OT.Constrained }
  in
  assert_that result (size_is 0)

let test_constrained_variant_drops_macro_fail _ =
  (* One candidate with passes_macro=true, one with false. Constrained
     variant should keep only the passing one. *)
  let pass = make_scored ~symbol:"AAPL" ~passes_macro:true () in
  let fail = make_scored ~symbol:"MSFT" ~passes_macro:false () in
  let result =
    F.fill ~config:F.default_config
      { candidates = [ pass; fail ]; variant = OT.Constrained }
  in
  assert_that result
    (elements_are
       [
         field (fun (rt : OT.optimal_round_trip) -> rt.symbol) (equal_to "AAPL");
       ])

let test_relaxed_macro_admits_both _ =
  (* With Relaxed_macro, both candidates are admissible. *)
  let pass = make_scored ~symbol:"AAPL" ~passes_macro:true () in
  let fail = make_scored ~symbol:"MSFT" ~passes_macro:false () in
  let result =
    F.fill ~config:F.default_config
      { candidates = [ pass; fail ]; variant = OT.Relaxed_macro }
  in
  assert_that result (size_is 2)

(* ------------------------------------------------------------------ *)
(* Two-candidate ordering by R-multiple descending                      *)
(* ------------------------------------------------------------------ *)

let test_simultaneous_candidates_ranked_by_r_descending _ =
  (* Two candidates entering on the same Friday in different sectors with no
     other constraints; the higher-R candidate must be admitted first and
     appear first in the output (ties broken by R desc). *)
  let weak = make_scored ~symbol:"WEAK" ~r_multiple:0.5 ~sector:"Sector_A" () in
  let strong =
    make_scored ~symbol:"STRONG" ~r_multiple:3.0 ~sector:"Sector_B" ()
  in
  let result =
    F.fill ~config:F.default_config
      { candidates = [ weak; strong ]; variant = OT.Relaxed_macro }
  in
  assert_that result
    (elements_are
       [
         field
           (fun (rt : OT.optimal_round_trip) -> rt.symbol)
           (equal_to "STRONG");
         field (fun (rt : OT.optimal_round_trip) -> rt.symbol) (equal_to "WEAK");
       ])

(* ------------------------------------------------------------------ *)
(* Concurrent-position cap                                              *)
(* ------------------------------------------------------------------ *)

let test_concurrent_position_cap_forces_skip _ =
  (* max_positions = 2: third candidate (lowest R) on the same Friday must be
     skipped. All three in distinct sectors so sector cap is not the cause. *)
  let cfg = { F.default_config with max_positions = 2 } in
  let c1 = make_scored ~symbol:"A" ~r_multiple:5.0 ~sector:"Sector_A" () in
  let c2 = make_scored ~symbol:"B" ~r_multiple:3.0 ~sector:"Sector_B" () in
  let c3 = make_scored ~symbol:"C" ~r_multiple:1.0 ~sector:"Sector_C" () in
  let result =
    F.fill ~config:cfg
      { candidates = [ c1; c2; c3 ]; variant = OT.Relaxed_macro }
  in
  assert_that result
    (elements_are
       [
         field (fun (rt : OT.optimal_round_trip) -> rt.symbol) (equal_to "A");
         field (fun (rt : OT.optimal_round_trip) -> rt.symbol) (equal_to "B");
       ])

(* ------------------------------------------------------------------ *)
(* Sector cap                                                            *)
(* ------------------------------------------------------------------ *)

let test_sector_cap_forces_skip _ =
  (* max_sector_concentration = 1: only one position per sector. Three
     candidates in the same sector — only the highest-R is admitted. *)
  let cfg = { F.default_config with max_sector_concentration = 1 } in
  let high = make_scored ~symbol:"AAPL" ~r_multiple:5.0 ~sector:"Tech" () in
  let mid = make_scored ~symbol:"MSFT" ~r_multiple:3.0 ~sector:"Tech" () in
  let low = make_scored ~symbol:"GOOG" ~r_multiple:1.0 ~sector:"Tech" () in
  let result =
    F.fill ~config:cfg
      { candidates = [ high; mid; low ]; variant = OT.Relaxed_macro }
  in
  assert_that result
    (elements_are
       [
         field (fun (rt : OT.optimal_round_trip) -> rt.symbol) (equal_to "AAPL");
       ])

(* ------------------------------------------------------------------ *)
(* Cash exhaustion                                                      *)
(* ------------------------------------------------------------------ *)

let test_cash_exhaustion_forces_skip _ =
  (* Tiny starting_cash so only one of two candidates can be sized. The
     higher-R candidate is admitted; the second runs out of cash. Both in
     different sectors and below max_positions. *)
  let cfg : F.config =
    {
      starting_cash = 1_000.0;
      risk_per_trade_pct = 0.10;
      max_positions = 5;
      max_sector_concentration = 5;
    }
  in
  (* risk_per_trade_dollars = 1000 * 0.10 = 100. With initial_risk_per_share
     = 10 (entry 100, stop 90), shares = floor(100/10) = 10. Position cost =
     10 * 100 = 1000. After admitting one such candidate, cash = 0, so the
     second candidate cannot be funded. *)
  let high =
    make_scored ~symbol:"A" ~r_multiple:5.0 ~entry_price:100.0
      ~suggested_stop:90.0 ~sector:"Sector_A" ()
  in
  let low =
    make_scored ~symbol:"B" ~r_multiple:1.0 ~entry_price:100.0
      ~suggested_stop:90.0 ~sector:"Sector_B" ()
  in
  let result =
    F.fill ~config:cfg
      { candidates = [ high; low ]; variant = OT.Relaxed_macro }
  in
  assert_that result
    (elements_are
       [ field (fun (rt : OT.optimal_round_trip) -> rt.symbol) (equal_to "A") ])

(* ------------------------------------------------------------------ *)
(* Skip if symbol already held                                          *)
(* ------------------------------------------------------------------ *)

let test_skip_if_symbol_already_held _ =
  (* AAPL enters week 1, exits week 5. A second AAPL candidate also enters
     week 1 (same week) — must be skipped because AAPL is already held. The
     filler emits exactly one round-trip for AAPL. *)
  let entry = _date "2024-01-19" in
  let first = make_scored ~symbol:"AAPL" ~entry_week:entry ~r_multiple:3.0 () in
  let dup =
    make_scored ~symbol:"AAPL" ~entry_week:entry ~r_multiple:5.0
      ~suggested_stop:80.0 ()
  in
  let result =
    F.fill ~config:F.default_config
      { candidates = [ first; dup ]; variant = OT.Relaxed_macro }
  in
  assert_that result
    (elements_are
       [
         all_of
           [
             field
               (fun (rt : OT.optimal_round_trip) -> rt.symbol)
               (equal_to "AAPL");
             field
               (fun (rt : OT.optimal_round_trip) -> rt.r_multiple)
               (float_equal ~epsilon:1e-6 5.0);
           ];
       ])

(* ------------------------------------------------------------------ *)
(* End-of-run close-out                                                 *)
(* ------------------------------------------------------------------ *)

let test_end_of_run_closes_out_remaining _ =
  (* A single candidate whose exit_week is later than any other entry's exit;
     the filler must close it via _close_remaining and emit it as a round-trip
     with the scorer-supplied [End_of_run] trigger preserved. *)
  let lone_eor =
    make_scored ~symbol:"LONE" ~entry_week:(_date "2024-01-19")
      ~exit_week_offset_weeks:50 ~r_multiple:2.5 ~exit_trigger:OT.End_of_run ()
  in
  let result =
    F.fill ~config:F.default_config
      { candidates = [ lone_eor ]; variant = OT.Relaxed_macro }
  in
  assert_that result
    (elements_are
       [
         all_of
           [
             field
               (fun (rt : OT.optimal_round_trip) -> rt.symbol)
               (equal_to "LONE");
             field
               (fun (rt : OT.optimal_round_trip) -> rt.exit_trigger)
               (equal_to OT.End_of_run);
             field
               (fun (rt : OT.optimal_round_trip) -> rt.shares)
               (gt (module Float_ord) 0.0);
           ];
       ])

(* ------------------------------------------------------------------ *)
(* Sequential reuse: cash freed by exit funds a later entry              *)
(* ------------------------------------------------------------------ *)

let test_cash_recycles_after_exit _ =
  (* Tight cash that funds exactly one position. Position 1 enters week 1 and
     exits week 4 with positive P&L; position 2 enters week 5. The exit's
     cash accrual must allow position 2 to be admitted. *)
  let cfg : F.config =
    {
      starting_cash = 1_000.0;
      risk_per_trade_pct = 0.10;
      max_positions = 5;
      max_sector_concentration = 5;
    }
  in
  let week1 = _date "2024-01-05" in
  let week5 = _date "2024-02-02" in
  let pos1 =
    make_scored ~symbol:"A" ~entry_week:week1 ~exit_week_offset_weeks:4
      ~entry_price:100.0 ~suggested_stop:90.0 ~r_multiple:1.0 ~sector:"Sector_A"
      ()
  in
  let pos2 =
    make_scored ~symbol:"B" ~entry_week:week5 ~exit_week_offset_weeks:2
      ~entry_price:100.0 ~suggested_stop:90.0 ~r_multiple:1.0 ~sector:"Sector_B"
      ()
  in
  let result =
    F.fill ~config:cfg
      { candidates = [ pos1; pos2 ]; variant = OT.Relaxed_macro }
  in
  assert_that result (size_is 2)

(* ------------------------------------------------------------------ *)
(* Test suite                                                          *)
(* ------------------------------------------------------------------ *)

let suite =
  "Optimal_portfolio_filler"
  >::: [
         "empty input -> no round-trips" >:: test_fill_empty;
         "Constrained variant filters macro-fail candidates"
         >:: test_constrained_variant_drops_macro_fail;
         "Relaxed_macro admits both regardless of macro flag"
         >:: test_relaxed_macro_admits_both;
         "simultaneous candidates ranked by R-multiple desc"
         >:: test_simultaneous_candidates_ranked_by_r_descending;
         "concurrent-position cap forces lower-rank skip"
         >:: test_concurrent_position_cap_forces_skip;
         "sector cap forces skip even when ranking allows"
         >:: test_sector_cap_forces_skip;
         "cash exhaustion forces skip" >:: test_cash_exhaustion_forces_skip;
         "skip if symbol already held" >:: test_skip_if_symbol_already_held;
         "end-of-run forces close-out" >:: test_end_of_run_closes_out_remaining;
         "cash recycles after exit funds a later entry"
         >:: test_cash_recycles_after_exit;
       ]

let () = run_test_tt_main suite
