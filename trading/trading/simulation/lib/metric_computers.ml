(* @large-module: 7 metric computers with distinct state types and logic *)
(** Pre-built metric computers for common performance metrics. *)

open Core

let trading_days_per_year = 252.0

module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

(* On non-trading days (weekends, holidays) the simulator has no bars, so
   positions are valued at 0 and portfolio_value equals just cash. Detect
   this by checking if the portfolio has positions but value ≈ cash. *)
let _cash_epsilon = 0.01

let _is_trading_day_step (step : Simulator_types.step_result) =
  let has_positions = not (List.is_empty step.portfolio.positions) in
  let value_is_just_cash =
    Float.( <= )
      (Float.abs (step.portfolio_value -. step.portfolio.current_cash))
      _cash_epsilon
  in
  (not has_positions) || not value_is_just_cash

(** {1 Summary Statistics Computer} *)

type summary_state = { steps : Simulator_types.step_result list }

let _compute_profit_factor (round_trips : Metrics.trade_metrics list) =
  let gross_profit =
    List.fold round_trips ~init:0.0 ~f:(fun acc (m : Metrics.trade_metrics) ->
        if Float.(m.pnl_dollars > 0.0) then acc +. m.pnl_dollars else acc)
  in
  let gross_loss =
    List.fold round_trips ~init:0.0 ~f:(fun acc (m : Metrics.trade_metrics) ->
        if Float.(m.pnl_dollars < 0.0) then acc +. Float.abs m.pnl_dollars
        else acc)
  in
  if Float.(gross_loss = 0.0) then
    if Float.(gross_profit > 0.0) then Float.infinity else 0.0
  else gross_profit /. gross_loss

let _summary_computer_impl : summary_state Simulator_types.metric_computer =
  {
    name = "summary";
    init = (fun ~config:_ -> { steps = [] });
    update = (fun ~state ~step -> { steps = step :: state.steps });
    finalize =
      (fun ~state ~config:_ ->
        let steps = List.rev state.steps in
        let round_trips = Metrics.extract_round_trips steps in
        let base_metrics =
          match Metrics.compute_summary round_trips with
          | None -> Metric_types.empty
          | Some stats -> Metrics.summary_stats_to_metrics stats
        in
        let profit_factor = _compute_profit_factor round_trips in
        Metric_types.merge base_metrics
          (Metric_types.singleton ProfitFactor profit_factor));
  }

let summary_computer () = Simulator_types.wrap_computer _summary_computer_impl

(** {1 Sharpe Ratio Computer} *)

type sharpe_state = { portfolio_values : float list; risk_free_rate : float }

let _mean values =
  match values with
  | [] -> 0.0
  | _ ->
      let sum = List.fold values ~init:0.0 ~f:( +. ) in
      sum /. Float.of_int (List.length values)

let _sq_diff mean acc x =
  let diff = x -. mean in
  acc +. (diff *. diff)

let _std values =
  match values with
  | [] | [ _ ] -> 0.0
  | _ ->
      let mean = _mean values in
      let sum_sq_diff = List.fold values ~init:0.0 ~f:(_sq_diff mean) in
      Float.sqrt (sum_sq_diff /. Float.of_int (List.length values))

let _compute_daily_returns values =
  let rec loop prev rest acc =
    match rest with
    | [] -> List.rev acc
    | curr :: rest' ->
        let return =
          if Float.(prev = 0.0) then 0.0 else (curr -. prev) /. prev
        in
        loop curr rest' (return :: acc)
  in
  match values with [] | [ _ ] -> [] | first :: rest -> loop first rest []

let _compute_sharpe daily_returns risk_free_rate =
  match daily_returns with
  | [] | [ _ ] -> 0.0
  | _ ->
      let mean_return = _mean daily_returns in
      let std_return = _std daily_returns in
      if Float.(std_return = 0.0) then 0.0
      else
        let excess_return =
          mean_return -. (risk_free_rate /. trading_days_per_year)
        in
        excess_return /. std_return *. Float.sqrt trading_days_per_year

let _sharpe_update ~state ~step =
  if not (_is_trading_day_step step) then state
  else
    let portfolio_values =
      step.Simulator_types.portfolio_value :: state.portfolio_values
    in
    { state with portfolio_values }

let _sharpe_finalize ~state ~config:_ =
  let daily_returns =
    _compute_daily_returns (List.rev state.portfolio_values)
  in
  let sharpe = _compute_sharpe daily_returns state.risk_free_rate in
  Metric_types.singleton SharpeRatio sharpe

let _sharpe_computer_impl ~risk_free_rate :
    sharpe_state Simulator_types.metric_computer =
  {
    name = "sharpe_ratio";
    init = (fun ~config:_ -> { portfolio_values = []; risk_free_rate });
    update = _sharpe_update;
    finalize = _sharpe_finalize;
  }

let sharpe_ratio_computer ?(risk_free_rate = 0.0) () =
  Simulator_types.wrap_computer (_sharpe_computer_impl ~risk_free_rate)

(** {1 Maximum Drawdown Computer} *)

type drawdown_state = { peak : float; max_drawdown : float; has_data : bool }

let _update_drawdown state value =
  let peak = Float.max state.peak value in
  let drawdown =
    if Float.(peak = 0.0) then 0.0 else (peak -. value) /. peak *. 100.0
  in
  {
    peak;
    max_drawdown = Float.max state.max_drawdown drawdown;
    has_data = true;
  }

let _init_drawdown value = { peak = value; max_drawdown = 0.0; has_data = true }

let _drawdown_update ~state ~step =
  if not (_is_trading_day_step step) then state
  else
    let value = step.Simulator_types.portfolio_value in
    match state.has_data with
    | false -> _init_drawdown value
    | true -> _update_drawdown state value

