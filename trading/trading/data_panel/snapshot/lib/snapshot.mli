(** In-memory per-(symbol, day) snapshot row.

    A {!t} is one row in the daily-snapshot warehouse: the precomputed indicator
    values for one symbol on one trading day, under a single
    {!Snapshot_schema.t}. Phase A is the type definition + sexp round-trip;
    Phase B (offline pipeline) is responsible for actually populating these from
    the per-symbol CSV history; Phase C (runtime) consumes them via mmap'd file
    format. See [dev/plans/daily-snapshot-streaming-2026-04-27.md].

    The [values] array is column-aligned to [schema.fields]: index [i] in
    [values] corresponds to field [List.nth_exn schema.fields i]. Reads should
    go through {!get} or {!index_of}, never raw indexing. *)

type t = {
  schema : Snapshot_schema.t;
      (** The schema this snapshot row was produced under. The
          [schema.schema_hash] is what the file-format layer uses to detect
          version skew between a serialized snapshot and the runtime's expected
          schema. *)
  symbol : string;  (** Universe symbol, e.g. ["AAPL"]. *)
  date : Core.Date.t;  (** The trading day this row describes. *)
  values : float array;
      (** Float64 indicator values, one per field in [schema.fields]. Length
          must equal [Snapshot_schema.n_fields schema]; constructors enforce
          this. [Float.nan] is the canonical "value unknown / not yet
          computable" marker (e.g. ATR-14 on day < 14 of a symbol's history). *)
}
[@@deriving sexp]

val create :
  schema:Snapshot_schema.t ->
  symbol:string ->
  date:Core.Date.t ->
  values:float array ->
  t Status.status_or
(** [create ~schema ~symbol ~date ~values] constructs a snapshot row, validating
    that [Array.length values = Snapshot_schema.n_fields schema]. Returns
    [Error Invalid_argument] on width mismatch, empty symbol, or width-mismatch.
*)

val get : t -> Snapshot_schema.field -> float option
(** [get t f] returns the cell for field [f] in this snapshot, or [None] if [f]
    is not in [t.schema.fields]. Returns [Some Float.nan] when the value is
    present but not computable for this (symbol, day). *)

val index_of : t -> Snapshot_schema.field -> int option
(** [index_of t f] is [Snapshot_schema.index_of t.schema f] — exposed for hot
    paths that want to lift the lookup outside an inner loop. *)
