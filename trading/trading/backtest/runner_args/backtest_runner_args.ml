open Core

type t = {
  start_date : string;
  end_date : string option;
  overrides : string list;
  shared_overrides : string list;
  trace_path : string option;
  memtrace_path : string option;
  gc_trace_path : string option;
  baseline : bool;
  smoke : bool;
  experiment_name : string option;
  fuzz_spec : string option;
}

type acc = {
  positional : string list;
  overrides : string list;
  shared_overrides : string list;
  trace_path : string option;
  memtrace_path : string option;
  gc_trace_path : string option;
  baseline : bool;
  smoke : bool;
  experiment_name : string option;
  fuzz_spec : string option;
}
(** Accumulator for [_extract_flags]. Carries every flag the parser recognises
    plus the running list of positional args. *)

let _empty_acc =
  {
    positional = [];
    overrides = [];
    shared_overrides = [];
    trace_path = None;
    memtrace_path = None;
    gc_trace_path = None;
    baseline = false;
    smoke = false;
    experiment_name = None;
    fuzz_spec = None;
  }

let _err msg = Error (Status.invalid_argument_error msg)

let rec _extract_flags args (acc : acc) =
  match args with
  | [] ->
      Ok
        {
          acc with
          positional = List.rev acc.positional;
          overrides = List.rev acc.overrides;
          shared_overrides = List.rev acc.shared_overrides;
        }
  | "--override" :: arg :: rest ->
      _extract_flags rest { acc with overrides = arg :: acc.overrides }
  | [ "--override" ] -> _err "--override requires an argument"
  | "--shared-override" :: arg :: rest ->
      _extract_flags rest
        { acc with shared_overrides = arg :: acc.shared_overrides }
  | [ "--shared-override" ] -> _err "--shared-override requires an argument"
  | "--trace" :: value :: rest ->
      _extract_flags rest { acc with trace_path = Some value }
  | [ "--trace" ] -> _err "--trace requires a path argument"
  | "--memtrace" :: value :: rest ->
      _extract_flags rest { acc with memtrace_path = Some value }
  | [ "--memtrace" ] -> _err "--memtrace requires a path argument"
  | "--gc-trace" :: value :: rest ->
      _extract_flags rest { acc with gc_trace_path = Some value }
  | [ "--gc-trace" ] -> _err "--gc-trace requires a path argument"
  | "--baseline" :: rest -> _extract_flags rest { acc with baseline = true }
  | "--smoke" :: rest -> _extract_flags rest { acc with smoke = true }
  | "--experiment-name" :: value :: rest ->
      _extract_flags rest { acc with experiment_name = Some value }
  | [ "--experiment-name" ] -> _err "--experiment-name requires a name argument"
  | "--fuzz" :: value :: rest ->
      _extract_flags rest { acc with fuzz_spec = Some value }
  | [ "--fuzz" ] -> _err "--fuzz requires a spec argument"
  | arg :: rest ->
      _extract_flags rest { acc with positional = arg :: acc.positional }

(** Pull start/end dates off the positional list. With [--smoke] (or [--fuzz] on
    a date key) the runner picks dates from the catalog / fuzz variants, so
    positionals become optional in those modes — when omitted the [start_date]
    field is filled with a sentinel atom (["smoke"] or ["fuzz"]) that the
    executable replaces before invoking [Runner.run_backtest]. The parser stays
    clock-free, so no validation that a fuzz on a non-date key actually has a
    positional date — that surfaces at run-time. *)
let _split_positional ~smoke ~fuzz_spec positional =
  let sentinel = if smoke then "smoke" else "fuzz" in
  let lenient = smoke || Option.is_some fuzz_spec in
  match (lenient, positional) with
  | true, [] -> Ok (sentinel, None)
  | true, [ s ] -> Ok (s, None)
  | true, [ s; e ] -> Ok (s, Some e)
  | true, _ -> _err "too many positional arguments"
  | false, [] -> _err "start_date is required"
  | false, [ s ] -> Ok (s, None)
  | false, [ s; e ] -> Ok (s, Some e)
  | false, _ -> _err "too many positional arguments"

(** Cross-flag validation: [--baseline], [--smoke], and [--fuzz] each require an
    explicit [--experiment-name] so the comparison / per-window / per-variant
    subdirs have a stable home under [dev/experiments/<name>/]. *)
let _validate_experiment_required ~baseline ~smoke ~fuzz_spec ~experiment_name =
  let need_name = baseline || smoke || Option.is_some fuzz_spec in
  if need_name && Option.is_none experiment_name then
    _err
      "--baseline, --smoke, and --fuzz require --experiment-name <name> for \
       output directory"
  else Ok ()

(** [--fuzz] is mutually exclusive with [--baseline] and [--smoke] for the first
    cut. Composing them would require a 3-D output structure (per-window ×
    per-variant × baseline-vs-variant) that the distribution renderer doesn't
    yet handle. Recommended pattern: run a single fuzz invocation per window or
    per baseline study. *)
let _validate_fuzz_exclusivity ~baseline ~smoke ~fuzz_spec =
  match fuzz_spec with
  | None -> Ok ()
  | Some _ when baseline -> _err "--fuzz is mutually exclusive with --baseline"
  | Some _ when smoke -> _err "--fuzz is mutually exclusive with --smoke"
  | Some _ -> Ok ()

let _build_result (acc : acc) (start_date, end_date) =
  Ok
    {
      start_date;
      end_date;
      overrides = acc.overrides;
      shared_overrides = acc.shared_overrides;
      trace_path = acc.trace_path;
      memtrace_path = acc.memtrace_path;
      gc_trace_path = acc.gc_trace_path;
      baseline = acc.baseline;
      smoke = acc.smoke;
      experiment_name = acc.experiment_name;
      fuzz_spec = acc.fuzz_spec;
    }

let parse args =
  Result.bind (_extract_flags args _empty_acc) ~f:(fun (acc : acc) ->
      Result.bind
        (_validate_experiment_required ~baseline:acc.baseline ~smoke:acc.smoke
           ~fuzz_spec:acc.fuzz_spec ~experiment_name:acc.experiment_name)
        ~f:(fun () ->
          Result.bind
            (_validate_fuzz_exclusivity ~baseline:acc.baseline ~smoke:acc.smoke
               ~fuzz_spec:acc.fuzz_spec) ~f:(fun () ->
              Result.bind
                (_split_positional ~smoke:acc.smoke ~fuzz_spec:acc.fuzz_spec
                   acc.positional)
                ~f:(_build_result acc))))
