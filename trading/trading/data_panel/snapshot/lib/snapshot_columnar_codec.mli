(** Low-level on-disk encoding primitives for the columnar mmap format
    ({!Snapshot_columnar}).

    Holds the layout constants, the date-to-epoch-days layer, the file [Header]
    block codec, and the little-endian {b byte-offset accessors} that read
    individual cells out of a whole-file [Bigstring] mapping.

    The reader maps each file as {b one} [Bigstring] (one virtual-memory area)
    and slices cells out by computed byte offset — rather than mapping each
    column as its own typed [Bigarray] view. Collapsing the ~14 per-column maps
    to one whole-file map keeps the VMA count bounded under a high handle count
    (the Rosetta x86-64 translator exhausts its mapping bookkeeping well before
    the Linux [vm.max_map_count] limit).

    Split out of {!Snapshot_columnar} so the latter reads as the
    writer/reader/reconstruction logic and stays within the file-length limit;
    this module is the mechanical byte layer it builds on. See the
    {!Snapshot_columnar} docstring for the full on-disk layout. *)

val magic : string
(** The 8-byte leading magic ["SNAPCOL1"] that gates a v2 file from a v1 sexp
    file (or any other content) at open time. *)

val magic_len : int
(** Byte length of {!magic} (8). *)

val format_version : int
(** The on-disk format version this codec writes and accepts (1). *)

val int32_bytes : int
(** Byte width of an [int32] cell (4) — the date column and length prefixes. *)

val float64_bytes : int
(** Byte width of a [float64] cell (8) — every value-column cell. *)

val date_to_epoch_days : Core.Date.t -> int
(** [date_to_epoch_days d] is [Date.diff d 1970-01-01]: exact pure-day
    arithmetic, so the round-trip with {!epoch_days_to_date} is exact. *)

val epoch_days_to_date : int -> Core.Date.t
(** Inverse of {!date_to_epoch_days}. *)

(** The fixed-size header block written after the [magic] + [header_len] prefix,
    kept separate from the raw column blocks so the payload stays mmap-able.
    Encoded with a small hand-rolled little-endian scheme: three [int32] scalars
    followed by two length-prefixed strings. *)
module Header : sig
  type t = {
    format_version : int;
    n_rows : int;
    n_fields : int;
    schema_hash : string;
    symbol : string;
  }

  val to_bytes : t -> Bytes.t
  (** Serializes [t] to its little-endian byte encoding. *)

  val of_bytes : Bytes.t -> t
  (** Inverse of {!to_bytes}; reads the cursor over [b] left-to-right. Raises if
      [b] is shorter than the encoding (callers read [header_len] bytes first,
      so a well-formed file never trips this). *)
end

val get_date : Core.Bigstring.t -> dates_off:int -> i:int -> int
(** [get_date bs ~dates_off ~i] is the [i]-th epoch-days date, read as an
    [int32] LE at byte offset [dates_off + i * int32_bytes] into the whole-file
    mapping [bs]. *)

val get_cell :
  Core.Bigstring.t -> cols_off:int -> n_rows:int -> col:int -> i:int -> float
(** [get_cell bs ~cols_off ~n_rows ~col ~i] is the [float64] cell at row [i] of
    column [col], read by IEEE-754 bits (so [Float.nan] round-trips) at byte
    offset [cols_off + (col * n_rows + i) * float64_bytes] into the whole-file
    mapping [bs]. The struct-of-arrays layout stores all [n_rows] cells of a
    column contiguously, hence the [col * n_rows] stride. *)

val lower_bound :
  Core.Bigstring.t -> dates_off:int -> n:int -> target:int -> int
(** [lower_bound bs ~dates_off ~n ~target] is the first index [i] in [[0, n]]
    with [get_date bs ~dates_off ~i >= target] — a standard lower-bound binary
    search over the sorted date column at [dates_off]. Used to prune a
    [read_range] to its matching row range. *)
