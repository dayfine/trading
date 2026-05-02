open Core

type t = {
  start_date : string;
  end_date : string option;
  overrides : string list;
  trace_path : string option;
  memtrace_path : string option;
  gc_trace_path : string option;
  baseline : bool;
  smoke : bool;
  experiment_name : string option;
}

type acc = {
  positional : string list;
  overrides : string list;
  trace_path : string option;
  memtrace_path : string option;
  gc_trace_path : string option;
  baseline : bool;
  smoke : bool;
  experiment_name : string option;
}
(** Accumulator for [_extract_flags]. Carries every flag the parser recognises
    plus the running list of positional args. *)

let _empty_acc =
  {
    positional = [];
    overrides = [];
    trace_path = None;
    memtrace_path = None;
    gc_trace_path = None;
    baseline = false;
    smoke = false;
    experiment_name = None;
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
        }
  | "--override" :: arg :: rest ->
      _extract_flags rest { acc with overrides = arg :: acc.overrides }
  | [ "--override" ] -> _err "--override requires an argument"
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
  | arg :: rest ->
      _extract_flags rest { acc with positional = arg :: acc.positional }

(** Pull start/end dates off the positional list. With [--smoke], the runner
    picks dates from the catalog so positionals are tolerated when present
    (start_date defaults to ["smoke"] sentinel) and the count must be 0..2;
    without [--smoke], at least [start_date] is required. *)
let _split_positional ~smoke positional =
  match (smoke, positional) with
  | true, [] -> Ok ("smoke", None)
  | true, [ s ] -> Ok (s, None)
  | true, [ s; e ] -> Ok (s, Some e)
  | true, _ -> _err "too many positional arguments"
  | false, [] -> _err "start_date is required"
  | false, [ s ] -> Ok (s, None)
  | false, [ s; e ] -> Ok (s, Some e)
  | false, _ -> _err "too many positional arguments"

(** Cross-flag validation: [--baseline] and [--smoke] require an explicit
    [--experiment-name] so the comparison / per-window subdirs have a stable
    home under [dev/experiments/<name>/]. *)
let _validate_experiment_required ~baseline ~smoke ~experiment_name =
  if (baseline || smoke) && Option.is_none experiment_name then
    _err
      "--baseline and --smoke require --experiment-name <name> for output \
       directory"
  else Ok ()

let parse args =
  Result.bind (_extract_flags args _empty_acc) ~f:(fun (acc : acc) ->
      Result.bind
        (_validate_experiment_required ~baseline:acc.baseline ~smoke:acc.smoke
           ~experiment_name:acc.experiment_name) ~f:(fun () ->
          Result.bind (_split_positional ~smoke:acc.smoke acc.positional)
            ~f:(fun (start_date, end_date) ->
              Ok
                {
                  start_date;
                  end_date;
                  overrides = acc.overrides;
                  trace_path = acc.trace_path;
                  memtrace_path = acc.memtrace_path;
                  gc_trace_path = acc.gc_trace_path;
                  baseline = acc.baseline;
                  smoke = acc.smoke;
                  experiment_name = acc.experiment_name;
                })))
