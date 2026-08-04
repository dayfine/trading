(** Round-trip + schema-version tests for {!Weekly_snapshot} via
    {!Snapshot_writer} / {!Snapshot_reader}. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot

(* ------- Fixtures ------- *)

let _date d = Date.of_string d

(** A representative non-empty snapshot exercising every field. Pinned values so
    the round-trip test is deterministic. *)
let _full_snapshot : Weekly_snapshot.t =
  {
    schema_version = Weekly_snapshot.current_schema_version;
    system_version = "c93bf39d";
    date = _date "2020-08-28";
    macro = { regime = "Bullish"; score = 0.72 };
    sectors_strong = [ "XLK"; "XLY"; "XLC" ];
    sectors_weak = [ "XLE"; "XLU" ];
    long_candidates =
      [
        {
          symbol = "AAPL";
          score = 0.91;
          grade = "A+";
          entry = 502.13;
          stop = 466.20;
          sector = "XLK";
          rationale = "Stage2 breakout above 30wk MA, 2.1x volume confirmation";
          rs_vs_spy = Some 1.34;
          resistance_grade = Some "A";
          (* Non-default sizing fields, so the round-trip exercises them. *)
          sized_shares = 5;
          sized_position_value = 2510.65;
          sized_position_pct = 0.025;
          sized_risk_amount = 179.65;
          sizing_note = None;
          stop_is_structural = true;
          data_suspect = false;
          reconciliation = Entry_reconciliation.Not_reconciled;
          score_components = [];
        };
        {
          symbol = "MSFT";
          score = 0.87;
          grade = "A";
          entry = 215.50;
          stop = 200.10;
          sector = "XLK";
          rationale = "Continuation breakout";
          rs_vs_spy = Some 1.18;
          resistance_grade = None;
          sized_shares = 0;
          sized_position_value = 0.0;
          sized_position_pct = 0.0;
          sized_risk_amount = 0.0;
          sizing_note = Some "0 sh — cash / caps exhausted";
          stop_is_structural = false;
          data_suspect = false;
          reconciliation = Entry_reconciliation.Not_reconciled;
          score_components = [];
        };
      ];
    short_candidates = [];
    (* Non-default eligible-beyond-cap counts, so the round-trip exercises the
       issue #2122 slice-d fields too. *)
    long_eligible_beyond_cap = 12;
    short_eligible_beyond_cap = 3;
    held_positions =
      [
        {
          symbol = "GOOG";
          entered = _date "2020-06-19";
          stop = 1365.00;
          status = "Holding";
          shares = 3;
          entry_price = 1400.00;
          current_price = 1500.00;
          unrealized_pct = 7.14;
          recommended_stop = Some 1420.00;
        };
      ];
    warnings = [ "SNSE: dropped from candidate consideration — sparse tail" ];
  }

(** A fully-empty snapshot — verifies empty data sections render correctly (no
    candidates, no held positions, no strong/weak sectors). *)
let _empty_snapshot : Weekly_snapshot.t =
  {
    schema_version = Weekly_snapshot.current_schema_version;
    system_version = "deadbeef";
    date = _date "2021-01-08";
    macro = { regime = "Neutral"; score = 0.0 };
    sectors_strong = [];
    sectors_weak = [];
    long_candidates = [];
    short_candidates = [];
    long_eligible_beyond_cap = 0;
    short_eligible_beyond_cap = 0;
    held_positions = [];
    warnings = [];
  }

(* ------- Round-trip ------- *)

let test_round_trip_full _ =
  let serialized = Snapshot_writer.serialize _full_snapshot in
  assert_that
    (Snapshot_reader.parse serialized)
    (is_ok_and_holds (equal_to _full_snapshot))

let test_round_trip_empty _ =
  let serialized = Snapshot_writer.serialize _empty_snapshot in
  assert_that
    (Snapshot_reader.parse serialized)
    (is_ok_and_holds (equal_to _empty_snapshot))

let test_serialize_is_byte_stable _ =
  (* Serializing the same value twice must produce identical bytes. Pins the
     "canonical output" property — required for stable diffs across runs. *)
  let first = Snapshot_writer.serialize _full_snapshot in
  let second = Snapshot_writer.serialize _full_snapshot in
  assert_that first (equal_to second)

let test_re_serialize_identity _ =
  (* parse |> serialize is byte-identity: a snapshot read from disk and
     written back yields the same bytes. *)
  let bytes = Snapshot_writer.serialize _full_snapshot in
  assert_that
    (Snapshot_reader.parse bytes)
    (is_ok_and_holds
       (field (fun t -> Snapshot_writer.serialize t) (equal_to bytes)))

(* An OLD-format snapshot — written before the Phase A/B sizing + held-enrichment
   fields existed — still parses: the new candidate / held_position fields carry
   [@sexp.default] so missing fields resolve to their unsized values. This pins
   the back-compat contract that yesterday's committed picks (e.g.
   dev/weekly-picks/7f24f2c8d/2026-07-17.sexp) keep loading unchanged. *)
let _old_format_snapshot =
  "((schema_version 1) (system_version old) (date 2026-07-17)\n\
  \ (macro ((regime Bullish) (score 1)))\n\
  \ (sectors_strong ()) (sectors_weak ())\n\
  \ (long_candidates\n\
  \  (((symbol ACAD) (score 100) (grade A+) (entry 28.49) (stop 26.21)\n\
  \    (sector \"Health Care\") (rationale test)\n\
  \    (rs_vs_spy (0.99)) (resistance_grade (Clean)))))\n\
  \ (short_candidates ())\n\
  \ (held_positions\n\
  \  (((symbol GOOG) (entered 2020-06-19) (stop 1365) (status Holding)))))"

let test_old_format_parses_with_defaults _ =
  assert_that
    (Snapshot_reader.parse _old_format_snapshot)
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (t : Weekly_snapshot.t) -> t.long_candidates)
              (elements_are
                 [
                   all_of
                     [
                       field
                         (fun (c : Weekly_snapshot.candidate) -> c.symbol)
                         (equal_to "ACAD");
                       field
                         (fun (c : Weekly_snapshot.candidate) -> c.sized_shares)
                         (equal_to 0);
                       field
                         (fun (c : Weekly_snapshot.candidate) -> c.sizing_note)
                         is_none;
                       (* Additive #2083-fix3 field: a snapshot written before
                          it existed parses as unflagged. *)
                       field
                         (fun (c : Weekly_snapshot.candidate) -> c.data_suspect)
                         (equal_to false);
                     ];
                 ]);
            field
              (fun (t : Weekly_snapshot.t) -> t.held_positions)
              (elements_are
                 [
                   all_of
                     [
                       field
                         (fun (h : Weekly_snapshot.held_position) -> h.shares)
                         (equal_to 0);
                       field
                         (fun (h : Weekly_snapshot.held_position) ->
                           h.recommended_stop)
                         is_none;
                     ];
                 ]);
            (* [warnings] (issue #2083 fix 1) is additive: an old snapshot with
               no [warnings] field parses with the empty-list default. *)
            field (fun (t : Weekly_snapshot.t) -> t.warnings) is_empty;
          ]))

