(* Sexp-default drift linter: catches a record type that is declared more
   than once (an .mli redeclaring another module's record via [include], or
   the ordinary .ml/.mli pair) where the SAME field carries a DIFFERENT
   [@sexp.default ...] attribute across the declarations.

   Why this needs its own check: [@sexp.default e] attributes do not
   participate in OCaml signature matching. Two record type declarations can
   be structurally identical (same field names/types/order -- required for
   the build to typecheck) while disagreeing on what a field's attribute
   says its default is. The compiler is silent; only the reader who happens
   to compare both copies by eye catches it. This bit the repo twice:
   entry_order_max_rest_weeks (#2384, promoted 0->26 in the .ml, .mli left
   at 0) and stale_exit_after_days (#2388, .mli says [@sexp.default None],
   the other two copies say [@sexp.default Some default_stale_exit_days]).

   Usage: sexp_default_drift_linter <trading-root> [<exceptions-conf>]

   Scans all lib/*.ml and lib/*.mli files under <trading-root>. For each
   record type declaration (Ptype_record) found, groups declarations by
   (type name, ordered field-name list) -- this pair is exactly what the
   compiler already forces to be identical whenever two declarations are
   linked by [include] + independent redeclaration, or by a module's own
   .ml/.mli pair. A group with more than one declaring file is therefore a
   *bona fide* duplicate of one logical record, not a coincidence.

   No group-size floor is applied (a prior revision filtered out groups
   below 6 fields; removed 2026-08-20 rework of PR #2430). Measured on the
   shipped tree: of 909 record declarations, a 6-field floor silently
   dropped 614 (67.5%) before grouping and cut multi-file duplicate-group
   coverage from 402 groups (no floor) to 134 (floor 6) -- yet running with
   no floor at all produces the SAME zero live findings as the floor did,
   because the (type_name, field-list) grouping key plus the opted-in
   filter below are already what makes a match non-coincidental: a false
   positive would require two UNRELATED types to share an exact type name,
   an exact ordered field-name list, [@sexp.default] on the same field in
   both, AND different literal values -- and even then it is a one-line
   [linter_exceptions.conf] entry, not a correctness bug. A field-count
   floor bought no precision and cost most of the check's coverage; see
   dev/status/harness.md's H-SEXP-DEFAULT-DRIFT-LINTER entry for the fuller
   writeup.

   For each field in such a group, compares the [@sexp.default ...]
   attribute payload (its source text) across all declaring files, after:
     - collapsing whitespace runs (so multi-line vs single-line attributes
       compare equal), and
     - resolving simple top-level [let name = <literal>] constants defined
       in any scanned .ml file, so `[@sexp.default 5]` and
       `[@sexp.default default_stale_exit_days]` (where
       [let default_stale_exit_days = 5]) compare EQUAL rather than
       producing a textual false positive.
   A field missing the attribute in one declaration but carrying one in
   another is also a mismatch (the #2384 shape if the attribute had been
   dropped rather than changed, per the task write-up).

   A group/field pair may be exempted via a
   "sexp_default_drift <type_name>.<field_name> <reason>  # review_at: ..."
   line in the exceptions conf (same file/format as the other linters'
   sections; see linter_exceptions.conf header). *)

open Parsetree

(* --- Utility -------------------------------------------------------------- *)

let contains_substring s sub =
  let n = String.length s and m = String.length sub in
  if m > n then false
  else
    let found = ref false in
    let i = ref 0 in
    while (not !found) && !i + m <= n do
      if String.sub s !i m = sub then found := true;
      incr i
    done;
    !found

(* Collapse any run of whitespace to a single space and trim ends, so
   formatting differences (line breaks, extra indentation) between two
   copies of the same attribute don't register as a mismatch. *)
let normalize_ws s =
  let buf = Buffer.create (String.length s) in
  let in_ws = ref false in
  String.iter
    (fun c ->
      match c with
      | ' ' | '\t' | '\n' | '\r' ->
          if not !in_ws then Buffer.add_char buf ' ';
          in_ws := true
      | c ->
          Buffer.add_char buf c;
          in_ws := false)
    s;
  String.trim (Buffer.contents buf)

(* --- Exceptions conf -------------------------------------------------------- *)

let read_exceptions conf_path =
  match open_in conf_path with
  | exception Sys_error _ -> []
  | ic ->
      let result = ref [] in
      (try
         while true do
           let line = input_line ic in
           let t = String.trim line in
           if String.length t = 0 || t.[0] = '#' then ()
           else
             match
               List.filter
                 (fun s -> String.length s > 0)
                 (String.split_on_char ' ' t)
             with
             | linter :: key :: _ when String.equal linter "sexp_default_drift"
               ->
                 result := key :: !result
             | _ -> ()
         done
       with End_of_file -> ());
      close_in ic;
      !result

(* --- File collection -------------------------------------------------------- *)

let is_excluded_dir entry =
  String.equal entry "_build"
  || String.equal entry "ta_ocaml"
  || String.equal entry ".claude"

(* [lib/*.ml] and [lib/*.mli] under [root] -- exactly the surface every
   known instance of this defect class lives on (record types with
   [@@deriving sexp] and .mli companions), and matches the scope other
   dune-wired structural linters in this repo use (linter_file_length.sh,
   linter_mli_coverage.sh). *)
let collect_lib_files root =
  let result = ref [] in
  let rec walk dir =
    match Sys.readdir dir with
    | exception _ -> ()
    | entries ->
        Array.iter
          (fun entry ->
            if is_excluded_dir entry then ()
            else
              let path = Filename.concat dir entry in
              if Sys.is_directory path then walk path
              else if
                String.equal (Filename.basename dir) "lib"
                && (Filename.check_suffix path ".ml"
                   || Filename.check_suffix path ".mli")
                && not (Filename.check_suffix path ".pp.ml")
              then result := path :: !result)
          entries
  in
  walk root;
  !result

let read_file path =
  let ic = open_in path in
  let content = really_input_string ic (in_channel_length ic) in
  close_in ic;
  content

(* --- AST extraction ---------------------------------------------------------- *)

(* field name -> raw (unnormalized) source text of its [@sexp.default e],
   or [None] if the field carries no such attribute. *)
type field = { fname : string; default_text : string option }
type record_decl = { file : string; type_name : string; fields : field list }

let slice content (loc : Location.t) =
  let a = loc.Location.loc_start.Lexing.pos_cnum
  and b = loc.Location.loc_end.Lexing.pos_cnum in
  if a >= 0 && b <= String.length content && a <= b then
    Some (String.sub content a (b - a))
  else None

let sexp_default_text content (attrs : attribute list) =
  List.find_map
    (fun (attr : attribute) ->
      if String.equal attr.attr_name.txt "sexp.default" then
        match attr.attr_payload with
        | PStr [ { pstr_desc = Pstr_eval (expr, _); _ } ] ->
            slice content expr.pexp_loc
        | _ -> None
      else None)
    attrs

let field_of_label_decl content (ld : label_declaration) =
  {
    fname = ld.pld_name.txt;
    default_text = sexp_default_text content ld.pld_attributes;
  }

let record_of_type_decl file content (td : type_declaration) =
  match td.ptype_kind with
  | Ptype_record ldecls ->
      Some
        {
          file;
          type_name = td.ptype_name.txt;
          fields = List.map (field_of_label_decl content) ldecls;
        }
  | _ -> None

(* Simple top-level [let name = <literal>] bindings -- the only shape of
   constant this check resolves. Anything else (function application,
   multi-arg let, qualified names) is left unresolved and compared as raw
   text: a conservative choice that risks a rare false positive over ever
   silently hiding a real mismatch. *)
let is_literal expr =
  match expr.pexp_desc with Pexp_constant _ -> true | _ -> false

let constant_of_value_binding content (vb : value_binding) =
  match (vb.pvb_pat.ppat_desc, is_literal vb.pvb_expr) with
  | Ppat_var { txt = name; _ }, true ->
      Option.map
        (fun text -> (name, normalize_ws text))
        (slice content vb.pvb_expr.pexp_loc)
  | _ -> None

let constants_of_structure content structure =
  List.concat_map
    (fun item ->
      match item.pstr_desc with
      | Pstr_value (_, bindings) ->
          List.filter_map (constant_of_value_binding content) bindings
      | _ -> [])
    structure

let records_of_structure file content structure =
  List.concat_map
    (fun item ->
      match item.pstr_desc with
      | Pstr_type (_, tds) ->
          List.filter_map (record_of_type_decl file content) tds
      | _ -> [])
    structure

let records_of_signature file content signature =
  List.concat_map
    (fun item ->
      match item.psig_desc with
      | Psig_type (_, tds) ->
          List.filter_map (record_of_type_decl file content) tds
      | _ -> [])
    signature

(* --- Per-file parsing ---------------------------------------------------------- *)

let parse_ml path =
  let content = read_file path in
  let lexbuf = Lexing.from_string content in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with Lexing.pos_fname = path };
  match Parse.implementation lexbuf with
  | structure ->
      ( records_of_structure path content structure,
        constants_of_structure content structure )
  | exception _ -> ([], [])

let parse_mli path =
  let content = read_file path in
  let lexbuf = Lexing.from_string content in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with Lexing.pos_fname = path };
  match Parse.interface lexbuf with
  | signature -> (records_of_signature path content signature, [])
  | exception _ -> ([], [])

let parse_file path =
  if Filename.check_suffix path ".mli" then parse_mli path else parse_ml path

(* --- Constant resolution + normalization ---------------------------------------- *)

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

(* --- Main ---------------------------------------------------------------------- *)

let () =
  let trading_root =
    if Array.length Sys.argv > 1 then Sys.argv.(1)
    else begin
      Printf.eprintf
        "Usage: sexp_default_drift_linter <trading-root> [<exceptions-conf>]\n";
      exit 2
    end
  in
  let exceptions =
    if Array.length Sys.argv > 2 then read_exceptions Sys.argv.(2) else []
  in
  let files = List.sort String.compare (collect_lib_files trading_root) in
  let parsed = List.map (fun f -> (f, parse_file f)) files in
  let records = List.concat_map (fun (_, (recs, _)) -> recs) parsed in
  let constants = List.concat_map (fun (_, (_, consts)) -> consts) parsed in
  let table = build_constant_table constants in
  let groups = group_records records in
  let all_violations = List.concat_map (check_group table) groups in
  let live_violations =
    List.filter
      (fun v -> not (List.mem (exception_key v) exceptions))
      all_violations
  in
  if live_violations = [] then
    print_endline
      "OK: no sexp.default drift across duplicated record declarations."
  else begin
    Printf.printf
      "FAIL: sexp_default_drift linter -- %d field(s) with a [@sexp.default \
       ...] mismatch across duplicate record declarations:\n\n"
      (List.length live_violations);
    List.iter (fun v -> print_endline (format_violation v)) live_violations;
    Printf.printf
      "\n\
       Fix by making every declaration agree on the same default (do not just \
       add a linter_exceptions.conf entry). If this is a pre-existing \
       divergence too risky to fix in this change (a behaviour-changing \
       default flip -- see .claude/rules/experiment-flag-discipline.md R1), \
       add a\n\
      \  sexp_default_drift <type>.<field> <reason>  # review_at: <trigger>\n\
       line to devtools/checks/linter_exceptions.conf instead, with a real \
       tracked follow-up.\n";
    exit 1
  end
