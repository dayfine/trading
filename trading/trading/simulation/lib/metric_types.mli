(** Basic metric types with no dependencies.

    This module provides the fundamental types for the metrics framework. It has
    no dependencies on other simulation modules, allowing it to be used as a
    foundation for both Simulator and Metrics modules. *)

(** {1 Metric Type Enum} *)

(** Enum identifying the type of metric *)
type metric_type =
  | TotalPnl  (** Total profit/loss in dollars *)
  | AvgHoldingDays  (** Average holding period *)
  | WinCount  (** Number of winning trades *)
  | LossCount  (** Number of losing trades *)
  | WinRate  (** Win percentage *)
  | SharpeRatio  (** Risk-adjusted return metric *)
  | MaxDrawdown  (** Maximum peak-to-trough decline *)
[@@deriving show, eq]

(** {1 Metric Types} *)

type metric = {
  name : string;  (** Machine-readable identifier (e.g., "sharpe_ratio") *)
  metric_type : metric_type;  (** The type of this metric *)
  value : float;  (** The computed value *)
}
[@@deriving show, eq]
(** A single computed metric *)

type metric_set = metric list
(** A collection of metrics from a simulation run *)

(** {1 Metric Unit} *)

(** Unit of measurement for formatting *)
type metric_unit =
  | Dollars  (** Monetary value in dollars *)
  | Percent  (** Percentage value (0-100 scale) *)
  | Days  (** Time duration in days *)
  | Count  (** Discrete count *)
  | Ratio  (** Dimensionless ratio *)
[@@deriving show, eq]

(** {1 Metric Info} *)

type metric_info = {
  display_name : string;  (** Human-readable name *)
  description : string;  (** Brief explanation *)
  unit : metric_unit;  (** Unit for formatting *)
}
(** Metadata about a metric type *)

val get_metric_info : metric_type -> metric_info
(** Get display info for a metric type *)

(** {1 Utility Functions} *)

val find_metric : metric_set -> name:string -> metric option
(** Find a metric by its machine-readable name *)

val format_metric : metric -> string
(** Format a single metric for display (e.g., "Sharpe Ratio: 1.25") *)

val format_metrics : metric_set -> string
(** Format all metrics for display, one per line *)

val make_metric : metric_type -> float -> metric
(** Create a metric with the canonical name for its type *)
