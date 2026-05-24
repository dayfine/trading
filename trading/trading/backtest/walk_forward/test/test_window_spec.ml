(** Unit tests for {!Walk_forward.Window_spec}. Pure date-arithmetic checks — no
    backtest invocation. *)

open OUnit2
open Core
open Matchers
module WS = Walk_forward.Window_spec
module Scenario = Scenario_lib.Scenario

let _date y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

let _rolling ~start_date ~end_date ~train_days ~test_days ~step_days : WS.t =
  Rolling { start_date; end_date; train_days; test_days; step_days }

(* ---------- Validation (Rolling) ---------- *)

let test_negative_train_days_raises _ =
  let spec =
    _rolling ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 12 31)
      ~train_days:(-1) ~test_days:30 ~step_days:30
  in
  assert_raises (Failure "WindowSpec.generate: train_days must be >= 0, got -1")
    (fun () -> WS.generate spec)

let test_zero_test_days_raises _ =
  let spec =
    _rolling ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 12 31)
      ~train_days:30 ~test_days:0 ~step_days:30
  in
  assert_raises (Failure "WindowSpec.generate: test_days must be > 0, got 0")
    (fun () -> WS.generate spec)

let test_zero_step_days_raises _ =
  let spec =
    _rolling ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 12 31)
      ~train_days:30 ~test_days:30 ~step_days:0
  in
  assert_raises (Failure "WindowSpec.generate: step_days must be > 0, got 0")
    (fun () -> WS.generate spec)

(* ---------- Empty-range cases (Rolling) ---------- *)

let test_start_after_end_yields_empty _ =
  let spec =
    _rolling ~start_date:(_date 2020 12 31) ~end_date:(_date 2020 1 1)
      ~train_days:0 ~test_days:30 ~step_days:30
  in
  assert_that (WS.generate spec) (size_is 0)

let test_no_fold_fits_yields_empty _ =
  (* Window is 60 days (0 + 60) but available range is 30 days. *)
  let spec =
    _rolling ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 1 30)
      ~train_days:0 ~test_days:60 ~step_days:60
  in
  assert_that (WS.generate spec) (size_is 0)

(* ---------- Train-period None when train_days = 0 ---------- *)

let test_train_days_zero_yields_no_train_period _ =
  let spec =
    _rolling ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 6 30)
      ~train_days:0 ~test_days:30 ~step_days:30
  in
  let folds = WS.generate spec in
  assert_that folds
    (elements_are
       [
         all_of
           [
             field (fun (f : WS.fold) -> f.train_period) is_none;
             field
               (fun (f : WS.fold) -> f.test_period.start_date)
               (equal_to (_date 2020 1 1));
             field
               (fun (f : WS.fold) -> f.test_period.end_date)
               (equal_to (_date 2020 1 30));
           ];
         all_of
           [
             field
               (fun (f : WS.fold) -> f.test_period.start_date)
               (equal_to (_date 2020 1 31));
             field
               (fun (f : WS.fold) -> f.test_period.end_date)
               (equal_to (_date 2020 2 29));
           ];
         all_of
           [
             field
               (fun (f : WS.fold) -> f.test_period.start_date)
               (equal_to (_date 2020 3 1));
             field
               (fun (f : WS.fold) -> f.test_period.end_date)
               (equal_to (_date 2020 3 30));
           ];
         all_of
           [
             field
               (fun (f : WS.fold) -> f.test_period.start_date)
               (equal_to (_date 2020 3 31));
             field
               (fun (f : WS.fold) -> f.test_period.end_date)
               (equal_to (_date 2020 4 29));
           ];
         all_of
           [
             field
               (fun (f : WS.fold) -> f.test_period.start_date)
               (equal_to (_date 2020 4 30));
             field
               (fun (f : WS.fold) -> f.test_period.end_date)
               (equal_to (_date 2020 5 29));
           ];
         all_of
           [
             field
               (fun (f : WS.fold) -> f.test_period.start_date)
               (equal_to (_date 2020 5 30));
             field
               (fun (f : WS.fold) -> f.test_period.end_date)
               (equal_to (_date 2020 6 28));
           ];
       ])

