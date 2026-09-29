open Sexplib

type unit_guard = { file : string; test : string }

type guard =
  | No_guard
  | Guards of { units : unit_guard list; validators : string list }

type t = {
  issue : int option;
  ref_ : string option;
  finding : string;
  guard : guard;
  reason : string option;
  status : string;
}

let statuses =
  [ "open"; "fixed"; "fixed-behind-flag"; "wontfix"; "observation" ]

let kind t =
  match t.guard with
  | No_guard -> "none"
  | Guards { units = []; _ } -> "validator"
  | Guards { validators = []; _ } -> "unit"
  | Guards _ -> "both"

let label t =
  match (t.issue, t.ref_) with
  | Some n, _ -> Printf.sprintf "#%d" n
  | None, Some r -> r
  | None, None -> "<unlabelled>"

(* ---- parsing ---- *)

let _err fmt = Printf.ksprintf (fun s -> Error s) fmt

let _parse_guard_entry (acc_u, acc_v) = function
  | Sexp.List [ Atom "unit"; List [ Atom file; Atom test ] ] ->
      Ok ({ file; test } :: acc_u, acc_v)
  | List [ Atom "validator"; Atom id ] -> Ok (acc_u, id :: acc_v)
  | s -> _err "bad guard entry %s" (Sexp.to_string s)

let _parse_guard = function
  | Sexp.Atom "none" -> Ok No_guard
  | List [] -> _err "empty guard list (use the atom none)"
  | List entries ->
      let step acc e = Result.bind acc (fun a -> _parse_guard_entry a e) in
      Result.map
        (fun (u, v) -> Guards { units = List.rev u; validators = List.rev v })
        (List.fold_left step (Ok ([], [])) entries)
  | s -> _err "bad guard %s" (Sexp.to_string s)

let _pair = function
  | Sexp.List [ Atom k; v ] -> Ok (k, v)
  | s -> _err "bad field %s" (Sexp.to_string s)

let _cons_pair acc kv =
  Result.bind acc (fun l -> Result.map (fun p -> p :: l) (_pair kv))

let _fields_of = function
  | Sexp.List kvs -> List.fold_left _cons_pair (Ok []) kvs
  | s -> _err "row is not a list: %s" (Sexp.to_string s)

let _known = [ "issue"; "ref"; "finding"; "guard"; "reason"; "status" ]

let _unknown_key fields =
  List.find_opt (fun (k, _) -> not (List.mem k _known)) fields

let _string_field fields key =
  match List.assoc_opt key fields with
  | None -> Ok None
  | Some (Sexp.Atom s) -> Ok (Some s)
  | Some _ -> _err "field %s must be a string" key

let _issue_field fields =
  match List.assoc_opt "issue" fields with
  | None -> Ok None
  | Some (Sexp.Atom s) -> (
      match int_of_string_opt s with
      | Some n -> Ok (Some n)
      | None -> _err "issue %s is not an integer" s)
  | Some _ -> _err "issue must be an integer"

let _required = function
  | Some (s : string) when String.trim s <> "" -> Ok s
  | _ -> Error "missing or empty required field"

let _build fields =
  let ( let* ) = Result.bind in
  let* issue = _issue_field fields in
  let* ref_ = _string_field fields "ref" in
  let* finding = _string_field fields "finding" in
  let* finding =
    Result.map_error (fun e -> "finding: " ^ e) (_required finding)
  in
  let* reason = _string_field fields "reason" in
  let* status = _string_field fields "status" in
  let* status = Result.map_error (fun e -> "status: " ^ e) (_required status) in
  let* guard =
    match List.assoc_opt "guard" fields with
    | None -> Error "missing guard"
    | Some g -> _parse_guard g
  in
  Ok { issue; ref_; finding; guard; reason; status }

let _semantic_errors t =
  let bad_status =
    if List.mem t.status statuses then []
    else
      [
        Printf.sprintf "unknown status %S (allowed: %s)" t.status
          (String.concat " " statuses);
      ]
  in
  let no_id =
    if t.issue = None && t.ref_ = None then [ "row needs an issue or a ref" ]
    else []
  in
  let no_reason =
    match (t.guard, t.reason) with
    | No_guard, (None | Some "") -> [ "guard none requires a non-empty reason" ]
    | _ -> []
  in
  bad_status @ no_id @ no_reason

let _parse_row sexp =
  let ( let* ) = Result.bind in
  let* fields = _fields_of sexp in
  match _unknown_key fields with
  | Some (k, _) -> _err "unknown key %s" k
  | None -> _build fields

let _add_row (rows, errs) sexp =
  match _parse_row sexp with
  | Error e -> (rows, Printf.sprintf "malformed row: %s" e :: errs)
  | Ok t ->
      let fmt e = Printf.sprintf "%s: %s" (label t) e in
      (t :: rows, List.rev_append (List.map fmt (_semantic_errors t)) errs)

let parse sexps =
  let rows, errs = List.fold_left _add_row ([], []) sexps in
  (List.rev rows, List.rev errs)

(* ---- existence checks ---- *)

let contains ~haystack ~needle =
  let n = String.length needle and h = String.length haystack in
  let rec go i =
    i + n <= h && (String.sub haystack i n = needle || go (i + 1))
  in
  n = 0 || go 0

let _digits_end s i =
  let n = String.length s in
  let rec go j =
    if j < n && s.[j] >= '0' && s.[j] <= '9' then go (j + 1) else j
  in
  go i

(* Match [("V<digits>",] at position [i]; return the id and next index. *)
let _validator_at s i =
  let n = String.length s in
  if i + 4 < n && String.sub s i 3 = "(\"V" then
    let j = _digits_end s (i + 3) in
    if j > i + 3 && j + 1 < n && s.[j] = '"' && s.[j + 1] = ',' then
      Some (String.sub s (i + 2) (j - i - 2))
    else None
  else None

let registered_validators source =
  let n = String.length source in
  let rec go i acc =
    if i >= n then List.rev acc
    else
      match _validator_at source i with
      | Some id -> go (i + 1) (id :: acc)
      | None -> go (i + 1) acc
  in
  go 0 []

let _check_unit ~read_file (t : t) (u : unit_guard) =
  match read_file u.file with
  | None ->
      [ Printf.sprintf "%s: unit guard file missing: %s" (label t) u.file ]
  | Some text when contains ~haystack:text ~needle:u.test -> []
  | Some _ ->
      [
        Printf.sprintf "%s: test name %S not found in %s" (label t) u.test
          u.file;
      ]

let _check_validator ~validators t id =
  if List.mem id validators then []
  else
    [
      Printf.sprintf "%s: validator %s is not registered in validator_checks.ml"
        (label t) id;
    ]

let check_rows ~validators ~read_file rows =
  let one t =
    match t.guard with
    | No_guard -> []
    | Guards { units; validators = vs } ->
        List.concat_map (_check_unit ~read_file t) units
        @ List.concat_map (_check_validator ~validators t) vs
  in
  List.concat_map one rows
