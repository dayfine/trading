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

let _run ~inventory_path ~output_path ~secrets_path ~include_delisted =
  let open Deferred.Result.Let_syntax in
  let%bind token = _read_token ~secrets_path |> Deferred.return in
  let%bind inventory = _load_inventory ~inventory_path |> Deferred.return in
  let inventory_symbols =
    List.map inventory.Inventory.symbols ~f:(fun e -> e.Inventory.symbol)
  in
  Core.printf "Inventory has %d symbols.\n%!" (List.length inventory_symbols);
  let%bind live = Eodhd.Http_client.get_symbols ~token () in
  Core.printf "EODHD US LIVE listing has %d entries.\n%!" (List.length live);
  let%bind delisted =
    if include_delisted then (
      let%bind d = Eodhd.Http_client.get_delisted_symbols ~token () in
      Core.printf "EODHD US DELISTED listing has %d entries.\n%!"
        (List.length d);
      Deferred.Result.return d)
    else Deferred.Result.return []
  in
  let eodhd_listings = live @ delisted in
  let today = Date.today ~zone:Time_float.Zone.utc in
  let source_endpoints =
    if include_delisted then
      [
        ("/api/exchange-symbol-list/US", today);
        ("/api/exchange-symbol-list/US?delisted=1", today);
      ]
    else [ ("/api/exchange-symbol-list/US", today) ]
  in
  let enriched =
    Asset_type_enrichment_lib.join ~inventory_symbols ~eodhd_listings
      ~generated_at:today ~source_endpoints
  in
  let%bind () =
    Asset_type_enrichment_lib.save enriched ~path:(Fpath.v output_path)
    |> Deferred.return
  in
  _print_summary enriched;
  Core.printf "Wrote %s\n%!" output_path;
  Deferred.Result.return ()

let _main ~inventory_path ~output_path ~secrets_path ~include_delisted () =
  _run ~inventory_path ~output_path ~secrets_path ~include_delisted >>= function
  | Ok () -> return ()
  | Error e ->
      Core.eprintf "Error: %s\n" (Status.show e);
      exit 1

let _default_secrets_path = "trading/analysis/data/sources/eodhd/secrets"

let command =
  Command.async
    ~summary:
      "Bulk-enrich inventory symbols with EODHD Asset_type (Q1 PR2 of \
       custom-universe-bidirectional). Pass -include-delisted to merge in the \
       /api/exchange-symbol-list/US?delisted=1 roster (P3 of the \
       delisted-aware universe agenda — see \
       dev/notes/eodhd-delisted-roster-unlock-2026-05-18.md)."
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
     and include_delisted =
       flag "include-delisted" no_arg
         ~doc:
           "If set, also fetch /api/exchange-symbol-list/US?delisted=1 and \
            merge results so delisted-symbol inventory entries get \
            attribution. Required for the delisted-aware composition agenda."
     in
     _main ~inventory_path ~output_path ~secrets_path ~include_delisted)

let () = Command_unix.run command
