(** Cross-reference logic for the EODHD delisted-symbol audit.

    Companion plan: this is the offline half of P5 phase-2 — we already have a
    list of S&P 500 symbols that were *removed* from the index (sourced from
    {!Wiki_sp500.Changes_parser}) and we want to know, for each such symbol,
    whether EODHD has it in its delisted-symbol feed, in its live-symbol feed,
    or nowhere. The "live fetch" CLI flag (calling EODHD over HTTP) is left for
    a follow-up — this module operates entirely on pinned JSON fixtures. *)

(** {1 Inputs} *)

type removed_symbol = { symbol : string; effective_date : string }
[@@deriving sexp_of, equal]
(** A single "removed" event from the Wiki S&P 500 changes table, reduced to
    just the symbol and the effective date (as a free-form string — typically
    [YYYY-MM-DD] — preserved verbatim for human inspection in the report). The
    audit deliberately drops [security_name] and [reason_text] from the upstream
    {!Wiki_sp500.Changes_parser.change_event}: those fields are not needed for
    cross-referencing against EODHD, and dropping them keeps the fixture format
    trivial to hand-author. *)

type eodhd_fixture = { delisted : string list; live : string list }
[@@deriving sexp_of, equal]
(** A snapshot of EODHD's exchange-symbol-list endpoint for the US market. In
    real use this would be populated from two calls — one with [?delisted=1] and
    one without — but for offline cross-referencing we only need the set of
    ticker codes on each side. *)

(** {1 Cross-reference output} *)

type status =
  | Matched_in_eodhd_delisted  (** EODHD knows the symbol delisted. *)
  | Live_on_eodhd
      (** EODHD has the symbol in its active universe — usually means the ticker
          was reassigned (e.g. WB: Wachovia → Weibo). *)
  | Not_found  (** EODHD does not have the symbol on either side. *)
[@@deriving sexp_of, equal]

type row = { symbol : string; effective_date : string; status : status }
[@@deriving sexp_of, equal]
(** One row per audited removed-symbol. Output is sorted by [symbol] ascending
    for deterministic reports. *)

(** {1 Parsers} *)

val parse_removed_sexp : string -> removed_symbol list Status.status_or
(** Parse a sexp of the form
    [(((symbol "ACE") (effective_date "2016-01-11")) ...)]. Returns [Error] on
    structural malformation. *)

val parse_eodhd_fixture : string -> eodhd_fixture Status.status_or
(** Parse a JSON object of the form
    [{"delisted":[{"Code":"LEH",...}, ...], "live":[{"Code":"AAPL",...}, ...]}].
    Only the [Code] field of each entry is consulted; other fields are ignored
    so the fixture can be a verbatim slice of EODHD's response. *)

(** {1 Cross-referencer} *)

val cross_reference :
  removed:removed_symbol list -> eodhd:eodhd_fixture -> row list
(** Classify each [removed] symbol against [eodhd]. Output is sorted by [symbol]
    ascending. Pure. *)

(** {1 Report writer} *)

val render_markdown : row list -> string
(** Render the cross-reference output as a markdown report. The report has a
    summary line ("Matched: N / Live: M / Not-found: K") followed by a table of
    [symbol | effective_date | status] sorted by status then symbol. Pure. *)
