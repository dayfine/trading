(** Backtest runner CLI — thin wrapper around the {!Backtest} library.

    Usage modes:

    {1 Single-run mode (legacy)}

    [backtest_runner <start_date> [end_date] [--override <arg>] [--trace <path>]
     [--memtrace <path>] [--gc-trace <path>] [--experiment-name <name>]]

    Writes [params.sexp], [summary.sexp], [trades.csv], etc. to either
    [dev/experiments/<name>/] (when [--experiment-name] is set) or a timestamped
    directory under [dev/backtest/] (default).

    {1 Baseline-comparison mode}

    [backtest_runner <start_date> [end_date] --baseline --experiment-name <name>
     [--shared-override <arg> ...] [--override <arg> ...]]

    Runs twice — once with the variant overrides ([variant/] subdir) and once
    without ([baseline/] subdir) — then writes [comparison.sexp] +
    [comparison.md] at the experiment root with per-metric deltas. Any
    [--shared-override] flags apply to {b both} runs.

    {1 Smoke mode}

    [backtest_runner --smoke --experiment-name <name> [--shared-override <arg>
     ...] [--override <arg> ...] [--baseline]]

    Runs each window in {!Scenario_lib.Smoke_catalog.all} (Bull / Crash /
    Recovery), writing results under [dev/experiments/<name>/<window-name>/].
    Composes with [--baseline] for per-window comparisons. Each window's
    [universe_path] (sp500 by default; see {!Scenario_lib.Smoke_catalog})
    constrains the loaded universe so the run fits inside the dev container's
    memory budget.

    {1 Fuzz mode}

    [backtest_runner [<start_date> [end_date]] --fuzz
     <param>=<center>±<delta>:<n> [--fuzz-window <bull|crash|recovery>]
     --experiment-name <name> [--override <arg>] ...]

    Parses the spec via {!Backtest.Fuzz_spec.parse}, runs N variants, and writes
    [fuzz_distribution.{sexp,md}] alongside per-variant subdirs at
    [dev/experiments/<name>/variants/var-NN/]. Two example invocations:

    {v
      --fuzz start_date=2019-05-01±5w:11   # date jitter ±5 weeks, 11 variants
      --fuzz stops_config.initial_stop_buffer=1.05±0.02:11  # numeric jitter
    v}

    Mutually exclusive with [--baseline] and [--smoke]; composes freely with
    [--override] / [--shared-override] (those apply to every variant). For
    date-key specs the positional [start_date] is overridden by the variant; for
    numeric-key specs the positional [start_date] is required.

    The optional [--fuzz-window <name>] flag points at a window in
    {!Scenario_lib.Smoke_catalog} (currently [bull], [crash], [recovery]) and
    constrains every variant to that window's [universe_path] (sp500 by
    default). Without it, fuzz mode loads the full ~10K-symbol [sectors.csv] and
    OOMs the 8 GB dev container — this is the same fix smoke mode received; the
    runner now warns when [--fuzz-window] is omitted. Note: only the universe is
    constrained; the window's start/end dates are NOT substituted into variants.

    {1 --override vs. --shared-override}

    Both flags accept the same syntax, freely composable:
    - {b Key-path}: [stops_config.initial_stop_buffer=1.05] — ergonomic,
      dispatched via {!Backtest.Config_override}.
    - {b Raw sexp}: [((stops_config ((initial_stop_buffer 1.05))))] — legacy,
      kept for backward compat with existing scripts.

    The runner converts both forms to the [Sexp.t list] that
    [Backtest.Runner._apply_overrides] already deep-merges into the default
    {!Weinstein_strategy.config}. Overrides apply to exactly the named field;
    every other config value comes from the default.

    Mode-dependent semantics:
    - [--override] applies to the (single / variant / each-window) run; in
      [--baseline] mode it does NOT apply to the baseline.
    - [--shared-override] applies to BOTH runs in [--baseline] mode (e.g.
      [universe_cap=500] to cap memory for both legs of the A/B). Outside
      [--baseline], shared overrides are equivalent to [--override]. *)

open Core

let _usage_msg =
  "Usage: backtest_runner <start_date> [end_date] [--override <arg>] \
   [--shared-override <arg>] [--trace <path>] [--memtrace <path>] [--gc-trace \
   <path>] [--baseline] [--smoke] [--fuzz <spec>] [--fuzz-window \
   <bull|crash|recovery>] [--experiment-name <name>]"

