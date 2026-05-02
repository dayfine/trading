open Core

type variant_value = V_date of Date.t | V_float of float [@@deriving sexp_of]

type variant = {
  index : int;
  label : string;
  key_path : string;
  value : variant_value;
}
[@@deriving sexp_of]

type t = {
  raw_spec : string;
  key_path : string;
  n : int;
  variants : variant list;
}
[@@deriving sexp_of]

let _err msg = Error (Status.invalid_argument_error msg)

(** [±] is the multibyte UTF-8 sequence ["\xC2\xB1"] (2 bytes); we accept it AND
    the ASCII fallback [+/-] for shells that don't pass UTF-8 cleanly. *)
let _plus_minus_utf8 = "\xC2\xB1"

let _plus_minus_ascii = "+/-"

(** Split [s] on the first occurrence of [pattern], returning [(before, after)].
    Pulled out so [_split_on_plus_minus] can try both separators without
    nesting. *)
let _split_on_pattern s ~pattern =
  match String.substr_index s ~pattern with
  | None -> None
  | Some i ->
      let plen = String.length pattern in
      let before = String.sub s ~pos:0 ~len:i in
      let after =
        String.sub s ~pos:(i + plen) ~len:(String.length s - i - plen)
      in
      Some (before, after)

(** Find the first occurrence of either separator and return [(before, after)].
    Returns [None] if neither is present. UTF-8 [±] is checked first because
    it's the documented form. *)
let _split_on_plus_minus s =
  match _split_on_pattern s ~pattern:_plus_minus_utf8 with
  | Some pair -> Some pair
  | None -> _split_on_pattern s ~pattern:_plus_minus_ascii

(** Validate that [key] looks like a dotted alphanumeric+underscore key path —
    same rules as {!Config_override.is_key_path_form} so the two flag families
    accept the same key syntax. *)
let _validate_key_path key =
  if String.is_empty key then _err "fuzz spec: empty key before ="
  else if
    String.for_all key ~f:(fun c ->
        Char.is_alphanum c || Char.equal c '_' || Char.equal c '.')
  then Ok key
  else _err (sprintf "fuzz spec: invalid key path %S (must be dotted_key)" key)

(** Try to parse as YYYY-MM-DD; returns [None] on failure (caller falls back to
    float parsing). *)
let _try_parse_date s = Option.try_with (fun () -> Date.of_string s)

(** Validate the magnitude string of a date delta. Splits the
    integer-vs-unknown-format case from the unit-char dispatch in the caller. *)
let _validate_date_delta_magnitude mag_str =
  match Int.of_string_opt mag_str with
  | None ->
      _err
        (sprintf "fuzz spec: date delta magnitude %S is not an integer" mag_str)
  | Some n when n < 0 ->
      _err "fuzz spec: date delta magnitude must be non-negative"
  | Some n -> Ok n

(** Validate the unit-char of a date delta. Returns the lowercased char on
    success. *)
let _validate_date_delta_unit unit_char =
  match Char.lowercase unit_char with
  | ('d' | 'w' | 'm') as c -> Ok c
  | _ ->
      _err
        (sprintf "fuzz spec: date delta unit %C unknown (expected d/w/m)"
           unit_char)

(** Combine validated unit-char with validated magnitude. *)
let _pair_mag_unit unit_char n = Ok (n, unit_char)

(** Parse a date delta literal of the form [Nd] / [Nw] / [Nm]; returns [Error]
    on bad format. Returns the magnitude in (n, unit-char). *)
let _parse_date_delta s =
  let len = String.length s in
  if len < 2 then
    _err (sprintf "fuzz spec: date delta %S too short (expected e.g. 5w)" s)
  else
    let mag_str = String.sub s ~pos:0 ~len:(len - 1) in
    Result.bind
      (_validate_date_delta_unit s.[len - 1])
      ~f:(fun unit_char ->
        Result.bind
          (_validate_date_delta_magnitude mag_str)
          ~f:(_pair_mag_unit unit_char))

(** Constants for date-delta unit conversion. The month conversion uses an
    approximate average length so the call site stays a flat lookup; documented
    in the .mli — not appropriate for very large month deltas (use weeks or days
    instead). *)
let _days_per_week = 7

let _days_per_month_approx = 30

(** Convert a date delta (n, unit) into a number of days. Months use the
    approximate constant above; the alternative (dispatching to
    [Date.add_months] on each variant) only matters for very large month deltas,
    which is not the use case here. *)
let _days_of_date_delta n unit_char =
  match unit_char with
  | 'd' -> n
  | 'w' -> n * _days_per_week
  | 'm' -> n * _days_per_month_approx
  | _ -> failwith "unreachable: _parse_date_delta only emits d/w/m"

(** Parse [":<n>"] suffix. Returns [(rest_before_colon, n)] or [Error]. *)
let _split_n s =
  match String.lsplit2 s ~on:':' with
  | None -> _err (sprintf "fuzz spec: missing :n count after delta in %S" s)
  | Some (rest, n_str) -> (
      match Int.of_string_opt n_str with
      | Some n when n >= 1 -> Ok (rest, n)
      | Some _ -> _err "fuzz spec: n count must be >= 1"
      | None -> _err (sprintf "fuzz spec: n count %S is not an integer" n_str))

(** Format a float to a stable label string with three decimals. Three is enough
    to keep adjacent variants legibly distinct for typical fuzz step sizes (e.g.
    a one-part-per-thousand step). *)
let _float_label f = sprintf "%.3f" f

(** Generate N evenly-spaced floats from [center - delta] to [center + delta]
    (inclusive). N=1 returns just [center]; N>=2 returns endpoints exact. *)
let _linspace ~center ~delta ~n =
  if n = 1 then [ center ]
  else
    let step = 2.0 *. delta /. Float.of_int (n - 1) in
    List.init n ~f:(fun i -> center -. delta +. (Float.of_int i *. step))

let _build_float_variants ~key_path ~center ~delta ~n =
  let values = _linspace ~center ~delta ~n in
  List.mapi values ~f:(fun i v ->
      { index = i + 1; label = _float_label v; key_path; value = V_float v })

(** Generate N integer day-offsets centred on zero, evenly spread across
    [-delta_days .. +delta_days] (rounded to nearest day). N=1 returns [[0]]. *)
let _date_offsets ~delta_days ~n =
  if n = 1 then [ 0 ]
  else
    let step = Float.of_int (2 * delta_days) /. Float.of_int (n - 1) in
    List.init n ~f:(fun i ->
        Float.iround_nearest_exn
          (Float.of_int (-delta_days) +. (Float.of_int i *. step)))

let _build_date_variants ~key_path ~center ~delta_days ~n =
  let offsets = _date_offsets ~delta_days ~n in
  List.mapi offsets ~f:(fun i offset ->
      let d = Date.add_days center offset in
      { index = i + 1; label = Date.to_string d; key_path; value = V_date d })

(** Error message for missing [±] / [+/-] separator. Pulled out so
    [_split_value_half] reads as a flat bind chain. *)
let _missing_pm_error ~spec =
  _err
    (sprintf "fuzz spec: missing '%s' or '%s' separator in value half of %S"
       _plus_minus_utf8 _plus_minus_ascii spec)

(** Pull the value-half (everything after [=]) apart into [(center, delta, n)]
    given the already-validated key path. *)
let _split_value_half ~spec rest =
  match _split_on_plus_minus rest with
  | None -> _missing_pm_error ~spec
  | Some (center_str, delta_and_n) ->
      Result.map (_split_n delta_and_n) ~f:(fun (delta_str, n) ->
          (center_str, delta_str, n))

(** Combine a key_path with a (center, delta, n) triple into the final 4-tuple
    consumed by [parse]. *)
let _combine_spec_parts key_path (center_str, delta_str, n) =
  (key_path, center_str, delta_str, n)

(** Resolve the value-half once a key has been validated. Pulled out so
    [_split_spec]'s outer match-arm body stays one-liner. *)
let _resolve_value_with_key ~spec key_path rest =
  Result.map (_split_value_half ~spec rest) ~f:(_combine_spec_parts key_path)

(** Split a spec into (key, value-half, n). *)
let _split_spec spec =
  match String.lsplit2 spec ~on:'=' with
  | None -> _err (sprintf "fuzz spec: missing '=' in %S" spec)
  | Some (key, rest) ->
      Result.bind (_validate_key_path key) ~f:(fun key_path ->
          _resolve_value_with_key ~spec key_path rest)

(** Validate a parsed float delta — must be non-negative. Pulled out so the
    caller branches stay flat. *)
let _validate_float_delta delta =
  if Float.(delta < 0.0) then
    _err "fuzz spec: numeric delta must be non-negative"
  else Ok delta

(** Resolve a (center_str, delta_str) pair under the assumption that the center
    is a float (i.e. date parsing already failed). *)
let _build_float_branch ~key_path ~center_str ~delta_str ~n =
  match (Float.of_string_opt center_str, Float.of_string_opt delta_str) with
  | None, _ ->
      _err
        (sprintf "fuzz spec: center %S is neither YYYY-MM-DD nor a number"
           center_str)
  | Some _, None ->
      _err
        (sprintf "fuzz spec: delta %S is not a number (numeric center)"
           delta_str)
  | Some center, Some delta ->
      Result.map (_validate_float_delta delta) ~f:(fun delta ->
          _build_float_variants ~key_path ~center ~delta ~n)

(** Resolve a (center_str, delta_str) pair under the assumption that the center
    is a date. *)
let _build_date_branch ~key_path ~center_date ~delta_str ~n =
  Result.map (_parse_date_delta delta_str) ~f:(fun (mag, unit_char) ->
      let delta_days = _days_of_date_delta mag unit_char in
      _build_date_variants ~key_path ~center:center_date ~delta_days ~n)

(** Resolve a (center_str, delta_str) pair to a fully-built variant list. Tries
    date parsing first; if that succeeds, the delta must be a Nd/Nw/Nm literal.
    If the center isn't a date, falls back to float parsing for both halves. *)
let _build_variants ~key_path ~center_str ~delta_str ~n =
  match _try_parse_date center_str with
  | Some center_date -> _build_date_branch ~key_path ~center_date ~delta_str ~n
  | None -> _build_float_branch ~key_path ~center_str ~delta_str ~n

let parse spec =
  let%bind.Result key_path, center_str, delta_str, n = _split_spec spec in
  let%bind.Result variants =
    _build_variants ~key_path ~center_str ~delta_str ~n
  in
  Ok { raw_spec = spec; key_path; n; variants }

let subdir_name ~n ~index =
  let width = String.length (Int.to_string n) in
  sprintf "var-%0*d" width index
