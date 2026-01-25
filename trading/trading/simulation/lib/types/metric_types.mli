(** Basic metric types with no dependencies.

    This module provides the fundamental types for the metrics framework. It has
    no dependencies on other simulation modules, allowing it to be used as a
    foundation for both Simulator and Metrics modules. *)

open Core

(** {1 Metric Type Enum} *)

(** Module containing the metric type enum with Map-compatible comparator *)
module Metric_type : sig
  type t =
    | TotalPnl  (** Total profit/loss in dollars *)
    | AvgHoldingDays  (** Average holding period *)
    | WinCount  (** Number of winning trades *)
    | LossCount  (** Number of losing trades *)
    | WinRate  (** Win percentage *)
    | SharpeRatio  (** Risk-adjusted return metric *)
    | MaxDrawdown  (** Maximum peak-to-trough decline *)
  [@@deriving show, eq, compare, sexp]

  include Comparator.S with type t := t
end

(** Alias for convenience *)
type metric_type = Metric_type.t =
  | TotalPnl
  | AvgHoldingDays
  | WinCount
  | LossCount
  | WinRate
  | SharpeRatio
  | MaxDrawdown
[@@deriving show, eq, compare, sexp]

(** {1 Metric Set} *)

type metric_set = float Map.M(Metric_type).t
(** A collection of metrics keyed by type. Use [Map.find] for lookup. *)

val empty : metric_set
(** Empty metric set *)

val singleton : metric_type -> float -> metric_set
(** Create a metric set with a single entry *)

val of_alist_exn : (metric_type * float) list -> metric_set
(** Create from association list. Raises if duplicate keys. *)

val merge : metric_set -> metric_set -> metric_set
(** Merge two metric sets. Later values override earlier ones. *)

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

(** {1 Formatting} *)

val format_metric : metric_type -> float -> string
(** Format a single metric for display (e.g., "Sharpe Ratio: 1.25") *)

val format_metrics : metric_set -> string
(** Format all metrics for display, one per line *)
