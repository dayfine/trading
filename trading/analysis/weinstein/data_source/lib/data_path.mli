(** Data path utilities — shared by all code that needs to locate [data/].

    Use {!default_data_dir} instead of hardcoding an absolute path. This makes
    test binaries portable: dune sets the working directory to a build
    subdirectory, so relative paths break when a test moves. *)

val default_data_dir : unit -> Fpath.t
(** [default_data_dir ()] returns the path to the shared data directory.

    Reads the [TRADING_DATA_DIR] environment variable when set; falls back to
    [/workspaces/trading-1/data] (the canonical Docker path).

    The returned path is the directory that contains per-symbol subdirectories
    and [inventory.json]. Pass it to {!Historical_source.make},
    {!Universe.rebuild_from_data_dir}, and test helpers that load real price
    data. *)
