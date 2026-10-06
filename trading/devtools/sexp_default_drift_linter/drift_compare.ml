(* Constant resolution, record grouping, default comparison, reporting. *)

open Drift_parse
open Drift_util

(* name -> resolved literal text, built across every scanned .ml file. A
   name defined with two DIFFERENT literal values in different files is
   dropped from the table (unresolvable/ambiguous) rather than guessed at --
   the field then falls back to raw-text comparison for that occurrence. *)
let build_constant_table per_file_constants =
  let tbl = Hashtbl.create 256 in
  let ambiguous = Hashtbl.create 16 in
  List.iter
    (fun (name, text) ->
      match Hashtbl.find_opt tbl name with
      | None -> Hashtbl.replace tbl name text
      | Some existing ->
          if not (String.equal existing text) then
            Hashtbl.replace ambiguous name ())
    per_file_constants;
  Hashtbl.iter (fun name () -> Hashtbl.remove tbl name) ambiguous;
  tbl

let is_ident_char c =
  (c >= 'a' && c <= 'z')
  || (c >= 'A' && c <= 'Z')
  || (c >= '0' && c <= '9')
  || c = '_' || c = '.'

(* Token-substitute any atom (identifier / qualified-identifier run) that is
   a key in [table] with its resolved literal text, then collapse
   whitespace. This lets `[@sexp.default default_stale_exit_days]` and
   `[@sexp.default 5]` (where [default_stale_exit_days = 5]) compare equal. *)
let resolve_constants table text =
  let n = String.length text in
  let buf = Buffer.create n in
  let i = ref 0 in
  while !i < n do
    if is_ident_char text.[!i] then begin
      let j = ref !i in
      while !j < n && is_ident_char text.[!j] do
        incr j
      done;
      let atom = String.sub text !i (!j - !i) in
      (match Hashtbl.find_opt table atom with
      | Some resolved -> Buffer.add_string buf resolved
      | None -> Buffer.add_string buf atom);
      i := !j
    end
    else begin
      Buffer.add_char buf text.[!i];
      incr i
    end
  done;
  normalize_ws (Buffer.contents buf)

(* --- Grouping ---------------------------------------------------------------- *)

let group_key (r : record_decl) =
  r.type_name ^ "|" ^ String.concat "," (List.map (fun f -> f.fname) r.fields)

let group_records records =
  let tbl = Hashtbl.create 64 in
  List.iter
    (fun r ->
      let key = group_key r in
      let existing = Option.value (Hashtbl.find_opt tbl key) ~default:[] in
      Hashtbl.replace tbl key (r :: existing))
    records;
  Hashtbl.fold
    (fun _ decls acc ->
      let distinct_files =
        List.sort_uniq String.compare (List.map (fun r -> r.file) decls)
      in
      if List.length distinct_files > 1 then decls :: acc else acc)
    tbl []

(* --- Comparison ---------------------------------------------------------------- *)

type violation = {
  type_name : string;
  field_name : string;
  kind : [ `Presence | `Value ];
  entries : (string * string option) list;
      (* file, resolved (raw for presence) text *)
}

(* For a single field name, gather (file, resolved-default-text option)
   across every declaration in the group and decide whether they all agree. *)
(* A declaration that carries NO [@sexp.default ...] anywhere on this type is
   an "opted-out" copy -- most likely a module that deliberately keeps its
   .mli free of the (compiler-unchecked, purely decorative) attribute, not a
   forgotten update. Comparing an opted-out declaration's silence against an
   opted-in sibling's real default produces a flood of pre-existing,
   intentional-style false positives (measured: 19 of 20 hits on `main`
   before this filter, none a real bug). Only declarations that DO carry at
   least one real attribute on this type are compared against each other --
   that is the shape of the two confirmed bugs (#2384, #2388): the type is
   documented with defaults in more than one place, and one copy is stale.

   This filter is also what still excludes a genuinely partially-documented
   type from ever being compared -- e.g. [Liquidity_config.t]: a two-file,
   five-field record whose [.ml] carries 2 [@sexp.default] attributes and
   whose [.mli] carries 0. With only one opted-in declaration, [opted_in]
   never reaches 2 and the type is silently never checked. Measured across
   all 402 multi-file duplicate groups on the shipped tree with no
   group-size floor (2026-08-20 rework of PR #2430): 376 groups are 0
   opted-in (nothing to compare -- an intentional documentation style, see
   above), 19 are fully opted-in (>=2, actually compared), 1 has 3
   opted-in declarations, and **6 groups sit exactly at this blind spot**
   (opted_in = 1, silently unchecked -- [Liquidity_config.t] is one of the
   6). A type moving from 1 to 2 opted-in declarations (e.g. a future
   [.mli] documenting its own defaults) starts being checked with no code
   change required. *)
let has_any_default (r : record_decl) =
  List.exists (fun f -> f.default_text <> None) r.fields

let check_field table type_name fname (decls : record_decl list) =
  let opted_in = List.filter has_any_default decls in
  if List.length opted_in < 2 then None
  else
    let entries =
      List.filter_map
        (fun (r : record_decl) ->
          match
            List.find_opt (fun f -> String.equal f.fname fname) r.fields
          with
          | None ->
              None (* field-list equality is the grouping key; unreachable *)
          | Some f -> Some (r.file, f.default_text))
        opted_in
    in
    let presences =
      List.sort_uniq compare (List.map (fun (_, t) -> t = None) entries)
    in
    if List.length presences > 1 then
      Some { type_name; field_name = fname; kind = `Presence; entries }
    else
      let resolved =
        List.map
          (fun (f, t) -> (f, Option.map (resolve_constants table) t))
          entries
      in
      let values = List.sort_uniq compare (List.map snd resolved) in
      if List.length values > 1 then
        Some
          { type_name; field_name = fname; kind = `Value; entries = resolved }
      else None

let check_group table decls =
  match decls with
  | [] -> []
  | (first : record_decl) :: _ ->
      List.filter_map
        (fun f -> check_field table first.type_name f.fname decls)
        first.fields

(* --- Reporting ---------------------------------------------------------------- *)

let exception_key v = v.type_name ^ "." ^ v.field_name

let format_violation v =
  let kind_desc =
    match v.kind with
    | `Presence -> "attribute present in some declarations, absent in others"
    | `Value -> "attribute value differs across declarations"
  in
  let lines =
    List.map
      (fun (file, text) ->
        Printf.sprintf "      %s: %s" file
          (match text with
          | Some t -> Printf.sprintf "[@sexp.default %s]" t
          | None -> "(no [@sexp.default])"))
      v.entries
  in
  Printf.sprintf "  %s (%s) -- %s\n%s" (exception_key v) v.type_name kind_desc
    (String.concat "\n" lines)
