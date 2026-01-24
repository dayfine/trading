(** Pre-built metric computers for common performance metrics. *)

open Core

(** {1 Summary Statistics Computer} *)

type summary_state = { steps : Simulator.step_result list }

let _summary_computer_impl : summary_state Simulator.metric_computer =
  {
    name = "summary";
    init = (fun ~config:_ -> { steps = [] });
    update = (fun ~state ~step -> { steps = step :: state.steps });
    finalize =
      (fun ~state ~config:_ ->
        let steps = List.rev state.steps in
        let round_trips = Metrics.extract_round_trips steps in
        match Metrics.compute_summary round_trips with
        | None -> []
        | Some stats -> Metrics.summary_stats_to_metrics stats);
  }

let summary_computer () = Simulator.wrap_computer _summary_computer_impl

(** {1 Sharpe Ratio Computer} *)

type sharpe_state = { portfolio_values : float list; risk_free_rate : float }

let _mean values =
  match values with
  | [] -> 0.0
  | _ ->
      let sum = List.fold values ~init:0.0 ~f:( +. ) in
      sum /. Float.of_int (List.length values)

let _std values =
  match values with
  | [] | [ _ ] -> 0.0
  | _ ->
      let mean = _mean values in
      let sum_sq_diff =
        List.fold values ~init:0.0 ~f:(fun acc x ->
            let diff = x -. mean in
            acc +. (diff *. diff))
      in
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

let _sharpe_computer_impl ~risk_free_rate :
    sharpe_state Simulator.metric_computer =
  {
    name = "sharpe_ratio";
    init = (fun ~config:_ -> { portfolio_values = []; risk_free_rate });
    update =
      (fun ~state ~step ->
        {
          state with
          portfolio_values =
            step.Simulator.portfolio_value :: state.portfolio_values;
        });
    finalize =
      (fun ~state ~config:_ ->
        let values = List.rev state.portfolio_values in
        let daily_returns = _compute_daily_returns values in
        let sharpe_ratio =
          match daily_returns with
          | [] | [ _ ] -> 0.0
          | _ ->
              let mean_return = _mean daily_returns in
              let std_return = _std daily_returns in
              if Float.(std_return = 0.0) then 0.0
              else
                let daily_rf = state.risk_free_rate /. 252.0 in
                let excess_return = mean_return -. daily_rf in
                excess_return /. std_return *. Float.sqrt 252.0
        in
        [ Metric_types.make_metric SharpeRatio sharpe_ratio ]);
  }

let sharpe_ratio_computer ?(risk_free_rate = 0.0) () =
  Simulator.wrap_computer (_sharpe_computer_impl ~risk_free_rate)

(** {1 Maximum Drawdown Computer} *)

type drawdown_state = { peak : float; max_drawdown : float; has_data : bool }

let _drawdown_computer_impl : drawdown_state Simulator.metric_computer =
  {
    name = "max_drawdown";
    init =
      (fun ~config:_ -> { peak = 0.0; max_drawdown = 0.0; has_data = false });
    update =
      (fun ~state ~step ->
        let value = step.Simulator.portfolio_value in
        if not state.has_data then
          { peak = value; max_drawdown = 0.0; has_data = true }
        else
          let peak = Float.max state.peak value in
          let drawdown =
            if Float.(peak = 0.0) then 0.0 else (peak -. value) /. peak *. 100.0
          in
          let max_drawdown = Float.max state.max_drawdown drawdown in
          { peak; max_drawdown; has_data = true });
    finalize =
      (fun ~state ~config:_ ->
        [ Metric_types.make_metric MaxDrawdown state.max_drawdown ]);
  }

let max_drawdown_computer () = Simulator.wrap_computer _drawdown_computer_impl

(** {1 Factory} *)

let create_computer (metric_type : Metric_types.metric_type) :
    Simulator.any_metric_computer =
  match metric_type with
  | TotalPnl | AvgHoldingDays | WinCount | LossCount | WinRate ->
      summary_computer ()
  | SharpeRatio -> sharpe_ratio_computer ()
  | MaxDrawdown -> max_drawdown_computer ()

(** {1 Default Computer Set} *)

let default_computers ?(risk_free_rate = 0.0) () =
  [
    summary_computer ();
    sharpe_ratio_computer ~risk_free_rate ();
    max_drawdown_computer ();
  ]
