open Core

let perturbation_pcts = [ -0.10; -0.05; 0.05; 0.10 ]

type perturbation = {
  knob : string;
  pct : float;
  perturbed_value : float;
  clipped : bool;
  parameters : (string * float) list;
}
[@@deriving sexp, show, eq]

type scored_row = {
  knob : string;
  pct : float;
  perturbed_value : float;
  clipped : bool;
  score : float;
  delta_vs_best : float;
  sensitive : bool;
}
[@@deriving sexp, show, eq]

type report = {
  candidate_label_prefix : string;
  baseline_label : string;
  best_iteration_index : int;
  best_score : float;
  baseline_score : float;
  rows : scored_row list;
}
[@@deriving sexp, show, eq]

(** Fraction of the best cell's improvement-over-baseline below which a
    perturbed score qualifies as "sensitive". Pinned at half (per the spec): a
    knob is sensitive when a ±5% / ±10% jitter wipes out at least half the BO's
    discovered improvement. *)
let _sensitivity_drop_fraction = 0.5

let sensitivity_threshold ~best_score ~baseline_score =
  if Float.(best_score > baseline_score) then
    Some
      (best_score
      -. (_sensitivity_drop_fraction *. (best_score -. baseline_score)))
  else None

(* ---------- perturbation generation ---------- *)

let _clip ~lo ~hi v =
  if Float.(v < lo) then (lo, true)
  else if Float.(v > hi) then (hi, true)
  else (v, false)

let _replace_knob ~knob ~new_value (params : (string * float) list) :
    (string * float) list =
  List.map params ~f:(fun (k, v) ->
      if String.equal k knob then (k, new_value) else (k, v))

let _perturbations_for_knob ~knob ~best_value ~bounds_for_knob ~best_params :
    perturbation list =
  let lo, hi = bounds_for_knob in
  List.map perturbation_pcts ~f:(fun pct ->
      let raw = best_value *. (1.0 +. pct) in
      let perturbed_value, clipped = _clip ~lo ~hi raw in
      let parameters =
        _replace_knob ~knob ~new_value:perturbed_value best_params
      in
      { knob; pct; perturbed_value; clipped; parameters })

let generate_perturbations ~best_params ~bounds =
  let bounds_map = String.Map.of_alist_reduce bounds ~f:(fun a _ -> a) in
  List.concat_map best_params ~f:(fun (knob, best_value) ->
      match Map.find bounds_map knob with
      | None -> []
      | Some bounds_for_knob ->
          _perturbations_for_knob ~knob ~best_value ~bounds_for_knob
            ~best_params)

(* ---------- row assembly ---------- *)

let build_rows ~best_score ~baseline_score ~perturbations ~scores =
  if List.length perturbations <> List.length scores then
    invalid_arg
      (Printf.sprintf
         "Sensitivity_sweep.build_rows: length mismatch — %d perturbations vs \
          %d scores"
         (List.length perturbations)
         (List.length scores));
  let threshold = sensitivity_threshold ~best_score ~baseline_score in
  List.map2_exn perturbations scores ~f:(fun (p : perturbation) score ->
      let delta_vs_best = score -. best_score in
      let sensitive =
        match threshold with None -> false | Some t -> Float.(score < t)
      in
      {
        knob = p.knob;
        pct = p.pct;
        perturbed_value = p.perturbed_value;
        clipped = p.clipped;
        score;
        delta_vs_best;
        sensitive;
      })

(* ---------- markdown renderer ---------- *)

let _format_float f = if Float.is_nan f then "n/a" else sprintf "%.6f" f

let _format_signed f =
  if Float.is_nan f then "n/a"
  else if Float.(f >= 0.0) then sprintf "+%.6f" f
  else sprintf "%.6f" f

let _format_pct pct =
  if Float.(pct >= 0.0) then sprintf "+%.0f%%" (pct *. 100.0)
  else sprintf "%.0f%%" (pct *. 100.0)

