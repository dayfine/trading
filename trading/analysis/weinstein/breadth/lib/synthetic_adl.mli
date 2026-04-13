(** Synthetic advance/decline line computation.

    Pure functions for computing daily advance/decline breadth data from a
    universe of stock price series. No file I/O — callers load prices and write
    output. *)

type daily_counts = { advances : int; declines : int; total : int }
[@@deriving show, eq]
(** Per-date aggregated breadth counts. *)

(** {1 Symbol parsing} *)

val parse_symbols : string list -> string list
(** [parse_symbols rows] extracts ticker symbols from CSV rows (excluding the
    header). Each row is expected to have the symbol as the first
    comma-separated field. Blank symbols are skipped. *)

(** {1 Price parsing} *)

val parse_close_prices : string list -> (string * float) list
(** [parse_close_prices rows] parses CSV rows (excluding the header) into
    [(date, close)] pairs. Rows with unparseable close prices are skipped.
    Results are sorted by date ascending. The expected CSV column order is:
    date, open, high, low, close, ... *)

(** {1 Advance/decline computation} *)

val compute_daily_changes :
  min_stocks:int -> (string * float) list list -> (string * daily_counts) list
(** [compute_daily_changes ~min_stocks all_prices] computes per-date
    advance/decline counts from multiple symbol price series.

    For each symbol with at least 2 price points, each day's close is compared
    to the previous day's close. A date is included in the result only when at
    least [min_stocks] symbols report data for it. Results are sorted by date
    ascending. *)

(** {1 Statistics} *)

val pearson_correlation : float list -> float list -> float
(** [pearson_correlation xs ys] computes the Pearson correlation coefficient.
    Returns [0.0] for empty inputs or zero variance. *)

val mean_absolute_error : float list -> float list -> float
(** [mean_absolute_error xs ys] computes the mean absolute error between two
    float lists. Returns [0.0] for empty inputs. *)

(** {1 Formatting} *)

val format_date_yyyymmdd : string -> string
(** [format_date_yyyymmdd "2024-01-15"] returns ["20240115"]. Removes dashes
    from a date string. *)

val format_breadth_row : string * int -> string
(** [format_breadth_row (date, count)] formats a breadth row as
    ["YYYYMMDD, count"]. The date is converted from [YYYY-MM-DD] to [YYYYMMDD].
*)
