(** Per-variant metric metadata + formatting helpers.

    Carved out of {!Metric_types} so the enum file stays under the file-length
    limit. The lookup function and formatting helpers used to live there; this
    module is now their authoritative home. Consumers should import this module
    by name (e.g. [Metric_info_registry.format_metric]) rather than relying on
    aliases. *)

(** Unit of measurement, used for formatting per-variant. *)
type metric_unit =
  | Dollars  (** Monetary value in dollars *)
  | Percent  (** Percentage value (0-100 scale) *)
  | Days  (** Time duration in days *)
  | Count  (** Discrete count *)
  | Ratio  (** Dimensionless ratio *)
[@@deriving show, eq]

type metric_info = {
  display_name : string;  (** Human-readable name *)
  description : string;  (** Brief explanation *)
  unit : metric_unit;  (** Unit for formatting *)
}
(** Metadata about a metric type *)

val get_metric_info : Metric_types.metric_type -> metric_info
(** Look up display info for a metric type. Total — every variant has an entry.
*)

val format_metric : Metric_types.metric_type -> float -> string
(** Format a single metric for display (e.g., "Sharpe Ratio: 1.25"). *)

val format_metrics : Metric_types.metric_set -> string
(** Format all metrics in a set for display, one per line. *)
