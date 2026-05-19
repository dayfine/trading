(** Client for the Kenneth French Data Library daily industry-portfolio datasets
    (5-Industry and 49-Industry).

    Authority: [dev/notes/deep-history-data-pointers-2026-05-16.md] §"Kenneth
    French Data Library" + companion memory
    [memory/reference_deep_history_data_sources.md] §"Tier 1 — 50-100y deep
    history". Primary source is Kenneth French's data library at Dartmouth/Tuck,
    exposed as a ZIP-wrapped CSV.

    Coverage: 1926-07-01 through end of the previous calendar month, daily
    cadence (weekdays + business holidays excluded; the file simply skips
    non-trading days). Each row carries N daily portfolio returns expressed as
    percent (e.g. [0.46] = 0.46%, not [0.0046]). [N = 5] for the 5-Industry
    dataset (Consumer, Manufacturing, Hi-Tech, Health, Other); [N = 49] for the
    49-Industry dataset (Agric, Food, Soda, ... Other — the canonical Fama-
    French SIC-bucketed taxonomy).

    The Kenneth French CSV format has a two-block structure: an "Average Value
    Weighted Returns -- Daily" block followed by an "Average Equal Weighted
    Returns -- Daily" block. Both blocks span the same date range and use the
    same N industry headers. The file also carries a 7-line preamble (provenance
    text + missing-data legend) and a copyright line in the footer; the parser
    strips both and validates the block headers verbatim.

    The {!parse} function is column-count-driven: it derives the expected column
    count from the in-CSV industry header, so the same code path serves the
    5-Industry and 49-Industry datasets (and any future N-industry French daily
    dataset that shares the same two-block layout). The {!source_uri_*}
    constants expose the canonical ZIP URIs for each dataset (logged / probed by
    the bin layer). Live HTTP fetch lives in [bin/french_curl_fetch.ml]; ZIP
    extraction in [bin/fetch_french_history.ml]; this module has no IO. *)

open Core

type daily_return = {
  date : Date.t;
      (** Trading-day anchor. The Kenneth French CSV uses [YYYYMMDD] with no
          separator; we normalize to [Date.t]. Only trading days appear (the
          file simply skips weekends + market holidays). *)
  industry_returns : (string * float option) list;
      (** Industry name → daily return in percent. Industry order matches the
          source-CSV header order (Consumer, Manufacturing, Hi-Tech, Health,
          Other for the 5-Industry dataset; Agric, Food, ... Other for the
          49-Industry dataset). The list is parallel-aligned to the industries
          list on the parent {!series} and has the same length. [None] for any
          value that matched a missing-data sentinel ([-99.99] or [-999.99] per
          the file's preamble; common in the 49-Industry dataset for industries
          that did not exist in 1926, rare-to-never in the 5-Industry daily
          dataset, but the contract holds them in both). *)
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
(** [parse csv] parses the raw Kenneth French CSV body for any daily-cadence
    industry-portfolio dataset (5-Industry and 49-Industry verified; the same
    code path serves any N-industry French daily file with the canonical
    two-block layout).

    Expects the canonical structure: a 7-line preamble (provenance lines), blank
    lines, the "Average Value Weighted Returns -- Daily" header, a leading-comma
    industry header (e.g. [,Cnsmr,Manuf,HiTec,Hlth,Other] for 5-Industry or
    [,Agric,Food,Soda,Beer,Smoke,...,Other] for 49-Industry), one row per
    trading day, blank lines, the "Average Equal Weighted Returns -- Daily"
    header + identical industry header + identical cadence of data rows, then a
    trailing copyright line.

    The expected column count is derived from the industry header itself (no
    hardcoded width), so the parser scales naturally from 5 to 49 (and beyond)
    without code changes.

    Returns [Ok parsed] on success; [Error _] on structural failure: missing /
    drifted block header, missing industry header, empty body, unparseable date,
    unparseable numeric, wrong column count on any data row, or industry-name
    disagreement between the two blocks. *)

val source_uri : Uri.t
(** Deprecated alias for {!source_uri_5industry}. Retained for compatibility
    with existing callers in [bin/fetch_french_history.ml]; prefer the
    explicitly-named [source_uri_5industry] in new code. *)

val source_uri_5industry : Uri.t
(** [source_uri_5industry] is the public ZIP URI for the 5-Industry daily
    portfolios on the Dartmouth/Tuck server. Pure constant; exposed for logging
    / probe / reproducibility. *)

val source_uri_49industry : Uri.t
(** [source_uri_49industry] is the public ZIP URI for the 49-Industry daily
    portfolios on the Dartmouth/Tuck server. Pure constant; exposed for logging
    / probe / reproducibility. *)
