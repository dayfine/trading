open Core

let default_data_dir () =
  match Sys.getenv "TRADING_DATA_DIR" with
  | Some p -> Fpath.v p
  | None -> Fpath.v "/workspaces/trading-1/data"
