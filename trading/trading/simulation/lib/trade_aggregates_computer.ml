(** Trade-aggregate metric computer (M5.2b).

    See {!Trade_aggregates_computer.mli} for the metric list. The shape mirrors
    [Summary_computer]: accumulate [step_result]s during [update], reconstruct
    round-trips at [finalize] via [Metrics.extract_round_trips], then derive the
    aggregate metric set. *)

open Core
module Metric_types = Trading_simulation_types.Metric_types
module Simulator_types = Trading_simulation_types.Simulator_types

type state = { steps : Simulator_types.step_result list; initial_cash : float }

(** Mean of a non-empty float list. Returns [0.0] for the empty case rather than
    raising — the call sites already guarded by an emptiness check, so this is
    just a defensive default. *)
let _mean = function
  | [] -> 0.0
  | xs ->
      let sum = List.fold xs ~init:0.0 ~f:( +. ) in
      sum /. Float.of_int (List.length xs)

let _max_consecutive ~pred trades =
  List.fold trades ~init:(0, 0) ~f:(fun (curr, best) t ->
      if pred t then
        let next = curr + 1 in
        (next, Int.max next best)
      else (0, best))
  |> snd

let _entry_notional (m : Metrics.trade_metrics) = m.entry_price *. m.quantity

let _expectancy ~win_rate_pct ~avg_win ~avg_loss =
  let win_p = win_rate_pct /. 100.0 in
  let loss_p = 1.0 -. win_p in
  (win_p *. avg_win) -. (loss_p *. Float.abs avg_loss)

let _win_loss_ratio ~avg_win ~avg_loss =
  if Float.(avg_loss = 0.0) then
    if Float.(avg_win > 0.0) then Float.infinity else 0.0
  else avg_win /. Float.abs avg_loss

(** Sort round-trips chronologically by entry date so consecutive-win and
    consecutive-loss runs reflect real time order across symbols. *)
let _sort_by_entry trades =
  List.sort trades ~compare:(fun (a : Metrics.trade_metrics) b ->
      Date.compare a.entry_date b.entry_date)

let _split_winners_losers trades =
  List.partition_tf trades ~f:(fun (m : Metrics.trade_metrics) ->
      Float.(m.pnl_dollars > 0.0))

let _largest_win_dollar = function
  | [] -> 0.0
  | winners ->
      List.fold winners ~init:Float.neg_infinity
        ~f:(fun acc (m : Metrics.trade_metrics) -> Float.max acc m.pnl_dollars)

let _largest_loss_dollar = function
  | [] -> 0.0
  | losers ->
      List.fold losers ~init:Float.infinity
        ~f:(fun acc (m : Metrics.trade_metrics) -> Float.min acc m.pnl_dollars)

(** Collect the per-group means used by multiple downstream metrics. Returned
    flat for clarity at the call site rather than as a record (no record escapes
    this module). *)
let _group_means ~winners ~losers =
  let avg_win_dollar =
    _mean
      (List.map winners ~f:(fun (m : Metrics.trade_metrics) -> m.pnl_dollars))
  in
  let avg_win_pct =
    _mean
      (List.map winners ~f:(fun (m : Metrics.trade_metrics) -> m.pnl_percent))
  in
  let avg_loss_dollar =
    _mean
      (List.map losers ~f:(fun (m : Metrics.trade_metrics) -> m.pnl_dollars))
  in
  let avg_loss_pct =
    _mean
      (List.map losers ~f:(fun (m : Metrics.trade_metrics) -> m.pnl_percent))
  in
  let avg_holding_winners =
    _mean
      (List.map winners ~f:(fun (m : Metrics.trade_metrics) ->
           Float.of_int m.days_held))
  in
  let avg_holding_losers =
    _mean
      (List.map losers ~f:(fun (m : Metrics.trade_metrics) ->
           Float.of_int m.days_held))
  in
  ( avg_win_dollar,
    avg_win_pct,
    avg_loss_dollar,
    avg_loss_pct,
    avg_holding_winners,
    avg_holding_losers )

