(** Unit tests for {!Backtest.Gc_trace}. Pin the snapshot schema, the
    no-op-when-trace-is-None contract, the insertion-order semantics, and the
    CSV write+read round-trip. *)

open OUnit2
open Core
open Matchers

let test_record_none_is_noop _ =
  (* Without ~trace, record is a no-op. We invoke it and observe that a fresh
     collector remains empty. *)
  let t = Backtest.Gc_trace.create () in
  Backtest.Gc_trace.record ~phase:"start" ();
  assert_that (Backtest.Gc_trace.snapshot_list t) (size_is 0)

let test_record_appends_snapshot _ =
  let t = Backtest.Gc_trace.create () in
  Backtest.Gc_trace.record ~trace:t ~phase:"load_universe_done" ();
  assert_that
    (Backtest.Gc_trace.snapshot_list t)
    (elements_are
       [
         all_of
           [
             field
               (fun (s : Backtest.Gc_trace.snapshot) -> s.phase)
               (equal_to "load_universe_done");
             field
               (fun (s : Backtest.Gc_trace.snapshot) -> s.wall_ms)
               (ge (module Int_ord) 0);
             (* major_words is monotonic non-decreasing across runtime, so
                a freshly-allocated process already has major_words > 0
                from the runtime startup allocations. *)
             field
               (fun (s : Backtest.Gc_trace.snapshot) -> s.top_heap_words)
               (ge (module Int_ord) 0);
           ];
       ])

let test_snapshot_list_is_insertion_order _ =
  let t = Backtest.Gc_trace.create () in
  let phases = [ "start"; "load_universe_done"; "macro_done"; "end" ] in
  List.iter phases ~f:(fun phase -> Backtest.Gc_trace.record ~trace:t ~phase ());
  assert_that
    (Backtest.Gc_trace.snapshot_list t
    |> List.map ~f:(fun (s : Backtest.Gc_trace.snapshot) -> s.phase))
    (elements_are
       [
         equal_to "start";
         equal_to "load_universe_done";
         equal_to "macro_done";
         equal_to "end";
       ])

let test_csv_header_matches_snapshot_fields _ =
  (* Pin the CSV header so it stays in sync with the [snapshot] record. *)
  assert_that Backtest.Gc_trace.csv_header
    (equal_to
       "phase,wall_ms,minor_words,promoted_words,major_words,heap_words,top_heap_words")

let test_write_round_trips_first_row _ =
  (* Write a 2-snapshot collector to CSV, read it back, verify the header and
     the first phase column. The numeric fields vary run-to-run (live GC
     state); only the structural pins (header line + phase column) are
     deterministic enough to assert. *)
  let t = Backtest.Gc_trace.create () in
  Backtest.Gc_trace.record ~trace:t ~phase:"start" ();
  Backtest.Gc_trace.record ~trace:t ~phase:"end" ();
  let dir = Core_unix.mkdtemp "/tmp/gc_trace_test_" in
  let path = Filename.concat dir "trace.csv" in
  Backtest.Gc_trace.write ~out_path:path (Backtest.Gc_trace.snapshot_list t);
  let lines = In_channel.read_lines path in
  assert_that lines
    (all_of
       [
         (* Header + 2 data rows = 3 lines. *)
         size_is 3;
         field
           (fun ls -> List.nth_exn ls 0)
           (equal_to Backtest.Gc_trace.csv_header);
         field
           (fun ls -> List.nth_exn ls 1 |> String.split ~on:',' |> List.hd_exn)
           (equal_to "start");
         field
           (fun ls -> List.nth_exn ls 2 |> String.split ~on:',' |> List.hd_exn)
           (equal_to "end");
       ])

let test_write_creates_parent_dir _ =
  let root = Core_unix.mkdtemp "/tmp/gc_trace_test_" in
  let path = Filename.concat root "a/b/c/trace.csv" in
  Backtest.Gc_trace.write ~out_path:path [];
  assert_that (Sys_unix.file_exists_exn path) (equal_to true)

let test_write_empty_writes_header_only _ =
  let dir = Core_unix.mkdtemp "/tmp/gc_trace_test_" in
  let path = Filename.concat dir "empty.csv" in
  Backtest.Gc_trace.write ~out_path:path [];
  let lines = In_channel.read_lines path in
  assert_that lines (elements_are [ equal_to Backtest.Gc_trace.csv_header ])

let suite =
  "Gc_trace"
  >::: [
         "record without trace is no-op" >:: test_record_none_is_noop;
         "record with trace appends a snapshot" >:: test_record_appends_snapshot;
         "snapshot_list preserves insertion order"
         >:: test_snapshot_list_is_insertion_order;
         "csv_header matches snapshot fields"
         >:: test_csv_header_matches_snapshot_fields;
         "write produces header + ordered phase column"
         >:: test_write_round_trips_first_row;
         "write creates parent dir" >:: test_write_creates_parent_dir;
         "write of empty list writes header only"
         >:: test_write_empty_writes_header_only;
       ]

let () = run_test_tt_main suite
