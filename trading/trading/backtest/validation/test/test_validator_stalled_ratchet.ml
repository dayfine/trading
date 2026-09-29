(** Tests for V22 (stalled trailing-stop ratchet) — issue #3002 part C
    ({!Post_run_validator.Validator_stall_check}) — and the stop-decision
    plumbing it needs from [trade_audit.sexp].

    The four real specimens are trimmed from a run of
    [goldens-small/six-year-2018-2023.sexp] at the commit that added V22 (the
    run is not committed; the spec and the [trading/test_data] store are):
    - CMG-wein-744 fires: the #2982 basis mix, two genuine stalls;
    - KHC-wein-1463 fires on one genuine first-cycle stall;
    - HPQ-wein-450 is clean: both its stalls are phantom-shaped;
    - FDX-wein-1233 is clean: its stop rises inside 13 weeks.

    Every row V22 reads is copied verbatim, including each stall's predecessor
    row. Other hold rows are omitted. That changes nothing V22 reads: holds
    neither start nor end a stretch, and only a stall's immediate predecessor is
    consulted. *)

open Core
open OUnit2
open Matchers
module Vt = Post_run_validator.Validator_types
module Vc = Post_run_validator.Validator_checks
module Va = Post_run_validator.Validator_artifacts
module Vr = Post_run_validator.Validator_report
module Sd = Weinstein_stops.Stop_decision

(* ---- builders ---------------------------------------------------------- *)

(* One stop-decision row. [stop_after] defaults to [stop] (no move). *)
let row ?(cb = 1) ?stop_after ?candidate ?(ma = 0.0) ?corr ~date ~reason stop :
    Sd.t =
  {
    date = Date.of_string date;
    position_id = "";
    state_before = Sd.Trailing;
    state_after = Sd.Trailing;
    stop_before = stop;
    stop_after = Option.value stop_after ~default:stop;
    candidate;
    correction_count_before = cb;
    correction_count = cb;
    last_trend_extreme = None;
    last_correction_extreme = corr;
    ma_value = ma;
    reason;
  }

let history ?(symbol = "TKT") ?(entry_date = "2020-01-03") decisions :
    Vt.stop_history =
  {
    position_id = symbol ^ "-wein-1";
    symbol;
    entry_date = Date.of_string entry_date;
    decisions;
  }

(* Inputs with a loaded audit (audit_absent = None). *)
let loaded ?config ?(trades = []) histories =
  {
    (Vt.empty_inputs ?config ()) with
    trades;
    audit_absent = None;
    stop_histories = histories;
  }

let v22 inputs = Vc.run_check ~id:"V22" inputs

let outcome ~n_violations ~n_skipped ~passed =
  all_of
    [
      field
        (fun (r : Vt.check_result) -> r.n_violations)
        (equal_to n_violations);
      field (fun (r : Vt.check_result) -> r.n_skipped) (equal_to n_skipped);
      field (fun (r : Vt.check_result) -> r.passed) (equal_to passed);
    ]

let details =
  field (fun (r : Vt.check_result) ->
      List.map r.specimens ~f:(fun (s : Vt.specimen) ->
          (s.symbol, s.entry_date, s.detail)))

let skip_reason m = field (fun (r : Vt.check_result) -> r.skip_reason) m

(* ---- real specimens ---------------------------------------------------- *)

(* A hold row: the stall's predecessor that tells a genuine cycle
   ([Correction_not_recovered]) from a phantom ([No_correction_yet]). *)
let cnr ?cb ~date stop = row ?cb ~date ~reason:Sd.Correction_not_recovered stop
let ncy ?cb ~date stop = row ?cb ~date ~reason:Sd.No_correction_yet stop

(* CMG-wein-744: stop 581.6544 from 2019-02-19 to 2019-11-08, never raised.
   Four cycles completed, and their candidates (10.38-14.74) sit under the
   adjusted MA (~10-15), ~50x below raw prices. That is CMG's 2024 50:1 split,
   the #2982 basis mix. The 2019-03-19 and 2019-07-29 stalls follow
   [No_correction_yet] (the low printed before the peak, e.g. low 717.24 on
   07-02, peak 779.86 on 07-26) and do not count. The 2019-06-10 and 2019-08-29
   stalls follow [Correction_not_recovered] and do. *)
