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
       "phase,wall_ms,minor_words,promoted_words,major_words,heap_words,top_heap_words,cache_entries,cache_bytes,mmap_open")

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

(* --- snapshot-cache columns (#2878) ---------------------------------- *)

(* Distinct field values so the three columns cannot be transposed without
   reddening the row assertion below. *)
let _sample : Backtest.Gc_trace.cache_sample =
  { cache_entries = 12; cache_bytes = 3456; mmap_open = 7 }

(* The last three columns of a CSV row. *)
let _cache_columns row =
  String.split row ~on:',' |> fun cs ->
  List.drop cs (List.length cs - 3) |> String.concat ~sep:","

let _write_rows snapshots =
  let dir = Core_unix.mkdtemp "/tmp/gc_trace_test_" in
  let path = Filename.concat dir "trace.csv" in
  Backtest.Gc_trace.write ~out_path:path snapshots;
  In_channel.read_lines path |> List.tl_exn

(* The zero-overhead contract: with no [trace], the sampler thunk must never be
   forced. A counter, not a comment — this is the wiring that would silently
   rot if [record] started sampling before its [None] check. *)
let test_cache_sampler_not_forced_without_trace _ =
  let calls = ref 0 in
  let sampler () =
    Int.incr calls;
    _sample
  in
  Backtest.Gc_trace.record ~cache_sampler:sampler ~phase:"start" ();
  assert_that !calls (equal_to 0)

(* With a trace, the sampler IS forced, once per [record], and its values land
   on the snapshot. *)
let test_cache_sampler_forced_once_per_record _ =
  let calls = ref 0 in
  let sampler () =
    Int.incr calls;
    _sample
  in
  let t = Backtest.Gc_trace.create () in
  Backtest.Gc_trace.record ~trace:t ~cache_sampler:sampler ~phase:"start" ();
  Backtest.Gc_trace.record ~trace:t ~cache_sampler:sampler ~phase:"end" ();
  assert_that
    ( !calls,
      Backtest.Gc_trace.snapshot_list t
      |> List.map ~f:(fun (s : Backtest.Gc_trace.snapshot) -> s.cache) )
    (equal_to (2, [ Some _sample; Some _sample ]))

(* A sampled row carries the three values; an unsampled row carries three EMPTY
   fields, so a consumer can tell "not sampled" from a measured zero. *)
let test_cache_columns_render_sampled_and_blank _ =
  let t = Backtest.Gc_trace.create () in
  Backtest.Gc_trace.record ~trace:t
    ~cache_sampler:(fun () -> _sample)
    ~phase:"sampled" ();
  Backtest.Gc_trace.record ~trace:t ~phase:"unsampled" ();
  assert_that
    (_write_rows (Backtest.Gc_trace.snapshot_list t)
    |> List.map ~f:_cache_columns)
    (elements_are [ equal_to "12,3456,7"; equal_to ",," ])

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
         "cache sampler is not forced without a trace"
         >:: test_cache_sampler_not_forced_without_trace;
         "cache sampler is forced once per record"
         >:: test_cache_sampler_forced_once_per_record;
         "cache columns render sampled values and blanks"
         >:: test_cache_columns_render_sampled_and_blank;
       ]

let () = run_test_tt_main suite
