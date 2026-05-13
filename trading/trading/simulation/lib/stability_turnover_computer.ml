(** Stability + turnover portfolio-quality metrics. See .mli for spec. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types
module Portfolio_summary = Trading_simulation_types.Portfolio_summary

(** Window length for the rolling-Sharpe stability scan, in trading-day steps.
    90 days mirrors the rolling-Sharpe convention used in M5.2c reporting and is
    short enough to surface regime changes while long enough that the per-window
    Sharpe estimate is not pure noise. *)
let _rolling_window = 90

(** Calendar days per year for [TradeFrequencyAnnualized]. Matches the
    convention used by {!Portfolio_state_computer._trade_frequency} which
    divides by [30.44] days/month. *)
let _calendar_days_per_year = 365.25

(** Tolerance below which a denominator is treated as zero — used both for
    [PositionConcentrationHhi] (gross-notional denominator) and
    [PositionTurnover] (mean-portfolio-value denominator). *)
let _denominator_tolerance = 1e-9

(* ---- Per-step snapshot kept on state ---- *)

type _snapshot = {
  date : Date.t;
  cost_basis_by_symbol : (string * float) list;
      (** Gross cost-basis-notional [|cost_basis|] per symbol; ordering not
          significant. Empty when no positions are open. *)
  portfolio_value : float;
}

type state = {
  portfolio_values : float list;  (** Reversed: head is most recent. *)
  snapshots : _snapshot list;  (** Reversed: head is most recent. *)
}

let _empty_state = { portfolio_values = []; snapshots = [] }

(** Project a step's positions to the gross-cost-basis snapshot used by both
    turnover and HHI. Pulled out so [_update] stays flat. *)
let _snapshot_of_step (step : Simulator_types.step_result) : _snapshot =
  let cost_basis_by_symbol =
    List.map step.portfolio.positions
      ~f:(fun (p : Portfolio_summary.position_summary) ->
        (p.symbol, Float.abs p.cost_basis))
  in
  {
    date = step.date;
    cost_basis_by_symbol;
    portfolio_value = step.portfolio_value;
  }

(* ---- Rolling Sharpe stability ---- *)

let _step_returns values =
  let rec loop prev rest acc =
    match rest with
    | [] -> List.rev acc
    | curr :: rest' ->
        let r = if Float.(prev <= 0.0) then 0.0 else (curr -. prev) /. prev in
        loop curr rest' (r :: acc)
  in
  match values with [] | [ _ ] -> [] | first :: rest -> loop first rest []

let _mean = function
  | [] -> 0.0
  | xs -> List.fold xs ~init:0.0 ~f:( +. ) /. Float.of_int (List.length xs)

let _sq_dev_acc m acc x =
  let d = x -. m in
  acc +. (d *. d)

let _stdev_pop xs =
  match xs with
  | [] | [ _ ] -> 0.0
  | _ ->
      let m = _mean xs in
      let sum_sq = List.fold xs ~init:0.0 ~f:(_sq_dev_acc m) in
      Float.sqrt (sum_sq /. Float.of_int (List.length xs))

(** Annualized Sharpe of a contiguous return slice; matches {!Sharpe_computer}'s
    convention (population stdev, scale by [sqrt(252)]). *)
let _window_sharpe slice =
  match slice with
  | [] | [ _ ] -> 0.0
  | _ ->
      let m = _mean slice in
      let s = _stdev_pop slice in
      if Float.(s = 0.0) then 0.0
      else m /. s *. Float.sqrt Metric_computer_utils.trading_days_per_year

(** Walk a contiguous return series and emit one Sharpe per [_rolling_window]
    slice (no slide step — every contiguous window). *)
let _rolling_sharpe_series returns =
  let arr = Array.of_list returns in
  let n = Array.length arr in
  if n < _rolling_window then []
  else
    List.init
      (n - _rolling_window + 1)
      ~f:(fun start ->
        let slice = Array.sub arr ~pos:start ~len:_rolling_window in
        _window_sharpe (Array.to_list slice))

let _rolling_sharpe_stability returns =
  let sharpes = _rolling_sharpe_series returns in
  match sharpes with [] | [ _ ] -> 0.0 | _ -> _stdev_pop sharpes

(* ---- Position turnover ---- *)

let _abs_delta_notional ~prev ~curr =
  let prev_map = Map.of_alist_exn (module String) prev in
  let curr_map = Map.of_alist_exn (module String) curr in
  let symbols =
    Set.union
      (Set.of_list (module String) (List.map prev ~f:fst))
      (Set.of_list (module String) (List.map curr ~f:fst))
  in
  Set.fold symbols ~init:0.0 ~f:(fun acc sym ->
      let p = Map.find prev_map sym |> Option.value ~default:0.0 in
      let c = Map.find curr_map sym |> Option.value ~default:0.0 in
      acc +. Float.abs (c -. p))

(** Step-over-step churn: walk the snapshot list pairwise and accumulate the
    total [|Δ notional|]. Returned in chronological order's totals (the input is
    already chronological per [_finalize]). *)
