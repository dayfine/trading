(** Pure drift-comparison logic for Stooq vs EODHD daily OHLCV.

    Pairs each EODHD bar with the Stooq observation for the same trading
    date, computes signed relative diff on Stooq [close] vs EODHD
    [adjusted_close], and emits a summary report.

    {b Why [adjusted_close] and not [close_price]:} Stooq's [Close] is
    split-adjusted (historical bars are restated whenever a split occurs);
    EODHD's [close_price] is the raw closing price as printed on the tape
    (NOT split-adjusted), while EODHD's [adjusted_close] is both
    split-adjusted AND dividend-adjusted. Comparing Stooq's split-adjusted
    [close] against EODHD's raw [close_price] would produce post-split
    ratios as massive false-positive drift (e.g. AAPL 4-for-1 split on
    2020-08-31 produces ~300% drift on pre-split dates).

    The trade-off: Stooq is split-adjusted but NOT dividend-adjusted; EODHD
    [adjusted_close] is both. Expect structural ~1-2% drift across the
    overlap window from dividend-adjustment alone. The audit signal we
    care about is {b sudden discontinuities} in the drift series (e.g. a
    cliff of >5% drift suddenly appearing across a single day boundary)
    indicating a vendor split-revision G14-class bug — not the level of
    the baseline drift itself.

    Pure module — no IO. The companion executable [stooq_drift_check.ml]
    handles file IO + CLI wiring + curl. *)

open! Core

type drift_row = {
  date : Date.t;  (** Trading date present in both series. *)
  stooq_close : float;
      (** Stooq's close (split-adjusted, dividend-unadjusted). *)
  eodhd_adj_close : float;
      (** EODHD's [adjusted_close] (split-adjusted AND dividend-adjusted). *)
  rel_diff : float;
      (** [(eodhd_adj_close - stooq_close) / stooq_close]. Signed: positive
          means EODHD reads higher than Stooq. Stooq is the denominator
          because it is the {b reference / second source} in this audit. *)
}
[@@deriving show, eq]
(** A single aligned trading day with its computed relative drift. *)

type stats = {
  n_compared : int;  (** Total days in the overlap. *)
  n_flagged : int;
      (** Days whose [|rel_diff|] exceeds the threshold. *)
  mean_abs_rel_diff : float;
      (** Mean of [|rel_diff|] across compared days. [0.0] when no overlap. *)
  max_abs_rel_diff : float;
      (** Largest [|rel_diff|] across compared days. [0.0] when no overlap. *)
}
[@@deriving show, eq]
(** Summary stats for an overlap window. *)

type report = {
  symbol : string;  (** The symbol audited (uppercase). *)
  threshold : float;
      (** The [|rel_diff|] cutoff used to mark a day as flagged. *)
  overlap_first : Date.t option;
      (** First overlap day; [None] when overlap is empty. *)
  overlap_last : Date.t option;
      (** Last overlap day; [None] when overlap is empty. *)
  stooq_only_count : int;
      (** Stooq days absent from EODHD (informational; bars not compared). *)
  eodhd_only_count : int;
      (** EODHD days absent from Stooq (informational; bars not compared). *)
  stats : stats;
  flagged_rows : drift_row list;
      (** Days whose [|rel_diff|] exceeded the threshold, sorted descending
          by [|rel_diff|]. The full row list is intentionally NOT exposed so
          large overlaps don't bloat the report; if you need all rows,
          consume {!build_drift_rows} directly. *)
}
[@@deriving show, eq]
(** Full drift report for a single symbol. *)

val build_drift_rows :
  stooq:Stooq.Stooq_client.daily_observation list ->
  eodhd:Types.Daily_price.t list ->
  drift_row list
(** [build_drift_rows ~stooq ~eodhd] joins the two series on [date] and emits
    one [drift_row] per shared trading day. Both inputs are assumed to be in
    ascending date order. Output is in ascending date order.

    Dates present in only one source are silently dropped — that defines the
    overlap window. *)

val compute_stats : threshold:float -> drift_row list -> stats
(** [compute_stats ~threshold rows] summarizes the drift distribution. Only
    [n_flagged] depends on [threshold]. *)

val build_report :
  symbol:string ->
  stooq:Stooq.Stooq_client.daily_observation list ->
  eodhd:Types.Daily_price.t list ->
  threshold:float ->
  report
(** [build_report ~symbol ~stooq ~eodhd ~threshold] is the full pipeline:
    align, compute stats, collect flagged rows (descending |rel_diff|),
    surface stooq-only / eodhd-only date counts.

    [threshold] is a relative-diff cutoff, e.g. [0.005] = 0.5%. *)

val format_text_report : report -> string
(** [format_text_report r] renders [r] as a human-readable plaintext summary
    for stdout. Includes header line, overlap range, stats, flagged-row
    counts, and the top 10 flagged days. *)