(* ---------- Train + test back-to-back ---------- *)

let test_train_followed_by_test _ =
  let spec =
    _rolling ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 12 31)
      ~train_days:60 ~test_days:30 ~step_days:90
  in
  let folds = WS.generate spec in
  (* First fold: train 01-01..03-01 (60d), test 03-01..03-30 (30d). *)
  let first = List.hd_exn folds in
  assert_that first
    (all_of
       [
         field (fun (f : WS.fold) -> f.index) (equal_to 0);
         field (fun (f : WS.fold) -> f.name) (equal_to "fold-000");
         field
           (fun (f : WS.fold) ->
             match f.train_period with
             | Some p -> p.start_date
             | None -> _date 1900 1 1)
           (equal_to (_date 2020 1 1));
         field
           (fun (f : WS.fold) ->
             match f.train_period with
             | Some p -> p.end_date
             | None -> _date 1900 1 1)
           (equal_to (_date 2020 2 29));
         field
           (fun (f : WS.fold) -> f.test_period.start_date)
           (equal_to (_date 2020 3 1));
         field
           (fun (f : WS.fold) -> f.test_period.end_date)
           (equal_to (_date 2020 3 30));
       ])

(* ---------- Step < test = overlapping rolling folds ---------- *)

let test_overlapping_step_yields_overlapping_test_windows _ =
  let spec =
    _rolling ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 4 30)
      ~train_days:0 ~test_days:60 ~step_days:30
  in
  let folds = WS.generate spec in
  let test_starts =
    List.map folds ~f:(fun (f : WS.fold) -> f.test_period.start_date)
  in
  let test_ends =
    List.map folds ~f:(fun (f : WS.fold) -> f.test_period.end_date)
  in
  assert_that test_starts
    (elements_are
       [
         equal_to (_date 2020 1 1);
         equal_to (_date 2020 1 31);
         equal_to (_date 2020 3 1);
       ]);
  assert_that test_ends
    (elements_are
       [
         equal_to (_date 2020 2 29);
         equal_to (_date 2020 3 30);
         equal_to (_date 2020 4 29);
       ])

(* ---------- Drop folds extending past end_date ---------- *)

let test_drops_folds_past_end_date _ =
  (* start=01-01, end=01-31, test_days=30, step=15. Possible test windows:
     [01-01..01-30] (ok), [01-16..02-14] (PAST end), drop. *)
  let spec =
    _rolling ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 1 31)
      ~train_days:0 ~test_days:30 ~step_days:15
  in
  let folds = WS.generate spec in
  assert_that folds (size_is 1)

(* ---------- Index + name shape ---------- *)

let test_fold_names_zero_padded _ =
  let spec =
    _rolling ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 4 30)
      ~train_days:0 ~test_days:30 ~step_days:30
  in
  let folds = WS.generate spec in
  let names = List.map folds ~f:(fun (f : WS.fold) -> f.name) in
  assert_that names
    (elements_are
       [
         equal_to "fold-000";
         equal_to "fold-001";
         equal_to "fold-002";
         equal_to "fold-003";
       ])

(* ---------- Sexp round-trip (variant shape) ---------- *)

let test_sexp_round_trip_rolling _ =
  let spec =
    _rolling ~start_date:(_date 2020 1 1) ~end_date:(_date 2024 12 31)
      ~train_days:365 ~test_days:182 ~step_days:91
  in
  let parsed = WS.t_of_sexp (WS.sexp_of_t spec) in
  assert_that parsed
    (matching ~msg:"Expected Rolling variant"
       (function WS.Rolling r -> Some r | _ -> None)
       (all_of
          [
            field
              (fun (r : WS.rolling_spec) -> r.start_date)
              (equal_to (_date 2020 1 1));
            field (fun (r : WS.rolling_spec) -> r.train_days) (equal_to 365);
            field (fun (r : WS.rolling_spec) -> r.test_days) (equal_to 182);
            field (fun (r : WS.rolling_spec) -> r.step_days) (equal_to 91);
          ]))