(* The verbatim content of the actual committed regression file
   [dev/weekly-picks/7f24f2c8d/2026-07-17.sexp] — the report at the center of
   issue #2083 (rank-1 "SNSE" pick that did not exist at the broker; see the
   [Sparse_tail_gate] .mli). Written before the [warnings] field existed. This
   pins that the real committed bytes — not just a synthetic stand-in — still
   parse after adding [warnings], and that [Snapshot_reader.parse] does not
   itself apply the (opt-in, disabled-by-default) sparse-tail gate: this old
   snapshot was produced by an unarmed run, so SNSE is present in
   [long_candidates] exactly as it was written; [warnings] parses to []. *)
let _committed_2026_07_17_snapshot =
  {|((schema_version 1) (system_version 7f24f2c8d) (date 2026-07-17)
 (macro ((regime Bullish) (score 1)))
 (sectors_strong
  ("Consumer Staples" Financials "Health Care" Industrials
   "Information Technology" Materials "Real Estate" Utilities))
 (sectors_weak ("Communication Services"))
 (long_candidates
  (((symbol ACAD) (score 100) (grade A+) (entry 28.49) (stop 26.2108)
    (sector "Health Care")
    (rationale
     "Stage1\226\134\146Stage2 breakout; Strong volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (0.99667305842511389))
    (resistance_grade ("Weinstein_types.Virgin_territory (0.00)")))
   ((symbol COGT) (score 100) (grade A+) (entry 43.95)
    (stop 40.434000000000005) (sector "Health Care")
    (rationale
     "Stage1\226\134\146Stage2 breakout; Strong volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (1.2191952277722209))
    (resistance_grade ("Weinstein_types.Virgin_territory (0.00)")))
   ((symbol ENTA) (score 100) (grade A+) (entry 17.24) (stop 15.8608)
    (sector "Health Care")
    (rationale
     "Stage1\226\134\146Stage2 breakout; Strong volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (1.0318044550304823))
    (resistance_grade ("Weinstein_types.Clean (0.00)")))
   ((symbol HIPO) (score 100) (grade A+) (entry 39.17) (stop 36.0364)
    (sector Financials)
    (rationale
     "Stage1\226\134\146Stage2 breakout; Strong volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (0.898632516844866))
    (resistance_grade ("Weinstein_types.Virgin_territory (0.00)")))
   ((symbol NBBK) (score 100) (grade A+) (entry 22.97) (stop 21.1324)
    (sector Financials)
    (rationale
     "Stage1\226\134\146Stage2 breakout; Strong volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (0.99415019911156788))
    (resistance_grade ("Weinstein_types.Virgin_territory (0.00)")))
   ((symbol PESI) (score 100) (grade A+) (entry 16.58)
    (stop 15.253599999999999) (sector Industrials)
    (rationale
     "Stage1\226\134\146Stage2 breakout; Strong volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (1.3047617760274572))
    (resistance_grade ("Weinstein_types.Clean (0.00)")))
   ((symbol SNDX) (score 100) (grade A+) (entry 25.72) (stop 23.6624)
    (sector "Health Care")
    (rationale
     "Stage1\226\134\146Stage2 breakout; Strong volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (1.0985269706978031))
    (resistance_grade ("Weinstein_types.Virgin_territory (0.00)")))
   ((symbol SNSE) (score 100) (grade A+) (entry 36.94) (stop 33.9848)
    (sector "Health Care")
    (rationale
     "Stage1\226\134\146Stage2 breakout; Strong volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (1.473931483971608))
    (resistance_grade ("Weinstein_types.Clean (0.00)")))
   ((symbol STC) (score 100) (grade A+) (entry 79) (stop 72.68)
    (sector Financials)
    (rationale
     "Stage1\226\134\146Stage2 breakout; Strong volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (0.97503891147342825))
    (resistance_grade ("Weinstein_types.Virgin_territory (0.00)")))
   ((symbol AII) (score 90) (grade A+) (entry 26.49) (stop 24.3708)
    (sector Financials)
    (rationale
     "Stage1\226\134\146Stage2 breakout; Adequate volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (0.9035379102270007))
    (resistance_grade ("Weinstein_types.Virgin_territory (0.00)")))
   ((symbol BALL) (score 90) (grade A+) (entry 68.63) (stop 63.1396)
    (sector Materials)
    (rationale
     "Stage1\226\134\146Stage2 breakout; Adequate volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (1.0432791102122678))
    (resistance_grade ("Weinstein_types.Clean (0.00)")))
   ((symbol CALM) (score 90) (grade A+) (entry 118.04)
    (stop 108.59680000000002) (sector "Consumer Staples")
    (rationale
     "Stage1\226\134\146Stage2 breakout; Adequate volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (0.94615288747363169))
    (resistance_grade ("Weinstein_types.Clean (0.00)")))
   ((symbol CNA) (score 90) (grade A+) (entry 50.97) (stop 46.8924)
    (sector Financials)
    (rationale
     "Stage1\226\134\146Stage2 breakout; Adequate volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (1.0491252683261))
    (resistance_grade ("Weinstein_types.Clean (0.00)")))
   ((symbol ESNT) (score 90) (grade A+) (entry 67.43)
    (stop 62.035600000000009) (sector Financials)
    (rationale
     "Stage1\226\134\146Stage2 breakout; Adequate volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (1.0079342597877079))
    (resistance_grade ("Weinstein_types.Clean (0.00)")))
   ((symbol FBK) (score 90) (grade A+) (entry 62.68)
    (stop 57.665600000000005) (sector Financials)
    (rationale
     "Stage1\226\134\146Stage2 breakout; Adequate volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (1.0170009813215131))
    (resistance_grade ("Weinstein_types.Virgin_territory (0.00)")))
   ((symbol HRTG) (score 90) (grade A+) (entry 32.14)
    (stop 29.568800000000003) (sector Financials)
    (rationale
     "Stage1\226\134\146Stage2 breakout; Adequate volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (0.96976933827468681))
    (resistance_grade ("Weinstein_types.Virgin_territory (0.00)")))
   ((symbol MBI) (score 90) (grade A+) (entry 8.3) (stop 7.636000000000001)
    (sector Financials)
    (rationale
     "Stage1\226\134\146Stage2 breakout; Adequate volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (0.90435403190026487))
    (resistance_grade ("Weinstein_types.Virgin_territory (0.00)")))
   ((symbol MEDP) (score 90) (grade A+) (entry 632.06) (stop 581.4952)
    (sector "Health Care")
    (rationale
     "Stage1\226\134\146Stage2 breakout; Adequate volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (0.9768174691554552))
    (resistance_grade ("Weinstein_types.Virgin_territory (0.00)")))
   ((symbol NMIH) (score 90) (grade A+) (entry 42.49) (stop 39.0908)
    (sector Financials)
    (rationale
     "Stage1\226\134\146Stage2 breakout; Adequate volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (1.0266122912537363))
    (resistance_grade ("Weinstein_types.Clean (0.00)")))
   ((symbol NNI) (score 90) (grade A+) (entry 145.1) (stop 133.492)
    (sector Financials)
    (rationale
     "Stage1\226\134\146Stage2 breakout; Adequate volume; RS positive; Overhead supply (continuous); Strong sector")
    (rs_vs_spy (0.95345653431494692))
    (resistance_grade ("Weinstein_types.Virgin_territory (0.00)")))))
 (short_candidates ()) (held_positions ()))|}

let test_committed_2026_07_17_snapshot_still_parses _ =
  assert_that
    (Snapshot_reader.parse _committed_2026_07_17_snapshot)
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (t : Weekly_snapshot.t) -> t.system_version)
              (equal_to "7f24f2c8d");
            field
              (fun (t : Weekly_snapshot.t) ->
                List.count t.long_candidates
                  ~f:(fun (c : Weekly_snapshot.candidate) ->
                    String.equal c.symbol "SNSE"))
              (equal_to 1);
            field (fun (t : Weekly_snapshot.t) -> t.warnings) is_empty;
          ]))

(* ------- Schema-version handling ------- *)

let test_unknown_schema_version_rejected _ =
  let bumped =
    {
      _full_snapshot with
      schema_version = Weekly_snapshot.current_schema_version + 1;
    }
  in
  let serialized = Snapshot_writer.serialize bumped in
  assert_that
    (Snapshot_reader.parse serialized)
    (is_error_with Status.Invalid_argument)

let test_invalid_sexp_rejected _ =
  assert_that
    (Snapshot_reader.parse "this is not sexp at all (")
    (is_error_with Status.Invalid_argument)

(* ------- File naming + on-disk round-trip ------- *)

let test_path_for_layout _ =
  let path =
    Snapshot_writer.path_for ~root:"/tmp/picks" ~system_version:"c93bf39d"
      (_date "2020-08-28")
  in
  assert_that path (equal_to "/tmp/picks/c93bf39d/2020-08-28.sexp")

let test_path_lex_order_matches_chronological _ =
  (* Pinned: lexicographic order of the basenames matches chronological order
     for the YYYY-MM-DD format. Three pinned dates that would sort differently
     under any other format. *)
  let dates = [ _date "2020-12-31"; _date "2020-08-28"; _date "2021-01-08" ] in
  let basenames =
    List.map dates ~f:(fun d ->
        Snapshot_writer.path_for ~root:"r" ~system_version:"v" d
        |> Filename.basename)
  in
  let sorted = List.sort basenames ~compare:String.compare in
  assert_that sorted
    (equal_to [ "2020-08-28.sexp"; "2020-12-31.sexp"; "2021-01-08.sexp" ])

let _with_temp_dir f =
  let dir = Filename_unix.temp_dir "weekly_snapshot_test" "" in
  Exn.protect
    ~f:(fun () -> f dir)
    ~finally:(fun () ->
      try Core_unix.rmdir (Filename.concat dir "c93bf39d") with _ -> ())

let test_write_and_read_round_trip _ =
  _with_temp_dir (fun root ->
      let read_back =
        Result.bind
          (Snapshot_writer.write_to_file ~root
             ~system_version:_full_snapshot.system_version _full_snapshot)
          ~f:Snapshot_reader.read_from_file
      in
      assert_that read_back (is_ok_and_holds (equal_to _full_snapshot)))

let test_write_rejects_mismatched_version _ =
  _with_temp_dir (fun root ->
      assert_that
        (Snapshot_writer.write_to_file ~root ~system_version:"different_version"
           _full_snapshot)
        (is_error_with Status.Invalid_argument))

let test_read_missing_file _ =
  assert_that
    (Snapshot_reader.read_from_file "/tmp/nonexistent_snapshot_xyz.sexp")
    (is_error_with Status.NotFound)

let suite =
  "weekly_snapshot_round_trip"
  >::: [
         "round_trip_full" >:: test_round_trip_full;
         "round_trip_empty" >:: test_round_trip_empty;
         "serialize_is_byte_stable" >:: test_serialize_is_byte_stable;
         "re_serialize_identity" >:: test_re_serialize_identity;
         "unknown_schema_version_rejected"
         >:: test_unknown_schema_version_rejected;
         "invalid_sexp_rejected" >:: test_invalid_sexp_rejected;
         "old_format_parses_with_defaults"
         >:: test_old_format_parses_with_defaults;
         "committed_2026_07_17_snapshot_still_parses"
         >:: test_committed_2026_07_17_snapshot_still_parses;
         "path_for_layout" >:: test_path_for_layout;
         "path_lex_order_matches_chronological"
         >:: test_path_lex_order_matches_chronological;
         "write_and_read_round_trip" >:: test_write_and_read_round_trip;
         "write_rejects_mismatched_version"
         >:: test_write_rejects_mismatched_version;
         "read_missing_file" >:: test_read_missing_file;
       ]

let () = run_test_tt_main suite
