open Core

type t = {
  start_date : string;
  end_date : string option;
  overrides : Sexp.t list;
  trace_path : string option;
  memtrace_path : string option;
  gc_trace_path : string option;
}

type acc = {
  positional : string list;
  overrides : Sexp.t list;
  trace_path : string option;
  memtrace_path : string option;
  gc_trace_path : string option;
}
(** Accumulator for [_extract_flags]. Carries every flag the parser recognises
    plus the running list of positional args. Kept private so callers see the
    immutable {!t} only. *)

let _empty_acc =
  {
    positional = [];
    overrides = [];
    trace_path = None;
    memtrace_path = None;
    gc_trace_path = None;
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
  | "--override" :: sexp_str :: rest -> (
      match Or_error.try_with (fun () -> Sexp.of_string sexp_str) with
      | Ok sexp ->
          _extract_flags rest { acc with overrides = sexp :: acc.overrides }
      | Error err ->
          _err
            (sprintf "--override value is not a valid sexp: %s"
               (Error.to_string_hum err)))
  | [ "--override" ] -> _err "--override requires a sexp argument"
  | "--trace" :: value :: rest ->
      _extract_flags rest { acc with trace_path = Some value }
  | [ "--trace" ] -> _err "--trace requires a path argument"
  | "--memtrace" :: value :: rest ->
      _extract_flags rest { acc with memtrace_path = Some value }
  | [ "--memtrace" ] -> _err "--memtrace requires a path argument"
  | "--gc-trace" :: value :: rest ->
      _extract_flags rest { acc with gc_trace_path = Some value }
  | [ "--gc-trace" ] -> _err "--gc-trace requires a path argument"
  | arg :: rest ->
      _extract_flags rest { acc with positional = arg :: acc.positional }

let _split_positional positional =
  match positional with
  | [] -> _err "start_date is required"
  | [ s ] -> Ok (s, None)
  | [ s; e ] -> Ok (s, Some e)
  | _ -> _err "too many positional arguments"

let parse args =
  Result.bind (_extract_flags args _empty_acc) ~f:(fun (acc : acc) ->
      Result.bind (_split_positional acc.positional)
        ~f:(fun (start_date, end_date) ->
          Ok
            {
              start_date;
              end_date;
              overrides = acc.overrides;
              trace_path = acc.trace_path;
              memtrace_path = acc.memtrace_path;
              gc_trace_path = acc.gc_trace_path;
            }))
