(** Distributional return-shape metrics (M5.2d). See .mli for spec. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

(** Tail cuts for CVaR / TailRatio. Both are conventional: 5% Expected Shortfall
    is the dominant academic measure; 1% is the regulatory tail. *)
let _cvar_95_p = 0.05

let _cvar_99_p = 0.01
let _tail_ratio_p = 0.05

type state = {
  portfolio_values : float list;  (** Reversed: head is most recent. *)
}

(** Step-over-step percent returns from a chronological value series. *)
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

let _mean = function
  | [] -> 0.0
  | xs ->
      let sum = List.fold xs ~init:0.0 ~f:( +. ) in
      sum /. Float.of_int (List.length xs)

(** Population variance (divides by N, not N-1). Higher moments use the
    population convention to keep the formulas numerically self-consistent with
    the standardized [(r - μ) / σ] terms. *)
let _variance returns =
  match returns with
  | [] | [ _ ] -> 0.0
  | _ ->
      let m = _mean returns in
      let sum_sq =
        List.fold returns ~init:0.0 ~f:(fun acc r ->
            let d = r -. m in
            acc +. (d *. d))
      in
      sum_sq /. Float.of_int (List.length returns)

(** Third / fourth central moments (population). *)
let _moments_3_4 returns =
  match returns with
  | [] | [ _ ] -> (0.0, 0.0)
  | _ ->
      let m = _mean returns in
      let n_f = Float.of_int (List.length returns) in
      let m3, m4 =
        List.fold returns ~init:(0.0, 0.0) ~f:(fun (acc3, acc4) r ->
            let d = r -. m in
            let d2 = d *. d in
            (acc3 +. (d2 *. d), acc4 +. (d2 *. d2)))
      in
      (m3 /. n_f, m4 /. n_f)

let _skewness returns =
  let var = _variance returns in
  if Float.(var <= 0.0) then 0.0
  else
    let m3, _m4 = _moments_3_4 returns in
    let sigma = Float.sqrt var in
    m3 /. (sigma *. sigma *. sigma)

let _kurtosis_excess returns =
  let var = _variance returns in
  if Float.(var <= 0.0) then 0.0
  else
    let _m3, m4 = _moments_3_4 returns in
    (m4 /. (var *. var)) -. 3.0

(** [_bottom_n_mean ~p sorted_asc] returns the mean of the lowest [floor(n × p)]
    returns; 0.0 if that count is zero. The input must be sorted ascending. *)
let _bottom_n_mean ~p sorted_asc =
  let n = List.length sorted_asc in
  let k = Float.iround_down_exn (Float.of_int n *. p) in
  if k <= 0 then 0.0
  else
    let bottom = List.take sorted_asc k in
    _mean bottom

(** [_top_n_mean ~p sorted_asc] returns the mean of the highest [floor(n × p)]
    returns; 0.0 if that count is zero. *)
let _top_n_mean ~p sorted_asc =
  let n = List.length sorted_asc in
  let k = Float.iround_down_exn (Float.of_int n *. p) in
  if k <= 0 then 0.0
  else
    let top = List.drop sorted_asc (n - k) in
    _mean top

let _cvar ~p returns =
  let sorted = List.sort returns ~compare:Float.compare in
  _bottom_n_mean ~p sorted

let _tail_ratio returns =
  let sorted = List.sort returns ~compare:Float.compare in
  let top = _top_n_mean ~p:_tail_ratio_p sorted in
  let bottom = _bottom_n_mean ~p:_tail_ratio_p sorted in
  let abs_bottom = Float.abs bottom in
  if Float.(abs_bottom = 0.0) then
    if Float.(top > 0.0) then Float.infinity else 0.0
  else top /. abs_bottom

let _gain_to_pain returns =
  let gains, losses =
    List.fold returns ~init:(0.0, 0.0) ~f:(fun (g, l) r ->
        if Float.(r > 0.0) then (g +. r, l)
        else if Float.(r < 0.0) then (g, l +. r)
        else (g, l))
  in
  let abs_losses = Float.abs losses in
  if Float.(abs_losses = 0.0) then
    if Float.(gains > 0.0) then Float.infinity else 0.0
  else gains /. abs_losses

let _empty_metric_set () =
  Metric_types.of_alist_exn
    [
      (Skewness, 0.0);
      (Kurtosis, 0.0);
      (CVaR95, 0.0);
      (CVaR99, 0.0);
      (TailRatio, 0.0);
      (GainToPain, 0.0);
    ]

let _build_metrics returns =
  Metric_types.of_alist_exn
    [
      (Skewness, _skewness returns);
      (Kurtosis, _kurtosis_excess returns);
      (CVaR95, _cvar ~p:_cvar_95_p returns);
      (CVaR99, _cvar ~p:_cvar_99_p returns);
      (TailRatio, _tail_ratio returns);
      (GainToPain, _gain_to_pain returns);
    ]

let _update ~state ~step =
  if not (Metric_computer_utils.is_trading_day_step step) then state
  else
    {
      portfolio_values =
        step.Simulator_types.portfolio_value :: state.portfolio_values;
    }

let _finalize ~state ~config:_ =
  let returns = _step_returns_pct (List.rev state.portfolio_values) in
  match returns with [] -> _empty_metric_set () | _ -> _build_metrics returns

let computer () : Simulator_types.any_metric_computer =
  Simulator_types.wrap_computer
    {
      name = "distributional";
      init = (fun ~config:_ -> { portfolio_values = [] });
      update = _update;
      finalize = _finalize;
    }
