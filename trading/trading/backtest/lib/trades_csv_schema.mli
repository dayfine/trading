(** Reader-side column addressing for [trades.csv].

    {!Trade_context.csv_header_fields} / {!Trade_context.csv_row_fields} are the
    writer side of the trailing per-trade context block; this module is the
    reader side of it.

    Consumers that re-read a run's [trades.csv] from disk (the trade-audit
    report, the optimal-strategy artefact loader) need the [position_id] cell so
    they can join a row back to its {!Trade_audit.audit_record} exactly, the way
    {!Trade_context} does in-process. They cannot hardcode its index: it is a
    {b trailing} column, and those readers deliberately tolerate further
    trailing columns being appended by later schema revisions, so a fixed index
    silently starts reading a neighbouring cell the next time the writer grows.
    Resolving by {b name} against the file's own header keeps the reader honest
    — it either finds the column or reports its absence. Silently reading the
    wrong cell is worse than reading nothing. *)

val position_id_column_name : string
(** The [trades.csv] column name carrying the strategy position ID. Shared with
    the writer-side {!Trade_context.csv_header_fields} so the two cannot drift.
*)

type t
(** Column positions recovered from one [trades.csv] header line. *)

val of_header_line : string -> t
(** Parse a [trades.csv] header line. A header with no [position_id] column
    (every layout that predates the column, including the legacy 12-column one)
    yields a value behaving like {!legacy}. *)

val legacy : t
(** The schema of a layout that carries no [position_id] column at all.
    {!position_id_of_cells} always returns [None] against it. Parsers for the
    legacy row layout use this explicitly, rather than relying on an index
    lookup happening to miss. *)

val position_id_of_cells : t -> string list -> string option
(** Read the [position_id] cell out of one already-split [trades.csv] data row.

    Returns [None] — never a wrong cell, never [Some ""] — when any of: the
    schema has no [position_id] column; the row is shorter than that column's
    index (a row written before the column existed); or the cell is empty (the
    canonical missing-data sentinel {!Trade_context.csv_row_fields} writes for
    [None]). Surrounding whitespace is stripped. *)