let _clipped_label clipped = if clipped then "yes" else "no"
let _sensitive_label sensitive = if sensitive then "**yes**" else "no"

let _title_section ~checkpoint_path ~walk_forward_spec_path
    ~baseline_aggregate_path =
  sprintf
    "# Sensitivity-sweep report\n\n\
     Checkpoint: `%s`\n\n\
     Walk-forward spec: `%s`\n\n\
     Baseline aggregate: `%s`\n\n\
     Perturbations applied per knob (in order): %s.\n\n\
     A perturbation is flagged **sensitive** when its score drops by more than \
     %.0f%% of the best cell's improvement over baseline.\n\n"
    checkpoint_path walk_forward_spec_path baseline_aggregate_path
    (String.concat ~sep:", " (List.map perturbation_pcts ~f:_format_pct))
    (_sensitivity_drop_fraction *. 100.0)

let _summary_section r =
  let threshold =
    sensitivity_threshold ~best_score:r.best_score
      ~baseline_score:r.baseline_score
  in
  let threshold_str =
    match threshold with
    | Some t -> _format_float t
    | None ->
        "n/a (best_score did not exceed baseline_score; sensitivity not \
         classified)"
  in
  sprintf
    "## Summary\n\n\
     | Field | Value |\n\
     |---|---|\n\
     | Best iteration index (0-based) | %d |\n\
     | Best score (re-executed) | %s |\n\
     | Baseline score | %s |\n\
     | Sensitivity threshold (score below this is flagged) | %s |\n\
     | Candidate-label prefix | `%s` |\n\
     | Baseline-label | `%s` |\n\n"
    r.best_iteration_index
    (_format_float r.best_score)
    (_format_float r.baseline_score)
    threshold_str r.candidate_label_prefix r.baseline_label

let _row_md row =
  sprintf "| `%s` | %s | %s | %s | %s | %s | %s |\n" row.knob
    (_format_pct row.pct)
    (_format_float row.perturbed_value)
    (_clipped_label row.clipped)
    (_format_float row.score)
    (_format_signed row.delta_vs_best)
    (_sensitive_label row.sensitive)

let _per_perturbation_section r =
  let header =
    "## Per-perturbation results\n\n\
     | Knob | Pct | Perturbed value | Clipped to bound | Score | Δ vs best | \
     Sensitive |\n\
     |---|---|---|---|---|---|---|\n"
  in
  let body = String.concat (List.map r.rows ~f:_row_md) in
  header ^ body ^ "\n"

let _sensitive_summary_section r =
  let sensitive_rows = List.filter r.rows ~f:(fun row -> row.sensitive) in
  let sensitive_knobs =
    List.map sensitive_rows ~f:(fun row -> row.knob)
    |> List.dedup_and_sort ~compare:String.compare
  in
  match sensitive_knobs with
  | [] ->
      sprintf
        "## Sensitivity summary\n\n\
         No perturbations crossed the sensitivity threshold. The best cell's \
         knob configuration is robust to ±5%% / ±10%% jitter on the %d tested \
         knobs.\n"
        (List.dedup_and_sort ~compare:String.compare
           (List.map r.rows ~f:(fun row -> row.knob))
        |> List.length)
  | _ ->
      let knob_lines =
        List.map sensitive_knobs ~f:(fun k -> sprintf "- `%s`\n" k)
        |> String.concat
      in
      sprintf
        "## Sensitivity summary\n\n\
         %d sensitive perturbation(s) across %d knob(s):\n\n\
         %s\n"
        (List.length sensitive_rows)
        (List.length sensitive_knobs)
        knob_lines

let render_report r ~checkpoint_path ~walk_forward_spec_path
    ~baseline_aggregate_path =
  String.concat
    [
      _title_section ~checkpoint_path ~walk_forward_spec_path
        ~baseline_aggregate_path;
      _summary_section r;
      _per_perturbation_section r;
      _sensitive_summary_section r;
    ]
