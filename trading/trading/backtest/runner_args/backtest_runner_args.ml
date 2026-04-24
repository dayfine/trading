open Core

type t = {
  start_date : string;
  end_date : string option;
  overrides : Sexp.t list;
  loader_strategy : Loader_strategy.t option;
  trace_path : string option;
}

type acc = {
  positional : string list;
  overrides : Sexp.t list;
  loader_strategy : Loader_strategy.t option;
  trace_path : string option;
}
(** Accumulator for [_extract_flags]. Carries every flag the parser recognises
    plus the running list of positional args. Kept private so callers see the
    immutable {!t} only. *)

let _empty_acc =
  { positional = []; overrides = []; loader_strategy = None; trace_path = None }

let _err msg = Error (Status.invalid_argument_error msg)

let _parse_loader_strategy value =
  try Ok (Loader_strategy.of_string value) with Failure msg -> _err msg

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
  | "--loader-strategy" :: value :: rest -> (
      match _parse_loader_strategy value with
      | Ok parsed ->
          _extract_flags rest { acc with loader_strategy = Some parsed }
      | Error _ as e -> e)
  | [ "--loader-strategy" ] ->
      _err "--loader-strategy requires a value (legacy or tiered)"
  | "--trace" :: value :: rest ->
      _extract_flags rest { acc with trace_path = Some value }
  | [ "--trace" ] -> _err "--trace requires a path argument"
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
              loader_strategy = acc.loader_strategy;
              trace_path = acc.trace_path;
            }))
