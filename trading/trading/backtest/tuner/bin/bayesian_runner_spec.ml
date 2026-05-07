open Core
module Metric_types = Trading_simulation_types.Metric_types

type objective_spec =
  | Sharpe
  | Calmar
  | TotalReturn
  | Concavity_coef
  | Composite of (Metric_types.metric_type * float) list
[@@deriving sexp]

type acquisition_spec = Expected_improvement | Upper_confidence_bound of float
[@@deriving sexp]

type t = {
  bounds : (string * (float * float)) list;
  acquisition : acquisition_spec;
  initial_random : int;
  total_budget : int;
  seed : int option;
  n_acquisition_candidates : int option;
  objective : objective_spec;
  scenarios : string list;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]

let load path =
  try t_of_sexp (Sexp.load_sexp path)
  with exn ->
    failwithf "Bayesian_runner_spec.load: failed to parse %s: %s" path
      (Exn.to_string exn) ()

let to_grid_objective = function
  | Sharpe -> Tuner.Grid_search.Sharpe
  | Calmar -> Tuner.Grid_search.Calmar
  | TotalReturn -> Tuner.Grid_search.TotalReturn
  | Concavity_coef -> Tuner.Grid_search.Concavity_coef
  | Composite weights -> Tuner.Grid_search.Composite weights

let to_acquisition = function
  | Expected_improvement -> `Expected_improvement
  | Upper_confidence_bound beta -> `Upper_confidence_bound beta

let to_bo_config t =
  let rng =
    match t.seed with
    | Some n -> Stdlib.Random.State.make [| n |]
    | None -> Stdlib.Random.State.make [| 42 |]
  in
  Tuner.Bayesian_opt.create_config ~bounds:t.bounds
    ~acquisition:(to_acquisition t.acquisition)
    ~initial_random:t.initial_random ~total_budget:t.total_budget ~rng ()
