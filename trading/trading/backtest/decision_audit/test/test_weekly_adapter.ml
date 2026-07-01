(** Unit tests for [Decision_audit.Weekly_adapter].

    Covers the funded / near-miss split at the displayed cut, the candidate ->
    record field mapping (score narrowing, grade parse, rs / sector), the stage
    default (Stage2 for longs, Stage4 for shorts), and the short-candidate ->
    near-miss (side = Short) path — all on synthetic [Weekly_snapshot.t]. *)

open OUnit2
open Core
open Matchers
module WS = Weinstein_snapshot.Weekly_snapshot
module TA = Backtest.Trade_audit
module SR = Decision_audit.Screen_record
module WA = Decision_audit.Weekly_adapter

let _date d = Date.of_string d

let _candidate ?(entry = 100.0) ?(stop = 92.0) ?(rationale = "Stage2 breakout")
    ?(rs_vs_spy = Some 1.0) ?(resistance_grade = None) ?(sector = "Tech")
    ~symbol ~score ~grade () : WS.candidate =
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

(** A minimal snapshot: only the fields the adapter reads carry test data; the
    rest get inert defaults. *)
let _snapshot ?(date = _date "2024-03-01") ?(long_candidates = [])
    ?(short_candidates = []) () : WS.t =
  {
    schema_version = WS.current_schema_version;
    system_version = "test";
    date;
    macro = { regime = "Bullish"; score = 0.7 };
    sectors_strong = [];
    sectors_weak = [];
    long_candidates;
    short_candidates;
    held_positions = [];
  }

(* Funded cut ------------------------------------------------------------ *)

let test_funded_is_first_displayed_k_longs _ =
  let longs =
    [
      _candidate ~symbol:"AAPL" ~score:90.0 ~grade:"A+" ();
      _candidate ~symbol:"MSFT" ~score:80.0 ~grade:"A" ();
      _candidate ~symbol:"NVDA" ~score:70.0 ~grade:"B" ();
    ]
  in
  let snap = _snapshot ~long_candidates:longs () in
  assert_that
    (WA.of_weekly_snapshots [ snap ] ~displayed_k:2)
    (elements_are
       [
         field
           (fun (s : SR.t) -> s.funded)
           (elements_are
              [
                field (fun (e : SR.funded_entry) -> e.symbol) (equal_to "AAPL");
                field (fun (e : SR.funded_entry) -> e.symbol) (equal_to "MSFT");
              ]);
       ])

let test_long_overflow_is_top_n_cutoff_near_miss _ =
  let longs =
    [
      _candidate ~symbol:"AAPL" ~score:90.0 ~grade:"A+" ();
      _candidate ~symbol:"NVDA" ~score:70.0 ~grade:"B" ();
    ]
  in
  let snap = _snapshot ~long_candidates:longs () in
  assert_that
    (WA.of_weekly_snapshots [ snap ] ~displayed_k:1)
    (elements_are
       [
         field
           (fun (s : SR.t) -> s.near_misses)
           (elements_are
              [
                all_of
                  [
                    field (fun (n : SR.near_miss) -> n.symbol) (equal_to "NVDA");
                    field
                      (fun (n : SR.near_miss) -> n.side)
                      (equal_to Trading_base.Types.Long);
                    field
                      (fun (n : SR.near_miss) -> n.reason_skipped)
                      (equal_to TA.Top_n_cutoff);
                  ];
              ]);
       ])

(* Field mapping --------------------------------------------------------- *)

let test_funded_field_mapping _ =
  (* score 78.4 narrows to 78; grade "A" parses; rs / sector carried; stage
     defaults to Stage2 with weeks_advancing left None. *)
  let longs =
    [
      _candidate ~symbol:"AAPL" ~score:78.4 ~grade:"A" ~rs_vs_spy:(Some 1.2)
        ~sector:"Health" ();
    ]
  in
  let snap = _snapshot ~long_candidates:longs () in
  assert_that
    (WA.of_weekly_snapshots [ snap ] ~displayed_k:3)
    (elements_are
       [
         field
           (fun (s : SR.t) -> s.funded)
           (elements_are
              [
                all_of
                  [
                    field (fun (e : SR.funded_entry) -> e.score) (equal_to 78);
                    field
                      (fun (e : SR.funded_entry) -> e.grade)
                      (equal_to Weinstein_types.A);
                    field
                      (fun (e : SR.funded_entry) -> e.rs_value)
                      (is_some_and (float_equal 1.2));
                    field
                      (fun (e : SR.funded_entry) -> e.sector_name)
                      (equal_to "Health");
                    field
                      (fun (e : SR.funded_entry) -> e.weeks_advancing)
                      is_none;
                    field (fun (e : SR.funded_entry) -> e.volume_ratio) is_none;
                    field
                      (fun (e : SR.funded_entry) -> e.stage)
                      (equal_to
                         (Weinstein_types.Stage2
                            { weeks_advancing = 0; late = false }));
                  ];
              ]);
       ])

