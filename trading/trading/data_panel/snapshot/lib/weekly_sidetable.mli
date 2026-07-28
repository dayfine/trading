(** Sparse per-symbol weekly resistance side-table (sketch v5, PR 1 of 4).

    The resistance information content of a symbol is just its trailing weekly
    bars — one [(week_end_date, mid, high)] point per week, ~520 for a 10y
    window, growing ~52/yr. The v4 warehouse instead materialized, for every
    trading day, an 80-cell histogram of those same weekly bars re-anchored to
    that day's close (~350x redundant), so a top-3000 warehouse did not fit the
    Docker VM. This module is the compact on-disk replacement: one [.weekly]
    side-file per symbol next to its [.snap] panel, holding the condensed weekly
    series over the full (deep-fed) history.

    {2 On-disk layout}

    A single fixed-width little-endian binary file (no sexp on the data path —
    same discipline as {!Snapshot_columnar}):

    {v
      bytes 0..7        magic "WKSIDE01"
      bytes 8..11       format_version : int32-LE
      bytes 12..15      count : int32-LE  (number of entries)
      then count * 20 bytes, each entry:
        4 bytes  week_end_date : int32-LE epoch-days (Date.diff d 1970-01-01)
        8 bytes  mid           : float64-LE (IEEE-754 bits)
        8 bytes  high          : float64-LE (IEEE-754 bits)
    v}

    The [format_version] byte lets PR 2+ evolve the on-disk shape; readers
    reject a version they do not recognize. Dates use the same epoch-days
    convention as {!Snapshot_columnar} so the two files agree bit-for-bit on how
    a [Date.t] serializes.

    {2 Semantics (built by [Weekly_sidetable_builder], consumed by the PR 2
    reader)}

    Each entry is one weekly bar of the symbol's history:
    - [week_end_date]: the date of the last daily bar in that ISO week;
    - [mid = (weekly_high +. weekly_low) /. 2.0];
    - [high = weekly_high].

    {b Basis (#2133).} The [mid] / [high] price basis is recorded by the
    warehouse manifest's [weekly_sidetable_format_hash], not by this format: a
    warehouse stamped with {!format_hash_raw_basis} carries RAW weekly high/mid
    (the pre-migration builder, matching the v1 resistance mapper), while one
    stamped with {!format_hash} carries split/dividend-ADJUSTED high/mid (the
    #2133 builder rescales onto the adjusted basis so a split inside the
    lookback window no longer hides or fabricates supply). The reader anchors
    the sketch at the raw [Close] column for the raw basis and at
    [Adjusted_close] for the adjusted basis; the on-disk byte layout is
    identical for both.

    The trailing entry is the current (possibly partial) week as of the last
    daily bar — the same [include_partial_week:true] aggregation the resistance
    sketch consumes. Append-only in intent (an incremental rebuild appends newly
    finalized weeks and rewrites the trailing partial); this module only owns
    the format, not the incremental writer. *)

type entry = {
  week_end_date : Core.Date.t;
      (** Date of the last daily bar in the entry's ISO week. *)
  mid : float;  (** [(weekly_high +. weekly_low) /. 2.0], raw basis. *)
  high : float;  (** Raw (unadjusted) weekly high. *)
}
[@@deriving sexp, compare, equal]

val magic : string
(** The 8-byte leading magic ["WKSIDE01"] identifying a v5 weekly side-table. *)

val format_version : int
(** On-disk format version this module writes and accepts (1). *)

val format_hash_raw_basis : string
(** The pre-#2133 hash, stamped by warehouses whose side-table entries carry RAW
    weekly high/mid. Retained so the reader still recognizes and correctly
    anchors (at the raw [Close] column) side-tables produced before the basis
    migration. Never stamped on new builds — the builder stamps {!format_hash}.
*)

val format_hash : string
(** Stable hex hash identifying the {b adjusted-basis} (#2133) side-table
    format. Recorded in the warehouse manifest so a reader can detect the basis
    and gate a side-table produced under an unrecognized format. Distinct from
    {!format_hash_raw_basis} (the hashed content carries an adjusted-basis
    suffix); a {!format_version} bump moves both hashes (loud). *)

val encode : entry list -> bytes
(** [encode entries] serializes [entries] to the binary layout above, in list
    order. The empty list produces a valid header-only file (count 0). *)

val decode : bytes -> entry list Status.status_or
(** [decode bytes] parses a buffer produced by {!encode}. Returns
    [Error Internal] on a bad magic, an unsupported {!format_version}, or a
    length that does not match the declared count (loud, not silent). *)

val write_file : path:string -> entry list -> unit Status.status_or
(** [write_file ~path entries] writes [encode entries] to [path], overwriting
    any existing file. Returns [Error Internal] on a filesystem error. *)

val read_file : path:string -> entry list Status.status_or
(** [read_file ~path] reads and {!decode}s the file at [path]. Returns
    [Error Internal] on a filesystem error or any decode failure. *)
