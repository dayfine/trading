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
        };
      ];
    short_candidates = [];
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
    held_positions = [];
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
         "path_for_layout" >:: test_path_for_layout;
         "path_lex_order_matches_chronological"
         >:: test_path_lex_order_matches_chronological;
         "write_and_read_round_trip" >:: test_write_and_read_round_trip;
         "write_rejects_mismatched_version"
         >:: test_write_rejects_mismatched_version;
         "read_missing_file" >:: test_read_missing_file;
       ]

let () = run_test_tt_main suite