let cmg_744 =
  let stop = 581.6544 in
  let stall ~cb ~date ~candidate ~ma ~corr =
    row ~cb ~date ~reason:Sd.Cycle_stalled ~candidate ~ma ~corr stop
  in
  history ~symbol:"CMG" ~entry_date:"2019-02-15"
    [
      row ~cb:0 ~date:"2019-02-19" ~reason:Sd.Seeded_trailing
        ~ma:9.91225677419355 ~corr:599.02 stop;
      ncy ~cb:0 ~date:"2019-03-18" stop;
      stall ~cb:0 ~date:"2019-03-19" ~candidate:10.375 ~ma:10.65055741935484
        ~corr:592.73;
      cnr ~cb:1 ~date:"2019-06-07" stop;
      stall ~cb:1 ~date:"2019-06-10" ~candidate:12.896067870967743
        ~ma:13.0263311827957 ~corr:636.73;
      ncy ~cb:2 ~date:"2019-07-26" stop;
      stall ~cb:2 ~date:"2019-07-29" ~candidate:13.875 ~ma:14.21314322580645
        ~corr:717.24;
      cnr ~cb:3 ~date:"2019-08-28" stop;
      stall ~cb:3 ~date:"2019-08-29" ~candidate:14.74478067096774
        ~ma:14.893717849462364 ~corr:770.53;
      cnr ~cb:4 ~date:"2019-11-08" stop;
    ]

(* KHC-wein-1463: its first cycle ([correction_count_before = 0]) completes on
   2021-03-26 after [Correction_not_recovered] and counts. The 2021-05-07 stall
   follows [No_correction_yet] and does not. The stop holds 17 weeks. *)
let khc_1463 =
  let stop = 35.980799999999995 in
  history ~symbol:"KHC" ~entry_date:"2021-02-19"
    [
      row ~cb:0 ~date:"2021-02-22" ~reason:Sd.Seeded_trailing stop;
      cnr ~cb:0 ~date:"2021-03-25" stop;
      row ~cb:0 ~date:"2021-03-26" ~reason:Sd.Cycle_stalled ~candidate:26.875
        ~ma:27.295381935483871 ~corr:36.37 stop;
      ncy ~cb:1 ~date:"2021-05-06" stop;
      row ~cb:1 ~date:"2021-05-07" ~reason:Sd.Cycle_stalled
        ~candidate:29.138891845161286 ~ma:29.4332240860215 ~corr:39.371 stop;
      cnr ~cb:2 ~date:"2021-06-25" stop;
    ]

(* HPQ-wein-450: stalls on 2018-08-20 (cb 0) and 2018-09-24 (cb 1), each the
   bar after [No_correction_yet] — phantom-shaped. The old
   [correction_count_before > 0] rule fired on the second. Then
   [Entered_tightening] moves the stop 19.776 -> 22.375 on 2018-10-29, 119 days
   after the first row. Clean. *)
let hpq_450 =
  let s0 = 19.776 in
  history ~symbol:"HPQ" ~entry_date:"2018-06-29"
    [
      row ~cb:0 ~date:"2018-07-02" ~reason:Sd.Seeded_trailing s0;
      ncy ~cb:0 ~date:"2018-08-17" s0;
      row ~cb:0 ~date:"2018-08-20" ~reason:Sd.Cycle_stalled
        ~candidate:17.410649477419355 s0;
      ncy ~cb:1 ~date:"2018-09-21" s0;
      row ~cb:1 ~date:"2018-09-24" ~reason:Sd.Cycle_stalled
        ~candidate:17.993714129032256 s0;
      row ~cb:2 ~date:"2018-10-29" ~reason:Sd.Entered_tightening
        ~stop_after:22.375 s0;
      row ~cb:0 ~date:"2018-10-30" ~reason:Sd.Tightened_ratchet
        ~stop_after:22.7258 22.375;
      row ~cb:0 ~date:"2018-11-20" ~reason:Sd.Stop_hit 22.7258;
    ]

(* FDX-wein-1233: stalls after [Correction_not_recovered] on 2020-07-30 and
   2020-08-27 (the 2020-08-10 one follows [No_correction_yet]), with the MA
   lagging the advance. Then the MA catches up and the stop rises four times,
   the first raise 64 days after the first row. Clean. *)
