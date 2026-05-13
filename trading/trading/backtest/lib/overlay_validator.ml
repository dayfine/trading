open Core

let _is_record fields =
  List.for_all fields ~f:(function
    | Sexp.List [ Sexp.Atom _; _ ] -> true
    | _ -> false)

let _record_field_pairs fields =
  List.filter_map fields ~f:(function
    | Sexp.List [ Sexp.Atom k; v ] -> Some (k, v)
    | _ -> None)

(** Deep-merge [overlay] into [base], collecting any overlay key that does not
    resolve to a real field in [base]. The walk only treats both nodes as
    "records" when each is a list of [(atom, value)] pairs ([_is_record]); any
    other shape is overlay-wins (legacy behaviour preserved at leaves).

    [path] is the dot-path from the root used only to build human-readable error
    messages when an unknown key is found. The caller seeds it with [[]] and
    each recursive step prepends the parent field name.

    Returns [(merged_sexp, unknown_paths)] where [unknown_paths] is the list of
    dot-paths the overlay attempted to set that have no match in [base]. The
    PR-#1051 bug was exactly this: overlays keyed on
    [screening_config.weights.rs] (no such field — the real names are
    [w_positive_rs] etc.) were silently dropped, so an 81-cell sweep produced
    bit-identical metrics. [apply_overrides] raises on a non-empty
    [unknown_paths] list to surface this loudly. *)
let rec _merge_sexp ~path base overlay =
  match (base, overlay) with
  | Sexp.List base_fields, Sexp.List overlay_fields
    when _is_record base_fields && _is_record overlay_fields ->
      _merge_records ~path base_fields overlay_fields
  | _, _ -> (overlay, [])

and _merge_records ~path base_fields overlay_fields =
  let base_keys =
    _record_field_pairs base_fields |> List.map ~f:fst |> String.Set.of_list
  in
  let overlay_pairs = _record_field_pairs overlay_fields in
  let unknown_at_this_level =
    List.filter_map overlay_pairs ~f:(fun (k, _) ->
        if Set.mem base_keys k then None
        else Some (String.concat ~sep:"." (List.rev (k :: path))))
  in
  let overlay_map = String.Map.of_alist_exn overlay_pairs in
  let nested_unknowns, merged_pairs =
    List.fold_map base_fields ~init:[] ~f:(_merge_one_field ~path ~overlay_map)
  in
  (Sexp.List merged_pairs, unknown_at_this_level @ nested_unknowns)

and _merge_field_with_overlay ~path ~k ~base_v ~overlay_v ~acc =
  let merged_v, sub_unknowns = _merge_sexp ~path:(k :: path) base_v overlay_v in
  (sub_unknowns @ acc, Sexp.List [ Sexp.Atom k; merged_v ])

and _merge_one_field ~path ~overlay_map acc field =
  match field with
  | Sexp.List [ Sexp.Atom k; base_v ] -> (
      match Map.find overlay_map k with
      | Some overlay_v ->
          _merge_field_with_overlay ~path ~k ~base_v ~overlay_v ~acc
      | None -> (acc, field))
  | other -> (acc, other)

(** Format an unknown-key error message for human-readable output. The
    [overlay_idx] is the position in the [overrides] list (0-based) so operators
    can tell which [--override] flag is the culprit. *)
let _format_unknown_keys_error ~overlay_idx ~unknowns ~overlay_sexp =
  let bullets =
    List.map unknowns ~f:(fun p -> Printf.sprintf "  - %s" p)
    |> String.concat ~sep:"\n"
  in
  Printf.sprintf
    "Runner overlay #%d contains key(s) that do not resolve to any field on \
     the base [Weinstein_strategy.config] record:\n\
     %s\n\
     Offending overlay sexp:\n\
     %s\n\
     This is fatal — the previous behaviour silently dropped the unknown keys, \
     so e.g. a sweep over a misspelled path produced bit-identical metrics \
     across every cell. Fix the key path (consult \
     [Weinstein_strategy.sexp_of_config] / [Screener.config] for valid field \
     names) and re-run."
    overlay_idx bullets
    (Sexp.to_string_hum overlay_sexp)

let _raise_if_unknowns ~overlay_idx ~overlay_sexp = function
  | [] -> ()
  | unknowns ->
      failwith (_format_unknown_keys_error ~overlay_idx ~unknowns ~overlay_sexp)

let _merge_one_overlay i acc_sexp overlay =
  let merged_sexp, unknowns = _merge_sexp ~path:[] acc_sexp overlay in
  _raise_if_unknowns ~overlay_idx:i ~overlay_sexp:overlay unknowns;
  merged_sexp

let apply_overrides (config : Weinstein_strategy.config) overrides =
  match overrides with
  | [] -> config
  | _ ->
      let base = Weinstein_strategy.sexp_of_config config in
      let merged = List.foldi overrides ~init:base ~f:_merge_one_overlay in
      Weinstein_strategy.config_of_sexp merged