(* ---------- Legacy flat-record sexp parses as Rolling ---------- *)

let test_legacy_flat_sexp_parses_as_rolling _ =
  let legacy_sexp =
    Sexp.of_string
      "((start_date 2020-01-01) (end_date 2024-12-31) (train_days 365) \
       (test_days 182) (step_days 91))"
  in
  let parsed = WS.t_of_sexp legacy_sexp in
  assert_that parsed
    (matching ~msg:"Expected Rolling variant from legacy shape"
       (function WS.Rolling r -> Some r | _ -> None)
       (all_of
          [
            field
              (fun (r : WS.rolling_spec) -> r.start_date)
              (equal_to (_date 2020 1 1));
            field (fun (r : WS.rolling_spec) -> r.train_days) (equal_to 365);
          ]))

(* ---------- Explicit constructor: pass-through with input order ---------- *)

let _ef ~name ?train_start ?train_end ~test_start ~test_end () :
    WS.explicit_fold =
  let train_period =
    match (train_start, train_end) with
    | Some ts, Some te ->
        Some ({ start_date = ts; end_date = te } : Scenario.period)
    | _ -> None
  in
  {
    name;
    train_period;
    test_period = { start_date = test_start; end_date = test_end };
  }

let test_explicit_passes_through_in_input_order _ =
  let spec : WS.t =
    Explicit
      [
        _ef ~name:"bull-2015-2017" ~test_start:(_date 2015 1 2)
          ~test_end:(_date 2017 12 29) ();
        _ef ~name:"covid-2020-2022h1" ~test_start:(_date 2020 1 2)
          ~test_end:(_date 2022 6 30) ();
        _ef ~name:"bull-2018-2020" ~test_start:(_date 2018 1 2)
          ~test_end:(_date 2020 12 31) ();
      ]
  in
  let folds = WS.generate spec in
  assert_that folds
    (elements_are
       [
         all_of
           [
             field (fun (f : WS.fold) -> f.index) (equal_to 0);
             field (fun (f : WS.fold) -> f.name) (equal_to "bull-2015-2017");
             field
               (fun (f : WS.fold) -> f.test_period.start_date)
               (equal_to (_date 2015 1 2));
             field (fun (f : WS.fold) -> f.train_period) is_none;
           ];
         all_of
           [
             field (fun (f : WS.fold) -> f.index) (equal_to 1);
             field (fun (f : WS.fold) -> f.name) (equal_to "covid-2020-2022h1");
           ];
         all_of
           [
             field (fun (f : WS.fold) -> f.index) (equal_to 2);
             field (fun (f : WS.fold) -> f.name) (equal_to "bull-2018-2020");
           ];
       ])

let test_explicit_preserves_train_period_when_supplied _ =
  let spec : WS.t =
    Explicit
      [
        _ef ~name:"with-train" ~train_start:(_date 2019 1 1)
          ~train_end:(_date 2019 12 31) ~test_start:(_date 2020 1 1)
          ~test_end:(_date 2020 12 31) ();
      ]
  in
  let folds = WS.generate spec in
  assert_that folds
    (elements_are
       [
         field
           (fun (f : WS.fold) -> f.train_period)
           (is_some_and
              (all_of
                 [
                   field
                     (fun (p : Scenario.period) -> p.start_date)
                     (equal_to (_date 2019 1 1));
                   field
                     (fun (p : Scenario.period) -> p.end_date)
                     (equal_to (_date 2019 12 31));
                 ]));
       ])

let test_explicit_empty_list_raises _ =
  let spec : WS.t = Explicit [] in
  assert_raises
    (Failure "WindowSpec.generate: Explicit folds list must be non-empty")
    (fun () -> WS.generate spec)

