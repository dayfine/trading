(** Data path utilities — shared by scripts and tests that need to locate
    [data/]. *)

val default_data_dir : unit -> Fpath.t
(** [default_data_dir ()] returns the canonical data directory path. Reads
    [TRADING_DATA_DIR] first; falls back to [/workspaces/trading-1/data] — the
    path set by the dev container Dockerfile (WORKDIR
    /workspaces/trading-1/trading). The env var lets CI jobs and other
    out-of-container callers point at the checkout's [data/] directory without
    symlinking.

    Use this instead of hardcoding the path. Pass it to
    {!Historical_source.make}, {!Inventory.build}, {!Universe.save}, and any
    other code that needs to locate cached price data. *)
