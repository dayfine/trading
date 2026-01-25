(** Basic metric types with no dependencies. *)

open Core

(** {1 Metric Type Enum} *)

module Metric_type = struct
  module T = struct
    type t =
      | TotalPnl
      | AvgHoldingDays
      | WinCount
      | LossCount
      | WinRate
      | SharpeRatio
      | MaxDrawdown
    [@@deriving show, eq, compare, sexp]
  end

  include T
  include Comparator.Make (T)
end

type metric_type = Metric_type.t =
  | TotalPnl
  | AvgHoldingDays
  | WinCount
  | LossCount
  | WinRate
  | SharpeRatio
  | MaxDrawdown
[@@deriving show, eq, compare, sexp]

include (Metric_type : Comparator.S with type t := metric_type)

(** {1 Metric Set} *)

type metric_set = float Map.M(Metric_type).t

let empty = Map.empty (module Metric_type)

let singleton metric_type value =
  Map.singleton (module Metric_type) metric_type value

let of_alist_exn alist = Map.of_alist_exn (module Metric_type) alist
let merge m1 m2 = Map.merge_skewed m1 m2 ~combine:(fun ~key:_ _v1 v2 -> v2)

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

(** {1 Formatting} *)

let format_metric metric_type value =
  let info = get_metric_info metric_type in
  match info.unit with
  | Dollars -> Printf.sprintf "%s: $%.2f" info.display_name value
  | Percent -> Printf.sprintf "%s: %.2f%%" info.display_name value
  | Days -> Printf.sprintf "%s: %.1f days" info.display_name value
  | Count -> Printf.sprintf "%s: %.0f" info.display_name value
  | Ratio -> Printf.sprintf "%s: %.4f" info.display_name value

let format_metrics metrics =
  Map.fold metrics ~init:[] ~f:(fun ~key ~data acc ->
      format_metric key data :: acc)
  |> List.rev |> String.concat ~sep:"\n"
