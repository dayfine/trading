open Core
module Scenario = Scenario_lib.Scenario

type variant = { label : string; overrides : Sexp.t list } [@@deriving sexp]

let _scenario_name ~(base : Scenario.t) ~variant ~(fold : Window_spec.fold) =
  sprintf "%s-%s-%s" base.name variant.label fold.name

let _description ~(base : Scenario.t) ~variant ~(fold : Window_spec.fold) =
  sprintf "[walk-forward fold %s | variant %s] %s" fold.name variant.label
    base.description

let build_fold_scenario ~(base : Scenario.t) ~(fold : Window_spec.fold)
    ~(variant : variant) : Scenario.t =
  {
    name = _scenario_name ~base ~variant ~fold;
    description = _description ~base ~variant ~fold;
    period = fold.test_period;
    universe_path = base.universe_path;
    config_overrides = base.config_overrides @ variant.overrides;
    strategy = base.strategy;
    slippage_bps = base.slippage_bps;
    expected = base.expected;
  }

let build_all ~(base : Scenario.t) ~(spec : Window_spec.t)
    ~(variants : variant list) =
  let folds = Window_spec.generate spec in
  List.concat_map variants ~f:(fun variant ->
      List.map folds ~f:(fun fold -> build_fold_scenario ~base ~fold ~variant))

let _days_per_year = 365.25

let cagr_pct ~test_days ~total_return_pct =
  let years = Float.of_int test_days /. _days_per_year in
  if Float.(years <= 0.0) then Float.nan
  else
    (((1.0 +. (total_return_pct /. 100.0)) ** (1.0 /. years)) -. 1.0) *. 100.0
