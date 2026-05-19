(** [leak_repro] — 2026-05-19 diagnostic for the ~25 MB/backtest live-heap leak
    in [Backtest.Runner.run_backtest].

    DELETE AFTER 2026-05-26 when the root cause writeup at
    [dev/notes/bayesian-leak-rootcause-memprof-2026-05-19.md] is no longer
    actionable. This is not production code.

    Loops [Backtest.Runner.run_backtest] on the same fold (sp500 historical
    2011-07-01..2012-06-29) and reports: (a) per-iter [Gc.stat] live-words delta
    — confirms the leak is real (b) per-call-site surviving allocation bytes,
    aggregated via [Stdlib.Gc.Memprof.start]'s deallocation-tracker callbacks —
    surfaces the allocation site responsible for the retained 25 MB/iter.

    Optional [--memtrace PATH] writes a parallel CTF trace for use with the
    external memtrace-viewer tool.

    Usage (inside docker container, repo root): eval $(opam env) dune build
    trading/backtest/scripts/leak_repro.exe
    _build/default/trading/backtest/scripts/leak_repro.exe \ --iters 3 \
    --fixtures-root trading/test_data/backtest_scenarios *)

open Core
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file

let _fold_start = Date.create_exn ~y:2011 ~m:Jul ~d:1
let _fold_end = Date.create_exn ~y:2012 ~m:Jun ~d:29
let _scenario_path = "goldens-sp500-historical/sp500-2010-2026.sexp"

type snapshot = {
  iter : int;
  live_words : int;
  heap_words : int;
  top_heap_words : int;
}
(** ----- GC snapshot helpers -----------------------------------------*)

let _snapshot_at iter =
  let s = Stdlib.Gc.stat () in
  {
    iter;
    live_words = s.live_words;
    heap_words = s.heap_words;
    top_heap_words = s.top_heap_words;
  }

let _print_snapshot s =
  printf
    "[iter %d] live=%d (%.1f MB) heap=%d (%.1f MB) top_heap=%d (%.1f MB)\n%!"
    s.iter s.live_words
    (Float.of_int s.live_words *. 8.0 /. 1_048_576.0)
    s.heap_words
    (Float.of_int s.heap_words *. 8.0 /. 1_048_576.0)
    s.top_heap_words
    (Float.of_int s.top_heap_words *. 8.0 /. 1_048_576.0)

let _print_delta_words label ~prev ~now =
  let d = now.live_words - prev.live_words in
  printf "    delta vs %s: live_words = %d (%.1f MB)\n%!" label d
    (Float.of_int d *. 8.0 /. 1_048_576.0)

(** ----- Memprof tracker ---------------------------------------------*)

type tracked = {
  id : int;
  size_words : int; (* size excluding header *)
  n_samples : int;
  callstack : Stdlib.Printexc.raw_backtrace;
}
(** A per-allocation record we keep in memprof's tracker metadata. Each sampled
    block holds a unique id so we can identify it in the survivor table after
    the run. *)

(** Hashtable keyed by allocation id; entries are inserted on alloc and removed
    on dealloc. After Gc.compact between iterations, anything still in this
    table is surviving (= reachable from a GC root). *)
let _live_allocs : (int, tracked) Hashtbl.t = Hashtbl.create (module Int)

let _next_id = ref 0

let _alloc_cb (alloc : Stdlib.Gc.Memprof.allocation) : tracked option =
  let id = !_next_id in
  incr _next_id;
  let entry =
    {
      id;
      size_words = alloc.size;
      n_samples = alloc.n_samples;
      callstack = alloc.callstack;
    }
  in
  Hashtbl.set _live_allocs ~key:id ~data:entry;
  Some entry

let _dealloc_cb (t : tracked) = Hashtbl.remove _live_allocs t.id

let _tracker : (tracked, tracked) Stdlib.Gc.Memprof.tracker =
  {
    alloc_minor = _alloc_cb;
    alloc_major = _alloc_cb;
    promote = (fun t -> Some t);
    dealloc_minor = _dealloc_cb;
    dealloc_major = _dealloc_cb;
  }

