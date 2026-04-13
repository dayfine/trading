(** Synthetic advance/decline line computation.

    Pure functions for computing daily advance/decline breadth data from a
    universe of stock price series. No file I/O — callers load prices and write
    output. *)

type daily_counts = { advances : int; declines : int; total : int }
[@@deriving show, eq]
(** Per-date aggregated breadth counts. *)

(** {1 Advance/decline computation} *)

val compute_daily_changes :
  min_stocks:int -> (string * float) list list -> (string * daily_counts) list
(** [compute_daily_changes ~min_stocks all_prices] computes per-date
    advance/decline counts from multiple symbol price series.

    For each symbol with at least 2 price points, each day's close is compared
    to the previous day's close. A date is included in the result only when at
    least [min_stocks] symbols report data for it. Results are sorted by date
    ascending. *)

(** {1 Validation} *)

type validation_result = {
  overlap_count : int;
  correlation : float;
  mae : float;
}
[@@deriving show, eq]
(** Result of comparing synthetic breadth data against golden data. *)

val validate_against_golden :
  synthetic:int Core.Map.M(Core.String).t ->
  golden:int Core.Map.M(Core.String).t ->
  validation_result
(** [validate_against_golden ~synthetic ~golden] compares synthetic breadth
    counts against golden reference data on overlapping dates. Returns
    correlation, mean absolute error, and overlap count. Returns zeros when
    there are no overlapping dates. *)
