(** Unit tests for [Backtest_all_eligible.All_eligible].

    Covers, per the issue #870 acceptance criteria + plan §Acceptance criteria:
    - Three Stage-2 signals fire in a synthetic minimal scenario; verify all
      three are taken (no cash gate).
    - Per-trade exit reasons + return values match independent hand-calc.
    - Aggregate alpha matches sum of per-trade alphas.

    Plus edge cases:
    - Empty input yields zeroed aggregate (no exception).
    - Per-trade arithmetic pin (entry/shares/pnl wiring).
    - Median for both odd and even trade counts.
    - Bucket histogram exactness.
    - Win/loss/flat split exactness.

    All tests follow the [.claude/rules/test-patterns.md] discipline: one
    [assert_that] per value, no nested asserts inside callbacks, [field] /
    [all_of] / [elements_are] for composition. *)

open OUnit2
open Core
open Matchers
module AE = Backtest_all_eligible.All_eligible
module OT = Backtest_optimal.Optimal_types

(* ------------------------------------------------------------------ *)
(* Builders                                                             *)
(* ------------------------------------------------------------------ *)

let _date d = Date.of_string d

(** Build a synthetic [candidate_entry]. Optional parameters let each test
    override only the fields it cares about. *)
let make_candidate ?(symbol = "AAPL") ?(entry_week = _date "2024-01-19")
    ?(side = Trading_base.Types.Long) ?(entry_price = 100.0)
    ?(suggested_stop = 92.0) ?(risk_pct = 0.08)
    ?(sector = "Information Technology") ?(cascade_grade = Weinstein_types.B)
    ?(cascade_score = 50) ?(passes_macro = true) () : OT.candidate_entry =
  {
    symbol;
    entry_week;
    side;
    entry_price;
    suggested_stop;
    risk_pct;
    sector;
    cascade_grade;
    cascade_score;
    passes_macro;
  }

(** Build a synthetic [scored_candidate] from explicit per-trade outcome
    fields. Mirrors [Outcome_scorer._build_scored] arithmetic for [Long]
    side: callers provide [entry_price], [suggested_stop], [exit_price],
    [exit_week] and the helper computes the dependent fields. *)
let make_scored ?(symbol = "AAPL") ?(entry_week = _date "2024-01-19")
    ?(side = Trading_base.Types.Long) ?(entry_price = 100.0)
    ?(suggested_stop = 92.0) ?(cascade_score = 50) ?(passes_macro = true)
    ~exit_week ~exit_price ~(exit_trigger : OT.exit_trigger) () :
    OT.scored_candidate =
  let candidate =
    make_candidate ~symbol ~entry_week ~side ~entry_price ~suggested_stop
      ~cascade_score ~passes_macro ()
  in
  let raw_return_pct =
    match side with
    | Trading_base.Types.Long -> (exit_price -. entry_price) /. entry_price
    | Short -> (entry_price -. exit_price) /. entry_price
  in
  let hold_weeks = Date.diff exit_week entry_week / 7 in
  let initial_risk_per_share = Float.abs (entry_price -. suggested_stop) in
  let r_multiple =
    if Float.( <= ) initial_risk_per_share 0.0 then 0.0
    else
      let signed_pnl =
        match side with
        | Long -> exit_price -. entry_price
        | Short -> entry_price -. exit_price
      in
      signed_pnl /. initial_risk_per_share
  in
  {
    entry = candidate;
    exit_week;
    exit_price;
    exit_trigger;
    raw_return_pct;
    hold_weeks;
    initial_risk_per_share;
    r_multiple;
  }

(* ------------------------------------------------------------------ *)
(* Per-trade arithmetic                                                 *)
(* ------------------------------------------------------------------ *)

