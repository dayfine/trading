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

type bound_spec =
  | Plain of float * float
  | Sentinel of { threshold : float; upper : float }

(** Custom sexp converters so the on-disk shape mirrors plan §2.5:
    [Plain (lo, hi)] writes as [(lo hi)] (legacy shape, two atoms);
    [Sentinel { threshold; upper }] writes as [(sentinel threshold upper)]
    (three atoms, leading tag). *)
let sexp_of_bound_spec = function
  | Plain (lo, hi) -> Sexp.List [ sexp_of_float lo; sexp_of_float hi ]
  | Sentinel { threshold; upper } ->
      Sexp.List
        [ Sexp.Atom "sentinel"; sexp_of_float threshold; sexp_of_float upper ]

let bound_spec_of_sexp sexp =
  match sexp with
  | Sexp.List [ Sexp.Atom "sentinel"; t; u ] ->
      Sentinel { threshold = float_of_sexp t; upper = float_of_sexp u }
  | Sexp.List [ lo; hi ] -> Plain (float_of_sexp lo, float_of_sexp hi)
  | _ ->
      Sexplib0.Sexp_conv.of_sexp_error
        "Bayesian_runner_spec.bound_spec_of_sexp: expected (lo hi) or \
         (sentinel threshold upper)"
        sexp

let sentinel_margin_fraction = 0.25

let plain_range = function
  | Plain (lo, hi) -> (lo, hi)
  | Sentinel { threshold; upper } ->
      let margin = (upper -. threshold) *. sentinel_margin_fraction in
      (threshold -. margin, upper)

let decode_sentinel_sample spec sampled =
  match spec with
  | Plain _ -> Some sampled
  | Sentinel { threshold; _ } ->
      if Float.( < ) sampled threshold then None else Some sampled

type t = {
  bounds : (string * (float * float)) list;
  acquisition : acquisition_spec;
  initial_random : int;
  total_budget : int;
  seed : int option;
  n_acquisition_candidates : int option;
  objective : objective_spec;
  scenarios : string list;
  holdout_folds : int list option; [@sexp.option]
  sentinel_bounds : (string * bound_spec) list option; [@sexp.option]
  length_scales : float list option; [@sexp.option]
  early_stop : (int * float) option; [@sexp.option]
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
  let length_scales = Option.map t.length_scales ~f:Array.of_list in
  let early_stop_config =
    Option.map t.early_stop ~f:(fun (window, epsilon) ->
        { Tuner.Bayesian_opt.window; epsilon })
  in
  Tuner.Bayesian_opt.create_config ~bounds:t.bounds
    ~acquisition:(to_acquisition t.acquisition)
    ~initial_random:t.initial_random ~total_budget:t.total_budget ~rng
    ?length_scales ?early_stop_config ()
