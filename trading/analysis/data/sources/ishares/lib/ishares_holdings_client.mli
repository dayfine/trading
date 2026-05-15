(** Client for iShares ETF holdings CSV (e.g. IWV — Russell 3000).

    Companion plan: [dev/plans/iwv-scraper-2026-05-16.md] §PR-A. The Phase 1.4
    URL probe ([dev/notes/phase1.4-iwv-url-probe-2026-05-16.md]) established
    that the iShares product endpoint serves a 15-column CSV with a stable
    header across 2006-09-29 to 2026-05-08.

    This module exposes two pure functions: {!parse} (CSV body → parsed snapshot
    or sentinel) and {!build_uri} (asOfDate → request URI). Live HTTP fetch
    ([Cohttp_async]-based) is deferred to PR-C of the IWV stack. Tests cover the
    parser against pinned CSV fixtures under [test/data/]; the HTTP layer is
    verified by hand at probe time. *)

open Core

type holding = {
  ticker : string;
  name : string;
  sector : string;
  asset_class : string;
  market_value : float;
  weight_pct : float;
  notional_value : float;
  quantity : float;
  price : float;
  location : string;
  exchange : string;
  currency : string;
  fx_rate : float;
  market_currency : string;
  accrual_date : string;
}
[@@deriving show, eq]
(** A single holdings row, flattening the 15-column iShares schema. Era quirks
    (handled verbatim by {!parse}):

    - Pre-2012: [sector] / [market_currency] may be ["-"]; rows ascend by
      [market_value]; includes cross-listings (LSE / XETRA).
    - 2012-04-30 onward: [sector] populated; rows descend by [market_value];
      futures hedges and a USD cash row appear at end-of-data.
    - All eras: a [ticker] of ["-"] denotes an un-tickered position (rights,
      escrows) and is preserved verbatim. Downstream filtering belongs to the
      membership-replay layer (PR-B). *)

type snapshot = { as_of : Date.t; holdings : holding list }
[@@deriving show, eq]
(** Parsed holdings snapshot. [as_of] is parsed from the "Fund Holdings as of"
    metadata row (line 2). [holdings] preserves source order; callers must not
    assume an ordering. *)

(** Result of parsing an iShares CSV body. iShares returns HTTP 200 even when no
    data is available; non-business days, holidays, and pre-2006-09-29 dates
    surface as [No_data_sentinel] via the line-2 ["-"] template. *)
type parse_outcome = No_data_sentinel | Parsed of snapshot
[@@deriving show, eq]

val parse : string -> parse_outcome Status.status_or
(** [parse csv] parses the raw response body. Accepts optional UTF-8 BOM, the
    9-line preamble, the 15-column header on line 10, and one comma-separated
    row per holding.

    Returns [Ok No_data_sentinel] when line 2 contains the ["-"] sentinel;
    [Ok (Parsed _)] when the response carries holdings; [Error _] only on
    structural failure (missing or drifted header, unparseable [as_of] date, or
    wrong column count on a data row).

    The parser is era-agnostic: it does not filter on [asset_class] or
    [location], does not drop ["-"] tickers, and does not normalise sector
    labels. Those concerns belong to PR-B and PR-D. *)

val build_uri : as_of:Date.t -> Uri.t
(** [build_uri ~as_of] constructs the iShares Russell 3000 ETF (IWV) holdings
    URL for the given [as_of] date. The pattern is the verified shape from the
    Phase 1.4 URL probe:

    {v
    https://www.ishares.com/us/products/239714/ishares-russell-3000-etf/
      1467271812596.ajax?fileType=csv&fileName=IWV_holdings
      &dataType=fund&asOfDate=YYYYMMDD
    v}

    Future PRs generalise this to IWB / IWM by parameterising the product
    identifiers; PR-A only ships IWV. *)