let test_build_trade_record_long _ =
  (* Pin the per-trade arithmetic for a long that gains 30%:
     entry=100, exit=130, $10K size → 100 shares → $3000 pnl. *)
  let scored =
    make_scored ~symbol:"AAPL" ~entry_week:(_date "2024-01-19")
      ~entry_price:100.0 ~suggested_stop:92.0 ~exit_week:(_date "2024-02-09")
      ~exit_price:130.0 ~exit_trigger:OT.End_of_run ()
  in
  let trade = AE.build_trade_record ~config:AE.default_config scored in
  assert_that trade
    (all_of
       [
         field (fun (t : AE.trade_record) -> t.symbol) (equal_to "AAPL");
         field
           (fun (t : AE.trade_record) -> t.signal_date)
           (equal_to (_date "2024-01-19"));
         field
           (fun (t : AE.trade_record) -> t.exit_date)
           (equal_to (_date "2024-02-09"));
         field (fun (t : AE.trade_record) -> t.entry_price) (float_equal 100.0);
         field (fun (t : AE.trade_record) -> t.return_pct) (float_equal 0.30);
         field (fun (t : AE.trade_record) -> t.hold_days) (equal_to 21);
         field
           (fun (t : AE.trade_record) -> t.entry_dollars)
           (float_equal 10_000.0);
         field (fun (t : AE.trade_record) -> t.shares) (float_equal 100.0);
         field (fun (t : AE.trade_record) -> t.pnl_dollars) (float_equal 3000.0);
         field
           (fun (t : AE.trade_record) -> t.exit_reason)
           (equal_to OT.End_of_run);
         field (fun (t : AE.trade_record) -> t.cascade_score) (equal_to 50);
       ])

let test_build_trade_record_short _ =
  (* Short side: entry=100, exit=80, profit. With $10K size → 100 shares,
     pnl_dollars = (100-80) * 100 = +2000. return_pct = (100-80)/100 = +0.20. *)
  let scored =
    make_scored ~symbol:"BBB" ~side:Trading_base.Types.Short ~entry_price:100.0
      ~suggested_stop:108.0 ~exit_week:(_date "2024-02-02") ~exit_price:80.0
      ~exit_trigger:OT.Stop_hit ()
  in
  let trade = AE.build_trade_record ~config:AE.default_config scored in
  assert_that trade
    (all_of
       [
         field
           (fun (t : AE.trade_record) -> t.side)
           (equal_to Trading_base.Types.Short);
         field (fun (t : AE.trade_record) -> t.return_pct) (float_equal 0.20);
         field (fun (t : AE.trade_record) -> t.pnl_dollars) (float_equal 2000.0);
         field
           (fun (t : AE.trade_record) -> t.exit_reason)
           (equal_to OT.Stop_hit);
       ])

let test_custom_entry_dollars _ =
  (* With entry_dollars=50_000 and entry_price=200, shares = 250.
     Exit at 220 → pnl = 20 * 250 = 5000, return = 0.10. *)
  let scored =
    make_scored ~entry_price:200.0 ~suggested_stop:184.0
      ~exit_week:(_date "2024-01-26") ~exit_price:220.0
      ~exit_trigger:OT.End_of_run ()
  in
  let cfg = { AE.default_config with entry_dollars = 50_000.0 } in
  let trade = AE.build_trade_record ~config:cfg scored in
  assert_that trade
    (all_of
       [
         field (fun (t : AE.trade_record) -> t.shares) (float_equal 250.0);
         field (fun (t : AE.trade_record) -> t.pnl_dollars) (float_equal 5000.0);
         field (fun (t : AE.trade_record) -> t.return_pct) (float_equal 0.10);
         field
           (fun (t : AE.trade_record) -> t.entry_dollars)
           (float_equal 50_000.0);
       ])

(* ------------------------------------------------------------------ *)
(* All-three-signals scenario (the headline acceptance test)            *)
(* ------------------------------------------------------------------ *)