let fdx_1233 =
  let raise_ ~cb ~date ~from ~to_ =
    row ~cb ~date ~reason:Sd.Raised ~stop_after:to_ ~candidate:to_ from
  in
  let s0 = 152.2464 in
  history ~symbol:"FDX" ~entry_date:"2020-07-10"
    [
      row ~cb:0 ~date:"2020-07-13" ~reason:Sd.Seeded_trailing s0;
      cnr ~cb:0 ~date:"2020-07-29" s0;
      row ~cb:0 ~date:"2020-07-30" ~reason:Sd.Cycle_stalled
        ~candidate:122.92382988387097 s0;
      ncy ~cb:1 ~date:"2020-08-07" s0;
      row ~cb:1 ~date:"2020-08-10" ~reason:Sd.Cycle_stalled
        ~candidate:128.92544386451613 s0;
      cnr ~cb:2 ~date:"2020-08-26" s0;
      row ~cb:2 ~date:"2020-08-27" ~reason:Sd.Cycle_stalled
        ~candidate:137.91059998064517 s0;
      ncy ~cb:3 ~date:"2020-09-14" s0;
      raise_ ~cb:3 ~date:"2020-09-15" ~from:s0 ~to_:152.94794310967745;
      raise_ ~cb:4 ~date:"2020-09-28" ~from:152.94794310967745
        ~to_:164.72676106451613;
      raise_ ~cb:5 ~date:"2020-10-09" ~from:164.72676106451613
        ~to_:171.24003940645159;
      raise_ ~cb:6 ~date:"2020-11-24" ~from:171.24003940645159
        ~to_:210.43657076129031;
      cnr ~cb:7 ~date:"2021-01-15" 210.43657076129031;
    ]

let cmg_detail =
  "no stop move for 37 weeks (2019-02-19..2019-11-08), 2 completed cycle(s) \
   stalled; last: stop 581.65, candidate 14.74, ma 14.89, correction extreme \
   770.53 (extreme/ma 51.74)"

let khc_detail =
  "no stop move for 17 weeks (2021-02-22..2021-06-25), 1 completed cycle(s) \
   stalled; last: stop 35.98, candidate 26.88, ma 27.30, correction extreme \
   36.37 (extreme/ma 1.33)"

let test_fires_on_cmg_2982_specimen _ =
  assert_that
    (v22 (loaded [ cmg_744 ]))
    (all_of
       [
         outcome ~n_violations:1 ~n_skipped:0 ~passed:false;
         details (equal_to [ ("CMG", "2019-02-15", cmg_detail) ]);
       ])

(* A first-cycle stall after [Correction_not_recovered] counts:
   [correction_count_before] is not the discriminator. *)
let test_fires_on_khc_first_cycle_after_correction _ =
  assert_that
    (v22 (loaded [ khc_1463 ]))
    (all_of
       [
         outcome ~n_violations:1 ~n_skipped:0 ~passed:false;
         details (equal_to [ ("KHC", "2021-02-19", khc_detail) ]);
       ])

(* A stall on the bar after [No_correction_yet] is phantom-shaped and does not
   count, even at [correction_count_before > 0]. *)
let test_clean_on_hpq_phantom_stalls _ =
  assert_that
    (v22 (loaded [ hpq_450 ]))
    (outcome ~n_violations:0 ~n_skipped:0 ~passed:true)

let test_clean_on_fdx_raise_within_13_weeks _ =
  assert_that
    (v22 (loaded [ fdx_1233 ]))
    (all_of
       [
         outcome ~n_violations:0 ~n_skipped:0 ~passed:true; skip_reason is_none;
       ])

(* ---- the rule ---------------------------------------------------------- *)

(* A genuine stall on [date]: [Correction_not_recovered] the day before. *)
let genuine ?(stop = 10.0) date =
  let d = Date.of_string date in
  [
    cnr ~date:(Date.to_string (Date.add_days d (-1))) stop;
    row ~date ~reason:Sd.Cycle_stalled ~candidate:(stop -. 1.0) stop;
  ]

let seeded date = row ~date ~reason:Sd.Seeded_trailing 10.0

(* Seeded on 2020-01-03, one genuine stall, then a hold [days] later. *)
let stalled_for days =
  let last = Date.add_days (Date.of_string "2020-01-03") days in
  history
    ((seeded "2020-01-03" :: genuine "2020-02-03")
    @ [ ncy ~date:(Date.to_string last) 10.0 ])

