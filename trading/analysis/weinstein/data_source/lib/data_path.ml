(* Canonical data directory.

   Default is [/workspaces/trading-1/data] — the path set by the dev container
   Dockerfile (WORKDIR /workspaces/trading-1/trading). Override via the
   [TRADING_DATA_DIR] environment variable; tests and CI jobs that run outside
   the dev container use this to point at the checkout's [data/] directory. *)
let default_data_dir () =
  match Sys.getenv_opt "TRADING_DATA_DIR" with
  | Some d when String.length d > 0 -> Fpath.v d
  | _ -> Fpath.v "/workspaces/trading-1/data"
