open Core
module Wf_types = Walk_forward.Walk_forward_types

let _no_overfit_hurdle_sharpe = 0.10

type verdict = Accept | Reject_overfit | Reject_insufficient_data
[@@deriving sexp]

type oos_result = {
  candidate_label : string;
  in_sample_mean_sharpe : float;
  oos_mean_sharpe : float;
  gap : float;
  in_sample_fold_count : int;
  oos_fold_count : int;
  per_oos_fold : (string * float) list;
  verdict : verdict;
}
[@@deriving sexp]

(* ---------- partitioning helpers ---------- *)

let _filter_to_candidate ~(candidate_label : string)
    (fold_actuals : Wf_types.fold_actual list) : Wf_types.fold_actual list =
  List.filter fold_actuals ~f:(fun fa ->
      String.equal fa.variant_label candidate_label)

(** Partition the candidate's per-fold rows into (in-sample, oos) by 1-indexed
    position in [holdout_folds]. The 1-indexed position of the [i]-th row in the
    input list is [i + 1]. *)
let _partition_in_sample_vs_oos ~(holdout_folds : int list)
    (rows : Wf_types.fold_actual list) :
    Wf_types.fold_actual list * Wf_types.fold_actual list =
  let holdout_set = Int.Set.of_list holdout_folds in
  List.foldi rows ~init:([], []) ~f:(fun i (acc_in, acc_oos) row ->
      let pos_one_indexed = i + 1 in
      if Set.mem holdout_set pos_one_indexed then (acc_in, row :: acc_oos)
      else (row :: acc_in, acc_oos))
  |> fun (in_rev, oos_rev) -> (List.rev in_rev, List.rev oos_rev)

let _mean_sharpe (rows : Wf_types.fold_actual list) : float =
  match rows with
  | [] -> Float.nan
  | _ ->
      let sum =
        List.fold rows ~init:0.0 ~f:(fun acc fa -> acc +. fa.sharpe_ratio)
      in
      sum /. Float.of_int (List.length rows)

let _verdict_of ~(in_sample_count : int) ~(oos_count : int) ~(gap : float) :
    verdict =
  if in_sample_count = 0 || oos_count = 0 then Reject_insufficient_data
  else if Float.(abs gap > _no_overfit_hurdle_sharpe) then Reject_overfit
  else Accept

(* ---------- public API ---------- *)

let validate ~(candidate_label : string) ~(holdout_folds : int list)
    ~(fold_actuals : Wf_types.fold_actual list) : oos_result =
  let candidate_rows = _filter_to_candidate ~candidate_label fold_actuals in
  let in_sample_rows, oos_rows =
    _partition_in_sample_vs_oos ~holdout_folds candidate_rows
  in
  let in_sample_mean_sharpe = _mean_sharpe in_sample_rows in
  let oos_mean_sharpe = _mean_sharpe oos_rows in
  let gap = oos_mean_sharpe -. in_sample_mean_sharpe in
  let in_sample_fold_count = List.length in_sample_rows in
  let oos_fold_count = List.length oos_rows in
  let per_oos_fold =
    List.map oos_rows ~f:(fun fa -> (fa.fold_name, fa.sharpe_ratio))
  in
  let verdict =
    _verdict_of ~in_sample_count:in_sample_fold_count ~oos_count:oos_fold_count
      ~gap:(if Float.is_nan gap then 0.0 else gap)
  in
  {
    candidate_label;
    in_sample_mean_sharpe;
    oos_mean_sharpe;
    gap;
    in_sample_fold_count;
    oos_fold_count;
    per_oos_fold;
    verdict;
  }

(* ---------- markdown renderer ---------- *)

let _verdict_label (v : verdict) : string =
  match v with
  | Accept -> "ACCEPT"
  | Reject_overfit -> "REJECT (over-fit: |gap| > 0.10)"
  | Reject_insufficient_data ->
      "REJECT (insufficient data: zero in-sample or OOS folds)"

let _format_float f = if Float.is_nan f then "n/a" else sprintf "%.4f" f

let _title_section ~spec_path ~candidate_label ~baseline_label =
  sprintf
    "# OOS validation report\n\n\
     BO spec: `%s`\n\n\
     Candidate variant: `%s`\n\n\
     Baseline variant: `%s`\n\n\
     Acceptance rule: per plan \
     [dev/plans/bayesian-multi-param-scaling-2026-05-16.md] §6.3 — OOS mean \
     Sharpe must be within %.2f of in-sample mean Sharpe.\n\n"
    spec_path candidate_label baseline_label _no_overfit_hurdle_sharpe

let _summary_section (r : oos_result) =
  sprintf
    "## In-sample vs OOS mean Sharpe\n\n\
     | Slice | Fold count | Mean Sharpe |\n\
     |---|---|---|\n\
     | In-sample | %d | %s |\n\
     | OOS | %d | %s |\n\
     | Gap (OOS - in-sample) | — | %s |\n\n"
    r.in_sample_fold_count
    (_format_float r.in_sample_mean_sharpe)
    r.oos_fold_count
    (_format_float r.oos_mean_sharpe)
    (_format_float r.gap)

let _per_fold_section (r : oos_result) =
  match r.per_oos_fold with
  | [] -> "## Per-OOS-fold Sharpe\n\n(no OOS folds — see verdict)\n\n"
  | rows ->
      let row_strs =
        List.map rows ~f:(fun (name, sharpe) ->
            sprintf "| `%s` | %s |\n" name (_format_float sharpe))
      in
      sprintf "## Per-OOS-fold Sharpe\n\n| Fold | Sharpe |\n|---|---|\n%s\n"
        (String.concat row_strs)

let _verdict_section (r : oos_result) =
  sprintf
    "## Verdict\n\n\
     **%s**\n\n\
     - Gap (OOS - in-sample) = %s\n\
     - Hurdle = %.2f (absolute)\n"
    (_verdict_label r.verdict) (_format_float r.gap) _no_overfit_hurdle_sharpe

let render_report (r : oos_result) ~(spec_path : string)
    ~(baseline_label : string) : string =
  String.concat
    [
      _title_section ~spec_path ~candidate_label:r.candidate_label
        ~baseline_label;
      _summary_section r;
      _per_fold_section r;
      _verdict_section r;
    ]

let write_report (path : string) (r : oos_result) ~(spec_path : string)
    ~(baseline_label : string) : unit =
  let md = render_report r ~spec_path ~baseline_label in
  Out_channel.with_file path ~f:(fun oc -> Out_channel.output_string oc md)