let detail_prefix prefix =
  details
    (elements_are
       [ field (fun (_, _, d) -> String.is_prefix d ~prefix) (equal_to true) ])

(* 13 weeks = 91 calendar days, inclusive: 91 fires, 90 passes. *)
let test_threshold_is_inclusive_91_days _ =
  assert_that
    (v22 (loaded [ stalled_for 91; stalled_for 90 ]))
    (all_of
       [
         outcome ~n_violations:1 ~n_skipped:0 ~passed:false;
         detail_prefix "no stop move for 13 weeks (2020-01-03..2020-04-03)";
       ])

(* The minimum stretch comes from config: at 26 weeks a 25-week stall passes
   and a 26-week one fires. *)
let test_min_weeks_from_config _ =
  let config = { Vt.default_config with stalled_ratchet_min_weeks = 26 } in
  assert_that
    (v22 (loaded ~config [ stalled_for 175; stalled_for 182 ]))
    (outcome ~n_violations:1 ~n_skipped:0 ~passed:false)

(* A long hold with no completed cycle is a held stop, not a stalled one. *)
let test_no_stall_no_fire _ =
  assert_that
    (v22
       (loaded
          [
            history
              [
                seeded "2020-01-03";
                ncy ~date:"2020-03-06" 10.0;
                cnr ~date:"2020-06-05" 10.0;
                row ~date:"2020-09-04" ~reason:Sd.Anchor_not_fresh 10.0;
              ];
          ]))
    (outcome ~n_violations:0 ~n_skipped:0 ~passed:true)

(* Only [Correction_not_recovered] as predecessor makes a stall count: after
   [No_correction_yet], [Seeded_trailing] or nothing (the first row) it does
   not. Each history is 154 days with its one stall. *)
let test_stall_needs_correction_on_file _ =
  let stall = row ~date:"2020-02-03" ~reason:Sd.Cycle_stalled 10.0 in
  let last = ncy ~date:"2020-06-05" 10.0 in
  let with_prev symbol prev =
    history ~symbol [ seeded "2020-01-03"; prev; stall; last ]
  in
  assert_that
    (v22
       (loaded
          [
            with_prev "CNR" (cnr ~date:"2020-01-31" 10.0);
            with_prev "NCY" (ncy ~date:"2020-01-31" 10.0);
            with_prev "SEED" (seeded "2020-01-31");
            history ~symbol:"FIRST" [ stall; last ];
          ]))
    (all_of
       [
         outcome ~n_violations:1 ~n_skipped:0 ~passed:false;
         details (elements_are [ field (fun (s, _, _) -> s) (equal_to "CNR") ]);
       ])

(* A stall followed by a raise 100 days after the first row fires: the stretch
   the raise closes is long enough ("last raise older than 13 weeks"). *)
let test_stretch_closed_by_raise_counts _ =
  assert_that
    (v22
       (loaded
          [
            history
              ((seeded "2020-01-03" :: genuine "2020-02-03")
              @ [
                  row ~date:"2020-04-12" ~reason:Sd.Raised ~stop_after:11.0
                    ~candidate:11.0 10.0;
                ]);
          ]))
    (outcome ~n_violations:1 ~n_skipped:0 ~passed:false)

(* A move resets the stretch: the stall before the ratchet does not carry into
   the 150-day stretch after it, which has no stall of its own. *)
let test_move_resets_stalls _ =
  assert_that
    (v22
       (loaded
          [
            history
              ((seeded "2020-01-03" :: genuine "2020-01-17")
              @ [
                  row ~date:"2020-02-03" ~reason:Sd.Tightened_ratchet
                    ~stop_after:10.5 10.0;
                  row ~date:"2020-07-02" ~reason:Sd.Tightened_hold 10.5;
                ]);
          ]))
    (outcome ~n_violations:0 ~n_skipped:0 ~passed:true)

(* An [Entered_tightening] that MOVES the stop ends the stretch like any move:
   the genuine stall before it sits in a 31-day stretch, and the 150 days after
   it hold no stall. A tag-based [moved] ([Raised] / [Tightened_ratchet]) would
   read one 181-day stretch and fire. *)
