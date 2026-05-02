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
         "path_for_layout" >:: test_path_for_layout;
         "path_lex_order_matches_chronological"
         >:: test_path_lex_order_matches_chronological;
         "write_and_read_round_trip" >:: test_write_and_read_round_trip;
         "write_rejects_mismatched_version"
         >:: test_write_rejects_mismatched_version;
         "read_missing_file" >:: test_read_missing_file;
       ]

let () = run_test_tt_main suite