let test_explicit_duplicate_names_raise _ =
  let spec : WS.t =
    Explicit
      [
        _ef ~name:"dup" ~test_start:(_date 2020 1 1) ~test_end:(_date 2020 6 30)
          ();
        _ef ~name:"dup" ~test_start:(_date 2020 7 1)
          ~test_end:(_date 2020 12 31) ();
      ]
  in
  assert_raises
    (Failure "WindowSpec.generate: duplicate fold name in Explicit: \"dup\"")
    (fun () -> WS.generate spec)

let test_explicit_sexp_round_trip _ =
  let spec : WS.t =
    Explicit
      [
        _ef ~name:"f1" ~test_start:(_date 2020 1 1) ~test_end:(_date 2020 6 30)
          ();
        _ef ~name:"f2" ~train_start:(_date 2019 1 1)
          ~train_end:(_date 2019 12 31) ~test_start:(_date 2020 1 1)
          ~test_end:(_date 2020 12 31) ();
      ]
  in
  let parsed = WS.t_of_sexp (WS.sexp_of_t spec) in
  assert_that parsed
    (matching ~msg:"Expected Explicit variant"
       (function WS.Explicit fs -> Some fs | _ -> None)
       (elements_are
          [
            field (fun (e : WS.explicit_fold) -> e.name) (equal_to "f1");
            field (fun (e : WS.explicit_fold) -> e.name) (equal_to "f2");
          ]))

(* ---------- Tiered: parse, concat, naming, overflow ---------- *)

let _tier ~name ~fold_count ~horizon_days : WS.tier =
  { name; fold_count; horizon_days }

let _tiered ~start_date ~end_date ~train_days ~tiers : WS.t =
  Tiered { start_date; end_date; train_days; tiers }

(* Parse the variant-tagged sexp shape and check it routes to Tiered. *)
let test_sexp_parses_tiered_variant _ =
  let sexp =
    Sexp.of_string
      "(Tiered ((start_date 2020-01-01) (end_date 2024-12-31) (train_days 365) \
       (tiers (((name cheap) (fold_count 2) (horizon_days 180))))))"
  in
  let parsed = WS.t_of_sexp sexp in
  assert_that parsed
    (matching ~msg:"Expected Tiered variant"
       (function WS.Tiered ts -> Some ts | _ -> None)
       (all_of
          [
            field
              (fun (ts : WS.tiered_spec) -> ts.start_date)
              (equal_to (_date 2020 1 1));
            field (fun (ts : WS.tiered_spec) -> ts.train_days) (equal_to 365);
            field
              (fun (ts : WS.tiered_spec) -> ts.tiers)
              (elements_are
                 [
                   all_of
                     [
                       field (fun (t : WS.tier) -> t.name) (equal_to "cheap");
                       field (fun (t : WS.tier) -> t.fold_count) (equal_to 2);
                       field
                         (fun (t : WS.tier) -> t.horizon_days)
                         (equal_to 180);
                     ];
                 ]);
          ]))

(* Two tiers (cheap-3 + medium-5) — 8 folds total, indices 0..7, names
   cheap-000..cheap-002, medium-000..medium-004. Use horizon_days=30, no
   train period, so date arithmetic is easy to follow. *)
let test_tiered_two_tiers_concat _ =
  let spec =
    _tiered ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 12 31)
      ~train_days:0
      ~tiers:
        [
          _tier ~name:"cheap" ~fold_count:3 ~horizon_days:30;
          _tier ~name:"medium" ~fold_count:5 ~horizon_days:30;
        ]
  in
  let folds = WS.generate spec in
  let indices = List.map folds ~f:(fun (f : WS.fold) -> f.index) in
  let names = List.map folds ~f:(fun (f : WS.fold) -> f.name) in
  assert_that indices
    (elements_are
       [
         equal_to 0;
         equal_to 1;
         equal_to 2;
         equal_to 3;
         equal_to 4;
         equal_to 5;
         equal_to 6;
         equal_to 7;
       ]);
  assert_that names
    (elements_are
       [
         equal_to "cheap-000";
         equal_to "cheap-001";
         equal_to "cheap-002";
         equal_to "medium-000";
         equal_to "medium-001";
         equal_to "medium-002";
         equal_to "medium-003";
         equal_to "medium-004";
       ])

