(** Parser for the Wikipedia "Selected changes to the list of S&P 500
    components" table.

    The companion plan is
    [dev/plans/wiki-eodhd-historical-universe-2026-05-03.md] §PR-A. This module
    is a pure-function HTML parser: input is a string holding the
    [<table id="changes">] element from
    [https://en.wikipedia.org/wiki/List_of_S%26P_500_companies], output is the
    parsed list of change events in source order (most-recent first, as the
    table is rendered).

    No I/O is performed here; refresh of the pinned HTML snapshot is a manual
    operation handled by the future [build_universe.exe] CLI (PR-C). *)

type ticker_id = { symbol : string; security_name : string }
[@@deriving show, eq]
(** A ticker identifier. [symbol] is the EODHD-style short ticker (e.g. ["CASY"]
    or ["BRK.B"] — preserved verbatim from the Wikipedia "Ticker" column).
    [security_name] is the human-readable security name (e.g. ["Casey's"] or
    ["Anheuser Busch"]) — extracted from the linked [<a>] inner text when
    present, otherwise from the plain [<td>] text. *)

type change_event = {
  effective_date : Core.Date.t;
  added : ticker_id option;
  removed : ticker_id option;
  reason_text : string;
}
[@@deriving show, eq]
(** A single addition/removal event. Wikipedia rows can have:
    - both [added] and [removed] populated (the common case: a 1-for-1 swap),
    - only [added] populated (a spin-off or a delayed companion to an earlier
      removal),
    - only [removed] populated (a delisting or an unmatched removal).
      [effective_date] is the parsed "Effective Date" column. [reason_text] is
      the free-text "Reason" column with footnote markers ([<sup>...</sup>])
      stripped and HTML entities decoded; the original wording is preserved
      verbatim for downstream classification. *)

val parse : string -> change_event list Status.status_or
(** [parse html] parses the [<table id="changes">] element from the Wikipedia
    S&P 500 page and returns the list of change events in source order.

    The parser is robust to:
    - footnote markers ([<sup id="cite_ref-..." class="reference">...</sup>]) —
      stripped from all extracted text;
    - empty Added/Removed cells (returned as [None]);
    - missing wikilinks on the security name (the cell may contain plain text
      rather than an [<a>] anchor — both forms are accepted);
    - [class="mw-redirect"] on inner anchors (treated identically to a normal
      anchor);
    - trailing newlines and whitespace inside [<td>] cells;
    - HTML entities ([&amp;], [&#39;], [&quot;], [&nbsp;]) — decoded.

    The two header [<tr>] rows (the colspan/rowspan outer header and the inner
    "Ticker / Security / Ticker / Security" sub-header) are skipped.

    Returns [Error] only on structural failure: missing [<table id="changes">]
    element, fewer than 6 [<td>] cells in a data row, or an unparseable
    "Effective Date". *)
