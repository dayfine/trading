(** Build inventory.sexp from locally cached price data.

    Scans [data_dir] recursively for [data.metadata.sexp] files (one per cached
    symbol) and writes a consolidated [data_dir/inventory.sexp] listing every
    symbol with its available date range.

    Motivation: the inventory is the central manifest of what data is available
    locally. It drives two downstream steps — {!bootstrap_universe} reads it to
    build [universe.sexp], and test helpers consult it to verify that required
    symbols are cached before running golden-scenario tests.

    When to run: after any bulk fetch via {!fetch_symbols}. Safe to re-run at
    any time; it is a pure read-and-aggregate operation with no side effects
    other than overwriting [inventory.sexp].

    Typical usage:
    {v
      build_inventory.exe                       # use default data dir
      build_inventory.exe -data-dir /my/data    # custom dir
    v} *)

open Core

let main ~data_dir_str () =
  let data_dir = Fpath.v data_dir_str in
  Printf.printf "Scanning %s ...\n%!" data_dir_str;
  let inv = Inventory.build ~data_dir in
  Printf.printf "Found %d symbols\n%!" (List.length inv.Inventory.symbols);
  match Inventory.save inv ~data_dir with
  | Ok () ->
      Printf.printf "Wrote inventory to %s\n%!"
        (Fpath.to_string (Inventory.path ~data_dir))
  | Error e ->
      Printf.eprintf "Error writing inventory: %s\n%!" (Status.show e);
      exit 1

let command =
  Command.basic ~summary:"Build inventory.sexp from cached metadata files"
    (let%map_open.Command data_dir =
       flag "data-dir"
         (optional_with_default
            (Data_path.default_data_dir () |> Fpath.to_string)
            string)
         ~doc:"PATH Directory containing cached symbol data"
     in
     fun () -> main ~data_dir_str:data_dir ())

let () = Command_unix.run command