let _pair_delta prev curr =
  _abs_delta_notional ~prev:prev.cost_basis_by_symbol
    ~curr:curr.cost_basis_by_symbol

let _total_abs_delta snapshots_chrono =
  let rec loop acc = function
    | [] | [ _ ] -> acc
    | prev :: (curr :: _ as rest) -> loop (acc +. _pair_delta prev curr) rest
  in
  loop 0.0 snapshots_chrono

let _turnover_normalised ~total ~mean_pv ~n =
  if Float.(Float.abs mean_pv < _denominator_tolerance) then 0.0
  else total /. mean_pv /. Float.of_int n

let _position_turnover snapshots_chrono =
  let n = List.length snapshots_chrono in
  if n < 2 then 0.0
  else
    let mean_pv =
      _mean (List.map snapshots_chrono ~f:(fun s -> s.portfolio_value))
    in
    let total = _total_abs_delta snapshots_chrono in
    _turnover_normalised ~total ~mean_pv ~n

(* ---- Friday-sampled HHI ---- *)

let _is_friday d =
  match Date.day_of_week d with Day_of_week.Fri -> true | _ -> false

let _hhi_for_snapshot snap =
  let weights =
    List.map snap.cost_basis_by_symbol ~f:(fun (_, v) -> v)
    |> List.filter ~f:(fun v -> Float.(v > 0.0))
  in
  let total = List.fold weights ~init:0.0 ~f:( +. ) in
  if Float.(Float.abs total < _denominator_tolerance) then None
  else
    let hhi =
      List.fold weights ~init:0.0 ~f:(fun acc w ->
          let w' = w /. total in
          acc +. (w' *. w'))
    in
    Some hhi

let _friday_hhi snapshots_chrono =
  let samples =
    List.filter_map snapshots_chrono ~f:(fun s ->
        if _is_friday s.date then _hhi_for_snapshot s else None)
  in
  if List.is_empty samples then 0.0 else _mean samples

(* ---- Output assembly ---- *)

let _empty_metric_set () =
  Metric_types.of_alist_exn
    [
      (RollingSharpeStability, 0.0);
      (PositionTurnover, 0.0);
      (PositionConcentrationHhi, 0.0);
    ]

let _build_metrics ~returns ~snapshots_chrono =
  Metric_types.of_alist_exn
    [
      (RollingSharpeStability, _rolling_sharpe_stability returns);
      (PositionTurnover, _position_turnover snapshots_chrono);
      (PositionConcentrationHhi, _friday_hhi snapshots_chrono);
    ]

let _update ~state ~step =
  if not (Metric_computer_utils.is_trading_day_step step) then state
  else
    {
      portfolio_values =
        step.Simulator_types.portfolio_value :: state.portfolio_values;
      snapshots = _snapshot_of_step step :: state.snapshots;
    }

let _finalize ~state ~config:_ =
  let returns = _step_returns (List.rev state.portfolio_values) in
  let snapshots_chrono = List.rev state.snapshots in
  match snapshots_chrono with
  | [] -> _empty_metric_set ()
  | _ -> _build_metrics ~returns ~snapshots_chrono

let computer () : Simulator_types.any_metric_computer =
  Simulator_types.wrap_computer
    {
      name = "stability_turnover";
      init = (fun ~config:_ -> _empty_state);
      update = _update;
      finalize = _finalize;
    }

(* ---- Derived: TradeFrequencyAnnualized ---- *)

let _annualized_freq ~num_trades ~start_date ~end_date =
  let days = Float.of_int (Date.diff end_date start_date) in
  if Float.(days <= 0.0) then 0.0
  else num_trades *. _calendar_days_per_year /. days

let trade_frequency_annualized_derived : Simulator_types.derived_metric_computer
    =
  {
    name = "trade_frequency_annualized";
    depends_on = [ NumTrades ];
    compute =
      (fun ~(config : Simulator_types.config) ~base_metrics ->
        let num_trades =
          Map.find base_metrics NumTrades |> Option.value ~default:0.0
        in
        let freq =
          _annualized_freq ~num_trades ~start_date:config.start_date
            ~end_date:config.end_date
        in
        Metric_types.singleton TradeFrequencyAnnualized freq);
  }