let test_moving_tightening_ends_stretch _ =
  assert_that
    (v22
       (loaded
          [
            history
              ((seeded "2020-01-03" :: genuine "2020-01-17")
              @ [
                  row ~date:"2020-02-03" ~reason:Sd.Entered_tightening
                    ~stop_after:10.5 10.0;
                  row ~date:"2020-07-02" ~reason:Sd.Tightened_hold 10.5;
                ]);
          ]))
    (outcome ~n_violations:0 ~n_skipped:0 ~passed:true)

(* "Moved" is a level change, not a tag: an [Entered_tightening] that leaves
   the stop where it was does not end the stretch. *)
let test_unmoved_tightening_does_not_reset _ =
  assert_that
    (v22
       (loaded
          [
            history
              ((seeded "2020-01-03" :: genuine "2020-01-17")
              @ [
                  row ~date:"2020-02-03" ~reason:Sd.Entered_tightening 10.0;
                  row ~date:"2020-07-02" ~reason:Sd.Tightened_hold 10.0;
                ]);
          ]))
    (outcome ~n_violations:1 ~n_skipped:0 ~passed:false)

(* Two qualifying stretches: the specimen reports the longer one. *)
let test_reports_longest_stretch _ =
  let h =
    history
      ((seeded "2020-01-03" :: genuine "2020-01-17")
      @ [
          row ~date:"2020-04-17" ~reason:Sd.Raised ~stop_after:11.0
            ~candidate:11.0 10.0;
        ]
      @ genuine ~stop:11.0 "2020-05-01"
      @ [ ncy ~date:"2020-11-13" 11.0 ])
  in
  assert_that
    (v22 (loaded [ h ]))
    (detail_prefix "no stop move for 30 weeks (2020-04-17..2020-11-13)")

(* A stall row with no correction extreme reads "n/a" for the ratio. *)
let test_ratio_na_without_extreme _ =
  assert_that
    (v22 (loaded [ stalled_for 91 ]))
    (details
       (elements_are
          [
            field
              (fun (_, _, d) -> String.is_suffix d ~suffix:"(extreme/ma n/a)")
              (equal_to true);
          ]))

(* ---- skip modes -------------------------------------------------------- *)

let trade symbol : Vt.trade_row =
  {
    symbol;
    side = "LONG";
    entry_date = Date.of_string "2020-01-06";
    exit_date = Date.of_string "2020-06-01";
    entry_price = 100.0;
    exit_price = 100.0;
    quantity = 10.0;
    exit_trigger = "";
    stop_trigger_kind = "";
    stop_initial_distance_pct = None;
    position_id = None;
    stop_fill_distance_pct = None;
  }

let open_row symbol : Vt.open_row =
  {
    symbol;
    side = "LONG";
    entry_date = Date.of_string "2020-01-06";
    entry_price = 100.0;
    quantity = 10.0;
  }

(* No audit: every round trip and open position skipped, with the reason. *)
let test_absent_audit_skips_with_reason _ =
  let inputs =
    {
      (Vt.empty_inputs ()) with
      trades = [ trade "A"; trade "B" ];
      open_positions = [ open_row "C" ];
    }
  in
  assert_that (v22 inputs)
    (all_of
       [
         outcome ~n_violations:0 ~n_skipped:3 ~passed:true;
         skip_reason (equal_to (Some "no trade_audit.sexp supplied"));
       ])

(* No audit and no positions: nothing to judge or skip, no reason. *)
let test_absent_audit_no_positions_is_empty _ =
  assert_that
    (v22 (Vt.empty_inputs ()))
    (all_of
       [
         outcome ~n_violations:0 ~n_skipped:0 ~passed:true; skip_reason is_none;
       ])

let pre_2986_reason =
  Some "trade_audit.sexp carries no stop_decisions (pre-#2986 artefact)"

