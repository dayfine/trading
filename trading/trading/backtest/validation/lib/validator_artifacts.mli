(** Parsing + loading of a run's artifacts and the per-symbol bar store. *)

open Core
open Validator_types

val parse_trades_csv : string -> trade_row list
(** Parse [trades.csv] at [path]; malformed rows are dropped. *)

val parse_open_positions_csv : string -> open_row list
(** Parse [open_positions.csv] at [path]; malformed rows are dropped. *)

type audit_join_row = {
  position_id : string;
  symbol : string;
  entry_date : Date.t;
  context : entry_context;
}
(** A [trade_audit.sexp] entry leg projected to the fields the join needs. *)

val build_audit_lookup :
  audit_join_row list -> trade_row -> entry_context option
(** [build_audit_lookup rows] returns the {!trade_row} -> {!entry_context}
    lookup. A trade row carrying a [position_id] joins on it — immune to the
    audit's signal-date vs the trade's fill-date entry-date skew that made the
    old [(symbol, entry_date)] join miss 100% of rows. A legacy row without a
    [position_id] falls back to the [(symbol, entry_date)] key. *)

val load_audit_lookup : string -> trade_row -> entry_context option
(** [load_audit_lookup path] parses [trade_audit.sexp] and returns a lookup from
    a {!trade_row} to its {!entry_context} via {!build_audit_lookup}
    (position_id when the row has one, else [(symbol, entry_date)]). Returns an
    always-[None] lookup when the file cannot be read. *)

val bars_of_daily : Types.Daily_price.t list -> bars
(** [bars_of_daily daily] projects an ascending run of stored daily bars onto
    the {!Validator_types.bars} the checks read. Exposed — rather than left
    inside {!load_bars} — because it is the single site that decides each
    field's {b price basis}, and that decision is a contract V13 and V15 pull in
    opposite directions:

    - [daily.(i).open_price] / [.high] / [.low] / [.close] are the {b raw}
      (unadjusted) OHLC, because the simulator fills against those same
      [Daily_price] fields and V13 compares a [trades.csv] fill price to them.
    - [daily.(i).adjusted_close] is the {b adjusted} close, because V15's
      day-over-day ratio must be blind to ordinary splits.
    - [weekly_closes] is likewise adjusted, and [weekly_dates] keeps one bar per
      ISO week (the last), dropping a trailing week that does not end on a
      Friday.

    Populating [adjusted_close] from the raw close would silently collapse the
    two bases into one and make V15 flag every split. *)

val load_bars : data_dir:string -> run_end:Date.t -> string -> bars option
(** [load_bars ~data_dir ~run_end] returns a memoised per-symbol bar loader over
    the CSV store rooted at [data_dir]. Bars past [run_end] are excluded.
    Returns [None] for symbols that fail to load. *)
