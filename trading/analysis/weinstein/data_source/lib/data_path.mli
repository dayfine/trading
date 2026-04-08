(** Data path utilities — shared by scripts and tests that need to locate
    [data/]. *)

val default_data_dir : unit -> Fpath.t
(** [default_data_dir ()] returns [/workspaces/trading-1/data], the canonical
    data directory path inside the Docker development container.

    Use this instead of hardcoding the path. Pass it to
    {!Historical_source.make}, {!Inventory.build}, {!Universe.save}, and any
    other code that needs to locate cached price data. *)
