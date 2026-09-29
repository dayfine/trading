open Core

(** Write the captured trace sexp at [path] and report on stderr. *)
let _write_trace ~path ~trace =
  let metrics = Backtest.Trace.snapshot trace in
  Backtest.Trace.write ~out_path:path metrics;
  eprintf "Trace written to: %s\n%!" path

(** Sampling rate for [Memtrace.start_tracing]. The Memtrace docs warn that
    rates above ~1e-4 carry measurable performance impact; 1e-4 yields ~10K
    samples for a typical backtest. *)
let _memtrace_sampling_rate = 1e-4

let _write_gc_trace ~path ~gc_trace =
  let snapshots = Backtest.Gc_trace.snapshot_list gc_trace in
  Backtest.Gc_trace.write ~out_path:path snapshots;
  eprintf "Gc-trace written to: %s\n%!" path

let _start_memtrace ~path =
  let _tracer : Memtrace.tracer =
    Memtrace.start_tracing ~context:None ~sampling_rate:_memtrace_sampling_rate
      ~filename:path
  in
  eprintf "Memtrace started, writing to: %s\n%!" path

(** Build a [Backtest_progress.emitter] that writes [progress.sexp] under
    [output_dir] every [n] Friday cycles, plus an unconditional final write.
    [None] when [progress_every] is [None]. *)
let _make_progress_emitter ~progress_every ~output_dir =
  Option.map progress_every ~f:(fun n ->
      let path = Filename.concat output_dir "progress.sexp" in
      eprintf
        "[progress] writing progress.sexp every %d Friday cycle(s) to %s\n%!" n
        path;
      {
        Backtest.Backtest_progress.every_n_fridays = n;
        on_progress =
          (fun progress ->
            Backtest.Backtest_progress.write_atomic ~path progress);
      })

let run_and_write ~start_date ~end_date ~overrides ~output_dir
    ?sector_map_override ?trace_path ?memtrace_path ?gc_trace_path
    ?bar_data_source ?progress_every ?slippage_bps () =
  Option.iter memtrace_path ~f:(fun path -> _start_memtrace ~path);
  let trace = Option.map trace_path ~f:(fun _ -> Backtest.Trace.create ()) in
  let gc_trace =
    Option.map gc_trace_path ~f:(fun _ -> Backtest.Gc_trace.create ())
  in
  let progress_emitter = _make_progress_emitter ~progress_every ~output_dir in
  Backtest.Gc_trace.record ?trace:gc_trace ~phase:"start" ();
  let result =
    Backtest.Runner.run_backtest ~start_date ~end_date ~overrides
      ?sector_map_override ?trace ?gc_trace ?bar_data_source ?progress_emitter
      ?slippage_bps ()
  in
  eprintf "Writing output to %s/\n%!" output_dir;
  Backtest.Result_writer.write ~output_dir result;
  (* Degenerate-fold + stuck-position guard (#1553/#1557): surface the finding
     union to stderr and [<output_dir>/fold_health.sexp]. Fires the divergence
     guard in real backtest-binary runs, not just the scenario catalog. Purely
     diagnostic — changes no metric, never aborts. *)
  Backtest.Fold_health_runner.emit ~output_dir result;
  eprintf "Output written to: %s/\n%!" output_dir;
  Option.iter (Option.both trace_path trace) ~f:(fun (path, trace) ->
      _write_trace ~path ~trace);
  Backtest.Gc_trace.record ?trace:gc_trace ~phase:"end" ();
  Option.iter (Option.both gc_trace_path gc_trace) ~f:(fun (path, gc_trace) ->
      _write_gc_trace ~path ~gc_trace);
  result
