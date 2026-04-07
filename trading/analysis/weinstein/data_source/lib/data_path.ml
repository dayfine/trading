(* /workspaces/trading-1/ is the container workspace root set in
   .devcontainer/Dockerfile via WORKDIR /workspaces/trading-1/trading. *)
let default_data_dir () = Fpath.v "/workspaces/trading-1/data"
