open Core

type t = {
  base_scenario : string;
  window_spec : Window_spec.t;
  variants : Walk_forward_runner.variant list;
  baseline_label : string;
  gate : Fold_gate.t;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]

(* Raw on-disk shape. [variants] is optional (empty when only [axes] is given);
   [axes] is the optional matrix-declaration block (plan Gap A). The public {!t}
   carries only the *resolved* variant list — [axes] is a parse-time concern
   that {!load} expands away, so the constructor surface and all downstream
   consumers stay unchanged. *)
type _raw = {
  base_scenario : string;
  window_spec : Window_spec.t;
  variants : Walk_forward_runner.variant list; [@sexp.default []]
  baseline_label : string;
  gate : Fold_gate.t;
  axes : Variant_matrix.t option; [@sexp.option]
}
[@@deriving of_sexp] [@@sexp.allow_extra_fields]

(* The auto-included baseline cell: all-default / empty-override, labelled from
   [baseline_label]. Prepended ahead of the expanded matrix so every axes-driven
   run carries its own reference point (plan Gap A: "Baseline = the all-default
   / empty-override cell, auto-included"). *)
let _baseline_variant ~baseline_label : Walk_forward_runner.variant =
  { label = baseline_label; overrides = [] }

(* De-dup by label; raise on collision so a typo or an overlapping
   explicit/matrix label fails loudly rather than silently dropping a cell. *)
let _check_unique_labels (variants : Walk_forward_runner.variant list) =
  let seen = String.Hash_set.create () in
  List.iter variants ~f:(fun v ->
      if Hash_set.mem seen v.label then
        failwithf "Spec: duplicate variant label %S" v.label ()
      else Hash_set.add seen v.label)

(* Resolve the raw record into the public {!t}. When [axes] is present, the
   final list is: explicit variants (if any), then the auto-baseline, then the
   expanded matrix. When [axes] is absent, the variants pass through unchanged
   (100% backward-compatible with the hand-written-variants path). *)
let _resolve (raw : _raw) : t =
  let variants =
    match raw.axes with
    | None -> raw.variants
    | Some axes ->
        raw.variants
        @ [ _baseline_variant ~baseline_label:raw.baseline_label ]
        @ Variant_matrix.expand axes
  in
  _check_unique_labels variants;
  {
    base_scenario = raw.base_scenario;
    window_spec = raw.window_spec;
    variants;
    baseline_label = raw.baseline_label;
    gate = raw.gate;
  }

let load path : t = _resolve (_raw_of_sexp (Sexp.load_sexp path))