let test_three_signals_all_taken_no_cash_gate _ =
  (* Three Stage-2 entries with distinct outcomes — all three appear in the
     output regardless of cash availability.

     Total $30K of "exposure" with no portfolio cash gate; in a real run,
     the second signal would have been rejected for Insufficient_cash with
     $20K starting cash. Here the diagnostic takes all three. *)
  let scored =
    [
      make_scored ~symbol:"AAA" ~entry_week:(_date "2024-01-19")
        ~entry_price:100.0 ~suggested_stop:92.0 ~exit_week:(_date "2024-02-09")
        ~exit_price:120.0 ~exit_trigger:OT.End_of_run ();
      make_scored ~symbol:"BBB" ~entry_week:(_date "2024-01-19")
        ~entry_price:50.0 ~suggested_stop:46.0 ~exit_week:(_date "2024-02-02")
        ~exit_price:45.0 ~exit_trigger:OT.Stop_hit ();
      make_scored ~symbol:"CCC" ~entry_week:(_date "2024-01-26")
        ~entry_price:200.0 ~suggested_stop:184.0
        ~exit_week:(_date "2024-03-01") ~exit_price:230.0
        ~exit_trigger:OT.Stage3_transition ();
    ]
  in
  let result = AE.grade ~config:AE.default_config ~scored in
  assert_that result.trades
    (elements_are
       [
         all_of
           [
             field (fun (t : AE.trade_record) -> t.symbol) (equal_to "AAA");
             field (fun (t : AE.trade_record) -> t.return_pct) (float_equal 0.20);
             field
               (fun (t : AE.trade_record) -> t.exit_reason)
               (equal_to OT.End_of_run);
             field
               (fun (t : AE.trade_record) -> t.pnl_dollars)
               (float_equal 2000.0);
           ];
         all_of
           [
             field (fun (t : AE.trade_record) -> t.symbol) (equal_to "BBB");
             field
               (fun (t : AE.trade_record) -> t.return_pct)
               (float_equal (-0.10));
             field
               (fun (t : AE.trade_record) -> t.exit_reason)
               (equal_to OT.Stop_hit);
             field
               (fun (t : AE.trade_record) -> t.pnl_dollars)
               (float_equal (-1000.0));
           ];
         all_of
           [
             field (fun (t : AE.trade_record) -> t.symbol) (equal_to "CCC");
             field (fun (t : AE.trade_record) -> t.return_pct) (float_equal 0.15);
             field
               (fun (t : AE.trade_record) -> t.exit_reason)
               (equal_to OT.Stage3_transition);
             field
               (fun (t : AE.trade_record) -> t.pnl_dollars)
               (float_equal 1500.0);
           ];
       ])

let test_three_signals_aggregate_matches_sum _ =
  (* Same three signals as above; assert aggregate metrics match independent
     hand-calc — alpha additivity is the key invariant. *)
  let scored =
    [
      make_scored ~symbol:"AAA" ~entry_price:100.0 ~suggested_stop:92.0
        ~exit_week:(_date "2024-02-09") ~exit_price:120.0
        ~exit_trigger:OT.End_of_run ();
      make_scored ~symbol:"BBB" ~entry_price:50.0 ~suggested_stop:46.0
        ~exit_week:(_date "2024-02-02") ~exit_price:45.0
        ~exit_trigger:OT.Stop_hit ();
      make_scored ~symbol:"CCC" ~entry_price:200.0 ~suggested_stop:184.0
        ~exit_week:(_date "2024-03-01") ~exit_price:230.0
        ~exit_trigger:OT.Stage3_transition ();
    ]
  in
  let result = AE.grade ~config:AE.default_config ~scored in
  (* Returns: 0.20, -0.10, 0.15. Sorted: -0.10, 0.15, 0.20. Median = 0.15.
     Mean = (0.20 - 0.10 + 0.15) / 3 = 0.0833... .
     Total pnl = 2000 - 1000 + 1500 = 2500. *)
  assert_that result.aggregate
    (all_of
       [
         field (fun (a : AE.aggregate) -> a.trade_count) (equal_to 3);
         field (fun (a : AE.aggregate) -> a.winners) (equal_to 2);
         field (fun (a : AE.aggregate) -> a.losers) (equal_to 1);
         field
           (fun (a : AE.aggregate) -> a.win_rate_pct)
           (float_equal ~epsilon:1e-9 (2.0 /. 3.0));
         field
           (fun (a : AE.aggregate) -> a.mean_return_pct)
           (float_equal ~epsilon:1e-9 (0.25 /. 3.0));
         field
           (fun (a : AE.aggregate) -> a.median_return_pct)
           (float_equal 0.15);
         field
           (fun (a : AE.aggregate) -> a.total_pnl_dollars)
           (float_equal 2500.0);
       ])

(* ------------------------------------------------------------------ *)
(* Edge cases                                                           *)
(* ------------------------------------------------------------------ *)

