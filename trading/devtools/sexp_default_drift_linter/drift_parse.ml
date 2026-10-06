(* Per-file parsing: record declarations and literal constants. *)

open Parsetree
open Drift_util
open Drift_scan

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

(* [parse_error = Some msg] means the file's records/constants were NOT
   collected -- this linter only ever parses source [ocamlc] has already
   accepted (every scanned file is a workspace .ml/.mli, so the build would
   have failed first if it were genuinely malformed), so a parse failure
   here means the linter's OWN parser (compiler-libs, pinned to a specific
   compiler version) is out of step with the toolchain actually building the
   tree -- not that the file is bad. See [_check_parse_failures]: this is
   reported loudly rather than silently dropped, because a live
   [@sexp.default] divergence inside an unparseable file would otherwise be
   invisible while the linter still reports OK. *)
type parse_outcome = {
  records : record_decl list;
  constants : (string * string) list;
  parse_error : string option;
}

let parse_ml path =
  let content = read_file path in
  let lexbuf = Lexing.from_string content in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with Lexing.pos_fname = path };
  match Parse.implementation lexbuf with
  | structure ->
      {
        records = records_of_structure path content structure;
        constants = constants_of_structure content structure;
        parse_error = None;
      }
  | exception exn ->
      {
        records = [];
        constants = [];
        parse_error = Some (Printexc.to_string exn);
      }

let parse_mli path =
  let content = read_file path in
  let lexbuf = Lexing.from_string content in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with Lexing.pos_fname = path };
  match Parse.interface lexbuf with
  | signature ->
      {
        records = records_of_signature path content signature;
        constants = [];
        parse_error = None;
      }
  | exception exn ->
      {
        records = [];
        constants = [];
        parse_error = Some (Printexc.to_string exn);
      }

let parse_file path =
  if Filename.check_suffix path ".mli" then parse_mli path else parse_ml path
