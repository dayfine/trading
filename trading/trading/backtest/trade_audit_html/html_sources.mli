(** Low-level readers for the extra scenario-directory artefacts the markdown
    path does not consume — the equity curve, open positions, final marks, the
    per-round-trip [quantity] / [stop_trigger_kind] columns, and the summary
    KPIs. Pure IO returning primitive values; {!Html_report.load} turns them
    into the derived series it needs. All readers tolerate a missing/empty file
    by returning an empty result. *)

open Core

val read_equity_curve : string -> (Date.t * float) list
(** [(date, portfolio_value)] rows from [equity_curve.csv]. *)

val read_final_prices : string -> (string * float) list
(** [(symbol, price)] end-of-run marks from [final_prices.csv]. *)

val read_open_positions :
  string -> (string * string * Date.t * float * float) list
(** [(symbol, side, entry_date, entry_price, quantity)] from
    [open_positions.csv]. *)

val key : string -> string -> string -> string
(** [key symbol entry_date exit_date] — the composite join key used by
    {!read_trade_extras} and by {!Html_report}'s row/interval joins. Dates are
    the CSV / {!Core.Date.to_string} form. *)

val read_trade_extras : string -> (string * (float * string)) list
(** [({!key} symbol entry exit, (quantity, stop_trigger_kind))] from
    [trades.csv], via header-name lookup (robust to the trailing schema columns
    trades.csv has accrued). *)

type summary = {
  initial_cash : float option;
  final_portfolio_value : float option;
  metrics : (string * float) list;
      (** Metric name (short suffix, e.g. ["sharperatio"]) to value. *)
  stale_held : string list;
}
(** The subset of [summary.sexp] the HTML report reads. Absent file / fields
    yield [None] / empty. *)

val read_summary : string -> summary
(** Parse [summary.sexp]; returns empty fields on a missing/malformed file. *)