(** Convert each raw [--override <arg>] string into the partial-config sexp the
    runner deep-merges. Routes key-path strings through
    {!Backtest.Config_override}; falls back to raw [Sexp.of_string] for legacy
    sexp blobs. Surfaces parse errors via [Stdlib.exit 1]. *)
let _resolve_overrides raw_overrides =
  List.map raw_overrides ~f:(fun s ->
      if Backtest.Config_override.is_key_path_form s then (
        match Backtest.Config_override.parse_to_sexp s with
        | Ok sexp -> sexp
        | Error err ->
            eprintf "Error: invalid --override %S: %s\n" s err.message;
            Stdlib.exit 1)
      else
        match Or_error.try_with (fun () -> Sexp.of_string s) with
        | Ok sexp -> sexp
        | Error err ->
            eprintf "Error: --override value is not a valid sexp: %s\n"
              (Error.to_string_hum err);
            Stdlib.exit 1)

let _parse_args () =
  let argv = Sys.get_argv () in
  if Array.length argv < 2 then (
    eprintf "%s\n" _usage_msg;
    Stdlib.exit 1);
  let args = Array.to_list argv |> List.tl_exn in
  match Backtest_runner_args.parse args with
  | Error status ->
      eprintf "Error: %s\n" status.message;
      Stdlib.exit 1
  | Ok parsed -> parsed

(** Resolve [--experiment-name] into an output root directory. When set, returns
    [dev/experiments/<name>]; otherwise a fresh timestamped
    [dev/backtest/<YYYY-MM-DD-HHMMSS>] directory.

    Pulled out of [main] so the same path-construction logic is shared between
    single-run, baseline, and smoke modes. *)
