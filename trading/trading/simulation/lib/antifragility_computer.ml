(** Antifragility metrics (M5.2d). See .mli for spec. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

(** Minimum number of paired (strategy, benchmark) returns required before we
    bother fitting the quadratic; below this both metrics emit 0.0. Five is the
    smallest count that makes one-per-quintile bucketing well-defined. *)
let _min_paired_samples = 5

(** Determinant tolerance below which the [3 × 3] OLS matrix is treated as
    singular (γ falls back to 0.0). Conservative — at single-digit percent
    inputs the determinant is far from zero on non-degenerate samples. *)
let _det_tolerance = 1e-12

type state = {
  portfolio_values : float list;  (** Reversed: head is most recent. *)
  benchmark_returns : float list option;
      (** Chronological. None = no plumbing. *)
}

let _step_returns_pct values =
  let rec loop prev rest acc =
    match rest with
    | [] -> List.rev acc
    | curr :: rest' ->
        let r =
          if Float.(prev <= 0.0) then 0.0 else (curr -. prev) /. prev *. 100.0
        in
        loop curr rest' (r :: acc)
  in
  match values with [] | [ _ ] -> [] | first :: rest -> loop first rest []

(** Truncate the longer of (strat, bench) to the shorter length and zip. The
    chronological ordering of both lists is the alignment contract; we don't
    attempt date-based alignment because the benchmark series is supplied as a
    bare list (per the .mli's deferred-plumbing rationale). *)
let _align_pairs strat bench =
  let n = Int.min (List.length strat) (List.length bench) in
  List.zip_exn (List.take strat n) (List.take bench n)

(* ---- Quadratic OLS via 3x3 matrix inversion ---- *)

type _ols_sums = {
  n : float;
  sx : float;
  sx2 : float;
  sx3 : float;
  sx4 : float;
  sy : float;
  sxy : float;
  sx2y : float;
}
(** Sums needed for the normal equations of [y = α + β·x + γ·x²]. Predictors are
    [(1, x, x²)], so [XᵀX] is a [3 × 3] symmetric matrix of moments [Σ x^{i+j}]
    and [Xᵀy] is a [3] vector of moments [Σ x^i · y]. *)

let _accumulate_sums pairs =
  List.fold pairs
    ~init:
      {
        n = 0.0;
        sx = 0.0;
        sx2 = 0.0;
        sx3 = 0.0;
        sx4 = 0.0;
        sy = 0.0;
        sxy = 0.0;
        sx2y = 0.0;
      } ~f:(fun acc (y, x) ->
      let x2 = x *. x in
      let x3 = x2 *. x in
      let x4 = x2 *. x2 in
      {
        n = acc.n +. 1.0;
        sx = acc.sx +. x;
        sx2 = acc.sx2 +. x2;
        sx3 = acc.sx3 +. x3;
        sx4 = acc.sx4 +. x4;
        sy = acc.sy +. y;
        sxy = acc.sxy +. (x *. y);
        sx2y = acc.sx2y +. (x2 *. y);
      })

(** Determinant of the 3x3 [XᵀX] matrix:

    {v
        | n    sx   sx2 |
        | sx   sx2  sx3 |
        | sx2  sx3  sx4 |
    v} *)
let _det33 s =
  (s.n *. ((s.sx2 *. s.sx4) -. (s.sx3 *. s.sx3)))
  -. (s.sx *. ((s.sx *. s.sx4) -. (s.sx3 *. s.sx2)))
  +. (s.sx2 *. ((s.sx *. s.sx3) -. (s.sx2 *. s.sx2)))

(** γ via Cramer's rule: replace the third column of [XᵀX] with [Xᵀy]:

    {v
        | n    sx   sy   |
        | sx   sx2  sxy  |
        | sx2  sx3  sx2y |
    v}

    γ = det(replaced) / det(XᵀX). *)
let _gamma_numerator s =
  (s.n *. ((s.sx2 *. s.sx2y) -. (s.sxy *. s.sx3)))
  -. (s.sx *. ((s.sx *. s.sx2y) -. (s.sxy *. s.sx2)))
  +. (s.sy *. ((s.sx *. s.sx3) -. (s.sx2 *. s.sx2)))

let _concavity_coef pairs =
  if List.length pairs < _min_paired_samples then 0.0
  else
    let s = _accumulate_sums pairs in
    let det = _det33 s in
    if Float.(Float.abs det < _det_tolerance) then 0.0
    else _gamma_numerator s /. det

(* ---- Bucket asymmetry via benchmark quintiles ---- *)

(** Sort pairs by benchmark value, then split into [n_buckets] equal-size chunks
    (the last bucket absorbs the remainder when not divisible). Returns one
    float list per bucket of strategy returns. *)
let _bucket_strat_by_bench ~n_buckets pairs =
  let sorted =
    List.sort pairs ~compare:(fun (_y1, x1) (_y2, x2) -> Float.compare x1 x2)
  in
  let n = List.length sorted in
  let chunk_size = n / n_buckets in
  List.init n_buckets ~f:(fun i ->
      let start_idx = i * chunk_size in
      let end_idx = if i = n_buckets - 1 then n else (i + 1) * chunk_size in
      List.filter_mapi sorted ~f:(fun idx (y, _x) ->
          if idx >= start_idx && idx < end_idx then Some y else None))

let _mean = function
  | [] -> 0.0
  | xs ->
      let sum = List.fold xs ~init:0.0 ~f:( +. ) in
      sum /. Float.of_int (List.length xs)

let _bucket_asymmetry pairs =
  if List.length pairs < _min_paired_samples then 0.0
  else
    let buckets = _bucket_strat_by_bench ~n_buckets:5 pairs in
    let means = List.map buckets ~f:_mean in
    match means with
    | [ q1; q2; q3; q4; q5 ] ->
        let extremes = q1 +. q5 in
        let middle = q2 +. q3 +. q4 in
        if Float.(Float.abs middle = 0.0) then 0.0 else extremes /. middle
    | _ -> 0.0

(* ---- Output assembly ---- *)

let _empty_metric_set () =
  Metric_types.of_alist_exn [ (ConcavityCoef, 0.0); (BucketAsymmetry, 0.0) ]

let _build_metrics ~strat_returns ~benchmark_returns =
  match benchmark_returns with
  | None -> _empty_metric_set ()
  | Some bench ->
      let pairs = _align_pairs strat_returns bench in
      Metric_types.of_alist_exn
        [
          (ConcavityCoef, _concavity_coef pairs);
          (BucketAsymmetry, _bucket_asymmetry pairs);
        ]

let _update ~state ~step =
  if not (Metric_computer_utils.is_trading_day_step step) then state
  else
    {
      state with
      portfolio_values =
        step.Simulator_types.portfolio_value :: state.portfolio_values;
    }

let _finalize ~state ~config:_ =
  let strat_returns = _step_returns_pct (List.rev state.portfolio_values) in
  _build_metrics ~strat_returns ~benchmark_returns:state.benchmark_returns

let computer ?benchmark_returns () : Simulator_types.any_metric_computer =
  Simulator_types.wrap_computer
    {
      name = "antifragility";
      init = (fun ~config:_ -> { portfolio_values = []; benchmark_returns });
      update = _update;
      finalize = _finalize;
    }
