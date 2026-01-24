(** Basic metric types with no dependencies.

    This module provides the fundamental types for the metrics framework. It has
    no dependencies on other simulation modules, allowing it to be used as a
    foundation for both Simulator and Metrics modules. *)

(** {1 Metric Types} *)

(** Unit of measurement for a metric value *)
type metric_unit =
  | Dollars  (** Monetary value in dollars *)
  | Percent  (** Percentage value (0-100 scale) *)
  | Days  (** Time duration in days *)
  | Count  (** Discrete count *)
  | Ratio  (** Dimensionless ratio *)
[@@deriving show, eq]

type metric = {
  name : string;  (** Machine-readable identifier (e.g., "sharpe_ratio") *)
  display_name : string;  (** Human-readable name (e.g., "Sharpe Ratio") *)
  description : string;  (** Brief explanation of what this metric measures *)
  value : float;  (** The computed value *)
  unit : metric_unit;  (** Unit of measurement *)
}
[@@deriving show, eq]
(** A single computed metric with metadata *)

type metric_set = metric list
(** A collection of metrics from a simulation run *)

(** {1 Metric Type Enum} *)

(** Enum for factory dispatch of metric computers *)
type metric_type =
  | Summary  (** Summary statistics from round-trip trades *)
  | SharpeRatio  (** Risk-adjusted return metric *)
  | MaxDrawdown  (** Maximum peak-to-trough decline *)
[@@deriving show, eq]

(** {1 Utility Functions} *)

val find_metric : metric_set -> name:string -> metric option
(** Find a metric by its machine-readable name *)

val format_metric : metric -> string
(** Format a single metric for display (e.g., "Sharpe Ratio: 1.25") *)

val format_metrics : metric_set -> string
(** Format all metrics for display, one per line *)