(* An audit loaded but carrying no stop decisions at all: every position
   skipped — counted from the audit records or from the run's positions,
   whichever is more — with the pre-#2986 reason. *)
let test_no_stop_decisions_anywhere_skips _ =
  assert_that
    ( v22 (loaded [ history []; history [] ]),
      v22 (loaded ~trades:[ trade "A"; trade "B"; trade "C" ] [ history [] ]) )
    (all_of
       [
         field fst
           (all_of
              [
                outcome ~n_violations:0 ~n_skipped:2 ~passed:true;
                skip_reason (equal_to pre_2986_reason);
              ]);
         field snd
           (all_of
              [
                outcome ~n_violations:0 ~n_skipped:3 ~passed:true;
                skip_reason (equal_to pre_2986_reason);
              ]);
       ])

(* With stop decisions present, a position without rows is skipped on its own
   reason while the others are judged. *)
let test_position_without_rows_skipped _ =
  assert_that
    (v22 (loaded [ cmg_744; history []; fdx_1233 ]))
    (all_of
       [
         outcome ~n_violations:1 ~n_skipped:1 ~passed:false;
         skip_reason (equal_to (Some "position has no stop-decision rows"));
       ])

(* ---- loader + end to end ---------------------------------------------- *)

(* A pre-#2986 record literal, trimmed from a real artefact
   ([dev/warmup-fix-runs/after-fix1-stop-log/bull-2019h2/trade_audit.sexp],
   AAPL 2019-06-21), the same literal the V21 tests use. *)
let legacy_record =
  {|((entry
     ((symbol AAPL) (entry_date 2019-06-21) (position_id AAPL-wein-61)
      (macro_trend Bullish) (macro_confidence 1) (macro_indicators ())
      (stage (Stage2 (weeks_advancing 1) (late false))) (ma_direction Rising)
      (ma_slope_pct 0.017967958275741824) (rs_trend ()) (rs_value ())
      (volume_quality ((Adequate 1.7052120350790312))) (volume_ratio (1.71))
      (resistance_quality (Clean)) (support_quality (Virgin_territory))
      (sector_name "Information Technology") (sector_rating Strong)
      (cascade_score 65) (cascade_grade B) (cascade_score_components ())
      (cascade_rationale ("Adequate volume"))
      (side Long) (suggested_entry 211.17) (suggested_stop 194.2764)
      (installed_stop 163.4592) (stop_floor_kind Support_floor)
      (risk_pct 0.079999999999999974) (initial_position_value 130291.89)
      (initial_risk_dollars 29437.563599999987)
      (alternatives_considered ())))
    (exit_ ())|}

(* The legacy record, closed, optionally carrying [decisions]. *)
let record_with decisions =
  match decisions with
  | [] -> legacy_record ^ ")"
  | ds ->
      sprintf "%s (stop_decisions (%s)))" legacy_record
        (String.concat ~sep:" "
           (List.map ds ~f:(fun d -> Sexp.to_string (Sd.sexp_of_t d))))

let blob records =
  sprintf "((audit_records (%s)) (cascade_summaries ()))"
    (String.concat ~sep:" " records)

let with_temp_file contents ~f =
  let path = Stdlib.Filename.temp_file "validator" ".sexp" in
  Out_channel.write_all path ~data:contents;
  Exn.protect ~f:(fun () -> f path) ~finally:(fun () -> Stdlib.Sys.remove path)

(* One parse yields one history per record, keyed by the entry's
   position_id / symbol / date; a pre-#2986 record decodes with no rows. *)
let test_load_audit_reads_stop_histories _ =
  let histories (a : Va.loaded_audit) =
    List.map a.stop_histories ~f:(fun (h : Vt.stop_history) ->
        ( h.position_id,
          h.symbol,
          Date.to_string h.entry_date,
          List.map h.decisions ~f:(fun d -> Date.to_string d.date) ))
  in
  let load s = with_temp_file s ~f:Va.load_audit in
  assert_that
    ( load (blob [ record_with [] ]),
      load (blob [ record_with cmg_744.decisions ]) )
    (all_of
       [
         field fst
           (matching ~msg:"Expected Ok" Result.ok
              (field histories
                 (equal_to [ ("AAPL-wein-61", "AAPL", "2019-06-21", []) ])));
         field snd
           (matching ~msg:"Expected Ok" Result.ok
              (field histories
                 (equal_to
                    [
                      ( "AAPL-wein-61",
                        "AAPL",
                        "2019-06-21",
                        [
                          "2019-02-19";
                          "2019-03-18";
                          "2019-03-19";
                          "2019-06-07";
                          "2019-06-10";
                          "2019-07-26";
                          "2019-07-29";
                          "2019-08-28";
                          "2019-08-29";
                          "2019-11-08";
                        ] );
                    ])));
       ])

let rec remove_tree path =
  if Stdlib.Sys.is_directory path then (
    Array.iter (Stdlib.Sys.readdir path) ~f:(fun n ->
        remove_tree (Stdlib.Filename.concat path n));
    Stdlib.Sys.rmdir path)
  else Stdlib.Sys.remove path

(* Run [Validator_report.run] over a directory holding [files]; return V22. *)
let v22_of_run files =
  let dir = Stdlib.Filename.temp_dir "validator_run" "" in
  List.iter files ~f:(fun (name, data) ->
      Out_channel.write_all (Stdlib.Filename.concat dir name) ~data);
  let out = Stdlib.Filename.concat dir "report" in
  let report =
    Exn.protect
      ~f:(fun () ->
        Vr.run ~run_dir:dir ~data_dir:dir ~config:Vt.default_config ~out)
      ~finally:(fun () -> remove_tree dir)
  in
  List.find report.checks ~f:(fun (c : Vt.check_result) ->
      String.equal c.id "V22")

let trades_csv = "header\nAAPL,LONG,2019-06-24,2019-11-08,,100,110,10\n"

(* From a run directory: the CMG rows fire; a pre-#2986 audit and a missing
   one each skip the run's one trade with their own reason. *)
let test_report_run_modes _ =
  let run audit =
    v22_of_run
      (("trades.csv", trades_csv)
      :: Option.value_map audit ~default:[] ~f:(fun a ->
          [ ("trade_audit.sexp", a) ]))
  in
  assert_that
    ( run (Some (blob [ record_with cmg_744.decisions ])),
      run (Some (blob [ record_with [] ])),
      run None )
    (all_of
       [
         field
           (fun (a, _, _) -> a)
           (is_some_and (outcome ~n_violations:1 ~n_skipped:0 ~passed:false));
         field
           (fun (_, b, _) -> b)
           (is_some_and
              (all_of
                 [
                   outcome ~n_violations:0 ~n_skipped:1 ~passed:true;
                   skip_reason (equal_to pre_2986_reason);
                 ]));
         field
           (fun (_, _, c) -> c)
           (is_some_and
              (all_of
                 [
                   outcome ~n_violations:0 ~n_skipped:1 ~passed:true;
                   skip_reason (equal_to (Some "trade_audit.sexp absent"));
                 ]));
       ])

(* V22 is registered as an EXPECTATION, between V21 and V23. *)
let test_registered_as_expectation _ =
  assert_that
    (List.drop Vc.all_check_ids 20, (v22 (loaded [])).severity)
    (equal_to ([ "V21"; "V22"; "V23" ], Vt.Expectation))

let suite =
  "validator_stalled_ratchet"
  >::: [
         "fires on CMG #2982 specimen" >:: test_fires_on_cmg_2982_specimen;
         "fires on KHC first cycle after correction"
         >:: test_fires_on_khc_first_cycle_after_correction;
         "clean on HPQ phantom stalls" >:: test_clean_on_hpq_phantom_stalls;
         "clean on FDX raise within 13 weeks"
         >:: test_clean_on_fdx_raise_within_13_weeks;
         "threshold is inclusive 91 days"
         >:: test_threshold_is_inclusive_91_days;
         "min weeks from config" >:: test_min_weeks_from_config;
         "no stall no fire" >:: test_no_stall_no_fire;
         "stall needs correction on file"
         >:: test_stall_needs_correction_on_file;
         "stretch closed by raise counts"
         >:: test_stretch_closed_by_raise_counts;
         "move resets stalls" >:: test_move_resets_stalls;
         "moving tightening ends stretch"
         >:: test_moving_tightening_ends_stretch;
         "unmoved tightening does not reset"
         >:: test_unmoved_tightening_does_not_reset;
         "reports longest stretch" >:: test_reports_longest_stretch;
         "ratio n/a without extreme" >:: test_ratio_na_without_extreme;
         "absent audit no positions is empty"
         >:: test_absent_audit_no_positions_is_empty;
         "absent audit skips with reason"
         >:: test_absent_audit_skips_with_reason;
         "no stop decisions anywhere skips"
         >:: test_no_stop_decisions_anywhere_skips;
         "position without rows skipped" >:: test_position_without_rows_skipped;
         "load_audit reads stop histories"
         >:: test_load_audit_reads_stop_histories;
         "report run modes" >:: test_report_run_modes;
         "registered as expectation" >:: test_registered_as_expectation;
       ]

let () = run_test_tt_main suite