let _drawdown_computer_impl : drawdown_state Simulator_types.metric_computer =
  {
    name = "max_drawdown";
    init =
      (fun ~config:_ -> { peak = 0.0; max_drawdown = 0.0; has_data = false });
    update = _drawdown_update;
    finalize =
      (fun ~state ~config:_ ->
        Metric_types.singleton MaxDrawdown state.max_drawdown);
  }

let max_drawdown_computer () =
  Simulator_types.wrap_computer _drawdown_computer_impl

(** {1 CAGR Computer} *)

type cagr_state = { first_value : float option; last_value : float option }

let _days_per_year = 365.25

let _cagr_update ~state ~step =
  if not (_is_trading_day_step step) then state
  else
    let value = step.Simulator_types.portfolio_value in
    let first_value =
      match state.first_value with None -> Some value | some -> some
    in
    { first_value; last_value = Some value }

let _compute_cagr ~first ~last ~start_date ~end_date =
  let days = Float.of_int (Date.diff end_date start_date) in
  let years = days /. _days_per_year in
  if Float.(years <= 0.0) || Float.(first <= 0.0) then 0.0
  else
    let ratio = last /. first in
    (Float.( ** ) ratio (1.0 /. years) -. 1.0) *. 100.0

let _cagr_finalize ~state ~(config : Simulator_types.config) =
  let cagr =
    match (state.first_value, state.last_value) with
    | Some first, Some last ->
        _compute_cagr ~first ~last ~start_date:config.start_date
          ~end_date:config.end_date
    | _ -> 0.0
  in
  Metric_types.singleton CAGR cagr

let _cagr_computer_impl : cagr_state Simulator_types.metric_computer =
  {
    name = "cagr";
    init = (fun ~config:_ -> { first_value = None; last_value = None });
    update = _cagr_update;
    finalize = _cagr_finalize;
  }

let cagr_computer () = Simulator_types.wrap_computer _cagr_computer_impl

(** {1 Portfolio State Computer} *)

type portfolio_state = {
  last_step : Simulator_types.step_result option;
  total_trades : int;
}

let _compute_trade_frequency ~total_trades ~start_date ~end_date =
  let days = Float.of_int (Date.diff end_date start_date) in
  let months = days /. 30.44 in
  if Float.(months <= 0.0) then 0.0 else Float.of_int total_trades /. months

let _portfolio_metrics_from_step ~(step : Simulator_types.step_result)
    ~total_trades ~start_date ~end_date =
  let open_count = Float.of_int (List.length step.portfolio.positions) in
  let unrealized_pnl = step.portfolio_value -. step.portfolio.current_cash in
  let trade_freq =
    _compute_trade_frequency ~total_trades ~start_date ~end_date
  in
  Metric_types.of_alist_exn
    [
      (OpenPositionCount, open_count);
      (UnrealizedPnl, unrealized_pnl);
      (TradeFrequency, trade_freq);
    ]

let _portfolio_finalize ~state ~(config : Simulator_types.config) =
  match state.last_step with
  | None -> Metric_types.empty
  | Some step ->
      _portfolio_metrics_from_step ~step ~total_trades:state.total_trades
        ~start_date:config.start_date ~end_date:config.end_date

let _portfolio_computer_impl : portfolio_state Simulator_types.metric_computer =
  {
    name = "portfolio_state";
    init = (fun ~config:_ -> { last_step = None; total_trades = 0 });
    update =
      (fun ~state ~step ->
        {
          last_step = Some step;
          total_trades = state.total_trades + List.length step.trades;
        });
    finalize = _portfolio_finalize;
  }

let portfolio_state_computer () =
  Simulator_types.wrap_computer _portfolio_computer_impl

(** {1 Derived Metric Computers} *)

let calmar_ratio_derived : Simulator_types.derived_metric_computer =
  {
    name = "calmar_ratio";
    depends_on = [ CAGR; MaxDrawdown ];
    compute =
      (fun ~config:_ ~base_metrics ->
        let get k = Map.find base_metrics k |> Option.value ~default:0.0 in
        let cagr = get CAGR in
        let max_dd = get MaxDrawdown in
        let calmar = if Float.( = ) max_dd 0.0 then 0.0 else cagr /. max_dd in
        Metric_types.singleton CalmarRatio calmar);
  }

(** {1 Factory} *)

let _calmar_stub () =
  Simulator_types.wrap_computer
    {
      name = "calmar_stub";
      init = (fun ~config:_ -> ());
      update = (fun ~state:() ~step:_ -> ());
      finalize =
        (fun ~state:() ~config:_ -> Metric_types.singleton CalmarRatio 0.0);
    }

let create_computer (metric_type : Metric_types.metric_type) :
    Simulator_types.any_metric_computer =
  match metric_type with
  | TotalPnl | AvgHoldingDays | WinCount | LossCount | WinRate | ProfitFactor ->
      summary_computer ()
  | SharpeRatio -> sharpe_ratio_computer ()
  | MaxDrawdown -> max_drawdown_computer ()
  | CAGR -> cagr_computer ()
  | CalmarRatio -> _calmar_stub ()
  | OpenPositionCount | UnrealizedPnl | TradeFrequency ->
      portfolio_state_computer ()

(** {1 Default Computer Set} *)

let default_computers ?(risk_free_rate = 0.0) () =
  [
    summary_computer ();
    sharpe_ratio_computer ~risk_free_rate ();
    max_drawdown_computer ();
    cagr_computer ();
    portfolio_state_computer ();
  ]

let default_derived_computers () = [ calmar_ratio_derived ]

let default_metric_suite ?(risk_free_rate = 0.0) () :
    Simulator_types.metric_suite =
  {
    computers = default_computers ~risk_free_rate ();
    derived = default_derived_computers ();
  }