(* Shorts ---------------------------------------------------------------- *)

let test_short_candidate_lands_in_near_misses _ =
  let snap =
    _snapshot
      ~long_candidates:[ _candidate ~symbol:"AAPL" ~score:90.0 ~grade:"A+" () ]
      ~short_candidates:[ _candidate ~symbol:"XYZ" ~score:60.0 ~grade:"C" () ]
      ()
  in
  assert_that
    (WA.of_weekly_snapshots [ snap ] ~displayed_k:3)
    (elements_are
       [
         field
           (fun (s : SR.t) -> s.near_misses)
           (elements_are
              [
                all_of
                  [
                    field (fun (n : SR.near_miss) -> n.symbol) (equal_to "XYZ");
                    field
                      (fun (n : SR.near_miss) -> n.side)
                      (equal_to Trading_base.Types.Short);
                    field
                      (fun (n : SR.near_miss) -> n.reason_skipped)
                      (equal_to TA.Top_n_cutoff);
                    field
                      (fun (n : SR.near_miss) -> n.stage)
                      (equal_to
                         (Weinstein_types.Stage4 { weeks_declining = 0 }));
                  ];
              ]);
       ])

(* Summary + ordering ---------------------------------------------------- *)

let test_summary_computed_and_snapshots_sorted _ =
  (* Two snapshots out of date order in → sorted ascending out; summary counts
     one funded + one long-overflow near-miss on the later screen. *)
  let mar_08 =
    _snapshot ~date:(_date "2024-03-08")
      ~long_candidates:
        [
          _candidate ~symbol:"AAPL" ~score:90.0 ~grade:"A+" ();
          _candidate ~symbol:"NVDA" ~score:70.0 ~grade:"B" ();
        ]
      ()
  in
  let mar_01 =
    _snapshot ~date:(_date "2024-03-01")
      ~long_candidates:[ _candidate ~symbol:"MSFT" ~score:80.0 ~grade:"A" () ]
      ()
  in
  assert_that
    (WA.of_weekly_snapshots [ mar_08; mar_01 ] ~displayed_k:1)
    (elements_are
       [
         all_of
           [
             field
               (fun (s : SR.t) -> Date.to_string s.screen_date)
               (equal_to "2024-03-01");
             field (fun (s : SR.t) -> s.summary.n_funded) (equal_to 1);
             field (fun (s : SR.t) -> s.summary.n_near_miss) (equal_to 0);
           ];
         all_of
           [
             field
               (fun (s : SR.t) -> Date.to_string s.screen_date)
               (equal_to "2024-03-08");
             field (fun (s : SR.t) -> s.summary.n_funded) (equal_to 1);
             field (fun (s : SR.t) -> s.summary.n_near_miss) (equal_to 1);
             field
               (fun (s : SR.t) -> s.summary.min_funded_score)
               (is_some_and (equal_to 90));
           ];
       ])

(* Grade parser fails loudly on an unknown label — the .mli's advertised guard
   ("never silently defaults an unknown label"). A silent [| _ -> A] fallback
   would pass every other test, so pin the raise explicitly. *)
let test_unknown_grade_raises _ =
  let snap =
    _snapshot
      ~long_candidates:[ _candidate ~symbol:"AAPL" ~score:90.0 ~grade:"Z" () ]
      ()
  in
  match WA.of_weekly_snapshots [ snap ] ~displayed_k:1 with
  | exception Invalid_argument _ -> ()
  | _ -> assert_failure "expected Invalid_argument for unknown grade 'Z'"

let suite =
  "Decision_audit.Weekly_adapter"
  >::: [
         "funded is first displayed_k longs"
         >:: test_funded_is_first_displayed_k_longs;
         "long overflow is Top_n_cutoff near-miss"
         >:: test_long_overflow_is_top_n_cutoff_near_miss;
         "funded field mapping" >:: test_funded_field_mapping;
         "short candidate lands in near-misses"
         >:: test_short_candidate_lands_in_near_misses;
         "summary computed + snapshots sorted"
         >:: test_summary_computed_and_snapshots_sorted;
         "unknown grade raises" >:: test_unknown_grade_raises;
       ]

let () = run_test_tt_main suite
