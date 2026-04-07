(** Universe persistence — shared by all DATA_SOURCE implementations.

    The universe is a list of tracked instruments stored as a sexp file at
    [data_dir/universe.sexp]. All source implementations (Live, Historical) load
    it with the same logic. *)

open Async

val get_deferred :
  string -> Types.Instrument_info.t list Status.status_or Deferred.t
(** [get_deferred data_dir] reads [data_dir/universe.sexp] and returns the
    instrument list wrapped in a deferred value.

    Returns an empty list (not an error) when the file is absent.

    Use this in {!Data_source.DATA_SOURCE.get_universe} implementations. The
    underlying sync [load] function is internal to this module. *)

val rebuild_from_data_dir : data_dir:Fpath.t -> unit -> (unit, Status.t) result
(** [rebuild_from_data_dir ~data_dir ()] reads [data_dir/inventory.json] and
    writes [data_dir/universe.sexp] from the symbols found there.

    Sector, industry, and other metadata fields will be empty — use the
    [fetch_universe.ml] script to populate them from EODHD fundamentals. This
    function is sufficient to bootstrap simulation and backtests that only need
    the symbol list.

    Returns [Ok ()] on success, or an error if the inventory file is missing or
    malformed. *)
