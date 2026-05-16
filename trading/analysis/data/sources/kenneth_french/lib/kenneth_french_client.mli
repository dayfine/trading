(** Client for the Kenneth French Data Library 5-Industry daily portfolios.

    Authority: [dev/notes/deep-history-data-pointers-2026-05-16.md] §"Kenneth
    French Data Library" + companion memory
    [memory/reference_deep_history_data_sources.md] §"Tier 1 — 50-100y deep
    history". Primary source is Kenneth French's data library at Dartmouth/Tuck,
    exposed as a ZIP-wrapped CSV.

    Coverage: 1926-07-01 through end of the previous calendar month, daily
    cadence (weekdays + business holidays excluded; the file simply skips
    non-trading days). Each row carries five daily portfolio returns (Consumer,
    Manufacturing, Hi-Tech, Health, Other) expressed as percent (e.g. [0.46] =
    0.46%, not [0.0046]).

    The Kenneth French CSV format has a two-block structure: an "Average Value
    Weighted Returns -- Daily" block followed by an "Average Equal Weighted
    Returns -- Daily" block. Both blocks span the same date range and use the
    same 5 industry headers. The file also carries a 7-line preamble (provenance
    text + missing-data legend) and a copyright line in the footer; the parser
    strips both and validates the block headers verbatim.

    This module exposes the pure {!parse} function (raw CSV body → both series
    or structural error) and the {!source_uri} constant for the canonical ZIP
    URI (logged / probed by the bin layer). Live HTTP fetch lives in
    [bin/french_curl_fetch.ml]; ZIP extraction in [bin/fetch_french_history.ml];
    this module has no IO. *)

open Core

type daily_return = {
  date : Date.t;
      (** Trading-day anchor. The Kenneth French CSV uses [YYYYMMDD] with no
          separator; we normalize to [Date.t]. Only trading days appear (the
          file simply skips weekends + market holidays). *)
  industry_returns : (string * float option) list;
      (** Industry name → daily return in percent. Industry order matches the
          source-CSV header order (Consumer, Manufacturing, Hi-Tech, Health,
          Other for the 5-Industry dataset). The list is parallel-aligned to the
          industries list on the parent {!series} and has the same length.
          [None] for any value that matched a missing-data sentinel ([-99.99] or
          [-999.99] per the file's preamble; rare-to-never in the 5-Industry
          daily dataset, but the contract holds them). *)
}
[@@deriving show, eq]
(** A single trading-day observation: one row from one of the two blocks
    (Value-Weighted or Equal-Weighted) in the source CSV. *)

type series = {
  industries : string list;
      (** Industry-name order, taken from the in-CSV column header. Both blocks
          (VW + EW) share the same industry order, so the parser surfaces a
          single list per {!series}; both VW and EW series in {!parsed} carry
          identical [industries] lists. *)
  observations : daily_return list;
      (** Observations in source order (ascending by date). The CSV is ascending
          and we preserve that ordering — downstream code can re-sort if needed.
      *)
}
[@@deriving show, eq]
(** One full daily block (Value-Weighted or Equal-Weighted) parsed out of the
    source CSV. *)

type parsed = {
  value_weighted : series;
      (** Average Value-Weighted daily returns. First block in the source CSV;
          the canonical series for portfolio backtests. *)
  equal_weighted : series;
      (** Average Equal-Weighted daily returns. Second block in the source CSV;
          useful for academic comparisons but not typical for portfolio
          construction. *)
}
[@@deriving show, eq]
(** Both daily-return blocks from a single source CSV. Both share the same
    industry order and date range; the parser asserts the industry-list equality
    but does not cross-check date alignment row-by-row (the file has been
    internally consistent across decades). *)

val parse : string -> parsed Status.status_or
(** [parse csv] parses the raw Kenneth French CSV body for the 5-Industry daily
    portfolios dataset.

    Expects the canonical structure: a 7-line preamble (provenance lines), blank
    lines, the "Average Value Weighted Returns -- Daily" header, a leading-comma
    industry header (e.g. [,Cnsmr,Manuf,HiTec,Hlth,Other]), one row per trading
    day, blank lines, the "Average Equal Weighted Returns -- Daily" header +
    identical industry header + identical cadence of data rows, then a trailing
    copyright line.

    Returns [Ok parsed] on success; [Error _] on structural failure: missing /
    drifted block header, missing industry header, empty body, unparseable date,
    unparseable numeric, wrong column count on any data row, or industry-name
    disagreement between the two blocks. *)

val source_uri : Uri.t
(** [source_uri] is the public ZIP URI for the 5-Industry daily portfolios on
    the Dartmouth/Tuck server. Pure constant; exposed for logging / probe /
    reproducibility. *)
