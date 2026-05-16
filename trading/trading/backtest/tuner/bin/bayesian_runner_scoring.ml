open Core
module Wf = Walk_forward.Walk_forward_types

(* Hyperparameter constants — see the mli for rationale. *)

let _lambda_dd = 0.10
let _gate_penalty_value = 10.0
let _lambda_gate = 1.0
let _degenerate_fold_floor_return_pct = -50.0

(* ---------- variant lookup helpers ---------- *)

let _lookup_stability ~(label : string) (agg : Wf.aggregate) :
    Wf.variant_stability Status.status_or =
  match
    List.find agg.stability ~f:(fun v ->
        String.equal v.variant_label label)
  with
  | Some v -> Ok v
  | None ->
      Status.error_not_found
        (Printf.sprintf
           "bayesian_runner_scoring: variant %S not found in aggregate.stability \
            (have: [%s])"
           label
           (String.concat ~sep:"; "
              (List.map agg.stability ~f:(fun v -> v.variant_label))))

let _lookup_verdict ~(label : string) (agg : Wf.aggregate) :
    Walk_forward.Fold_gate.verdict Status.status_or =
  match
    List.Assoc.find agg.verdicts ~equal:String.equal label
  with
  | Some v -> Ok v
  | None ->
      Status.error_not_found
        (Printf.sprintf
           "bayesian_runner_scoring: variant %S not found in aggregate.verdicts \
            (have: [%s])"
           label
           (String.concat ~sep:"; "
              (List.map agg.verdicts ~f:fst)))

(* ---------- component computations ---------- *)

let _compute_maxdd_hinge ~(candidate_maxdd : float) ~(baseline_maxdd : float) :
    float =
  Float.max 0.0 (candidate_maxdd -. baseline_maxdd)

let _compute_gate_penalty (verdict : Walk_forward.Fold_gate.verdict) : float =
  match verdict with
  | Pass _ -> 0.0
  | Fail _ -> _gate_penalty_value

(* ---------- top-level scorer ---------- *)

let score_cell ~parameters:_ ~candidate_label ~baseline_label
    ~(candidate_aggregate : Wf.aggregate)
    ~(baseline_aggregate : Wf.aggregate) : float Status.status_or =
  if candidate_aggregate.fold_count = 0 then
    Status.error_invalid_argument
      "bayesian_runner_scoring: candidate_aggregate.fold_count = 0; no folds \
       to score"
  else
    let open Result.Let_syntax in
    let%bind candidate_stab =
      _lookup_stability ~label:candidate_label candidate_aggregate
    in
    let%bind baseline_stab =
      _lookup_stability ~label:baseline_label baseline_aggregate
    in
    let%bind candidate_verdict =
      _lookup_verdict ~label:candidate_label candidate_aggregate
    in
    let mean_sharpe = candidate_stab.sharpe_ratio.mean in
    let candidate_maxdd = candidate_stab.max_drawdown_pct.mean in
    let baseline_maxdd = baseline_stab.max_drawdown_pct.mean in
    let maxdd_hinge =
      _compute_maxdd_hinge ~candidate_maxdd ~baseline_maxdd
    in
    let gate_penalty = _compute_gate_penalty candidate_verdict in
    let loss =
      (-.mean_sharpe)
      +. (_lambda_dd *. maxdd_hinge)
      +. (_lambda_gate *. gate_penalty)
    in
    Ok (-.loss)
