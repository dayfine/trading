(** Bootstrap universe.sexp from the local inventory without an API call.

    Reads [data_dir/inventory.sexp] (produced by {!build_inventory}) and writes
    [data_dir/universe.sexp] containing one entry per cached symbol. Sector,
    industry, exchange, and name fields are left empty — this is a structural
    bootstrap, not a data-enriched universe.

    Motivation: [universe.sexp] is required before any simulation or live scan.
    The full-quality path is [fetch_universe.ml] (which calls EODHD fundamentals
    to populate sector/industry metadata). This script provides a fast offline
    alternative when sector data is not needed, e.g. for backtests that ignore
    sector concentration limits or for CI environments without API access.

    When to run: once, after {!build_inventory}, when setting up a new
    environment or when the symbol set has changed. Re-run any time
    [inventory.sexp] is updated and sector data is not needed.

    Typical usage:
    {v
      bootstrap_universe.exe                       # use default data dir
      bootstrap_universe.exe -data-dir /my/data    # custom dir
    v} *)

open Core

(** Build a minimal Instrument_info from an inventory entry. Sector, industry,
    and other metadata fields are left empty — use fetch_universe.ml to populate
    them from EODHD fundamentals. *)
let _instrument_of_entry (e : Inventory.entry) : Types.Instrument_info.t =
  {
    symbol = e.symbol;
    name = "";
    sector = "";
    industry = "";
    market_cap = 0.0;
    exchange = "";
  }

let main ~data_dir_str () =
  let data_dir = Fpath.v data_dir_str in
  match Inventory.load ~data_dir with
  | Error e ->
      Printf.eprintf "Error loading inventory: %s\n%!" (Status.show e);
      exit 1
  | Ok inv -> (
      let instruments =
        List.map inv.Inventory.symbols ~f:_instrument_of_entry
      in
      Printf.printf "Building universe from %d symbols ...\n%!"
        (List.length instruments);
      match Universe.save ~data_dir instruments with
      | Ok () ->
          Printf.printf
            "Wrote universe.sexp (sector/industry fields empty).\n%!"
      | Error e ->
          Printf.eprintf "Error writing universe: %s\n%!" (Status.show e);
          exit 1)

let command =
  Command.basic
    ~summary:
      "Bootstrap universe.sexp from inventory.sexp (empty sector/industry \
       fields)"
    (let%map_open.Command data_dir =
       flag "data-dir"
         (optional_with_default
            (Data_path.default_data_dir () |> Fpath.to_string)
            string)
         ~doc:"PATH Data directory containing inventory.sexp"
     in
     fun () -> main ~data_dir_str:data_dir ())

let () = Command_unix.run command
