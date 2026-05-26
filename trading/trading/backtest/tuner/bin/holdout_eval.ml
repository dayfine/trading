open Core
module Wf_types = Walk_forward.Walk_forward_types

type verdict = Robust | Drops | Fails [@@deriving sexp, show, eq]

(** Threshold above which the verdict is {!Robust}. Pinned at one stdev of a
    typical per-fold Sharpe scale (~0.05). The prompt anchors this value so no
    env / config override is wired. *)
let robust_threshold = 0.05

let classify_verdict ~mean_paired_sharpe_delta =
  if Float.is_nan mean_paired_sharpe_delta then Fails
  else if Float.(mean_paired_sharpe_delta > robust_threshold) then Robust
  else if Float.(mean_paired_sharpe_delta >= 0.0) then Drops
  else Fails

type per_fold_row = {
  fold_name : string;
  candidate_sharpe : float;
  baseline_sharpe : float;
  delta_sharpe : float;
  candidate_max_drawdown_pct : float;
  baseline_max_drawdown_pct : float;
  delta_max_drawdown_pct : float;
}
[@@deriving sexp, show, eq]

type report = {
  candidate_label : string;
  baseline_label : string;
  holdout_folds : int list;
  best_iteration_index : int;
  best_iteration_score : float;
  rows : per_fold_row list;
  mean_paired_sharpe_delta : float;
  mean_paired_max_drawdown_delta : float;
  verdict : verdict;
}
[@@deriving sexp, show, eq]

(* ---------- pure helpers ---------- *)

let _filter_to_variant ~label (rows : Wf_types.fold_actual list) =
  List.filter rows ~f:(fun r -> String.equal r.variant_label label)

let _baseline_by_name (rows : Wf_types.fold_actual list) =
  List.map rows ~f:(fun r -> (r.fold_name, r))
  |> Map.of_alist_reduce (module String) ~f:(fun a _ -> a)

let pair_fold_actuals ~candidate_label ~baseline_label ~fold_actuals =
  let cand_rows = _filter_to_variant ~label:candidate_label fold_actuals in
  let base_rows = _filter_to_variant ~label:baseline_label fold_actuals in
  if List.is_empty cand_rows then
    failwithf "Holdout_eval.pair_fold_actuals: no rows for candidate %S"
      candidate_label ();
  if List.is_empty base_rows then
    failwithf "Holdout_eval.pair_fold_actuals: no rows for baseline %S"
      baseline_label ();
  let base_map = _baseline_by_name base_rows in
  let paired =
    List.filter_map cand_rows ~f:(fun cand ->
        match Map.find base_map cand.fold_name with
        | None -> None
        | Some base ->
            Some
              {
                fold_name = cand.fold_name;
                candidate_sharpe = cand.sharpe_ratio;
                baseline_sharpe = base.sharpe_ratio;
                delta_sharpe = cand.sharpe_ratio -. base.sharpe_ratio;
                candidate_max_drawdown_pct = cand.max_drawdown_pct;
                baseline_max_drawdown_pct = base.max_drawdown_pct;
                delta_max_drawdown_pct =
                  cand.max_drawdown_pct -. base.max_drawdown_pct;
              })
  in
  if List.is_empty paired then
    failwithf
      "Holdout_eval.pair_fold_actuals: no candidate fold_name matched baseline \
       (candidate %S has folds [%s]; baseline %S has folds [%s])"
      candidate_label
      (String.concat ~sep:"; " (List.map cand_rows ~f:(fun r -> r.fold_name)))
      baseline_label
      (String.concat ~sep:"; " (List.map base_rows ~f:(fun r -> r.fold_name)))
      ();
  paired

let _mean_or_nan xs =
  match xs with
  | [] -> Float.nan
  | _ -> List.fold xs ~init:0.0 ~f:( +. ) /. Float.of_int (List.length xs)

let build_report ~candidate_label ~baseline_label ~holdout_folds
    ~best_iteration_index ~best_iteration_score ~fold_actuals =
  let rows = pair_fold_actuals ~candidate_label ~baseline_label ~fold_actuals in
  let mean_paired_sharpe_delta =
    _mean_or_nan (List.map rows ~f:(fun r -> r.delta_sharpe))
  in
  let mean_paired_max_drawdown_delta =
    _mean_or_nan (List.map rows ~f:(fun r -> r.delta_max_drawdown_pct))
  in
  let verdict = classify_verdict ~mean_paired_sharpe_delta in
  {
    candidate_label;
    baseline_label;
    holdout_folds;
    best_iteration_index;
    best_iteration_score;
    rows;
    mean_paired_sharpe_delta;
    mean_paired_max_drawdown_delta;
    verdict;
  }