(* @nesting-ok: diagnostic-only; nested match on slot format is structural *)
let _backtrace_key (bt : Stdlib.Printexc.raw_backtrace) =
  (* Use the top 10 frames as the aggregation key. Anything deeper is
     usually identical across siblings and bloats the report. *)
  let slots = Stdlib.Printexc.backtrace_slots bt in
  match slots with
  | None -> "<no-debug-info>"
  | Some arr ->
      let n = min 10 (Array.length arr) in
      let buf = Buffer.create 256 in
      for i = 0 to n - 1 do
        let s = arr.(i) in
        let loc_str =
          match Stdlib.Printexc.Slot.format i s with
          | Some s -> s
          | None -> "<no-info>"
        in
        Buffer.add_string buf loc_str;
        Buffer.add_char buf '\n'
      done;
      Buffer.contents buf

(* Aggregate surviving allocations by callstack and print top-N.
   Memprof's unbiased estimator for total allocated words at a site is
   [Σ n_samples / sampling_rate].  We report this scaled to MB and also
   list how many sampled records were aggregated into each group. *)
(* @nesting-ok: diagnostic-only; report-render loop with per-rank printf *)
let _print_top_survivors ~sampling_rate ~top =
  let by_stack : (string, int * int * int) Hashtbl.t =
    Hashtbl.create (module String)
  in
  Hashtbl.iter _live_allocs ~f:(fun (t : tracked) ->
      let key = _backtrace_key t.callstack in
      Hashtbl.update by_stack key ~f:(function
        | None -> (t.n_samples, t.size_words, 1)
        | Some (samples, size_sum, c) ->
            (samples + t.n_samples, size_sum + t.size_words, c + 1)));
  let ranked =
    Hashtbl.to_alist by_stack
    |> List.sort ~compare:(fun (_, (s1, _, _)) (_, (s2, _, _)) ->
        Int.compare s2 s1)
  in
  let scale = 1.0 /. sampling_rate in
  printf "\n=== top %d survivor allocation sites (estimated) ===\n%!" top;
  printf "Survivor allocations in hashtable: %d (raw, sampled)\n%!"
    (Hashtbl.length _live_allocs);
  List.take ranked top
  |> List.iteri ~f:(fun i (stack, (samples, size_sum, n_groups)) ->
      let est_words = Float.of_int samples *. scale in
      let est_mb = est_words *. 8.0 /. 1_048_576.0 in
      let avg_block_words = Float.of_int size_sum /. Float.of_int n_groups in
      printf "\n--- rank %d ---\n" (i + 1);
      printf
        "  est live ~%.1f MB (%.0f words est; %d sampled allocs; %d distinct \
         blocks; avg block %.0f words)\n\
         %!"
        est_mb est_words samples n_groups avg_block_words;
      printf "  callstack (top 10 frames):\n%s%!"
        (String.concat ~sep:""
           (String.split_lines stack |> List.map ~f:(fun l -> "    " ^ l ^ "\n"))))

(** ----- Backtest runner ---------------------------------------------*)

let[@inline never] _run_one_backtest ~fixtures_root ~scenario =
  let resolved_universe =
    Filename.concat fixtures_root scenario.Scenario.universe_path
  in
  let sector_map_override =
    Universe_file.to_sector_map_override (Universe_file.load resolved_universe)
  in
  let result =
    Backtest.Runner.run_backtest ~start_date:_fold_start ~end_date:_fold_end
      ~overrides:scenario.config_overrides ?sector_map_override
      ~strategy_choice:scenario.strategy ?slippage_bps:scenario.slippage_bps ()
  in
  (* Use [result] for a scalar so the compiler doesn't optimise it out;
     [result] itself is unreachable on return. *)
  result.summary.n_round_trips

let _full_gc () =
  Stdlib.Gc.compact ();
  Stdlib.Gc.full_major ();
  Stdlib.Gc.compact ()