(* Pin within-tier zero-padding to width 3 (not global index). *)
let test_tiered_fold_names_within_tier_padded _ =
  let spec =
    _tiered ~start_date:(_date 2020 1 1) ~end_date:(_date 2025 12 31)
      ~train_days:0
      ~tiers:
        [
          _tier ~name:"medium" ~fold_count:2 ~horizon_days:30;
          _tier ~name:"expensive" ~fold_count:2 ~horizon_days:30;
        ]
  in
  let folds = WS.generate spec in
  let names = List.map folds ~f:(fun (f : WS.fold) -> f.name) in
  assert_that names
    (elements_are
       [
         equal_to "medium-000";
         equal_to "medium-001";
         equal_to "expensive-000";
         equal_to "expensive-001";
       ])

(* Tier-local anchoring: each tier's first fold starts at start_date + train_days. *)
let test_tiered_per_tier_anchor _ =
  let spec =
    _tiered ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 12 31)
      ~train_days:0
      ~tiers:
        [
          _tier ~name:"a" ~fold_count:1 ~horizon_days:60;
          _tier ~name:"b" ~fold_count:1 ~horizon_days:90;
        ]
  in
  let folds = WS.generate spec in
  let test_starts =
    List.map folds ~f:(fun (f : WS.fold) -> f.test_period.start_date)
  in
  let test_ends =
    List.map folds ~f:(fun (f : WS.fold) -> f.test_period.end_date)
  in
  assert_that test_starts
    (elements_are [ equal_to (_date 2020 1 1); equal_to (_date 2020 1 1) ]);
  assert_that test_ends
    (elements_are [ equal_to (_date 2020 2 29); equal_to (_date 2020 3 30) ])

(* With train_days > 0, each fold's train_period precedes its test_period
   back-to-back. *)
let test_tiered_train_followed_by_test _ =
  let spec =
    _tiered ~start_date:(_date 2020 1 1) ~end_date:(_date 2021 12 31)
      ~train_days:30
      ~tiers:[ _tier ~name:"cheap" ~fold_count:2 ~horizon_days:30 ]
  in
  let folds = WS.generate spec in
  assert_that folds
    (elements_are
       [
         all_of
           [
             field (fun (f : WS.fold) -> f.index) (equal_to 0);
             field (fun (f : WS.fold) -> f.name) (equal_to "cheap-000");
             field
               (fun (f : WS.fold) -> f.train_period)
               (is_some_and
                  (all_of
                     [
                       field
                         (fun (p : Scenario.period) -> p.start_date)
                         (equal_to (_date 2020 1 1));
                       field
                         (fun (p : Scenario.period) -> p.end_date)
                         (equal_to (_date 2020 1 30));
                     ]));
             field
               (fun (f : WS.fold) -> f.test_period.start_date)
               (equal_to (_date 2020 1 31));
             field
               (fun (f : WS.fold) -> f.test_period.end_date)
               (equal_to (_date 2020 2 29));
           ];
         all_of
           [
             field (fun (f : WS.fold) -> f.index) (equal_to 1);
             field (fun (f : WS.fold) -> f.name) (equal_to "cheap-001");
             field
               (fun (f : WS.fold) -> f.train_period)
               (is_some_and
                  (all_of
                     [
                       field
                         (fun (p : Scenario.period) -> p.start_date)
                         (equal_to (_date 2020 1 31));
                       field
                         (fun (p : Scenario.period) -> p.end_date)
                         (equal_to (_date 2020 2 29));
                     ]));
             field
               (fun (f : WS.fold) -> f.test_period.start_date)
               (equal_to (_date 2020 3 1));
             field
               (fun (f : WS.fold) -> f.test_period.end_date)
               (equal_to (_date 2020 3 30));
           ];
       ])

