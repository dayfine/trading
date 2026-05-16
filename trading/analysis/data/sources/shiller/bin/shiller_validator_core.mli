(** Pure cross-validation logic for Shiller monthly S&P composite vs. EODHD
    SP500 index (e.g. [GSPC.INDX]) adjusted-close.

    Authority: [dev/notes/deep-history-data-pointers-2026-05-16.md] §"Shiller
    dataset" — the validation use case is pinning EODHD's adjusted-close
    construction against Shiller's independently-built monthly composite over
    the overlap window. Drift indicates a silent split/dividend revision on one
    side.

    {b Alignment caveat — read before interpreting drift:}

    Shiller's monthly price is the {i monthly average of daily closing prices}
    (per his [ie_data] documentation), while this validator pairs each Shiller
    month with the {i last trading day} of that calendar month in the EODHD
    cache. The two are not identically defined; in high-volatility months the
    average-vs-month-end spread can be 5-20% even when both sources are
    internally consistent.

    Persistent monotone drift in {b recent} months is the signature we care
    about — that points at a vendor adjusted-close revision (split or dividend
    re-statement). Large bidirectional drift in {b historical} months mostly
    reflects intra-month volatility under the average-vs-month-end mismatch and
    is structural, not a bug.

    The module is pure: no IO. The companion executable [shiller_validator.ml]
    handles file IO + CLI wiring. *)

open! Core

type drift_row = {
  period : Date.t;
      (** Month anchor (first-of-month, matching Shiller's convention). The
          EODHD bar paired with this period is the last trading-day bar whose
          calendar date falls in this month. *)
  shiller_sp_price : float;  (** Shiller's monthly S&P composite price. *)
  eodhd_monthly_adj_close : float;
      (** EODHD's adjusted-close on the last trading day of the month — the
          natural month-end pairing for a monthly Shiller anchor. *)
  rel_diff : float;
      (** [(eodhd_monthly_adj_close - shiller_sp_price) / shiller_sp_price].
          Signed: positive means EODHD reads higher than Shiller. The Shiller
          price is the denominator because it is the reference series. *)
}
[@@deriving show, eq]
(** A single aligned month with its computed relative drift. *)

type stats = {
  n_compared : int;  (** Total months in the overlap. *)
  n_flagged : int;
      (** Months whose absolute relative diff exceeds the threshold. *)
  mean_abs_rel_diff : float;
      (** Mean of [|rel_diff|] across all compared months. [0.0] when
          [n_compared = 0]. *)
  stdev_abs_rel_diff : float;
      (** Population (not sample) standard deviation of [|rel_diff|]. [0.0] when
          [n_compared <= 1]. *)
  max_abs_rel_diff : float;
      (** Largest [|rel_diff|] across all compared months. [0.0] when
          [n_compared = 0]. *)
}
[@@deriving show, eq]
(** Summary statistics for an overlap window. *)

type report = {
  threshold : float;
      (** The [|rel_diff|] cutoff used to mark a month as flagged. *)
  overlap_first : Date.t option;
      (** First month in the overlap window, [None] when overlap is empty. *)
  overlap_last : Date.t option;
      (** Last month in the overlap window, [None] when overlap is empty. *)
  stats : stats;
  rows : drift_row list;  (** All aligned months, in ascending date order. *)
  top_drift : drift_row list;
      (** The top-N months by [|rel_diff|], descending. The cap is set by
          {!build_report}'s [~top_n] argument. *)
}
[@@deriving show, eq]
(** Full validation report — the value the executable persists as Markdown. *)

val resample_daily_to_monthly :
  Types.Daily_price.t list -> (Date.t * float) list
(** [resample_daily_to_monthly bars] groups [bars] by calendar (year, month) and
    emits one [(period, adjusted_close)] per group, where [period] is the FIRST
    of the month and [adjusted_close] is the [adjusted_close] of the LAST bar in
    that month (the last trading day — which is the last business day with a bar
    in the cache).

    Input is assumed to be sorted ascending by date (the EODHD cache always is).
    Output is in ascending order by [period]. An empty input produces an empty
    output. *)

val build_drift_rows :
  shiller:Shiller.Shiller_client.monthly_observation list ->
  eodhd_monthly:(Date.t * float) list ->
  drift_row list
(** [build_drift_rows ~shiller ~eodhd_monthly] aligns the two series on period
    (first-of-month for both) and emits a [drift_row] for every month present in
    BOTH inputs. Months that exist in only one are silently dropped — that is
    the definition of "overlap window".

    Both inputs are assumed to be in ascending date order. The output is in
    ascending date order. *)

val compute_stats : threshold:float -> drift_row list -> stats
(** [compute_stats ~threshold rows] summarizes the drift distribution.

    [threshold] is the [|rel_diff|] cutoff for flagging; only [stats.n_flagged]
    depends on it. *)

val build_report :
  shiller:Shiller.Shiller_client.monthly_observation list ->
  eodhd_monthly:(Date.t * float) list ->
  threshold:float ->
  top_n:int ->
  report
(** [build_report ~shiller ~eodhd_monthly ~threshold ~top_n] is the full
    pipeline: align, compute stats, pick the top [top_n] months by [|rel_diff|].

    [threshold] is a relative-diff cutoff, e.g. [0.005] = 0.5%. Must be
    non-negative. [top_n] caps the [top_drift] list. *)

val format_markdown_report : report -> string
(** [format_markdown_report r] renders [r] as a human-readable Markdown document
    (header + summary table + top-N table). The output is suitable for writing
    to [dev/data/shiller/validation_report.md]. *)

val parse_shiller_derived_csv :
  string -> Shiller.Shiller_client.monthly_observation list Status.status_or
(** [parse_shiller_derived_csv body] parses the CSV produced by
    [fetch_shiller_history.exe] (6 columns:
    [period,sp_price,dividend,earnings,cpi,long_rate]).

    Returns [Error _] on header drift, empty body, or a malformed row. Empty
    fields in the four optional columns map to [None]. *)
