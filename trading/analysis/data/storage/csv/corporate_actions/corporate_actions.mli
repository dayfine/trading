(** Per-symbol corporate-action files: [dividends.csv] and [splits.csv].

    Both files live next to the symbol's [data.csv], in the directory given by
    {!Csv.Csv_storage.symbol_data_dir}:

    {v
      <data_dir>/<L1>/<L2>/<SYM>/dividends.csv   ex_date,unadjusted_amount,adjusted_amount
      <data_dir>/<L1>/<L2>/<SYM>/splits.csv      date,factor
    v}

    An unknown [unadjusted_amount] is an empty cell.

    {1 Why this exists}

    Dividend crediting (#3137) and a split-only volume basis (#3136) need the
    vendor's recorded corporate actions, not events inferred from the ratio of
    adjusted to raw close. This module is the vendor-neutral on-disk format; the
    EODHD bulk fetcher ([fetch_corporate_actions.exe]) writes it.

    {1 Format}

    - One header line, then one row per event, sorted ascending by date.
    - Dates are ISO [YYYY-MM-DD]. Floats are written in their shortest exact
      round-trip form, so a write followed by a read returns equal values.
    - A header-only file means "fetched; the vendor recorded no events". A
      missing file means "never fetched". Readers keep the two apart.

    Writes go through a temporary file and a rename, so a reader never sees a
    half-written file, and writing the same events twice leaves byte-identical
    files. *)

open Core

type dividend = {
  ex_date : Date.t;  (** Ex-dividend date. *)
  unadjusted_amount : float option;
      (** Cash actually paid per share held on [ex_date], in the quote currency:
          the amount to credit against raw prices. [None] when the vendor did
          not report it. *)
  adjusted_amount : float;
      (** The same dividend restated for every later split (EODHD rounds it to
          five decimals, so it loses precision on old, heavily split names). *)
}
[@@deriving show, eq]
(** One cash dividend. *)

type split = {
  date : Date.t;  (** Ex-date of the split. *)
  factor : float;
      (** [new_shares /. old_shares]: [4.0] for a 4:1 forward split, [0.2] for a
          1:5 reverse split. Same convention as [Eodhd.Splits_endpoint.split].
      *)
}
[@@deriving show, eq]
(** One split. *)

val dividends_path : data_dir:Fpath.t -> string -> Fpath.t
(** [dividends_path ~data_dir symbol] is the path of [symbol]'s [dividends.csv].
    Pure path computation. *)

val splits_path : data_dir:Fpath.t -> string -> Fpath.t
(** [splits_path ~data_dir symbol] is the path of [symbol]'s [splits.csv]. Pure
    path computation. *)

val write_dividends :
  data_dir:Fpath.t -> string -> dividend list -> unit Status.status_or
(** [write_dividends ~data_dir symbol divs] writes [divs] (sorted by [ex_date])
    to {!dividends_path}, creating the symbol directory if needed and replacing
    any existing file. An empty list writes a header-only file. Returns
    [Internal] on an I/O failure. *)

val write_splits :
  data_dir:Fpath.t -> string -> split list -> unit Status.status_or
(** [write_splits ~data_dir symbol splits] is {!write_dividends} for
    [splits.csv], sorted by [date]. *)

val read_dividends :
  data_dir:Fpath.t -> string -> dividend list Status.status_or
(** [read_dividends ~data_dir symbol] reads [symbol]'s [dividends.csv].

    - [NotFound] when the file does not exist (never fetched).
    - [Ok []] for a header-only file (fetched, no dividends).
    - [Invalid_argument] for a wrong header or a malformed row, naming the file
      and the row. *)

val read_splits : data_dir:Fpath.t -> string -> split list Status.status_or
(** [read_splits ~data_dir symbol] is {!read_dividends} for [splits.csv]. *)

val has_both_files : data_dir:Fpath.t -> string -> bool
(** [has_both_files ~data_dir symbol] is [true] iff both [dividends.csv] and
    [splits.csv] exist for [symbol]. The fetcher uses it to skip symbols already
    fetched. *)
