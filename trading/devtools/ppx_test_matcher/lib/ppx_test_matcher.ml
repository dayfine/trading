open Ppxlib

(** [ppx_test_matcher] — a deriving plugin that generates exhaustive record
    matchers for test assertions.

    Given a record type:
    {[
    type t = { x : float; y : int } [@@deriving test_matcher]
    ]}

    It generates a function [match_t] with one required labeled parameter per
    field:
    {[
    let match_t ~x ~y (r : t) =
      x r.x;
      y r.y
    ]}

    Every field must be explicitly matched or ignored with [__] (the wildcard
    matcher from [Matchers]). If a field is added to the record, all call sites
    get a compiler error until they handle it. *)

(** Build one required labeled parameter: [~field_name] *)
let _make_field_param ~loc (ld : label_declaration) =
  let field_name = ld.pld_name.txt in
  let pat = Ast_builder.Default.ppat_var ~loc { txt = field_name; loc } in
  Ast_builder.Default.pexp_fun ~loc (Labelled field_name) None pat

(** Build a field assertion expression: [field_name r.field_name] *)
let _make_field_assert ~loc ~record_var (ld : label_declaration) =
  let field_name = ld.pld_name.txt in
  let field_access =
    Ast_builder.Default.pexp_field ~loc
      (Ast_builder.Default.pexp_ident ~loc { txt = Lident record_var; loc })
      { txt = Lident field_name; loc }
  in
  Ast_builder.Default.pexp_apply ~loc
    (Ast_builder.Default.pexp_ident ~loc { txt = Lident field_name; loc })
    [ (Nolabel, field_access) ]

(** Generate the matcher function for a record type declaration. *)
let _generate_matcher ~loc ~type_name ~record_var
    (fields : label_declaration list) =
  (* Body: sequence of field assertions *)
  let body =
    match fields with
    | [] -> [%expr ()]
    | [ single ] -> _make_field_assert ~loc ~record_var single
    | first :: rest ->
        List.fold_left
          (fun acc ld ->
            Ast_builder.Default.pexp_sequence ~loc acc
              (_make_field_assert ~loc ~record_var ld))
          (_make_field_assert ~loc ~record_var first)
          rest
  in
  (* Wrap body with the record parameter: fun (r : type_name) -> body *)
  let record_pat =
    Ast_builder.Default.ppat_constraint ~loc
      (Ast_builder.Default.ppat_var ~loc { txt = record_var; loc })
      (Ast_builder.Default.ptyp_constr ~loc { txt = Lident type_name; loc } [])
  in
  let with_record_param =
    Ast_builder.Default.pexp_fun ~loc Nolabel None record_pat body
  in
  (* Wrap with required labeled parameters for each field (in reverse so
     first field is outermost) *)
  List.fold_right
    (fun (ld : label_declaration) acc -> _make_field_param ~loc ld acc)
    fields with_record_param

let generate_impl ~ctxt (_rec_flag, type_declarations) =
  let loc = Expansion_context.Deriver.derived_item_loc ctxt in
  List.concat_map
    (fun (td : type_declaration) ->
      match td.ptype_kind with
      | Ptype_record fields ->
          let type_name = td.ptype_name.txt in
          let fn_name = "match_" ^ type_name in
          let record_var = "r__" in
          let expr = _generate_matcher ~loc ~type_name ~record_var fields in
          let pat = Ast_builder.Default.ppat_var ~loc { txt = fn_name; loc } in
          [
            Ast_builder.Default.pstr_value ~loc Nonrecursive
              [ Ast_builder.Default.value_binding ~loc ~pat ~expr ];
          ]
      | _ ->
          Location.raise_errorf ~loc
            "[@@deriving test_matcher] only works on record types")
    type_declarations

let impl_generator = Deriving.Generator.V2.make_noarg generate_impl
let _deriver = Deriving.add "test_matcher" ~str_type_decl:impl_generator
