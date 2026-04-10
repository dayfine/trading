(** Symbol -> GICS sector lookup loaded from [data/sectors.csv].

    The CSV is produced by the Python scraper at
    [analysis/scripts/fetch_sectors/fetch_sectors.py], which unions the S&P 500
    / 400 / 600 and Russell 1000 constituents (~1,650 unique US large/mid-cap
    stocks) and appends the 11 SPDR sector ETFs as a hardcoded static table.

    {1 Usage}

    {[
      let open Sector_map in
      let m = load_exn ~data_dir:(Fpath.v "/workspaces/trading-1/data") in
      match find m "AAPL" with
      | Some "Information Technology" -> ...
      | Some _ | None -> ...
    ]}

    The loader is pure — no caching, no side-effects beyond reading the file.
    Callers that need fast lookups across many calls should share a single [t]
    value. *)

type t
(** Opaque [symbol -> sector] lookup. *)

val empty : t
(** Empty map — useful for tests and for callers that want a "sectors
    unavailable" path without a branch. *)

val find : t -> string -> string option
(** [find m sym] returns the GICS sector for [sym], or [None] if the symbol is
    not in the CSV. The lookup is case-sensitive; callers are expected to pass
    symbols in the canonical uppercase form used by the rest of the system. *)

val to_alist : t -> (string * string) list
(** [to_alist m] returns all [(symbol, sector)] pairs sorted by symbol. Useful
    for debug dumps and for building the [sectors] argument to
    [Portfolio_risk.snapshot]. *)

val size : t -> int
(** [size m] is the number of distinct symbols in the map. *)

val of_alist : (string * string) list -> t
(** [of_alist pairs] builds a map from a raw association list. Later bindings
    override earlier ones. Intended for tests and for callers that assemble
    sector data from sources other than the CSV. *)

val load : data_dir:Fpath.t -> t Status.status_or
(** [load ~data_dir] reads [data_dir/sectors.csv] and returns the populated map.

    The CSV format is two columns — [symbol,sector] — with an optional header
    row ("symbol,sector" is recognised and skipped). Blank lines and lines whose
    sector field is empty are silently dropped.

    Returns [Ok empty] when [data_dir/sectors.csv] does not exist. Returns
    [Error] for I/O or parse errors (e.g. a line with fewer than two columns).
*)

val load_exn : data_dir:Fpath.t -> t
(** [load_exn ~data_dir] is [load] that raises [Failure] on error. Convenience
    for scripts. *)

val sectors_csv_path : Fpath.t -> Fpath.t
(** [sectors_csv_path data_dir] is the canonical location of the CSV,
    [data_dir/sectors.csv]. Exposed so that scripts can log the path and tests
    can point at fixtures. *)
