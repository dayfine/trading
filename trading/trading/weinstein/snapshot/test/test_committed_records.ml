(** Reproducibility + historical-reader pins over real committed pick records
    (issue #2122 slice c, folding the F4/F5 follow-up from the weekly-snapshot
    track).

    Two committed artifacts under [test/fixtures/picks/] (copies of the
    read-only records in [dev/weekly-picks/], which live outside this dune
    project's root and so cannot be depended on directly):

    - [790d23a06-2026-07-24.sexp] — the 07-24 v3 report, current schema, carries
      the [reconciliation] field on all 20 candidates.
    - [2bcf5b335-2026-07-24.sexp] — an EARLIER 07-24 run written {b before} the
      [reconciliation] field (and the #2122 slice-d [long_eligible_beyond_cap] /
      [short_eligible_beyond_cap] counts) existed.

    {1 What is pinned}

    - {b Bit-stable serialize/parse/serialize} on the current-schema record: a
      record read from disk and written back, then re-read and re-written, is
      byte-stable and value-stable. (This is the practical stand-in for the full
      universe+warehouse regeneration golden the issue describes — a full regen
      needs the weekly-review warehouse, which is deliberately NOT committed to
      the repo. The 2026-07-27 v3 regen demonstrated the full property live;
      this test pins the reader/writer half of it.)
    - {b Old-record forward-compatibility} (F4/F5): the pre-reconciliation
      record still parses, its [@sexp.default]-ed fields resolve to their
      defaults, and both renderers render it without raising. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot

let _committed_790d_path = "fixtures/picks/790d23a06-2026-07-24.sexp"
let _committed_2bcf_path = "fixtures/picks/2bcf5b335-2026-07-24.sexp"

let _read_fixture path : Weekly_snapshot.t =
  match Snapshot_reader.read_from_file path with
  | Ok t -> t
  | Error err -> failwith ("Failed to read fixture: " ^ Status.show err)

(* serialize -> parse -> serialize is a fixed point: the re-parsed record equals
   the original AND re-serializes to the same bytes. Note this does NOT assert
   [serialize (parse file) = file bytes] — the on-disk record predates the
   slice-d fields, so a fresh serialize now emits them; the invariant is
   idempotence of the reader/writer pair, not byte-equality with a stale file. *)
let test_committed_record_serialize_is_a_fixed_point _ =
  let t = _read_fixture _committed_790d_path in
  let serialized = Snapshot_writer.serialize t in
  assert_that
    (Snapshot_reader.parse serialized)
    (is_ok_and_holds
       (all_of
          [
            equal_to t;
            field (fun t -> Snapshot_writer.serialize t) (equal_to serialized);
          ]))

(* F4/F5: the pre-reconciliation record parses, and every additive field added
   after it was written resolves to its default — [reconciliation] to
   [Not_reconciled] on every candidate, and the slice-d eligible-beyond-cap
   counts to [0]. *)
let _reconciled_count (t : Weekly_snapshot.t) =
  List.count t.long_candidates ~f:(fun (c : Weekly_snapshot.candidate) ->
      match c.reconciliation with
      | Entry_reconciliation.Not_reconciled -> false
      | Valid_stop _ | Through_entry _ | Extended _ -> true)

let test_pre_reconciliation_record_parses_with_defaults _ =
  assert_that
    (Snapshot_reader.parse (In_channel.read_all _committed_2bcf_path))
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (t : Weekly_snapshot.t) -> t.system_version)
              (equal_to "2bcf5b335");
            (* Some candidates were recorded, and NONE carries a reconciliation
               class — all default to [Not_reconciled]. *)
            field
              (fun (t : Weekly_snapshot.t) -> List.length t.long_candidates)
              (gt (module Int_ord) 0);
            field _reconciled_count (equal_to 0);
            field
              (fun (t : Weekly_snapshot.t) -> t.long_eligible_beyond_cap)
              (equal_to 0);
            field
              (fun (t : Weekly_snapshot.t) -> t.short_eligible_beyond_cap)
              (equal_to 0);
          ]))

(* Both renderers render the old record without raising. A render that raised
   would fail the test at the [render] call; the substring assertion confirms a
   complete artifact was produced. *)
let test_pre_reconciliation_record_renders _ =
  let t = _read_fixture _committed_2bcf_path in
  assert_that (Report_renderer.render t)
    (matching ~msg:"Markdown report carries its dated header"
       (fun s ->
         if String.is_substring s ~substring:"# Weekly Pick Report — 2026-07-24"
         then Some ()
         else None)
       __);
  assert_that
    (Html_report_renderer.render t)
    (matching ~msg:"HTML report carries its dated title"
       (fun s ->
         if
           String.is_substring s
             ~substring:"<title>Weekly Pick Report — 2026-07-24</title>"
         then Some ()
         else None)
       __)

let suite =
  "committed_records"
  >::: [
         "committed_record_serialize_is_a_fixed_point"
         >:: test_committed_record_serialize_is_a_fixed_point;
         "pre_reconciliation_record_parses_with_defaults"
         >:: test_pre_reconciliation_record_parses_with_defaults;
         "pre_reconciliation_record_renders"
         >:: test_pre_reconciliation_record_renders;
       ]

let () = run_test_tt_main suite