(* ---------- markdown renderer ---------- *)

let _verdict_label = function
  | Robust -> "ROBUST"
  | Drops -> "DROPS"
  | Fails -> "FAILS"

let _format_float f = if Float.is_nan f then "n/a" else sprintf "%.4f" f

let _format_signed f =
  if Float.is_nan f then "n/a"
  else if Float.(f >= 0.0) then sprintf "+%.4f" f
  else sprintf "%.4f" f

let _format_int_list xs = String.concat ~sep:" " (List.map xs ~f:Int.to_string)

let _title_section ~checkpoint_path ~walk_forward_spec_path
    ~baseline_aggregate_path =
  let baseline_line =
    match baseline_aggregate_path with
    | None -> ""
    | Some p -> sprintf "Baseline aggregate: `%s`\n\n" p
  in
  sprintf
    "# Holdout-fold evaluation report\n\n\
     Checkpoint: `%s`\n\n\
     Walk-forward spec: `%s`\n\n\
     %sVerdict thresholds: mean per-fold Sharpe Δ > %.2f → ROBUST; 0 to %.2f → \
     DROPS; < 0 → FAILS.\n\n"
    checkpoint_path walk_forward_spec_path baseline_line robust_threshold
    robust_threshold

let _candidate_section r =
  sprintf
    "## Candidate\n\n\
     Source: best observation in checkpoint at iter %d of the BO sweep.\n\n\
     BO score (in-sample, all folds): %s\n\n\
     Holdout fold positions (1-indexed): %s\n\n\
     Candidate variant label: `%s`\n\n\
     Baseline variant label: `%s`\n\n"
    r.best_iteration_index
    (_format_float r.best_iteration_score)
    (_format_int_list r.holdout_folds)
    r.candidate_label r.baseline_label

let _per_fold_row_md row =
  sprintf "| `%s` | %s | %s | %s | %s | %s | %s |\n" row.fold_name
    (_format_float row.candidate_sharpe)
    (_format_float row.baseline_sharpe)
    (_format_signed row.delta_sharpe)
    (_format_float row.candidate_max_drawdown_pct)
    (_format_float row.baseline_max_drawdown_pct)
    (_format_signed row.delta_max_drawdown_pct)

let _per_fold_section r =
  let header =
    "## Per-holdout-fold metrics\n\n\
     | Fold | Cand Sharpe | Base Sharpe | Δ Sharpe | Cand MaxDD% | Base MaxDD% \
     | Δ MaxDD% |\n\
     |---|---|---|---|---|---|---|\n"
  in
  let body = String.concat (List.map r.rows ~f:_per_fold_row_md) in
  header ^ body ^ "\n"

let _annotation_section ~baseline_all_fold_mean_sharpe
    ~baseline_all_fold_mean_max_drawdown_pct =
  match
    (baseline_all_fold_mean_sharpe, baseline_all_fold_mean_max_drawdown_pct)
  with
  | None, None -> ""
  | _, _ ->
      sprintf
        "## All-fold baseline annotation (informational)\n\n\
         | Metric | All-fold baseline mean (from --baseline-aggregate) |\n\
         |---|---|\n\
         | Sharpe | %s |\n\
         | MaxDD%% | %s |\n\n"
        (_format_float
           (Option.value baseline_all_fold_mean_sharpe ~default:Float.nan))
        (_format_float
           (Option.value baseline_all_fold_mean_max_drawdown_pct
              ~default:Float.nan))

let _verdict_section r =
  sprintf
    "## Verdict\n\n\
     **%s**\n\n\
     - Mean per-fold paired Sharpe Δ = %s (threshold %.2f)\n\
     - Mean per-fold paired MaxDD%% Δ = %s (lower is better)\n\
     - Holdout folds evaluated: %d\n"
    (_verdict_label r.verdict)
    (_format_signed r.mean_paired_sharpe_delta)
    robust_threshold
    (_format_signed r.mean_paired_max_drawdown_delta)
    (List.length r.rows)

let render_report r ~checkpoint_path ~walk_forward_spec_path
    ~baseline_aggregate_path ~baseline_all_fold_mean_sharpe
    ~baseline_all_fold_mean_max_drawdown_pct =
  String.concat
    [
      _title_section ~checkpoint_path ~walk_forward_spec_path
        ~baseline_aggregate_path;
      _candidate_section r;
      _per_fold_section r;
      _annotation_section ~baseline_all_fold_mean_sharpe
        ~baseline_all_fold_mean_max_drawdown_pct;
      _verdict_section r;
    ]