let test_empty_scored_input _ =
  let result = AE.grade ~config:AE.default_config ~scored:[] in
  assert_that result
    (all_of
       [
         field (fun (r : AE.result) -> r.trades) is_empty;
         field
           (fun (r : AE.result) -> r.aggregate)
           (all_of
              [
                field (fun (a : AE.aggregate) -> a.trade_count) (equal_to 0);
                field (fun (a : AE.aggregate) -> a.winners) (equal_to 0);
                field (fun (a : AE.aggregate) -> a.losers) (equal_to 0);
                field
                  (fun (a : AE.aggregate) -> a.win_rate_pct)
                  (float_equal 0.0);
                field
                  (fun (a : AE.aggregate) -> a.mean_return_pct)
                  (float_equal 0.0);
                field
                  (fun (a : AE.aggregate) -> a.median_return_pct)
                  (float_equal 0.0);
                field
                  (fun (a : AE.aggregate) -> a.total_pnl_dollars)
                  (float_equal 0.0);
              ]);
       ])

let test_median_even_count _ =
  (* Four trades with returns 0.10, 0.20, 0.30, 0.40 → median = (0.20 + 0.30) / 2 = 0.25. *)
  let returns = [ 0.10; 0.20; 0.30; 0.40 ] in
  let trades =
    List.map returns ~f:(fun r ->
        let exit_price = 100.0 *. (1.0 +. r) in
        let scored =
          make_scored ~entry_price:100.0 ~suggested_stop:90.0
            ~exit_week:(_date "2024-02-09") ~exit_price
            ~exit_trigger:OT.End_of_run ()
        in
        AE.build_trade_record ~config:AE.default_config scored)
  in
  let agg = AE.compute_aggregate ~config:AE.default_config trades in
  assert_that agg
    (all_of
       [
         field (fun (a : AE.aggregate) -> a.trade_count) (equal_to 4);
         field
           (fun (a : AE.aggregate) -> a.median_return_pct)
           (float_equal 0.25);
       ])

let test_flat_trade_neither_winner_nor_loser _ =
  (* Trade with return_pct = 0.0 is neither a winner nor a loser. *)
  let scored =
    [
      make_scored ~symbol:"FLAT" ~entry_price:100.0 ~suggested_stop:92.0
        ~exit_week:(_date "2024-01-26") ~exit_price:100.0
        ~exit_trigger:OT.End_of_run ();
    ]
  in
  let result = AE.grade ~config:AE.default_config ~scored in
  assert_that result.aggregate
    (all_of
       [
         field (fun (a : AE.aggregate) -> a.trade_count) (equal_to 1);
         field (fun (a : AE.aggregate) -> a.winners) (equal_to 0);
         field (fun (a : AE.aggregate) -> a.losers) (equal_to 0);
         field (fun (a : AE.aggregate) -> a.win_rate_pct) (float_equal 0.0);
         field
           (fun (a : AE.aggregate) -> a.total_pnl_dollars)
           (float_equal 0.0);
       ])

