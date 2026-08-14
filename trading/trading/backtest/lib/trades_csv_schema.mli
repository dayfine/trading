(** Reader-side column addressing for [trades.csv].

    {!Trade_context.csv_header_fields} / {!Trade_context.csv_row_fields} are the
    writer side of the trailing per-trade context block; this module is the
    reader side of it.

    Consumers that re-read a run's [trades.csv] from disk (the trade-audit
    report, the optimal-strategy artefact loader) need the [position_id] cell so
    they can join a row back to its {!Trade_audit.audit_record} exactly, the way
    {!Trade_context} does in-process. They cannot hardcode its index.
    {!Trade_context.csv_header_fields} documents an {b append-only} discipline —
    new columns go after the existing ones, which is exactly what lets the
    positional readers named there keep pinning base-column indices. That
    discipline is a property of {i this} writer, not of the format, and it does
    not make index 19 stable: [position_id] sits {b inside} the trailing context
    block ([stop_fill_distance_pct] already follows it at index 20), and it got
    there by being slotted {b ahead of} that column. Appending strictly after
    the block is harmless; it is an insertion {b at or ahead of} [position_id] —
    by a future revision of this writer, or by any other producer of the format
    — that shifts it, and a fixed index would then silently read a neighbouring
    cell. Resolving by {b name} against the file's own header keeps the reader
    honest — it either finds the column or reports its absence. Silently reading
    the wrong cell is worse than reading nothing. *)

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