let _make_output_root ?experiment_name () =
  let data_dir_fpath = Data_path.default_data_dir () in
  let repo_root = Fpath.parent data_dir_fpath |> Fpath.to_string in
  match experiment_name with
  | Some name ->
      let path = repo_root ^ "dev/experiments/" ^ name in
      Core_unix.mkdir_p path;
      path
  | None ->
      let now = Core_unix.gettimeofday () in
      let tm = Core_unix.localtime now in
      let dirname =
        sprintf "%04d-%02d-%02d-%02d%02d%02d" (tm.tm_year + 1900)
          (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec
      in
      let path = repo_root ^ "dev/backtest/" ^ dirname in
      Core_unix.mkdir_p path;
      path

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

(** Run a single backtest and write its full result set to [output_dir]. The
    side-effecting work (trace + memtrace + gc-trace plumbing) is folded in here
    so single-run / baseline / smoke modes all share the same per-run pipeline.

    [sector_map_override], when supplied, replaces the sector map normally
    loaded from [data/sectors.csv] — used by smoke mode to constrain each window
    to the catalog's [universe_path]. See {!Backtest.Runner.run_backtest}.

    Returns the [Backtest.Runner.result] so callers (e.g. baseline mode) can
    feed both runs into [Backtest.Comparison.compute] without re-reading the
    summary from disk. *)
let _run_and_write ~start_date ~end_date ~overrides ~output_dir
    ?sector_map_override ?trace_path ?memtrace_path ?gc_trace_path
    ?bar_data_source () =
  Option.iter memtrace_path ~f:(fun path -> _start_memtrace ~path);
  let trace = Option.map trace_path ~f:(fun _ -> Backtest.Trace.create ()) in
  let gc_trace =
    Option.map gc_trace_path ~f:(fun _ -> Backtest.Gc_trace.create ())
  in
  Backtest.Gc_trace.record ?trace:gc_trace ~phase:"start" ();
  let result =
    Backtest.Runner.run_backtest ~start_date ~end_date ~overrides
      ?sector_map_override ?trace ?gc_trace ?bar_data_source ()
  in
  eprintf "Writing output to %s/\n%!" output_dir;
  Backtest.Result_writer.write ~output_dir result;
  eprintf "Output written to: %s/\n%!" output_dir;
  Option.iter (Option.both trace_path trace) ~f:(fun (path, trace) ->
      _write_trace ~path ~trace);
  Backtest.Gc_trace.record ?trace:gc_trace ~phase:"end" ();
  Option.iter (Option.both gc_trace_path gc_trace) ~f:(fun (path, gc_trace) ->
      _write_gc_trace ~path ~gc_trace);
  result

(** Single-run mode: one backtest, write to [output_dir], echo summary to
    stdout. This is the legacy code path (also reused by smoke mode for the
    no-baseline case). [overrides] are pre-merged from [--shared-override] +
    [--override] by the caller. *)
let _single_run ~start_date ~end_date ~overrides ~output_dir
    ?sector_map_override ?trace_path ?memtrace_path ?gc_trace_path
    ?bar_data_source () =
  let result =
    _run_and_write ~start_date ~end_date ~overrides ~output_dir
      ?sector_map_override ?trace_path ?memtrace_path ?gc_trace_path
      ?bar_data_source ()
  in
  Out_channel.output_string stdout
    (Sexp.to_string_hum (Backtest.Summary.sexp_of_t result.summary));
  Out_channel.newline stdout

(** Baseline-comparison mode: run with [shared_overrides @ overrides] (variant)
    and again with [shared_overrides] only (baseline), then write
    [comparison.{sexp,md}] at [output_root]. The [shared_overrides] split is
    what lets a caller cap the universe (or tweak any other env-shaping
    parameter) for both legs of the A/B without contaminating the comparison
    delta with the cap itself. *)
let _baseline_run ~start_date ~end_date ~shared_overrides ~overrides
    ~output_root ?sector_map_override () =
  let baseline_dir = Filename.concat output_root "baseline" in
  let variant_dir = Filename.concat output_root "variant" in
  Core_unix.mkdir_p baseline_dir;
  Core_unix.mkdir_p variant_dir;
  eprintf "[baseline] running with %d shared override(s)...\n%!"
    (List.length shared_overrides);
  let baseline_result =
    _run_and_write ~start_date ~end_date ~overrides:shared_overrides
      ~output_dir:baseline_dir ?sector_map_override ()
  in
  eprintf "[variant] running with %d shared + %d variant override(s)...\n%!"
    (List.length shared_overrides)
    (List.length overrides);
  let variant_result =
    _run_and_write ~start_date ~end_date
      ~overrides:(shared_overrides @ overrides)
      ~output_dir:variant_dir ?sector_map_override ()
  in
  let comparison =
    Backtest.Comparison.compute ~baseline:baseline_result.summary
      ~variant:variant_result.summary
  in
  let sexp_path = Filename.concat output_root "comparison.sexp" in
  let md_path = Filename.concat output_root "comparison.md" in
  Backtest.Comparison.write_sexp ~output_path:sexp_path comparison;
  Backtest.Comparison.write_markdown ~output_path:md_path comparison;
  eprintf "Comparison written to: %s and %s\n%!" sexp_path md_path

(** Resolve a smoke window's [universe_path] (relative to the fixtures root)
    into a [sector_map_override] for {!Backtest.Runner.run_backtest}. Mirrors
    the convention used by [scenario_runner.ml]: the path is documented as
    relative to [TRADING_DATA_DIR/backtest_scenarios/], which is what
    {!Scenario_lib.Fixtures_root.resolve} returns. *)
let _smoke_window_sector_map ~fixtures_root
    (window : Scenario_lib.Smoke_catalog.window) =
  let resolved = Filename.concat fixtures_root window.universe_path in
  Scenario_lib.Universe_file.to_sector_map_override
    (Scenario_lib.Universe_file.load resolved)

(** Resolve a [--fuzz-window <name>] flag value into a [sector_map_override] by
    looking up the named window in {!Scenario_lib.Smoke_catalog.all}. Exits 1
    with a friendly error if the name doesn't match any catalog entry — that way
    a typo surfaces immediately, not after the universe is already loaded. *)
let _resolve_fuzz_window_override name =
  match
    List.find Scenario_lib.Smoke_catalog.all
      ~f:(fun (w : Scenario_lib.Smoke_catalog.window) ->
        String.equal w.name name)
  with
  | Some window ->
      let fixtures_root = Scenario_lib.Fixtures_root.resolve () in
      _smoke_window_sector_map ~fixtures_root window
  | None ->
      let known =
        List.map Scenario_lib.Smoke_catalog.all
          ~f:(fun (w : Scenario_lib.Smoke_catalog.window) -> w.name)
        |> String.concat ~sep:", "
      in
      eprintf "Error: unknown --fuzz-window %S (known: %s)\n" name known;
      Stdlib.exit 1

(** Convert one fuzz variant into the (start_date, overrides) pair the
    per-variant run consumes. Date variants substitute the start_date; numeric
    variants are encoded as a partial-config sexp via {!Config_override} and
    appended to the shared overrides. *)
let _resolve_fuzz_variant ~base_start_date ~base_overrides
    (v : Backtest.Fuzz_spec.variant) =
  match v.value with
  | V_date d -> (d, base_overrides)
  | V_float f ->
      let key_path = String.split v.key_path ~on:'.' in
      let value_sexp = Sexp.Atom (sprintf "%g" f) in
      let override_sexp =
        Backtest.Config_override.to_sexp { key_path; value = value_sexp }
      in
      (base_start_date, base_overrides @ [ override_sexp ])

(** Fuzz mode: parse the spec, run N variants under
    [<output_root>/variants/var-NN/], collect each summary, and write
    [fuzz_distribution.{sexp,md}] at [output_root]. The [overrides] list (which
    already includes any [--shared-override] entries appended at the call site)
    is passed unchanged to every variant — fuzz-mode treats override and
    shared_override identically since there's no baseline to differentiate them.

    [sector_map_override], when supplied (via [--fuzz-window <name>]), replaces
    the default sector map for {b every} variant — same trick smoke mode uses to
    keep the run inside the dev-container memory budget. *)
let _fuzz_run ~start_date ~end_date ~overrides ~output_root ~fuzz_spec_raw
    ?sector_map_override () =
  let fuzz_spec =
    match Backtest.Fuzz_spec.parse fuzz_spec_raw with
    | Ok spec -> spec
    | Error err ->
        eprintf "Error: invalid --fuzz spec %S: %s\n" fuzz_spec_raw err.message;
        Stdlib.exit 1
  in
  let variants_root = Filename.concat output_root "variants" in
  Core_unix.mkdir_p variants_root;
  let n = fuzz_spec.n in
  let labelled_summaries =
    List.map fuzz_spec.variants ~f:(fun v ->
        let subdir = Backtest.Fuzz_spec.subdir_name ~n ~index:v.index in
        let variant_dir = Filename.concat variants_root subdir in
        Core_unix.mkdir_p variant_dir;
        let v_start, v_overrides =
          _resolve_fuzz_variant ~base_start_date:start_date
            ~base_overrides:overrides v
        in
        eprintf "[fuzz %d/%d] %s = %s\n%!" v.index n v.key_path v.label;
        let result =
          _run_and_write ~start_date:v_start ~end_date ~overrides:v_overrides
            ~output_dir:variant_dir ?sector_map_override ()
        in
        (v.label, result.summary))
  in
  let dist =
    Backtest.Fuzz_distribution.compute ~fuzz_spec_raw labelled_summaries
  in
  let sexp_path = Filename.concat output_root "fuzz_distribution.sexp" in
  let md_path = Filename.concat output_root "fuzz_distribution.md" in
  Backtest.Fuzz_distribution.write_sexp ~output_path:sexp_path dist;
  Backtest.Fuzz_distribution.write_markdown ~output_path:md_path dist;
  eprintf "Fuzz distribution written to: %s and %s\n%!" sexp_path md_path

(** Smoke mode: loop over every window in {!Scenario_lib.Smoke_catalog.all},
    delegating to either [_single_run] or [_baseline_run] per window depending
    on the [baseline] flag. Each window's [universe_path] is loaded into a
    [sector_map_override] so the run stays inside the dev container's memory
    budget rather than blowing up on the full ~10K-symbol [sectors.csv]. *)
let _smoke_run ~shared_overrides ~overrides ~output_root ~baseline () =
  let fixtures_root = Scenario_lib.Fixtures_root.resolve () in
  List.iter Scenario_lib.Smoke_catalog.all ~f:(fun window ->
      let window_dir = Filename.concat output_root window.name in
      Core_unix.mkdir_p window_dir;
      let sector_map_override =
        _smoke_window_sector_map ~fixtures_root window
      in
      let n_symbols =
        Option.value_map sector_map_override ~default:0 ~f:Hashtbl.length
      in
      eprintf "\n=== smoke window: %s (%s .. %s, %d symbols) — %s ===\n%!"
        window.name
        (Date.to_string window.start_date)
        (Date.to_string window.end_date)
        n_symbols window.description;
      if baseline then
        _baseline_run ~start_date:window.start_date ~end_date:window.end_date
          ~shared_overrides ~overrides ~output_root:window_dir
          ?sector_map_override ()
      else
        _single_run ~start_date:window.start_date ~end_date:window.end_date
          ~overrides:(shared_overrides @ overrides)
          ~output_dir:window_dir ?sector_map_override ())

(** Resolve [parsed.snapshot_dir] into a [Bar_data_source.t option]. When set,
    reads the manifest at [<snapshot_dir>/manifest.sexp] and constructs a
    [Snapshot] selector. Exits 1 on a missing or corrupt manifest so the failure
    mode (snapshot dir not yet built) surfaces immediately rather than as a
    runner-internal error. *)
let _resolve_bar_data_source snapshot_dir =
  Option.map snapshot_dir ~f:(fun dir ->
      let manifest_path = Filename.concat dir "manifest.sexp" in
      match Snapshot_pipeline.Snapshot_manifest.read ~path:manifest_path with
      | Ok manifest ->
          eprintf
            "[snapshot-mode] loaded manifest at %s (schema_hash=%s, %d entries)\n\
             %!"
            manifest_path manifest.schema_hash
            (List.length manifest.entries);
          Backtest.Bar_data_source.Snapshot { snapshot_dir = dir; manifest }
      | Error err ->
          eprintf "Error: failed to read snapshot manifest at %s: %s\n"
            manifest_path (Status.show err);
          Stdlib.exit 1)

(** Resolve the raw start/end positionals into [Date.t]. Smoke mode supplies its
    own dates per window so the positionals are unused there; the caller only
    invokes this for non-smoke runs. *)
let _resolve_dates ~start_date_raw ~end_date_raw =
  let start_date = Date.of_string start_date_raw in
  let end_date =
    match end_date_raw with
    | Some s -> Date.of_string s
    | None -> Date.today ~zone:Time_float.Zone.utc
  in
  (start_date, end_date)

(** Resolve dates safely for fuzz mode: when the user passed the [fuzz] sentinel
    for the start_date positional (no positional given), fall back to a
    placeholder [Date.t] — for date-key fuzz the variant supplies the real
    start_date, for numeric-key fuzz the user is expected to have supplied a
    positional. We surface a friendly error if a numeric-key fuzz runs without a
    positional. *)
let _resolve_dates_for_fuzz ~start_date_raw ~end_date_raw =
  if String.equal start_date_raw "fuzz" then
    (* Placeholder; date-key variants overwrite, numeric-key variants need a
       real positional and we'll fail loudly downstream. *)
    let placeholder = Date.create_exn ~y:2000 ~m:Month.Jan ~d:1 in
    let end_date =
      match end_date_raw with
      | Some s -> Date.of_string s
      | None -> Date.today ~zone:Time_float.Zone.utc
    in
    (placeholder, end_date)
  else _resolve_dates ~start_date_raw ~end_date_raw

let () =
  let parsed = _parse_args () in
  let overrides = _resolve_overrides parsed.overrides in
  let shared_overrides = _resolve_overrides parsed.shared_overrides in
  let output_root =
    _make_output_root ?experiment_name:parsed.experiment_name ()
  in
  match (parsed.fuzz_spec, parsed.smoke, parsed.baseline) with
  | Some fuzz_spec_raw, _, _ ->
      let start_date, end_date =
        _resolve_dates_for_fuzz ~start_date_raw:parsed.start_date
          ~end_date_raw:parsed.end_date
      in
      let sector_map_override =
        match parsed.fuzz_window with
        | Some name -> _resolve_fuzz_window_override name
        | None ->
            eprintf
              "[fuzz] WARNING: --fuzz-window not set; loading the full \
               sector-map. This OOMs the 8 GB dev container at panel-load. \
               Pass --fuzz-window <bull|crash|recovery> to constrain to the \
               sp500 universe (~491 symbols).\n\
               %!";
            None
      in
      (* Fuzz mode treats override and shared_override identically — there's
         no baseline to differentiate them, so flatten both into the per-variant
         override list. *)
      _fuzz_run ~start_date ~end_date
        ~overrides:(shared_overrides @ overrides)
        ~output_root ~fuzz_spec_raw ?sector_map_override ()
  | None, true, _ ->
      _smoke_run ~shared_overrides ~overrides ~output_root
        ~baseline:parsed.baseline ()
  | None, false, true ->
      let start_date, end_date =
        _resolve_dates ~start_date_raw:parsed.start_date
          ~end_date_raw:parsed.end_date
      in
      _baseline_run ~start_date ~end_date ~shared_overrides ~overrides
        ~output_root ()
  | None, false, false ->
      let start_date, end_date =
        _resolve_dates ~start_date_raw:parsed.start_date
          ~end_date_raw:parsed.end_date
      in
      let bar_data_source = _resolve_bar_data_source parsed.snapshot_dir in
      (* Outside [--baseline], shared overrides are equivalent to overrides:
         applied identically to the (single) run. *)
      _single_run ~start_date ~end_date
        ~overrides:(shared_overrides @ overrides)
        ~output_dir:output_root ?trace_path:parsed.trace_path
        ?memtrace_path:parsed.memtrace_path ?gc_trace_path:parsed.gc_trace_path
        ?bar_data_source ()