let test_return_buckets_default _ =
  (* Returns: -0.60, -0.30, -0.05, +0.10, +0.35, +0.75, +1.50.
     Default boundaries: [-0.5; -0.2; 0.0; 0.2; 0.5; 1.0].
     Buckets:
       (-inf, -0.5)  → -0.60                                   1
       [-0.5, -0.2)  → -0.30                                   1
       [-0.2,  0.0)  → -0.05                                   1
       [ 0.0,  0.2)  → +0.10                                   1
       [ 0.2,  0.5)  → +0.35                                   1
       [ 0.5,  1.0)  → +0.75                                   1
       [ 1.0,  inf)  → +1.50                                   1 *)
  let returns = [ -0.60; -0.30; -0.05; 0.10; 0.35; 0.75; 1.50 ] in
  let trades =
    List.map returns ~f:(fun r ->
        let exit_price = 100.0 *. (1.0 +. r) in
        let scored =
          make_scored ~entry_price:100.0 ~suggested_stop:90.0
            ~exit_week:(_date "2024-02-09") ~exit_price
            ~exit_trigger:OT.End_of_run ()
        in
        AE.build_trade_record ~config:AE.default_config scored)
  in
  let agg = AE.compute_aggregate ~config:AE.default_config trades in
  assert_that agg.return_buckets
    (elements_are
       [
         all_of
           [
             field (fun (_, _, c) -> c) (equal_to 1);
             field (fun (low, _, _) -> low) (float_equal Float.neg_infinity);
             field (fun (_, high, _) -> high) (float_equal (-0.5));
           ];
         all_of
           [
             field (fun (_, _, c) -> c) (equal_to 1);
             field (fun (low, _, _) -> low) (float_equal (-0.5));
             field (fun (_, high, _) -> high) (float_equal (-0.2));
           ];
         all_of
           [
             field (fun (_, _, c) -> c) (equal_to 1);
             field (fun (low, _, _) -> low) (float_equal (-0.2));
             field (fun (_, high, _) -> high) (float_equal 0.0);
           ];
         all_of
           [
             field (fun (_, _, c) -> c) (equal_to 1);
             field (fun (low, _, _) -> low) (float_equal 0.0);
             field (fun (_, high, _) -> high) (float_equal 0.2);
           ];
         all_of
           [
             field (fun (_, _, c) -> c) (equal_to 1);
             field (fun (low, _, _) -> low) (float_equal 0.2);
             field (fun (_, high, _) -> high) (float_equal 0.5);
           ];
         all_of
           [
             field (fun (_, _, c) -> c) (equal_to 1);
             field (fun (low, _, _) -> low) (float_equal 0.5);
             field (fun (_, high, _) -> high) (float_equal 1.0);
           ];
         all_of
           [
             field (fun (_, _, c) -> c) (equal_to 1);
             field (fun (low, _, _) -> low) (float_equal 1.0);
             field (fun (_, high, _) -> high) (float_equal Float.infinity);
           ];
       ])

let test_passes_macro_carried_through _ =
  (* The macro pass flag on the candidate is preserved on the trade record
     so consumers can split aggregates by macro regime without re-running
     the scan. *)
  let scored =
    [
      make_scored ~symbol:"BULL" ~entry_price:100.0 ~suggested_stop:92.0
        ~passes_macro:true ~exit_week:(_date "2024-02-09") ~exit_price:110.0
        ~exit_trigger:OT.End_of_run ();
      make_scored ~symbol:"BEAR" ~entry_price:100.0 ~suggested_stop:92.0
        ~passes_macro:false ~exit_week:(_date "2024-02-09") ~exit_price:90.0
        ~exit_trigger:OT.Stop_hit ();
    ]
  in
  let result = AE.grade ~config:AE.default_config ~scored in
  assert_that result.trades
    (elements_are
       [
         all_of
           [
             field (fun (t : AE.trade_record) -> t.symbol) (equal_to "BULL");
             field
               (fun (t : AE.trade_record) -> t.passes_macro)
               (equal_to true);
           ];
         all_of
           [
             field (fun (t : AE.trade_record) -> t.symbol) (equal_to "BEAR");
             field
               (fun (t : AE.trade_record) -> t.passes_macro)
               (equal_to false);
           ];
       ])

(* ------------------------------------------------------------------ *)
(* Test suite                                                          *)
(* ------------------------------------------------------------------ *)

let suite =
  "All_eligible"
  >::: [
         "build_trade_record long arithmetic" >:: test_build_trade_record_long;
         "build_trade_record short arithmetic" >:: test_build_trade_record_short;
         "custom entry_dollars sizes shares + pnl" >:: test_custom_entry_dollars;
         "three signals — all taken regardless of cash"
         >:: test_three_signals_all_taken_no_cash_gate;
         "three signals — aggregate matches sum"
         >:: test_three_signals_aggregate_matches_sum;
         "empty scored input → zeroed aggregate" >:: test_empty_scored_input;
         "median for even trade count averages middles"
         >:: test_median_even_count;
         "flat trade is neither winner nor loser"
         >:: test_flat_trade_neither_winner_nor_loser;
         "return buckets count exactly" >:: test_return_buckets_default;
         "passes_macro carried through to trade record"
         >:: test_passes_macro_carried_through;
       ]

let () = run_test_tt_main suite
