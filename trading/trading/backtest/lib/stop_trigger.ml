(** Exit-trigger types and their pure classifiers, included by {!Stop_log}. See
    [stop_log.mli] for the documented contract. *)

open Core
open Trading_strategy

type exit_trigger =
  | Stop_loss of { stop_price : float; actual_price : float }
  | Take_profit of { target_price : float; actual_price : float }
  | Signal_reversal of { description : string }
  | Time_expired of { days_held : int; max_days : int }
  | Underperforming of { days_held : int; current_return : float }
  | Portfolio_rebalancing
  | Strategy_signal of { label : string; detail : string option }
  | End_of_period
[@@deriving show, eq, sexp]

let exit_trigger_of_reason (reason : Position.exit_reason) : exit_trigger =
  match reason with
  | StopLoss { stop_price; actual_price; _ } ->
      Stop_loss { stop_price; actual_price }
  | TakeProfit { target_price; actual_price; _ } ->
      Take_profit { target_price; actual_price }
  | SignalReversal { description } -> Signal_reversal { description }
  | TimeExpired { days_held; max_days } -> Time_expired { days_held; max_days }
  | Underperforming { days_held; current_return } ->
      Underperforming { days_held; current_return }
  | PortfolioRebalancing -> Portfolio_rebalancing
  | StrategySignal { label; detail } -> Strategy_signal { label; detail }

let with_fill_price trigger ~fill_price =
  match trigger with
  | Stop_loss { stop_price; _ } ->
      Stop_loss { stop_price; actual_price = fill_price }
  | Take_profit { target_price; _ } ->
      Take_profit { target_price; actual_price = fill_price }
  | other -> other

type stop_trigger_kind =
  | Gap_through
  | Intraday
  | End_of_period
  | Non_stop_exit
[@@deriving show, eq, sexp]

let gap_down_threshold_pct = 0.005

let _is_gap_down ~side ~stop_price ~actual_price ~gap_threshold_pct =
  let open Trading_base.Types in
  match side with
  | Long -> Float.( < ) actual_price (stop_price *. (1.0 -. gap_threshold_pct))
  | Short -> Float.( > ) actual_price (stop_price *. (1.0 +. gap_threshold_pct))

let classify_stop_trigger_kind ?(gap_threshold_pct = gap_down_threshold_pct)
    ~side (trigger : exit_trigger) : stop_trigger_kind =
  match trigger with
  | Stop_loss { stop_price; actual_price } ->
      if _is_gap_down ~side ~stop_price ~actual_price ~gap_threshold_pct then
        Gap_through
      else Intraday
  | End_of_period -> End_of_period
  | Take_profit _ | Signal_reversal _ | Time_expired _ | Underperforming _
  | Portfolio_rebalancing | Strategy_signal _ ->
      Non_stop_exit
