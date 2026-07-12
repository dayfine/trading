(** Parsing + loading of a run's artifacts and the per-symbol bar store. *)

open Core
open Validator_types

val parse_trades_csv : string -> trade_row list
(** Parse [trades.csv] at [path]; malformed rows are dropped. *)

val parse_open_positions_csv : string -> open_row list
(** Parse [open_positions.csv] at [path]; malformed rows are dropped. *)

val load_audit_lookup : string -> trade_row -> entry_context option
(** [load_audit_lookup path] parses [trade_audit.sexp] and returns a lookup from
    a {!trade_row} to its {!entry_context} (keyed by [(symbol, entry_date)]).
    Returns an always-[None] lookup when the file cannot be read. *)

val load_bars : data_dir:string -> run_end:Date.t -> string -> bars option
(** [load_bars ~data_dir ~run_end] returns a memoised per-symbol bar loader over
    the CSV store rooted at [data_dir]. Bars past [run_end] are excluded.
    Returns [None] for symbols that fail to load. *)