let _start_memtrace_if_set ~memtrace_path =
  match memtrace_path with
  | None -> ()
  | Some path ->
      let _tracer : Memtrace.tracer =
        Memtrace.start_tracing ~context:None ~sampling_rate:1e-4 ~filename:path
      in
      printf "memtrace started, writing to %s\n%!" path

let _run ~iters ~fixtures_root ~scenario_path ~memtrace_path ~memprof_rate ~top
    =
  _start_memtrace_if_set ~memtrace_path;
  let scenario_full_path = Filename.concat fixtures_root scenario_path in
  let scenario = Scenario.load scenario_full_path in
  printf "scenario: %s\n%!" scenario.name;
  printf "fold:     %s..%s\n%!"
    (Date.to_string _fold_start)
    (Date.to_string _fold_end);
  printf "iters:    %d\n%!" iters;
  printf "memprof_rate: %g  (1 sample per %d words allocated)\n%!" memprof_rate
    (Int.of_float (1.0 /. memprof_rate));
  _full_gc ();
  let baseline = _snapshot_at 0 in
  _print_snapshot baseline;
  (* Start memprof AFTER the warmup baseline so module-init allocations
     aren't included. *)
  let _profile =
    Stdlib.Gc.Memprof.start ~sampling_rate:memprof_rate ~callstack_size:30
      _tracker
  in
  let prev = ref baseline in
  for i = 1 to iters do
    printf "\n=== iter %d ===\n%!" i;
    let n = _run_one_backtest ~fixtures_root ~scenario in
    printf "    (n_round_trips=%d returned)\n%!" n;
    _full_gc ();
    let now = _snapshot_at i in
    _print_snapshot now;
    _print_delta_words "prev" ~prev:!prev ~now;
    _print_delta_words "baseline" ~prev:baseline ~now;
    prev := now
  done;
  printf "\n=== final ===\n%!";
  let final = _snapshot_at iters in
  let total = final.live_words - baseline.live_words in
  printf
    "total live-word growth across %d iters: %d (~%.1f MB total = ~%.1f MB/iter)\n\
     %!"
    iters total
    (Float.of_int total *. 8.0 /. 1_048_576.0)
    (Float.of_int total *. 8.0 /. 1_048_576.0 /. Float.of_int iters);
  (* Stop sampling. Surviving allocs remain in _live_allocs because
     deallocation callbacks are NOT fired for blocks that are still
     reachable. We force one more GC after stopping so the deallocation
     callbacks for any unreachable-but-still-tracked blocks fire before
     we read the survivor table. *)
  Stdlib.Gc.Memprof.stop ();
  _full_gc ();
  _print_top_survivors ~sampling_rate:memprof_rate ~top

let () =
  let iters = ref 3 in
  let fixtures_root = ref "trading/test_data/backtest_scenarios" in
  let scenario_path = ref _scenario_path in
  let memtrace_path = ref None in
  let memprof_rate = ref 1e-3 in
  let top = ref 12 in
  let speclist =
    [
      ("--iters", Arg.Set_int iters, "N iterations (default 3)");
      ( "--fixtures-root",
        Arg.Set_string fixtures_root,
        "DIR scenario fixtures root" );
      ( "--scenario",
        Arg.Set_string scenario_path,
        "PATH relative to fixtures-root" );
      ( "--memtrace",
        Arg.String (fun s -> memtrace_path := Some s),
        "PATH start memtrace, write .ctf to PATH" );
      ( "--memprof-rate",
        Arg.Set_float memprof_rate,
        "RATE sampling rate in samples/word (default 1e-3)" );
      ("--top", Arg.Set_int top, "N show top-N survivor callstacks (default 12)");
    ]
  in
  Arg.parse speclist
    (fun s -> failwithf "unexpected positional arg: %s" s ())
    "leak_repro: loop run_backtest, watch live-words, attribute survivors.";
  _run ~iters:!iters ~fixtures_root:!fixtures_root ~scenario_path:!scenario_path
    ~memtrace_path:!memtrace_path ~memprof_rate:!memprof_rate ~top:!top