(* When train_days = 0, train_period is None. *)
let test_tiered_zero_train_days_no_train_period _ =
  let spec =
    _tiered ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 12 31)
      ~train_days:0
      ~tiers:[ _tier ~name:"oos" ~fold_count:1 ~horizon_days:60 ]
  in
  let folds = WS.generate spec in
  assert_that folds
    (elements_are
       [
         all_of
           [
             field (fun (f : WS.fold) -> f.train_period) is_none;
             field
               (fun (f : WS.fold) -> f.test_period.start_date)
               (equal_to (_date 2020 1 1));
             field
               (fun (f : WS.fold) -> f.test_period.end_date)
               (equal_to (_date 2020 2 29));
           ];
       ])

(* Tier-overflow case: fold_count * horizon_days + train_days exceeds available
   range — must raise (not silently truncate). *)
let test_tiered_overflow_raises _ =
  let spec =
    _tiered ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 1 30)
      ~train_days:0
      ~tiers:[ _tier ~name:"too-big" ~fold_count:3 ~horizon_days:60 ]
  in
  assert_raises
    (Failure
       "WindowSpec.generate: tier \"too-big\" overflows date range (last test \
        ends 2020-06-28 > end_date 2020-01-30)") (fun () -> WS.generate spec)

let test_tiered_empty_tiers_raises _ =
  let spec =
    _tiered ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 12 31)
      ~train_days:0 ~tiers:[]
  in
  assert_raises
    (Failure "WindowSpec.generate: Tiered tiers list must be non-empty")
    (fun () -> WS.generate spec)

let test_tiered_duplicate_tier_names_raise _ =
  let spec =
    _tiered ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 12 31)
      ~train_days:0
      ~tiers:
        [
          _tier ~name:"dup" ~fold_count:1 ~horizon_days:30;
          _tier ~name:"dup" ~fold_count:1 ~horizon_days:30;
        ]
  in
  assert_raises
    (Failure "WindowSpec.generate: duplicate tier name in Tiered: \"dup\"")
    (fun () -> WS.generate spec)

let test_tiered_zero_fold_count_raises _ =
  let spec =
    _tiered ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 12 31)
      ~train_days:0
      ~tiers:[ _tier ~name:"bad" ~fold_count:0 ~horizon_days:30 ]
  in
  assert_raises
    (Failure "WindowSpec.generate: tier \"bad\" fold_count must be >= 1, got 0")
    (fun () -> WS.generate spec)

let test_tiered_zero_horizon_days_raises _ =
  let spec =
    _tiered ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 12 31)
      ~train_days:0
      ~tiers:[ _tier ~name:"bad" ~fold_count:1 ~horizon_days:0 ]
  in
  assert_raises
    (Failure "WindowSpec.generate: tier \"bad\" horizon_days must be > 0, got 0")
    (fun () -> WS.generate spec)

let test_tiered_negative_train_days_raises _ =
  let spec =
    _tiered ~start_date:(_date 2020 1 1) ~end_date:(_date 2020 12 31)
      ~train_days:(-1)
      ~tiers:[ _tier ~name:"t" ~fold_count:1 ~horizon_days:30 ]
  in
  assert_raises
    (Failure "WindowSpec.generate: Tiered train_days must be >= 0, got -1")
    (fun () -> WS.generate spec)