let _trade_size_metrics ~all ~initial_cash =
  let avg_size_dollar = _mean (List.map all ~f:_entry_notional) in
  let avg_size_pct =
    if Float.(initial_cash <= 0.0) then 0.0
    else avg_size_dollar /. initial_cash *. 100.0
  in
  (avg_size_dollar, avg_size_pct)

let _consecutive_runs trades =
  let chrono = _sort_by_entry trades in
  let max_wins =
    _max_consecutive
      ~pred:(fun (m : Metrics.trade_metrics) -> Float.(m.pnl_dollars > 0.0))
      chrono
  in
  let max_losses =
    _max_consecutive
      ~pred:(fun (m : Metrics.trade_metrics) -> Float.(m.pnl_dollars < 0.0))
      chrono
  in
  (max_wins, max_losses)

let _empty_metric_set () =
  Metric_types.of_alist_exn
    [
      (NumTrades, 0.0);
      (LossRate, 0.0);
      (AvgWinDollar, 0.0);
      (AvgWinPct, 0.0);
      (AvgLossDollar, 0.0);
      (AvgLossPct, 0.0);
      (LargestWinDollar, 0.0);
      (LargestLossDollar, 0.0);
      (AvgTradeSizeDollar, 0.0);
      (AvgTradeSizePct, 0.0);
      (AvgHoldingDaysWinners, 0.0);
      (AvgHoldingDaysLosers, 0.0);
      (Expectancy, 0.0);
      (WinLossRatio, 0.0);
      (MaxConsecutiveWins, 0.0);
      (MaxConsecutiveLosses, 0.0);
    ]

let _metrics_of_trades ~initial_cash trades =
  let n = List.length trades in
  let winners, losers = _split_winners_losers trades in
  let win_count = List.length winners in
  let loss_count = List.length losers in
  let win_rate_pct = Float.of_int win_count /. Float.of_int n *. 100.0 in
  let loss_rate_pct = Float.of_int loss_count /. Float.of_int n *. 100.0 in
  let ( avg_win_dollar,
        avg_win_pct,
        avg_loss_dollar,
        avg_loss_pct,
        avg_holding_winners,
        avg_holding_losers ) =
    _group_means ~winners ~losers
  in
  let avg_size_dollar, avg_size_pct =
    _trade_size_metrics ~all:trades ~initial_cash
  in
  let max_wins, max_losses = _consecutive_runs trades in
  Metric_types.of_alist_exn
    [
      (NumTrades, Float.of_int n);
      (LossRate, loss_rate_pct);
      (AvgWinDollar, avg_win_dollar);
      (AvgWinPct, avg_win_pct);
      (AvgLossDollar, avg_loss_dollar);
      (AvgLossPct, avg_loss_pct);
      (LargestWinDollar, _largest_win_dollar winners);
      (LargestLossDollar, _largest_loss_dollar losers);
      (AvgTradeSizeDollar, avg_size_dollar);
      (AvgTradeSizePct, avg_size_pct);
      (AvgHoldingDaysWinners, avg_holding_winners);
      (AvgHoldingDaysLosers, avg_holding_losers);
      ( Expectancy,
        _expectancy ~win_rate_pct ~avg_win:avg_win_dollar
          ~avg_loss:avg_loss_dollar );
      ( WinLossRatio,
        _win_loss_ratio ~avg_win:avg_win_dollar ~avg_loss:avg_loss_dollar );
      (MaxConsecutiveWins, Float.of_int max_wins);
      (MaxConsecutiveLosses, Float.of_int max_losses);
    ]

let _finalize ~state ~config:_ =
  let steps = List.rev state.steps in
  let trades = Metrics.extract_round_trips steps in
  match trades with
  | [] -> _empty_metric_set ()
  | _ -> _metrics_of_trades ~initial_cash:state.initial_cash trades

let computer ?(initial_cash = 0.0) () : Simulator_types.any_metric_computer =
  Simulator_types.wrap_computer
    {
      name = "trade_aggregates";
      init = (fun ~config:_ -> { steps = []; initial_cash });
      update = (fun ~state ~step -> { state with steps = step :: state.steps });
      finalize = _finalize;
    }
