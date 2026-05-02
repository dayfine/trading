(** Snapshot field schema — what every per-(symbol, day) snapshot row contains.

    Phase A of the daily-snapshot streaming pipeline (see
    [dev/plans/daily-snapshot-streaming-2026-04-27.md] §Phasing Phase A).
    Defines the enumerable indicator fields that the offline pipeline (Phase B)
    will pre-compute and the runtime layer (Phase C) will mmap-stream.

    The schema is **order-significant**: the field list determines the binary
    column layout of [Snapshot.t.values] and the on-disk byte layout of
    [Snapshot_format] payloads. Two schemas with the same fields in different
    orders are different schemas (different [schema_hash]).

    A new field, removal, reordering, or rename produces a new [schema_hash];
    the runtime mmap-loader rejects file-vs-runtime hash mismatches loudly (no
    silent corruption — see [Snapshot_format.read]). Migration cost is a full
    corpus rebuild via [bin/build_snapshots.exe] (Phase B). *)

(** Canonical field set for daily snapshots — derived indicators plus the raw
    OHLCV scalars Phase D needs for per-tick price reads.

    Every value is a Float64 scalar (parity-gate decision, plan §Decisions).
    Variant-shaped indicators (e.g. multi-period RS) must be enumerated as
    distinct fields — there is no per-row bag.

    Field semantics — the offline pipeline is the single source of truth for how
    each is computed; the runtime simply reads the precomputed scalar:

    - {!EMA_50}: 50-period exponential moving average of the adjusted close
    - {!SMA_50}: 50-period simple moving average of the adjusted close
    - {!ATR_14}: 14-period average true range
    - {!RSI_14}: 14-period relative strength index
    - {!Stage}: Weinstein stage classification encoded as
      [1.0 | 2.0 | 3.0 | 4.0]; [Float.nan] means "not yet classifiable"
    - {!RS_line}: relative-strength line (price vs market benchmark)
    - {!Macro_composite}: macro-environment composite score
    - {!Open}: raw daily open price for the bar
    - {!High}: raw daily high price for the bar
    - {!Low}: raw daily low price for the bar
    - {!Close}: raw daily close price for the bar (unadjusted)
    - {!Volume}: raw daily share volume, cast to [float]; precision is exact for
      counts up to ~2^53, well above any realistic equity volume
    - {!Adjusted_close}: split- and dividend-adjusted close used by every
      indicator (so consumers can join indicator scalars back to the price the
      indicator was computed against)

    {2 OHLCV addition}

    Phase A originally enumerated only the seven indicator scalars. The Phase D
    engine + simulator integration discovered that the per-tick simulator needs
    raw OHLCV to price orders, and the Weinstein strategy reads OHLCV via
    [Bar_reader] for [Stage.classify] / [Volume.analyze_breakout] /
    [Resistance.analyze]. This precursor (Phase A.1) adds the six OHLCV fields
    so Phase D can land without re-introducing a parallel bar-shaped data path.

    The OHLCV fields are appended after the indicator scalars: existing column
    indices for [EMA_50 .. Macro_composite] are unchanged; the schema width
    grows from 7 to 13. The schema hash necessarily changes (it is order- and
    set-sensitive by design) — see {!compute_hash}. Pre-existing on-disk
    snapshots become unreadable under the new {!default}; the manifest's
    [schema_hash] gate will surface the mismatch loudly. This is the intended
    behaviour for a content-addressable schema fingerprint, not a regression. *)
type field =
  | EMA_50
  | SMA_50
  | ATR_14
  | RSI_14
  | Stage
  | RS_line
  | Macro_composite
  | Open
  | High
  | Low
  | Close
  | Volume
  | Adjusted_close
[@@deriving sexp, compare, equal, show]

val all_fields : field list
(** [all_fields] enumerates every variant of {!field} in declaration order. Used
    by tests and by [Snapshot_schema.default] to construct the canonical Phase-A
    schema. *)

val field_name : field -> string
(** [field_name f] returns the canonical short string name (e.g. ["EMA_50"]).
    Used for human-readable manifests and error messages — not for hashing. *)

type t = {
  fields : field list;
      (** Ordered field list. Index in this list = column index in
          [Snapshot.t.values]. Order is significant — different orderings
          produce different [schema_hash]. *)
  schema_hash : string;
      (** Lazily-cached deterministic fingerprint of [fields]. See
          {!compute_hash} for the exact algorithm. *)
}
[@@deriving sexp]
(** A schema is the ordered list of fields plus a memoized hash. Construct via
    {!create} (computes the hash) — never via record literal in production code.
*)

val create : fields:field list -> t
(** [create ~fields] builds a schema with [schema_hash] computed by
    {!compute_hash}. The empty field list is permitted (its hash is
    well-defined) but produces a schema that no real snapshot can match. *)

val default : t
(** [default] is the canonical 13-field schema: every variant of {!field} in
    declaration order ({!all_fields}). The single source of truth for snapshots
    produced by the offline pipeline. *)

val compute_hash : field list -> string
(** [compute_hash fields] returns a deterministic hex fingerprint of the ordered
    field list.

    The fingerprint is the MD5 of the canonical sexp serialization
    [fields |> [%sexp_of: field list] |> Sexp.to_string]. MD5 is used because no
    SHA-256 library is installed in the build; this is a content-address
    fingerprint for schema-version tracking, not a security primitive.

    Determinism guarantees:
    - same field list (same order) → same hash on every run, every machine
    - any reordering, addition, removal, or rename → different hash *)

val n_fields : t -> int
(** [n_fields t] returns the number of fields in [t.fields]. The expected
    column-width of every {!Snapshot.t.values} produced under [t]. *)

val index_of : t -> field -> int option
(** [index_of t f] returns the zero-based column index of [f] in [t.fields], or
    [None] if [f] is not in the schema. *)
