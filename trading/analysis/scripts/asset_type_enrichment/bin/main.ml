(** Bulk-enrich the local inventory with EODHD Asset_type classifications.

    Reads [inventory.sexp] (one line per cached symbol), fetches the US
    exchange-symbol-list from EODHD, joins the two, and writes the enriched
    index to [symbol_types.sexp]. Symbols absent from EODHD's listing are
    written with the [Not_in_eodhd_listing] sentinel so downstream filters can
    decide whether to drop them.

    Typical usage:
    {v
      asset_type_enrichment.exe \
        --inventory-path data/inventory.sexp \
        --output-path data/symbol_types.sexp \
        --secrets-path trading/analysis/data/sources/eodhd/secrets
    v}

    The EODHD endpoint hit is [/api/exchange-symbol-list/US]. INDX-suffixed
    inventory symbols (typically 3-4 entries: GSPC, DJI, etc.) are not in the US
    listing and will be written as [Not_in_eodhd_listing]; downstream filters
    should special-case index pseudo-symbols separately. *)

open Core
open Async

let _read_token ~secrets_path =
  try Ok (In_channel.read_all secrets_path |> String.rstrip)
  with Sys_error msg ->
    Status.error_invalid_argument
      (Printf.sprintf "failed to read secrets %s: %s" secrets_path msg)

let _load_inventory ~inventory_path =
  let path = Fpath.v inventory_path in
  match
    File_sexp.Sexp.load
      (module struct
        type t = Inventory.t

        let sexp_of_t = Inventory.sexp_of_t
        let t_of_sexp = Inventory.t_of_sexp
      end)
      ~path
  with
  | Ok inv -> Ok inv
  | Error err -> Error err

let _print_summary t =
  let counts = Asset_type_enrichment_lib.per_type_counts t in
  Core.printf "Wrote %d entries.\n" (List.length t.symbols);
  Core.print_string "Per-type counts:\n";
  List.iter counts ~f:(fun c ->
      Core.printf "  %-32s %d\n" c.Asset_type_enrichment_lib.asset_type_label
        c.count)

let _run ~inventory_path ~output_path ~secrets_path =
  let open Deferred.Result.Let_syntax in
  let%bind token = _read_token ~secrets_path |> Deferred.return in
  let%bind inventory = _load_inventory ~inventory_path |> Deferred.return in
  let inventory_symbols =
    List.map inventory.Inventory.symbols ~f:(fun e -> e.Inventory.symbol)
  in
  Core.printf "Inventory has %d symbols.\n%!" (List.length inventory_symbols);
  let%bind eodhd_listings = Eodhd.Http_client.get_symbols ~token () in
  Core.printf "EODHD US listing has %d entries.\n%!"
    (List.length eodhd_listings);
  let today = Date.today ~zone:Time_float.Zone.utc in
  let enriched =
    Asset_type_enrichment_lib.join ~inventory_symbols ~eodhd_listings
      ~generated_at:today
      ~source_endpoints:[ ("/api/exchange-symbol-list/US", today) ]
  in
  let%bind () =
    Asset_type_enrichment_lib.save enriched ~path:(Fpath.v output_path)
    |> Deferred.return
  in
  _print_summary enriched;
  Core.printf "Wrote %s\n%!" output_path;
  Deferred.Result.return ()

let _main ~inventory_path ~output_path ~secrets_path () =
  _run ~inventory_path ~output_path ~secrets_path >>= function
  | Ok () -> return ()
  | Error e ->
      Core.eprintf "Error: %s\n" (Status.show e);
      exit 1

let _default_secrets_path = "trading/analysis/data/sources/eodhd/secrets"

let command =
  Command.async
    ~summary:
      "Bulk-enrich inventory symbols with EODHD Asset_type (Q1 PR2 of \
       custom-universe-bidirectional)"
    (let%map_open.Command inventory_path =
       flag "inventory-path" (required string)
         ~doc:"PATH Path to inventory.sexp"
     and output_path =
       flag "output-path" (required string)
         ~doc:"PATH Where to write symbol_types.sexp"
     and secrets_path =
       flag "secrets-path"
         (optional_with_default _default_secrets_path string)
         ~doc:"PATH EODHD API token file (default: repo-local secrets)"
     in
     _main ~inventory_path ~output_path ~secrets_path)

let () = Command_unix.run command
