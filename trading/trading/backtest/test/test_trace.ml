open OUnit2
open Core
open Matchers

let test_phase_sexp_round_trip _ =
  let all_phases : Backtest.Trace.Phase.t list =
    [
      Load_universe;
      Load_bars;
      Macro;
      Sector_rank;
      Rs_rank;
      Stage_classify;
      Screener;
      Stop_update;
      Order_gen;
      Fill;
      Teardown;
      Promote_summary;
      Promote_full;
      Demote;
      Promote_metadata;
    ]
  in
  List.iter all_phases ~f:(fun p ->
      let s = Backtest.Trace.Phase.sexp_of_t p in
      let p' = Backtest.Trace.Phase.t_of_sexp s in
      assert_that p' (equal_to p))

let test_record_none_is_passthrough _ =
  (* When trace is None, record should still return f (). *)
  let result =
    Backtest.Trace.record Backtest.Trace.Phase.Macro (fun () -> 42)
  in
  assert_that result (equal_to 42)

let test_record_without_trace_leaves_other_collectors_empty _ =
  (* Record with ?trace=None — snapshot of a fresh collector remains empty. *)
  let t = Backtest.Trace.create () in
  let _ = Backtest.Trace.record Backtest.Trace.Phase.Macro (fun () -> ()) in
  (* No trace passed to record, so the collector we created is unaffected. *)
  assert_that (Backtest.Trace.snapshot t) (size_is 0)

let test_record_appends_entry _ =
  let t = Backtest.Trace.create () in
  let _ =
    Backtest.Trace.record ~trace:t ~symbols_in:100 ~symbols_out:20 ~bar_loads:5
      Backtest.Trace.Phase.Screener (fun () -> "hello")
  in
  assert_that
    (Backtest.Trace.snapshot t)
    (elements_are
       [
         all_of
           [
             field
               (fun (m : Backtest.Trace.phase_metrics) -> m.phase)
               (equal_to Backtest.Trace.Phase.Screener);
             field
               (fun (m : Backtest.Trace.phase_metrics) -> m.symbols_in)
               (equal_to (Some 100));
             field
               (fun (m : Backtest.Trace.phase_metrics) -> m.symbols_out)
               (equal_to (Some 20));
             field
               (fun (m : Backtest.Trace.phase_metrics) -> m.bar_loads)
               (equal_to (Some 5));
             field
               (fun (m : Backtest.Trace.phase_metrics) -> m.elapsed_ms)
               (ge (module Int_ord) 0);
           ];
       ])

let test_record_returns_f_value _ =
  let t = Backtest.Trace.create () in
  let v =
    Backtest.Trace.record ~trace:t Backtest.Trace.Phase.Macro (fun () -> 7)
  in
  assert_that v (equal_to 7);
  assert_that (Backtest.Trace.snapshot t) (size_is 1)

let test_record_order_is_insertion _ =
  let t = Backtest.Trace.create () in
  let phases : Backtest.Trace.Phase.t list =
    [ Load_universe; Macro; Screener; Teardown ]
  in
  List.iter phases ~f:(fun phase ->
      let _ = Backtest.Trace.record ~trace:t phase (fun () -> ()) in
      ());
  let observed =
    Backtest.Trace.snapshot t
    |> List.map ~f:(fun (m : Backtest.Trace.phase_metrics) -> m.phase)
  in
  assert_that observed
    (elements_are
       [
         equal_to Backtest.Trace.Phase.Load_universe;
         equal_to Backtest.Trace.Phase.Macro;
         equal_to Backtest.Trace.Phase.Screener;
         equal_to Backtest.Trace.Phase.Teardown;
       ])

let test_record_measures_elapsed _ =
  let t = Backtest.Trace.create () in
  let _ =
    Backtest.Trace.record ~trace:t Backtest.Trace.Phase.Macro (fun () ->
        (* Busy-wait > 10ms. Avoids Unix.sleepf in test. *)
        let start = Time_ns.now () in
        let stop = Time_ns.add start (Time_ns.Span.of_int_ms 15) in
        while Time_ns.(now () < stop) do
          ()
        done)
  in
  assert_that
    (Backtest.Trace.snapshot t)
    (elements_are
       [
         field
           (fun (m : Backtest.Trace.phase_metrics) -> m.elapsed_ms)
           (ge (module Int_ord) 10);
       ])

let test_write_sexp_round_trip _ =
  let t = Backtest.Trace.create () in
  let _ =
    Backtest.Trace.record ~trace:t ~symbols_in:1_000 ~symbols_out:50
      Backtest.Trace.Phase.Load_bars (fun () -> ())
  in
  let _ =
    Backtest.Trace.record ~trace:t ~symbols_in:50 ~symbols_out:3
      Backtest.Trace.Phase.Screener (fun () -> ())
  in
  let original = Backtest.Trace.snapshot t in
  let dir = Core_unix.mkdtemp "/tmp/trace_test_" in
  let out_path = Filename.concat dir "run.sexp" in
  Backtest.Trace.write ~out_path original;
  let sexp = Sexp.load_sexp out_path in
  let parsed = List.t_of_sexp Backtest.Trace.phase_metrics_of_sexp sexp in
  assert_that parsed (elements_are (List.map original ~f:(fun m -> equal_to m)))

let test_write_creates_parent_dir _ =
  let root = Core_unix.mkdtemp "/tmp/trace_test_" in
  (* Write into a non-existent nested path — write should mkdir -p. *)
  let out_path = Filename.concat root "a/b/c/run.sexp" in
  Backtest.Trace.write ~out_path [];
  assert_that (Sys_unix.file_exists_exn out_path) (equal_to true)

(** {1 Flush-on-record (B3)}

    These tests cover [?flush_path]: every [record] call rewrites the file.
    Critical for SIGKILL'd OOM runs — without flush-on-record, only end-of-run
    [Trace.write] persists, so a killed mid-run produces no observable trace. *)

(** Load a trace file written by [?flush_path] and parse back to a list of
    [phase_metrics]. Sharing this helper keeps the assertions symmetric across
    the three flush tests below. *)
let _load_trace_file path : Backtest.Trace.phase_metrics list =
  Sexp.load_sexp path |> List.t_of_sexp Backtest.Trace.phase_metrics_of_sexp

let test_flush_path_writes_after_first_record _ =
  let dir = Core_unix.mkdtemp "/tmp/trace_test_" in
  let path = Filename.concat dir "flush.sexp" in
  let t = Backtest.Trace.create ~flush_path:path () in
  let _ =
    Backtest.Trace.record ~trace:t Backtest.Trace.Phase.Load_universe (fun () ->
        ())
  in
  (* File exists and parses as a 1-entry trace whose phase matches. *)
  assert_that (_load_trace_file path)
    (elements_are
       [
         field
           (fun (m : Backtest.Trace.phase_metrics) -> m.phase)
           (equal_to Backtest.Trace.Phase.Load_universe);
       ])

let test_flush_path_is_incremental _ =
  let dir = Core_unix.mkdtemp "/tmp/trace_test_" in
  let path = Filename.concat dir "flush.sexp" in
  let t = Backtest.Trace.create ~flush_path:path () in
  let phases : Backtest.Trace.Phase.t list = [ Macro; Load_bars; Screener ] in
  List.iter phases ~f:(fun phase ->
      let _ = Backtest.Trace.record ~trace:t phase (fun () -> ()) in
      ());
  (* After 3 records, the file holds all 3 entries — not just the last. *)
  assert_that
    (_load_trace_file path
    |> List.map ~f:(fun (m : Backtest.Trace.phase_metrics) -> m.phase))
    (elements_are
       [
         equal_to Backtest.Trace.Phase.Macro;
         equal_to Backtest.Trace.Phase.Load_bars;
         equal_to Backtest.Trace.Phase.Screener;
       ])

let test_flush_path_leaves_no_tmp_artifact _ =
  let dir = Core_unix.mkdtemp "/tmp/trace_test_" in
  let path = Filename.concat dir "flush.sexp" in
  let t = Backtest.Trace.create ~flush_path:path () in
  let _ =
    Backtest.Trace.record ~trace:t Backtest.Trace.Phase.Macro (fun () -> ())
  in
  (* The atomic-write dance writes [path ^ ".tmp"] then renames. After a
     successful flush, no [.tmp] sibling should remain. *)
  assert_that (Sys_unix.file_exists_exn (path ^ ".tmp")) (equal_to false)

let test_create_without_flush_path_writes_no_file _ =
  let dir = Core_unix.mkdtemp "/tmp/trace_test_" in
  let path = Filename.concat dir "should-not-exist.sexp" in
  (* No [?flush_path] — pre-flush behaviour preserved. *)
  let t = Backtest.Trace.create () in
  let _ =
    Backtest.Trace.record ~trace:t Backtest.Trace.Phase.Macro (fun () -> ())
  in
  assert_that (Sys_unix.file_exists_exn path) (equal_to false)

let test_flush_path_creates_parent_dir _ =
  let root = Core_unix.mkdtemp "/tmp/trace_test_" in
  (* Nest the flush target under an unmade directory. The first flush should
     create the parents (mkdir -p) — same contract as {!Backtest.Trace.write}. *)
  let path = Filename.concat root "a/b/c/flush.sexp" in
  let t = Backtest.Trace.create ~flush_path:path () in
  let _ =
    Backtest.Trace.record ~trace:t Backtest.Trace.Phase.Macro (fun () -> ())
  in
  assert_that (Sys_unix.file_exists_exn path) (equal_to true)

let suite =
  "Trace"
  >::: [
         "phase sexp round-trip" >:: test_phase_sexp_round_trip;
         "record without trace is passthrough"
         >:: test_record_none_is_passthrough;
         "record without trace leaves other collectors empty"
         >:: test_record_without_trace_leaves_other_collectors_empty;
         "record appends entry" >:: test_record_appends_entry;
         "record returns f value" >:: test_record_returns_f_value;
         "snapshot is in insertion order" >:: test_record_order_is_insertion;
         "record measures elapsed ms" >:: test_record_measures_elapsed;
         "write round-trips via sexp" >:: test_write_sexp_round_trip;
         "write creates parent dir" >:: test_write_creates_parent_dir;
         "flush_path writes after first record"
         >:: test_flush_path_writes_after_first_record;
         "flush_path is incremental across records"
         >:: test_flush_path_is_incremental;
         "flush_path leaves no .tmp artifact after success"
         >:: test_flush_path_leaves_no_tmp_artifact;
         "create without flush_path writes no file"
         >:: test_create_without_flush_path_writes_no_file;
         "flush_path creates parent dir on first flush"
         >:: test_flush_path_creates_parent_dir;
       ]

let () = run_test_tt_main suite