let test_tiered_sexp_round_trip _ =
  let spec =
    _tiered ~start_date:(_date 2020 1 1) ~end_date:(_date 2024 12 31)
      ~train_days:365
      ~tiers:
        [
          _tier ~name:"cheap" ~fold_count:6 ~horizon_days:182;
          _tier ~name:"expensive" ~fold_count:8 ~horizon_days:91;
        ]
  in
  let parsed = WS.t_of_sexp (WS.sexp_of_t spec) in
  assert_that parsed
    (matching ~msg:"Expected Tiered variant"
       (function WS.Tiered ts -> Some ts | _ -> None)
       (all_of
          [
            field
              (fun (ts : WS.tiered_spec) -> ts.start_date)
              (equal_to (_date 2020 1 1));
            field (fun (ts : WS.tiered_spec) -> ts.train_days) (equal_to 365);
            field
              (fun (ts : WS.tiered_spec) -> ts.tiers)
              (elements_are
                 [
                   all_of
                     [
                       field (fun (t : WS.tier) -> t.name) (equal_to "cheap");
                       field (fun (t : WS.tier) -> t.fold_count) (equal_to 6);
                       field
                         (fun (t : WS.tier) -> t.horizon_days)
                         (equal_to 182);
                     ];
                   all_of
                     [
                       field
                         (fun (t : WS.tier) -> t.name)
                         (equal_to "expensive");
                       field (fun (t : WS.tier) -> t.fold_count) (equal_to 8);
                       field (fun (t : WS.tier) -> t.horizon_days) (equal_to 91);
                     ];
                 ]);
          ]))

let suite =
  "Window_spec"
  >::: [
         "negative train_days raises" >:: test_negative_train_days_raises;
         "zero test_days raises" >:: test_zero_test_days_raises;
         "zero step_days raises" >:: test_zero_step_days_raises;
         "start after end yields empty" >:: test_start_after_end_yields_empty;
         "no fold fits yields empty" >:: test_no_fold_fits_yields_empty;
         "train_days=0 yields no train_period"
         >:: test_train_days_zero_yields_no_train_period;
         "train followed by test back-to-back" >:: test_train_followed_by_test;
         "overlapping step yields overlapping test windows"
         >:: test_overlapping_step_yields_overlapping_test_windows;
         "drops folds past end_date" >:: test_drops_folds_past_end_date;
         "fold names zero-padded" >:: test_fold_names_zero_padded;
         "sexp round-trip Rolling" >:: test_sexp_round_trip_rolling;
         "legacy flat sexp parses as Rolling"
         >:: test_legacy_flat_sexp_parses_as_rolling;
         "Explicit passes through in input order"
         >:: test_explicit_passes_through_in_input_order;
         "Explicit preserves train_period when supplied"
         >:: test_explicit_preserves_train_period_when_supplied;
         "Explicit empty list raises" >:: test_explicit_empty_list_raises;
         "Explicit duplicate names raise"
         >:: test_explicit_duplicate_names_raise;
         "Explicit sexp round-trip" >:: test_explicit_sexp_round_trip;
         "Tiered sexp parses variant" >:: test_sexp_parses_tiered_variant;
         "Tiered two tiers concat with global indices"
         >:: test_tiered_two_tiers_concat;
         "Tiered fold names zero-padded within tier"
         >:: test_tiered_fold_names_within_tier_padded;
         "Tiered each tier anchors at start_date"
         >:: test_tiered_per_tier_anchor;
         "Tiered train followed by test back-to-back"
         >:: test_tiered_train_followed_by_test;
         "Tiered train_days=0 yields no train_period"
         >:: test_tiered_zero_train_days_no_train_period;
         "Tiered overflow raises" >:: test_tiered_overflow_raises;
         "Tiered empty tiers raises" >:: test_tiered_empty_tiers_raises;
         "Tiered duplicate tier names raise"
         >:: test_tiered_duplicate_tier_names_raise;
         "Tiered zero fold_count raises" >:: test_tiered_zero_fold_count_raises;
         "Tiered zero horizon_days raises"
         >:: test_tiered_zero_horizon_days_raises;
         "Tiered negative train_days raises"
         >:: test_tiered_negative_train_days_raises;
         "Tiered sexp round-trip" >:: test_tiered_sexp_round_trip;
       ]

let () = run_test_tt_main suite
