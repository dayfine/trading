(** Fetch universe metadata from EODHD exchange symbol list.

    Calls the EODHD [/api/exchange-symbol-list/US] endpoint to get name,
    exchange, and type for all US-listed symbols, then writes [universe.sexp]
    with populated metadata fields.

    Unlike {!bootstrap_universe} (which reads from the local inventory with
    empty metadata), this script populates [name] and [exchange] from the API.
    Sector and industry fields remain empty — the EODHD fundamentals endpoint
    required for those is on a higher API tier.

    Filters to [Common Stock] and [ETF] types by default. Use [--types] to
    override.

    Typical usage:
    {v
      fetch_universe.exe --api-key <key>
      fetch_universe.exe --api-key <key> --types "Common Stock,ETF,INDEX"
      fetch_universe.exe --api-key <key> --exchange NYSE
    v} *)

open Core
open Async

let _base_url = "https://eodhd.com/api/exchange-symbol-list"

let _make_uri ~exchange ~token =
  Uri.of_string
    (Printf.sprintf "%s/%s?api_token=%s&fmt=json" _base_url exchange token)

type symbol_entry = {
  code : string;
  name : string;
  exchange : string;
  symbol_type : string;
}

let _parse_entry json =
  let open Yojson.Safe.Util in
  try
    let code = json |> member "Code" |> to_string in
    let name = json |> member "Name" |> to_string in
    let exchange = json |> member "Exchange" |> to_string in
    let symbol_type = json |> member "Type" |> to_string in
    Some { code; name; exchange; symbol_type }
  with _ -> None

let _fetch_symbol_list ~token ~exchange =
  let uri = _make_uri ~exchange ~token in
  let%bind _resp, body = Cohttp_async.Client.get uri in
  let%bind body_str = Cohttp_async.Body.to_string body in
  try
    let json = Yojson.Safe.from_string body_str in
    match json with
    | `List entries -> return (Ok (List.filter_map entries ~f:_parse_entry))
    | _ -> return (Status.error_invalid_argument "Expected JSON array")
  with exn ->
    return
      (Status.error_invalid_argument
         (Printf.sprintf "JSON parse error: %s" (Exn.to_string exn)))

let _to_instrument (entry : symbol_entry) : Types.Instrument_info.t =
  {
    symbol = entry.code;
    name = entry.name;
    sector = "";
    industry = "";
    market_cap = 0.0;
    exchange = entry.exchange;
  }

let _filter_entries ~allowed_types entries =
  List.filter entries ~f:(fun e -> Set.mem allowed_types e.symbol_type)

let _save_universe ~data_dir ~types ~total_fetched ~instruments =
  printf "Fetched %d symbols, %d match type filter [%s]\n%!" total_fetched
    (List.length instruments)
    (String.concat ~sep:", " types);
  match Universe.save ~data_dir instruments with
  | Ok () ->
      printf "Wrote universe.sexp: %d instruments\n%!" (List.length instruments);
      return ()
  | Error e ->
      eprintf "Error writing universe: %s\n%!" (Status.show e);
      Async.exit 1

let main ~api_key ~exchange ~types ~data_dir_str () =
  let data_dir = Fpath.v data_dir_str in
  let allowed_types = String.Set.of_list types in
  printf "Fetching symbol list for exchange %s ...\n%!" exchange;
  match%bind _fetch_symbol_list ~token:api_key ~exchange with
  | Error e ->
      eprintf "Error fetching symbols: %s\n%!" (Status.show e);
      Async.exit 1
  | Ok entries ->
      let filtered = _filter_entries ~allowed_types entries in
      let instruments = List.map filtered ~f:_to_instrument in
      _save_universe ~data_dir ~types ~total_fetched:(List.length entries)
        ~instruments

let command =
  Command.async
    ~summary:
      "Fetch universe metadata from EODHD exchange symbol list and write \
       universe.sexp"
    (let%map_open.Command api_key =
       flag "api-key" (required string) ~doc:"KEY EODHD API key"
     and exchange =
       flag "exchange"
         (optional_with_default "US" string)
         ~doc:"CODE Exchange code (default: US)"
     and types_str =
       flag "types"
         (optional_with_default "Common Stock,ETF" string)
         ~doc:"T1,T2,... Comma-separated symbol types to include"
     and data_dir =
       flag "data-dir"
         (optional_with_default
            (Data_path.default_data_dir () |> Fpath.to_string)
            string)
         ~doc:"PATH Data directory for universe.sexp"
     in
     let types =
       String.split ~on:',' types_str
       |> List.map ~f:String.strip
       |> List.filter ~f:(fun s -> not (String.is_empty s))
     in
     fun () -> main ~api_key ~exchange ~types ~data_dir_str:data_dir ())

let () = Command_unix.run command
