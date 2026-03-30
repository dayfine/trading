(** Universe persistence — shared by all DATA_SOURCE implementations.

    The universe is a list of tracked instruments stored as a sexp file at
    [data_dir/universe.sexp]. All source implementations (Live, Historical) load
    it with the same logic. *)

val load : string -> Types.Instrument_info.t list Status.status_or
(** [load data_dir] reads [data_dir/universe.sexp] and returns the instrument
    list. Returns an empty list (not an error) when the file is absent. *)
