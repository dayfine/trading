(** Benchmark-relative metrics: alpha, beta, tracking error, Information Ratio,
    correlation. See .mli for spec. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

(** Trading days per year — used to annualize the per-step (daily) regression
    intercept and tracking error. Matches the convention used by
    {!Volatility_computer} and {!Sharpe_computer}. *)
let _trading_days_per_year = 252.0

(** Minimum paired samples before fitting. Two would be enough mathematically
    for a 2-parameter linear regression but five is the smallest count that
    keeps variance estimates non-degenerate; aligns with
    {!Antifragility_computer._min_paired_samples}. *)
let _min_paired_samples = 5

(** Variance below which the benchmark series is treated as constant; β / α /
    correlation fall back to [0.0]. *)
let _variance_tolerance = 1e-12

type state = {
  portfolio_values : float list;
  step_benchmark_returns : float list;
  benchmark_returns_override : float list option;
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

let _align_pairs strat bench =
  let n = Int.min (List.length strat) (List.length bench) in
  List.zip_exn (List.take strat n) (List.take bench n)

(* ---- Single-pass moment accumulator for OLS + correlation ---- *)

type _moments = {
  n : float;
  sx : float;  (** Σ x (benchmark) *)
  sy : float;  (** Σ y (strategy) *)
  sxx : float;  (** Σ x² *)
  syy : float;  (** Σ y² *)
  sxy : float;  (** Σ x·y *)
  sd2 : float;  (** Σ (y − x)² *)
}

let _zero_moments =
  { n = 0.0; sx = 0.0; sy = 0.0; sxx = 0.0; syy = 0.0; sxy = 0.0; sd2 = 0.0 }

let _add_pair m (y, x) =
  let d = y -. x in
  {
    n = m.n +. 1.0;
    sx = m.sx +. x;
    sy = m.sy +. y;
    sxx = m.sxx +. (x *. x);
    syy = m.syy +. (y *. y);
    sxy = m.sxy +. (x *. y);
    sd2 = m.sd2 +. (d *. d);
  }

let _accumulate_moments pairs = List.fold pairs ~init:_zero_moments ~f:_add_pair

(* ---- Derived quantities ---- *)

(** Population variance of the benchmark series; we only need a positivity
    check, so the population/sample distinction doesn't change the gating. *)
let _bench_variance m =
  let mean_x = m.sx /. m.n in
  (m.sxx /. m.n) -. (mean_x *. mean_x)

(** β = Cov(y, x) / Var(x); α = ȳ − β·x̄. Standard OLS for a 2-parameter
    [y = α + β·x] model. *)
let _alpha_beta m =
  let mean_x = m.sx /. m.n in
  let mean_y = m.sy /. m.n in
  let cov_xy = (m.sxy /. m.n) -. (mean_x *. mean_y) in
  let var_x = _bench_variance m in
  if Float.(Float.abs var_x < _variance_tolerance) then (0.0, 0.0)
  else
    let beta = cov_xy /. var_x in
    let alpha = mean_y -. (beta *. mean_x) in
    (alpha, beta)

(** Pearson correlation: [Cov(x, y) / (σ_x · σ_y)]. *)
let _correlation m =
  let mean_x = m.sx /. m.n in
  let mean_y = m.sy /. m.n in
  let cov_xy = (m.sxy /. m.n) -. (mean_x *. mean_y) in
  let var_x = (m.sxx /. m.n) -. (mean_x *. mean_x) in
  let var_y = (m.syy /. m.n) -. (mean_y *. mean_y) in
  if Float.(var_x < _variance_tolerance || var_y < _variance_tolerance) then 0.0
  else cov_xy /. Float.sqrt (var_x *. var_y)

(** Population stdev of (y − x). *)
let _active_return_stdev m =
  let mean_d = (m.sy -. m.sx) /. m.n in
  let var_d = (m.sd2 /. m.n) -. (mean_d *. mean_d) in
  if Float.(var_d < 0.0) then 0.0 else Float.sqrt var_d

(* ---- Output assembly ---- *)

let _empty_metric_set () =
  Metric_types.of_alist_exn
    [
      (BenchmarkAlphaPctAnnualized, 0.0);
      (BenchmarkBeta, 0.0);
      (TrackingErrorPctAnnualized, 0.0);
      (InformationRatio, 0.0);
      (CorrelationToBenchmark, 0.0);
    ]

(* Build the populated metric set from accumulated moments. Pulled out to
   keep [_build_metrics] flat (the wrapper there is just gating). *)
let _metrics_from_moments m =
  let alpha, beta = _alpha_beta m in
  let alpha_annualized = alpha *. _trading_days_per_year in
  let te_annualized =
    _active_return_stdev m *. Float.sqrt _trading_days_per_year
  in
  let info_ratio =
    if Float.(Float.abs te_annualized < _variance_tolerance) then 0.0
    else alpha_annualized /. te_annualized
  in
  Metric_types.of_alist_exn
    [
      (BenchmarkAlphaPctAnnualized, alpha_annualized);
      (BenchmarkBeta, beta);
      (TrackingErrorPctAnnualized, te_annualized);
      (InformationRatio, info_ratio);
      (CorrelationToBenchmark, _correlation m);
    ]

let _build_metrics ~strat_returns ~benchmark_returns =
  let bench_opt =
    match benchmark_returns with
    | None | Some [] -> None
    | Some bench -> Some (_align_pairs strat_returns bench)
  in
  match bench_opt with
  | None -> _empty_metric_set ()
  | Some pairs when List.length pairs < _min_paired_samples ->
      _empty_metric_set ()
  | Some pairs -> _metrics_from_moments (_accumulate_moments pairs)

let _resolve_benchmark_series state =
  match state.benchmark_returns_override with
  | Some _ as override -> override
  | None -> (
      match state.step_benchmark_returns with
      | [] -> None
      | xs -> Some (List.rev xs))

let _update ~state ~step =
  if not (Metric_computer_utils.is_trading_day_step step) then state
  else
    let portfolio_values =
      step.Simulator_types.portfolio_value :: state.portfolio_values
    in
    let step_benchmark_returns =
      match step.Simulator_types.benchmark_return with
      | None -> state.step_benchmark_returns
      | Some r -> r :: state.step_benchmark_returns
    in
    { state with portfolio_values; step_benchmark_returns }

let _finalize ~state ~config:_ =
  let strat_returns = _step_returns_pct (List.rev state.portfolio_values) in
  _build_metrics ~strat_returns
    ~benchmark_returns:(_resolve_benchmark_series state)

let _init ~benchmark_returns ~config:_ =
  {
    portfolio_values = [];
    step_benchmark_returns = [];
    benchmark_returns_override = benchmark_returns;
  }

let computer ?benchmark_returns () : Simulator_types.any_metric_computer =
  Simulator_types.wrap_computer
    {
      name = "benchmark_relative";
      init = _init ~benchmark_returns;
      update = _update;
      finalize = _finalize;
    }
