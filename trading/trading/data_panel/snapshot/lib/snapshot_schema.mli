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
    behaviour for a content-addressable schema fingerprint, not a regression.

    {2 Resistance sketch columns (resistance-v2) — RETIRED from the canonical
       schema in sketch-v5 PR 4}

    These constructors ([Res_max_high_130w] / [Res_max_high_260w] /
    [Res_max_high_520w] / [Res_bars_seen] / [Res_hist]) are {b retained in the
    [field] type for decode only}: the three-generation runtime reader still reads
    older v3 (37-col) and v4 (97-col) warehouses via their own per-file manifest
    schemas, which enumerate these fields. The canonical {!all_fields} / {!default}
    NO LONGER include them (schema width back to the 13 pre-resistance columns), so
    freshly built warehouses omit the dense sketch entirely. The overhead-supply
    sketch is reconstructed on demand from the sparse [SYMBOL.weekly] side-table
    ({!Data_panel_snapshot.Weekly_sidetable}) — see
    [dev/plans/resistance-v2-supply-sketches-2026-07-15.md] and the sketch-v5
    chain. The v4 semantics below still describe how a {b legacy} warehouse's dense
    columns are laid out (what the decode path reads):

    Precomputed point-in-time overhead-supply sketches, appended after
    [Adjusted_close] (same append discipline as the OHLCV addition; a v4 warehouse
    is 97 columns: 4 scalar sketch columns + [n_hist_cells = 80] age-banded
    histogram columns). All values are weekly-cadence aggregates computed causally
    from bars up to and including the row's day — see
    [dev/plans/resistance-v2-supply-sketches-2026-07-15.md] §D1-D4 and the
    age-banded histogram (lever f, sketch v3):

    - {!Res_max_high_130w} / {!Res_max_high_260w} / {!Res_max_high_520w}:
      maximum raw weekly high over the trailing 130/260/520 weekly bars
      (including the current partial week), matching the v1 resistance
      mapper's raw-high basis. [breakout >= Res_max_high_520w] is exactly
      v1's [Virgin_territory] test over the same 520-weekly-bar window (v1:
      virgin iff no bar's high strictly exceeds the breakout, i.e.
      [max_high <= breakout] — the derived test must use [>=], not [>], to
      preserve the tie case [max_high = breakout]).
    - {!Res_bars_seen}: true count of weekly bars available up to the row's
      day, capped at 520 — the honest [Insufficient_history] input (a
      window-starved warehouse can no longer masquerade as virgin history).
    - {!Res_hist k} for [k = 0 .. n_hist_cells - 1]: {b age-banded}
      log-price histogram anchored at the row's raw close [C]. The [n_hist_cells]
      columns are laid out band-major: cell [k] holds age band
      [k / n_hist_buckets] and price bucket [k mod n_hist_buckets]. The four
      age bands (youngest first) cover a weekly-bar age relative to the row of
      [0-26w / 26-78w / 78-130w / 130-520w] (half-open; the partial current week
      is age 0). Within every band price bucket [b] counts weekly bars whose
      mid-price [(high + low) / 2] falls in
      [C * 2^(b/20), C * 2^((b+1)/20)) and whose high exceeds [C] — i.e. supply
      sitting 0..100% above the row's price, ~3.5% per band. Bars more than 2x
      above [C] are dropped (proximity-negligible; the max-high family still
      detects non-virgin at any distance). Age decay is applied at SCORE time
      by [Resistance_supply] per-band config weights, NOT baked in at build
      time, so the decay is an [Overlay_validator] axis family (no warehouse
      rebuild per value). Summing the three 0-130w bands reproduces the
      pre-lever-f age-blind 130-weekly-bar histogram exactly, and the 130-520w
      band makes older supply MEASURED rather than only floored by the max-high
      horizons.

    Sketch cells are [Float.nan] when the row's raw close is non-positive or
    non-finite (corrupt bar guard). *)
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
  | Res_max_high_130w
  | Res_max_high_260w
  | Res_max_high_520w
  | Res_bars_seen
  | Res_hist of int
[@@deriving sexp, compare, equal, show]

val n_hist_buckets : int
(** [n_hist_buckets] is the number of log-price buckets per age band in the
    {!Res_hist} histogram (20). *)

val n_age_bands : int
(** [n_age_bands] is the number of weekly-bar age bands the {!Res_hist}
    histogram is split into (4): [0-26w / 26-78w / 78-130w / 130-520w]. *)

val n_hist_cells : int
(** [n_hist_cells = n_age_bands * n_hist_buckets] is the total number of
    {!Res_hist} columns in the canonical schema (80). [Res_hist k] is canonical
    only for [0 <= k < n_hist_cells], laid out band-major (cell [k] is age band
    [k / n_hist_buckets], price bucket [k mod n_hist_buckets]); {!all_fields}
    enumerates exactly that range. *)

val all_fields : field list
(** [all_fields] is the canonical column set: the 13 indicator + OHLCV fields,
    in declaration order. It does {b not} include the retired resistance-sketch
    constructors ([Res_*]) — those remain in the {!field} type for decoding
    legacy warehouses only (see the type docstring). Used by tests and by
    {!default} to construct the canonical schema. *)

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
(** [default] is the canonical 13-field schema: every field in {!all_fields}
    order (the dense resistance-sketch columns were retired in sketch-v5 PR 4).
    The single source of truth for snapshots produced by the offline pipeline.
*)

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
