(** Client for Robert Shiller's monthly S&P composite dataset.

    Authority: [dev/notes/deep-history-data-pointers-2026-05-16.md] §"Shiller
    dataset" + companion memory [memory/reference_deep_history_data_sources.md].
    The canonical primary source is Shiller's [ie_data.xls] on shillerdata.com;
    we ingest via the [github.com/datasets/s-and-p-500] mirror which auto-tracks
    Shiller and exposes the same series as a pure CSV (no spreadsheet parser
    needed).

    Coverage: 1871-01 through the previous calendar month, monthly cadence. Each
    row is the 1st of a month. Recent months (typically the most recent 3-12
    depending on Shiller's release cadence) carry [0.0] sentinels for
    fundamentals (dividend / earnings / CPI / long rate) because Shiller has not
    yet released those values; only [sp_price] is reliably populated through the
    head of the series.

    This module exposes two pure functions: {!parse} (CSV body → series or
    structural error) and {!source_uri} (the URI we fetch from, exposed for
    logging / probe scripts). Live HTTP fetch lives in
    [bin/shiller_curl_fetch.ml]; this module has no IO. *)

open Core

type monthly_observation = {
  period : Date.t;
      (** First-of-month anchor (e.g. [1871-01-01] = January 1871). The Shiller
          / mirror CSV represents months as YYYY-MM-01; we preserve that
          convention. *)
  sp_price : float;
      (** Monthly S&P composite price (Cowles 1871-1925 + S&P 1926-onward,
          spliced; see Shiller's [ie_data] documentation). Always populated for
          every row in the mirror. *)
  dividend : float option;
      (** Annualized monthly dividend on the S&P composite. [None] when Shiller
          has not yet released the figure for that month (mirror sentinel
          [0.0]). *)
  earnings : float option;
      (** Annualized monthly earnings on the S&P composite. [None] when Shiller
          has not yet released the figure for that month (mirror sentinel
          [0.0]). *)
  cpi : float option;
      (** US BLS consumer price index. [None] when not yet released (mirror
          sentinel [0.0]). *)
  long_rate : float option;
      (** Long-term interest rate (10-year US Treasury, "Rate GS10"). [None]
          when not yet released (mirror sentinel [0.0]). *)
}
[@@deriving show, eq]
(** A single monthly observation. The five Shiller-derived columns we surface
    (price, dividend, earnings, CPI, long rate) are the minimum substantive set
    for long-horizon backtests + adjusted-close cross-validation; the mirror
    also exposes computed columns (Real Price, PE10, etc.) which we
    intentionally drop — downstream code can re-derive them deterministically
    from price + CPI + dividend. *)

type series = { observations : monthly_observation list } [@@deriving show, eq]
(** Parsed monthly series, in source order (ascending by [period]). The mirror
    CSV is ascending by date and we preserve that ordering; callers should not
    re-sort unless they need a different cadence. *)

val parse : string -> series Status.status_or
(** [parse csv] parses the raw mirror CSV body. Accepts the standard
    [Date,SP500,Dividend,Earnings,Consumer Price Index,Long Interest Rate,...]
    header (10 columns) and one row per month.

    Returns [Ok series] on success; [Error _] on structural failure (missing /
    drifted header, empty body, unparseable date, unparseable numeric, or wrong
    column count on a data row).

    Sentinel handling: a literal [0.0] in any of the four fundamental columns
    (Dividend / Earnings / CPI / Long Interest Rate) maps to [None] in the
    output. The [SP500] column is always required and any [0.0] there is
    surfaced verbatim (the mirror never emits a zero price). *)

val source_uri : Uri.t
(** [source_uri] is the public mirror URL for the Shiller monthly CSV. Pure
    constant; exposed for logging / probe / reproducibility. *)
