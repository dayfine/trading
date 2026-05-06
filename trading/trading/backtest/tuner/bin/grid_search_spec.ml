open Core
module Metric_types = Trading_simulation_types.Metric_types

type objective_spec =
  | Sharpe
  | Calmar
  | TotalReturn
  | Concavity_coef
  | Composite of (Metric_types.metric_type * float) list
[@@deriving sexp]

type t = {
  params : (string * float list) list;
  objective : objective_spec;
  scenarios : string list;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]

let load path =
  try t_of_sexp (Sexp.load_sexp path)
  with exn ->
    failwithf "Grid_search_spec.load: failed to parse %s: %s" path
      (Exn.to_string exn) ()

let to_grid_objective = function
  | Sharpe -> Tuner.Grid_search.Sharpe
  | Calmar -> Tuner.Grid_search.Calmar
  | TotalReturn -> Tuner.Grid_search.TotalReturn
  | Concavity_coef -> Tuner.Grid_search.Concavity_coef
  | Composite weights -> Tuner.Grid_search.Composite weights

let to_grid_param_spec params = params
