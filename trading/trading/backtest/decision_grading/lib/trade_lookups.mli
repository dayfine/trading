(** Per-round-trip lookups used by the [decision_grading] driver: the real exit
    reason (from [trades.csv]) and the in-trade MFE (from the trade audit). *)

open Core

val join_tolerance_days : int
(** Max calendar-day gap when joining a [trades.csv] round-trip to its audit
    record: the audit [entry_date] is the Friday decision date, the round-trip's
    is the next-trading-day fill. Value: 7. *)

val exit_reason_lookup :
  scenario_dir:string -> (string * Date.t * Date.t, string) Hashtbl.t
(** Exit-reason lookup read from [<scenario_dir>/trades.csv]'s [exit_trigger]
    column, keyed by [(symbol, entry_date, exit_date)]. Columns are located by
    header name; rows missing any of the four columns are skipped. *)

type mfe_index
(** Audit MFEs indexed by symbol. *)

val build_mfe_index : (string * Date.t * float) list -> mfe_index
(** [build_mfe_index entries] indexes [(symbol, audit_entry_date, mfe)] triples
    by symbol. *)

val find_mfe : mfe_index -> symbol:string -> entry_date:Date.t -> float option
(** MFE of the audit record for [symbol] whose entry date is nearest
    [entry_date], within {!join_tolerance_days} (inclusive). [None] when the
    symbol has no record within tolerance. *)
