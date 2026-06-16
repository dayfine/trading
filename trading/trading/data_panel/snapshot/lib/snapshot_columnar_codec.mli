(** Low-level on-disk encoding primitives for the columnar mmap format
    ({!Snapshot_columnar}).

    Holds the layout constants, the date-to-epoch-days layer, the file [Header]
    block codec, and the [map_file] helpers producing zero-copy [Bigarray]
    views.

    Split out of {!Snapshot_columnar} so the latter reads as the
    writer/reader/reconstruction logic and stays within the file-length limit;
    this module is the mechanical byte/mmap layer it builds on. See the
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

type dates_arr =
  (int32, Bigarray.int32_elt, Bigarray.c_layout) Bigarray.Array1.t
(** A zero-copy view over the on-disk sorted [int32] epoch-days date column. *)

type col_arr =
  (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array1.t
(** A zero-copy view over one on-disk [float64] value column. *)

val map_col : Core_unix.File_descr.t -> byte_pos:int -> n_rows:int -> col_arr
(** [map_col fd ~byte_pos ~n_rows] memory-maps the [float64] column block of
    [n_rows] cells starting at [byte_pos] as a zero-copy {!col_arr}. *)

val map_dates :
  Core_unix.File_descr.t -> byte_pos:int -> n_rows:int -> dates_arr
(** [map_dates fd ~byte_pos ~n_rows] memory-maps the [int32] date column of
    [n_rows] cells at [byte_pos] as a zero-copy {!dates_arr}. *)

val lower_bound : dates_arr -> n:int -> target:int -> int
(** [lower_bound dates ~n ~target] is the first index [i] in [[0, n]] with
    [dates.{i} >= target] — a standard lower-bound binary search over the sorted
    date column. Used to prune a [read_range] to its matching row range. *)
