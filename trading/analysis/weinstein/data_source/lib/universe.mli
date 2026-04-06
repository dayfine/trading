(** Universe persistence — shared by all DATA_SOURCE implementations.

    The universe is a list of tracked instruments stored as a sexp file at
    [data_dir/universe.sexp]. All source implementations (Live, Historical) load
    it with the same logic. *)

open Async

val load : string -> Types.Instrument_info.t list Status.status_or
(** [load data_dir] reads [data_dir/universe.sexp] and returns the instrument
    list. Returns an empty list (not an error) when the file is absent. *)

val get_deferred :
  string -> Types.Instrument_info.t list Status.status_or Deferred.t
(** [get_deferred data_dir] wraps {!load} in a deferred value.

    Convenience function for use in {!Data_source.DATA_SOURCE.get_universe}
    implementations — eliminates the boilerplate [return (load data_dir)]
    pattern that would otherwise appear in every source implementation. *)
