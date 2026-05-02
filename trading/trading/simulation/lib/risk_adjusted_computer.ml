(** Risk-adjusted metric computers (M5.2c). See .mli for spec. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

(** Threshold against which Omega's upside / downside areas are split. The
    standard formulation uses 0% (return greater than the risk-free rate would
    be the alternative); we hold to 0% to keep the metric self-contained. *)
let _omega_threshold_pct = 0.0

type state = {
  portfolio_values : float list;  (** Reversed: head is most recent. *)
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

(** Omega ratio at [_omega_threshold_pct]. Sum of (return - threshold) over
    returns above the threshold, divided by absolute sum of (threshold - return)
    over returns below it. *)
let _omega returns =
  let upside, downside =
    List.fold returns ~init:(0.0, 0.0) ~f:(fun (up, down) r ->
        let excess = r -. _omega_threshold_pct in
        if Float.(excess > 0.0) then (up +. excess, down)
        else if Float.(excess < 0.0) then (up, down -. excess)
        else (up, down))
  in
  if Float.(downside = 0.0) then
    if Float.(upside > 0.0) then Float.infinity else 0.0
  else upside /. downside

let _update ~state ~step =
  if not (Metric_computer_utils.is_trading_day_step step) then state
  else
    {
      portfolio_values =
        step.Simulator_types.portfolio_value :: state.portfolio_values;
    }

let _finalize ~state ~config:_ =
  let returns = _step_returns_pct (List.rev state.portfolio_values) in
  let omega = _omega returns in
  Metric_types.singleton OmegaRatio omega

let computer () : Simulator_types.any_metric_computer =
  Simulator_types.wrap_computer
    {
      name = "omega_ratio";
      init = (fun ~config:_ -> { portfolio_values = [] });
      update = _update;
      finalize = _finalize;
    }

(** {1 Derived computers} *)

let _get base_metrics k = Map.find base_metrics k |> Option.value ~default:0.0

let sortino_ratio_derived : Simulator_types.derived_metric_computer =
  {
    name = "sortino_ratio_annualized";
    depends_on = [ CAGR; DownsideDeviationPctAnnualized ];
    compute =
      (fun ~config:_ ~base_metrics ->
        let cagr = _get base_metrics CAGR in
        let downside = _get base_metrics DownsideDeviationPctAnnualized in
        let sortino =
          if Float.(downside = 0.0) then 0.0 else cagr /. downside
        in
        Metric_types.singleton SortinoRatioAnnualized sortino);
  }

let mar_ratio_derived : Simulator_types.derived_metric_computer =
  {
    name = "mar_ratio";
    depends_on = [ CAGR; MaxDrawdown ];
    compute =
      (fun ~config:_ ~base_metrics ->
        let cagr = _get base_metrics CAGR in
        let max_dd = _get base_metrics MaxDrawdown in
        let mar = if Float.(max_dd = 0.0) then 0.0 else cagr /. max_dd in
        Metric_types.singleton MarRatio mar);
  }
