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

val save :
  data_dir:Fpath.t -> Types.Instrument_info.t list -> (unit, Status.t) result
(** [save ~data_dir instruments] writes [data_dir/universe.sexp]. Used by
    scripts that bootstrap or update the universe from fetched data. *)
