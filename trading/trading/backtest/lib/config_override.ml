open Core

type t = { key_path : string list; value : Sexp.t }

let _err msg = Error (Status.invalid_argument_error msg)

(** [is_key_char c] is true for the characters allowed in a key-path component:
    alphanumeric and underscore. Dots are separators, handled at the path level.
*)
let _is_key_char c = Char.is_alphanum c || Char.equal c '_'

(** Detect the [key.path=value] form by checking that the prefix up to the first
    [=] is non-empty and consists only of [_is_key_char] / [.]. Anything else
    (parens, leading dash, embedded space) routes to raw-sexp parsing. *)
let is_key_path_form s =
  match String.lsplit2 s ~on:'=' with
  | None -> false
  | Some ("", _) -> false
  | Some (key, _) ->
      String.for_all key ~f:(fun c -> _is_key_char c || Char.equal c '.')

let _validate_key_path components =
  if List.is_empty components then _err "empty key path"
  else if List.exists components ~f:String.is_empty then
    _err "key path has empty component (e.g. trailing or leading dot)"
  else Ok components

let _parse_value raw =
  if String.is_empty raw then _err "empty value"
  else
    match Or_error.try_with (fun () -> Sexp.of_string raw) with
    | Ok sexp -> Ok sexp
    | Error err ->
        _err (sprintf "value is not a valid sexp: %s" (Error.to_string_hum err))

(** Build the parsed [t] from already-validated halves. Pulled out so [parse] is
    a flat sequence of [Result.bind]s rather than a nested staircase. *)
let _build_t key_path value = Ok { key_path; value }

let parse s =
  match String.lsplit2 s ~on:'=' with
  | None -> _err (sprintf "missing '=' in override: %s" s)
  | Some (key, raw_value) ->
      let%bind.Result key_path =
        _validate_key_path (String.split key ~on:'.')
      in
      let%bind.Result value = _parse_value raw_value in
      _build_t key_path value

(** Wrap [value] in a chain of single-field record sexps following [key_path].
    For [["a"; "b"; "c"]] and value [v] this returns [((a ((b ((c v))))))]. *)
let rec _wrap_in_record key_path value =
  match key_path with
  | [] ->
      (* Unreachable: [_validate_key_path] rejects empty paths. *)
      value
  | [ k ] -> Sexp.List [ Sexp.List [ Sexp.Atom k; value ] ]
  | k :: rest ->
      let inner = _wrap_in_record rest value in
      Sexp.List [ Sexp.List [ Sexp.Atom k; inner ] ]

let to_sexp { key_path; value } = _wrap_in_record key_path value
let parse_to_sexp s = Result.map (parse s) ~f:to_sexp
