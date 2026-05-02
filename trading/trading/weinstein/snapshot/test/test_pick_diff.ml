(** Hand-pinned tests for {!Pick_diff} — cross-version pick diff. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot

(* ------- Fixtures ------- *)

let _date d = Date.of_string d
let _common_date = _date "2020-08-28"

let _candidate ?(score = 0.5) ?(grade = "B") ?(entry = 100.0) ?(stop = 90.0)
    ?(sector = "XLK") ?(rationale = "test") ?(rs_vs_spy = None)
    ?(resistance_grade = None) symbol : Weekly_snapshot.candidate =
  {
    symbol;
    score;
    grade;
    entry;
    stop;
    sector;
    rationale;
    rs_vs_spy;
    resistance_grade;
  }

let _snapshot ?(system_version = "v1") ?(date = _common_date)
    ?(macro =
      ({ regime = "Bullish"; score = 0.7 } : Weekly_snapshot.macro_context))
    ?(long_candidates = []) () : Weekly_snapshot.t =
  {
    schema_version = Weekly_snapshot.current_schema_version;
    system_version;
    date;
    macro;
    sectors_strong = [];
    sectors_weak = [];
    long_candidates;
    short_candidates = [];
    held_positions = [];
  }

(* ------- Tests ------- *)

let test_identical_snapshots_yield_empty_diff _ =
  let snap =
    _snapshot
      ~long_candidates:
        [ _candidate ~score:0.91 "AAPL"; _candidate ~score:0.87 "MSFT" ]
      ()
  in
  assert_that
    (Pick_diff.diff ~v1:snap ~v2:snap)
    (is_ok_and_holds
       (all_of
          [
            field (fun (d : Pick_diff.t) -> d.added_in_v2) (equal_to []);
            field (fun (d : Pick_diff.t) -> d.removed_in_v2) (equal_to []);
            field (fun (d : Pick_diff.t) -> d.score_changes) (equal_to []);
            field (fun (d : Pick_diff.t) -> d.rank_changes) (equal_to []);
            field (fun (d : Pick_diff.t) -> d.macro_change) is_none;
            field (fun (d : Pick_diff.t) -> d.date) (equal_to _common_date);
          ]))

let test_added_in_v2 _ =
  let v1 =
    _snapshot ~system_version:"v1"
      ~long_candidates:[ _candidate ~score:0.91 "AAPL" ]
      ()
  in
  let v2 =
    _snapshot ~system_version:"v2"
      ~long_candidates:
        [ _candidate ~score:0.91 "AAPL"; _candidate ~score:0.80 "NVDA" ]
      ()
  in
  assert_that (Pick_diff.diff ~v1 ~v2)
    (is_ok_and_holds
       (all_of
          [
            field (fun (d : Pick_diff.t) -> d.v1_version) (equal_to "v1");
            field (fun (d : Pick_diff.t) -> d.v2_version) (equal_to "v2");
            field (fun (d : Pick_diff.t) -> d.added_in_v2) (equal_to [ "NVDA" ]);
            field (fun (d : Pick_diff.t) -> d.removed_in_v2) (equal_to []);
            field (fun (d : Pick_diff.t) -> d.score_changes) (equal_to []);
            field (fun (d : Pick_diff.t) -> d.rank_changes) (equal_to []);
            field (fun (d : Pick_diff.t) -> d.macro_change) is_none;
          ]))

let test_removed_in_v2 _ =
  let v1 =
    _snapshot
      ~long_candidates:
        [ _candidate ~score:0.91 "AAPL"; _candidate ~score:0.65 "XOM" ]
      ()
  in
  let v2 = _snapshot ~long_candidates:[ _candidate ~score:0.91 "AAPL" ] () in
  assert_that (Pick_diff.diff ~v1 ~v2)
    (is_ok_and_holds
       (all_of
          [
            field (fun (d : Pick_diff.t) -> d.added_in_v2) (equal_to []);
            field
              (fun (d : Pick_diff.t) -> d.removed_in_v2)
              (equal_to [ "XOM" ]);
            field (fun (d : Pick_diff.t) -> d.score_changes) (equal_to []);
            field (fun (d : Pick_diff.t) -> d.rank_changes) (equal_to []);
          ]))

let test_score_change_on_shared_symbol _ =
  let v1 = _snapshot ~long_candidates:[ _candidate ~score:0.91 "AAPL" ] () in
  let v2 = _snapshot ~long_candidates:[ _candidate ~score:0.88 "AAPL" ] () in
  assert_that (Pick_diff.diff ~v1 ~v2)
    (is_ok_and_holds
       (all_of
          [
            field (fun (d : Pick_diff.t) -> d.added_in_v2) (equal_to []);
            field (fun (d : Pick_diff.t) -> d.removed_in_v2) (equal_to []);
            field
              (fun (d : Pick_diff.t) -> d.score_changes)
              (elements_are
                 [
                   all_of
                     [
                       field
                         (fun (c : Pick_diff.score_change) -> c.symbol)
                         (equal_to "AAPL");
                       field
                         (fun (c : Pick_diff.score_change) -> c.v1_score)
                         (float_equal 0.91);
                       field
                         (fun (c : Pick_diff.score_change) -> c.v2_score)
                         (float_equal 0.88);
                       field
                         (fun (c : Pick_diff.score_change) -> c.delta)
                         (float_equal (-0.03));
                     ];
                 ]);
            field (fun (d : Pick_diff.t) -> d.rank_changes) (equal_to []);
          ]))

let test_rank_only_swap _ =
  (* Same symbols, scores differ enough to flip rank, but we want to assert
     the rank deltas explicitly. *)
  let v1 =
    _snapshot
      ~long_candidates:
        [ _candidate ~score:0.91 "AAPL"; _candidate ~score:0.87 "MSFT" ]
      ()
  in
  let v2 =
    _snapshot
      ~long_candidates:
        [ _candidate ~score:0.95 "MSFT"; _candidate ~score:0.91 "AAPL" ]
      ()
  in
  assert_that (Pick_diff.diff ~v1 ~v2)
    (is_ok_and_holds
       (all_of
          [
            field (fun (d : Pick_diff.t) -> d.added_in_v2) (equal_to []);
            field (fun (d : Pick_diff.t) -> d.removed_in_v2) (equal_to []);
            field
              (fun (d : Pick_diff.t) -> d.rank_changes)
              (elements_are
                 [
                   equal_to
                     ({ symbol = "AAPL"; v1_rank = 1; v2_rank = 2; delta = 1 }
                       : Pick_diff.rank_change);
                   equal_to
                     ({ symbol = "MSFT"; v1_rank = 2; v2_rank = 1; delta = -1 }
                       : Pick_diff.rank_change);
                 ]);
          ]))

let test_macro_regime_change _ =
  let v1 = _snapshot ~macro:{ regime = "Bullish"; score = 0.7 } () in
  let v2 = _snapshot ~macro:{ regime = "Bearish"; score = -0.4 } () in
  assert_that (Pick_diff.diff ~v1 ~v2)
    (is_ok_and_holds
       (field
          (fun (d : Pick_diff.t) -> d.macro_change)
          (is_some_and
             (equal_to
                ({ v1_regime = "Bullish"; v2_regime = "Bearish" }
                  : Pick_diff.macro_change)))))

let test_different_dates_rejected _ =
  let v1 = _snapshot ~date:(_date "2020-08-28") () in
  let v2 = _snapshot ~date:(_date "2020-09-04") () in
  assert_that (Pick_diff.diff ~v1 ~v2) (is_error_with Status.Invalid_argument)

let test_combined_changes _ =
  (* Add, remove, score change, rank change, macro change all at once. *)
  let v1 =
    _snapshot ~system_version:"v1"
      ~macro:{ regime = "Bullish"; score = 0.6 }
      ~long_candidates:
        [
          _candidate ~score:0.91 "AAPL";
          _candidate ~score:0.87 "MSFT";
          _candidate ~score:0.65 "XOM";
        ]
      ()
  in
  let v2 =
    _snapshot ~system_version:"v2"
      ~macro:{ regime = "Neutral"; score = 0.05 }
      ~long_candidates:
        [
          _candidate ~score:0.92 "MSFT";
          _candidate ~score:0.88 "AAPL";
          _candidate ~score:0.70 "NVDA";
        ]
      ()
  in
  assert_that (Pick_diff.diff ~v1 ~v2)
    (is_ok_and_holds
       (all_of
          [
            field (fun (d : Pick_diff.t) -> d.added_in_v2) (equal_to [ "NVDA" ]);
            field
              (fun (d : Pick_diff.t) -> d.removed_in_v2)
              (equal_to [ "XOM" ]);
            field
              (fun (d : Pick_diff.t) -> d.score_changes)
              (elements_are
                 [
                   all_of
                     [
                       field
                         (fun (c : Pick_diff.score_change) -> c.symbol)
                         (equal_to "AAPL");
                       field
                         (fun (c : Pick_diff.score_change) -> c.delta)
                         (float_equal (-0.03));
                     ];
                   all_of
                     [
                       field
                         (fun (c : Pick_diff.score_change) -> c.symbol)
                         (equal_to "MSFT");
                       field
                         (fun (c : Pick_diff.score_change) -> c.delta)
                         (float_equal 0.05);
                     ];
                 ]);
            field
              (fun (d : Pick_diff.t) -> d.rank_changes)
              (elements_are
                 [
                   equal_to
                     ({ symbol = "AAPL"; v1_rank = 1; v2_rank = 2; delta = 1 }
                       : Pick_diff.rank_change);
                   equal_to
                     ({ symbol = "MSFT"; v1_rank = 2; v2_rank = 1; delta = -1 }
                       : Pick_diff.rank_change);
                 ]);
            field
              (fun (d : Pick_diff.t) -> d.macro_change)
              (is_some_and
                 (equal_to
                    ({ v1_regime = "Bullish"; v2_regime = "Neutral" }
                      : Pick_diff.macro_change)));
          ]))

let suite =
  "pick_diff"
  >::: [
         "identical_snapshots_yield_empty_diff"
         >:: test_identical_snapshots_yield_empty_diff;
         "added_in_v2" >:: test_added_in_v2;
         "removed_in_v2" >:: test_removed_in_v2;
         "score_change_on_shared_symbol" >:: test_score_change_on_shared_symbol;
         "rank_only_swap" >:: test_rank_only_swap;
         "macro_regime_change" >:: test_macro_regime_change;
         "different_dates_rejected" >:: test_different_dates_rejected;
         "combined_changes" >:: test_combined_changes;
       ]

let () = run_test_tt_main suite
