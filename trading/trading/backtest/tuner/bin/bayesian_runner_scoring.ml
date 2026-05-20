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
    List.find agg.stability ~f:(fun v -> String.equal v.variant_label label)
  with
  | Some v -> Ok v
  | None ->
      Status.error_not_found
        (Printf.sprintf
           "bayesian_runner_scoring: variant %S not found in \
            aggregate.stability (have: [%s])"
           label
           (String.concat ~sep:"; "
              (List.map agg.stability ~f:(fun v -> v.variant_label))))

let _lookup_verdict ~(label : string) (agg : Wf.aggregate) :
    Walk_forward.Fold_gate.verdict Status.status_or =
  match List.Assoc.find agg.verdicts ~equal:String.equal label with
  | Some v -> Ok v
  | None ->
      Status.error_not_found
        (Printf.sprintf
           "bayesian_runner_scoring: variant %S not found in \
            aggregate.verdicts (have: [%s])"
           label
           (String.concat ~sep:"; " (List.map agg.verdicts ~f:fst)))

(* ---------- component computations ---------- *)

let _compute_maxdd_hinge ~(candidate_maxdd : float) ~(baseline_maxdd : float) :
    float =
  Float.max 0.0 (candidate_maxdd -. baseline_maxdd)

let _compute_gate_penalty (verdict : Walk_forward.Fold_gate.verdict) : float =
  match verdict with Pass _ -> 0.0 | Fail _ -> _gate_penalty_value

(* ---------- per-objective scoring branches ---------- *)

let _score_sharpe_with_hinge ~(candidate_stab : Wf.variant_stability)
    ~(baseline_stab : Wf.variant_stability) ~(gate_penalty : float) : float =
  let mean_sharpe = candidate_stab.sharpe_ratio.mean in
  let candidate_maxdd = candidate_stab.max_drawdown_pct.mean in
  let baseline_maxdd = baseline_stab.max_drawdown_pct.mean in
  let maxdd_hinge = _compute_maxdd_hinge ~candidate_maxdd ~baseline_maxdd in
  let loss =
    -.mean_sharpe
    +. (_lambda_dd *. maxdd_hinge)
    +. (_lambda_gate *. gate_penalty)
  in
  -.loss

(* ---------- metric_type → variant_stability field lookup ---------- *)

(** Map a [metric_type] (from a Composite weights list or a single-metric
    objective) to the matching [per_metric_stats.mean] in a [variant_stability].
    Returns [None] for metric_types not carried by the walk-forward aggregate
    (e.g. [CVaR95], [TotalPnl], [WinRate], ...) — those weights are silently
    dropped per plan §1 Q1 (v1 design).

    [AvgHoldingDays] was added 2026-05-20 (P5 infra of
    [dev/plans/hold-period-deep-dive-2026-05-19.md]) so the Composite scorer can
    encode a hold-cadence reward term as [(AvgHoldingDays 0.10)] — positive
    weight rewards candidates whose mean hold exceeds the baseline. *)
let _metric_mean_from_stability
    (mt : Trading_simulation_types.Metric_types.metric_type)
    (stab : Wf.variant_stability) : float option =
  match mt with
  | TotalReturnPct -> Some stab.total_return_pct.mean
  | SharpeRatio -> Some stab.sharpe_ratio.mean
  | MaxDrawdown -> Some stab.max_drawdown_pct.mean
  | CalmarRatio -> Some stab.calmar_ratio.mean
  | CAGR -> Some stab.cagr_pct.mean
  | AvgHoldingDays -> Some stab.avg_holding_days.mean
  | _ -> None

let _score_composite_relative ~(candidate_stab : Wf.variant_stability)
    ~(baseline_stab : Wf.variant_stability)
    ~(weights :
       (Trading_simulation_types.Metric_types.metric_type * float) list)
    ~(gate_penalty : float) : float =
  let composite_delta =
    List.fold weights ~init:0.0 ~f:(fun acc (mt, weight) ->
        match
          ( _metric_mean_from_stability mt candidate_stab,
            _metric_mean_from_stability mt baseline_stab )
        with
        | Some cand, Some base -> acc +. (weight *. (cand -. base))
        | _ ->
            (* Metric type not present in variant_stability (e.g. CVaR95).
               Silently drop per plan §1 Q1 v1 behaviour. *)
            acc)
  in
  composite_delta -. (_lambda_gate *. gate_penalty)

(** Single-metric-relative formula for Calmar / TotalReturn / Concavity_coef.
    Score = (cand_metric - base_metric) - lambda_dd * max(0, cand_maxdd -
    base_maxdd) - lambda_gate * gate_penalty.

    Concavity_coef is not present in [variant_stability]; that path returns
    [0.0] for both candidate and baseline metric values, so the score reduces to
    just the (negated) hinge + gate penalty. Documented in the mli. *)
let _score_single_metric_relative ~(objective : Tuner.Grid_search.objective)
    ~(candidate_stab : Wf.variant_stability)
    ~(baseline_stab : Wf.variant_stability) ~(gate_penalty : float) : float =
  let metric_value (stab : Wf.variant_stability) =
    match objective with
    | Tuner.Grid_search.Calmar -> stab.calmar_ratio.mean
    | TotalReturn -> stab.total_return_pct.mean
    | Concavity_coef ->
        (* Not in variant_stability; treat as 0.0 on both sides. *)
        0.0
    | Sharpe | Composite _ ->
        (* Caller is responsible for not routing Sharpe / Composite through
           this branch. Defensive [0.0] keeps the formula total without
           introducing a spurious bias. *)
        0.0
  in
  let metric_delta =
    metric_value candidate_stab -. metric_value baseline_stab
  in
  let candidate_maxdd = candidate_stab.max_drawdown_pct.mean in
  let baseline_maxdd = baseline_stab.max_drawdown_pct.mean in
  let maxdd_hinge = _compute_maxdd_hinge ~candidate_maxdd ~baseline_maxdd in
  metric_delta -. (_lambda_dd *. maxdd_hinge) -. (_lambda_gate *. gate_penalty)

(* ---------- top-level scorer ---------- *)

let score_cell ~parameters:_ ~candidate_label ~baseline_label
    ~(candidate_aggregate : Wf.aggregate) ~(baseline_aggregate : Wf.aggregate)
    ~(objective : Tuner.Grid_search.objective) : float Status.status_or =
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
    let gate_penalty = _compute_gate_penalty candidate_verdict in
    match objective with
    | Tuner.Grid_search.Sharpe ->
        Ok
          (_score_sharpe_with_hinge ~candidate_stab ~baseline_stab ~gate_penalty)
    | Composite weights ->
        Ok
          (_score_composite_relative ~candidate_stab ~baseline_stab ~weights
             ~gate_penalty)
    | Calmar | TotalReturn | Concavity_coef ->
        Ok
          (_score_single_metric_relative ~objective ~candidate_stab
             ~baseline_stab ~gate_penalty)
