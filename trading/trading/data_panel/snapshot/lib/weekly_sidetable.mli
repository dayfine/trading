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

    Each entry is one weekly bar of the symbol's history, {b raw (unadjusted)}
    basis matching the v1 resistance mapper:
    - [week_end_date]: the date of the last daily bar in that ISO week;
    - [mid = (weekly_high +. weekly_low) /. 2.0];
    - [high = weekly_high] (raw, not adjusted).

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

val format_hash : string
(** Stable hex hash over ([magic], [format_version]). Recorded in the warehouse
    manifest so a reader can detect and gate a side-table produced under a
    different format. Changes iff {!magic} or {!format_version} changes — a
    version bump is therefore loud (the manifest hash moves). *)

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
