(** Basic metric types with no dependencies. *)

open Core

(** {1 Metric Type Enum} *)

type metric_type =
  | TotalPnl
  | AvgHoldingDays
  | WinCount
  | LossCount
  | WinRate
  | SharpeRatio
  | MaxDrawdown
[@@deriving show, eq]

(** {1 Metric Types} *)

type metric = { name : string; metric_type : metric_type; value : float }
[@@deriving show, eq]

type metric_set = metric list

(** {1 Metric Unit} *)

type metric_unit = Dollars | Percent | Days | Count | Ratio
[@@deriving show, eq]

(** {1 Metric Info} *)

type metric_info = {
  display_name : string;
  description : string;
  unit : metric_unit;
}

let get_metric_info = function
  | TotalPnl ->
      {
        display_name = "Total P&L";
        description = "Sum of profit/loss across all trades";
        unit = Dollars;
      }
  | AvgHoldingDays ->
      {
        display_name = "Avg Holding Period";
        description = "Average number of days positions were held";
        unit = Days;
      }
  | WinCount ->
      {
        display_name = "Winning Trades";
        description = "Number of profitable trades";
        unit = Count;
      }
  | LossCount ->
      {
        display_name = "Losing Trades";
        description = "Number of unprofitable trades";
        unit = Count;
      }
  | WinRate ->
      {
        display_name = "Win Rate";
        description = "Percentage of trades that were profitable";
        unit = Percent;
      }
  | SharpeRatio ->
      {
        display_name = "Sharpe Ratio";
        description =
          "Risk-adjusted return (annualized): excess return over risk-free \
           rate divided by volatility";
        unit = Ratio;
      }
  | MaxDrawdown ->
      {
        display_name = "Max Drawdown";
        description =
          "Maximum percentage decline from peak portfolio value during \
           simulation";
        unit = Percent;
      }

let _name_of_metric_type = function
  | TotalPnl -> "total_pnl"
  | AvgHoldingDays -> "avg_holding_days"
  | WinCount -> "win_count"
  | LossCount -> "loss_count"
  | WinRate -> "win_rate"
  | SharpeRatio -> "sharpe_ratio"
  | MaxDrawdown -> "max_drawdown"

let make_metric metric_type value =
  { name = _name_of_metric_type metric_type; metric_type; value }

(** {1 Utility Functions} *)

let find_metric (metrics : metric_set) ~name =
  List.find metrics ~f:(fun m -> String.equal m.name name)

let format_metric m =
  let info = get_metric_info m.metric_type in
  match info.unit with
  | Dollars -> Printf.sprintf "%s: $%.2f" info.display_name m.value
  | Percent -> Printf.sprintf "%s: %.2f%%" info.display_name m.value
  | Days -> Printf.sprintf "%s: %.1f days" info.display_name m.value
  | Count -> Printf.sprintf "%s: %.0f" info.display_name m.value
  | Ratio -> Printf.sprintf "%s: %.4f" info.display_name m.value

let format_metrics metrics =
  List.map metrics ~f:format_metric |> String.concat ~sep:"\n"
