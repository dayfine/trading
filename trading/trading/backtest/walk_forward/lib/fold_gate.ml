open Core

type metric_key = Sharpe | Calmar | TotalReturnPct | MaxDrawdownPct
[@@deriving sexp]

type t = { metric : metric_key; m : int; n : int; worst_delta : float }
[@@deriving sexp]

type fold_result = {
  fold_name : string;
  variant_score : float;
  baseline_score : float;
}
[@@deriving sexp]

type verdict =
  | Pass of { wins : int; n : int }
  | Fail of {
      wins : int;
      n : int;
      worst_fold : string;
      worst_gap : float;
      reason : string;
    }
[@@deriving sexp]

let higher_is_better = function
  | Sharpe | Calmar | TotalReturnPct -> true
  | MaxDrawdownPct -> false

let _validate (gate : t) (folds : fold_result list) =
  if gate.n < 1 then
    failwith (sprintf "Fold_gate.evaluate: n must be >= 1, got %d" gate.n);
  if gate.m < 0 || gate.m > gate.n then
    failwith
      (sprintf "Fold_gate.evaluate: m must be in [0, n=%d], got %d" gate.n
         gate.m);
  if Float.(gate.worst_delta < 0.0) then
    failwith
      (sprintf "Fold_gate.evaluate: worst_delta must be >= 0.0, got %f"
         gate.worst_delta);
  let actual = List.length folds in
  if actual <> gate.n then
    failwith
      (sprintf
         "Fold_gate.evaluate: fold count mismatch — gate.n=%d but got %d folds"
         gate.n actual)

(** [_signed_gap_for ~hib variant baseline] returns the shortfall amount, in the
    convention that positive = variant trails baseline. For "higher is better"
    metrics it is [baseline - variant]; for "lower is better" metrics (drawdown)
    it is [variant - baseline]. *)
let _signed_gap_for ~hib variant baseline =
  if hib then baseline -. variant else variant -. baseline

(** A fold is a "win" for variant when its signed_gap_for is strictly negative
    (variant strictly beats baseline). Ties count as baseline wins. *)
let _is_win ~hib (fr : fold_result) =
  Float.(_signed_gap_for ~hib fr.variant_score fr.baseline_score < 0.0)

(** Find the largest individual shortfall across folds — used both for the
    Δ-threshold check and for the diagnostic in [Fail.worst_fold]. *)
let _worst_shortfall ~hib (folds : fold_result list) =
  List.fold folds ~init:("", Float.neg_infinity)
    ~f:(fun (best_name, best_gap) fr ->
      let g = _signed_gap_for ~hib fr.variant_score fr.baseline_score in
      if Float.(g > best_gap) then (fr.fold_name, g) else (best_name, best_gap))

let evaluate (gate : t) (folds : fold_result list) =
  _validate gate folds;
  let hib = higher_is_better gate.metric in
  let wins = List.count folds ~f:(_is_win ~hib) in
  let worst_fold, worst_gap = _worst_shortfall ~hib folds in
  let delta_fail = Float.(worst_gap > gate.worst_delta) in
  let m_fail = wins < gate.m in
  match (m_fail, delta_fail) with
  | false, false -> Pass { wins; n = gate.n }
  | _, _ ->
      let reason =
        match (m_fail, delta_fail) with
        | true, true ->
            sprintf
              "M-threshold miss: %d wins < %d required; worst fold %s trails \
               by %.4f > Δ=%.4f"
              wins gate.m worst_fold worst_gap gate.worst_delta
        | true, false ->
            sprintf "M-threshold miss: %d wins < %d required" wins gate.m
        | false, true ->
            sprintf "Δ-threshold miss: fold %s trails by %.4f > Δ=%.4f"
              worst_fold worst_gap gate.worst_delta
        | false, false -> assert false (* unreachable *)
      in
      Fail
        {
          wins;
          n = gate.n;
          worst_fold;
          worst_gap = Float.max worst_gap 0.0;
          reason;
        }
