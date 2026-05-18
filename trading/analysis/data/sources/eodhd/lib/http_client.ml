open Async
open Core

type fetch_fn = Uri.t -> string Status.status_or Deferred.t

type historical_price_params = {
  symbol : string;
  start_date : Date.t option;
  end_date : Date.t option;
  period : Types.Cadence.t;
}

type symbol_metadata = {
  code : string;
  name : string;
  exchange : string;
  asset_type : Asset_type.t;
}
[@@deriving show, eq]

let _api_host = "eodhd.com"

let default_fetch uri : string Status.status_or Deferred.t =
  Cohttp_async.Client.get uri >>= fun (resp, body) ->
  match Cohttp.Response.status resp with
  | `OK -> Cohttp_async.Body.to_string body >>| fun body_str -> Ok body_str
  | status ->
      let status_str = Cohttp.Code.string_of_status status in
      Cohttp_async.Body.to_string body >>| fun body_str ->
      Error (Status.internal_error ("Error: " ^ status_str ^ "\n" ^ body_str))

(* Backwards-compatible alias for existing internal call sites. *)
let _fetch_body = default_fetch

let _period_to_string = function
  | Types.Cadence.Daily -> "d"
  | Types.Cadence.Weekly -> "w"
  | Types.Cadence.Monthly -> "m"

let _historical_price_uri (params : historical_price_params) =
  let period_str = _period_to_string params.period in
  let uri =
    Uri.make ~scheme:"https" ~host:_api_host
      ~path:("/api/eod/" ^ params.symbol)
      ~query:
        [ ("fmt", [ "json" ]); ("period", [ period_str ]); ("order", [ "a" ]) ]
      ()
  in
  let uri' =
    match params.start_date with
    | None -> uri
    | Some start_date ->
        Uri.add_query_param' uri ("from", start_date |> Date.to_string)
  in
  let today = Date.today ~zone:Time_float.Zone.utc in
  Uri.add_query_param' uri'
    ("to", Option.value params.end_date ~default:today |> Date.to_string)

let _make_symbols_uri token =
  Uri.make ~scheme:"https" ~host:_api_host ~path:"/api/exchange-symbol-list/US"
    ~query:[ ("api_token", [ token ]); ("fmt", [ "json" ]) ]
    ()

let _make_delisted_symbols_uri token =
  Uri.make ~scheme:"https" ~host:_api_host ~path:"/api/exchange-symbol-list/US"
    ~query:
      [ ("api_token", [ token ]); ("fmt", [ "json" ]); ("delisted", [ "1" ]) ]
    ()

let _float_of_yojson = function
  | `Float f -> Ok f
  | `Int i -> Ok (float_of_int i)
  | v ->
      Status.error_invalid_argument
        ("Expected float or int, got: " ^ Yojson.Safe.to_string v)

let _int_of_yojson = function
  | `Int i -> Ok i
  | v ->
      Status.error_invalid_argument
        ("Expected int, got: " ^ Yojson.Safe.to_string v)

let _string_of_yojson = function
  | `String s -> Ok s
  | v ->
      Status.error_invalid_argument
        ("Expected string, got: " ^ Yojson.Safe.to_string v)

let _string_or_null_of_yojson = function
  | `String s -> Ok s
  | `Null -> Ok ""
  | v ->
      Status.error_invalid_argument
        ("Expected string or null, got: " ^ Yojson.Safe.to_string v)

let _lookup_string_or_null fields name =
  match List.Assoc.find ~equal:String.equal fields name with
  | Some v -> _string_or_null_of_yojson v
  | None -> Ok ""

let _extract_symbol_from_json = function
  | `Assoc fields ->
      let open Result.Let_syntax in
      let%bind code =
        match List.Assoc.find ~equal:String.equal fields "Code" with
        | Some (`String c) -> Ok c
        | Some _ -> Status.error_invalid_argument "Code field is not a string"
        | None -> Status.error_not_found "Code field not found"
      in
      let%bind name = _lookup_string_or_null fields "Name" in
      let%bind exchange = _lookup_string_or_null fields "Exchange" in
      let%bind type_raw = _lookup_string_or_null fields "Type" in
      let asset_type = Asset_type.of_eodhd_string type_raw in
      Ok { code; name; exchange; asset_type }
  | _ -> Status.error_invalid_argument "Invalid symbol format"

let _parse_symbols_response body_str =
  try
    match Yojson.Safe.from_string body_str with
    | `List symbols ->
        let results = List.map symbols ~f:_extract_symbol_from_json in
        Result.all results
    | _ -> Status.error_invalid_argument "Invalid response format"
  with Yojson.Json_error msg ->
    Status.error_invalid_argument ("Invalid JSON: " ^ msg)

let get_symbols ~token ?(fetch = _fetch_body) () :
    symbol_metadata list Status.status_or Deferred.t =
  let uri = _make_symbols_uri token in
  fetch uri >>| Result.bind ~f:_parse_symbols_response

let get_delisted_symbols ~token ?(fetch = _fetch_body) () :
    symbol_metadata list Status.status_or Deferred.t =
  let uri = _make_delisted_symbols_uri token in
  fetch uri >>| Result.bind ~f:_parse_symbols_response

let _find_field fields name =
  match List.Assoc.find ~equal:String.equal fields name with
  | Some v -> Ok v
  | None -> Status.error_not_found ("Field " ^ name ^ " not found")

let _parse_price_fields fields =
  let open Result.Let_syntax in
  let%bind date =
    _find_field fields "date" >>= _string_of_yojson >>= fun s ->
    try Ok (Date.of_string s)
    with _ -> Status.error_invalid_argument ("Invalid date: " ^ s)
  in
  let%bind open_price = _find_field fields "open" >>= _float_of_yojson in
  let%bind high_price = _find_field fields "high" >>= _float_of_yojson in
  let%bind low_price = _find_field fields "low" >>= _float_of_yojson in
  let%bind close_price = _find_field fields "close" >>= _float_of_yojson in
  let%bind volume = _find_field fields "volume" >>= _int_of_yojson in
  let%bind adjusted_close =
    _find_field fields "adjusted_close" >>= _float_of_yojson
  in
  (* EODHD's [/api/eod] response carries no delisting marker on individual
     bars. The delisted-date is sourced separately (via the fundamentals
     endpoint or the delisted-symbol exchange listing) and would need a
     separate enrichment pass to attach. Leaving [active_through = None]
     here keeps the bar-parser contract narrow: bars in, bars out. *)
  Ok
    {
      Types.Daily_price.date;
      open_price;
      high_price;
      low_price;
      close_price;
      volume;
      adjusted_close;
      active_through = None;
    }

let _parse_json_price = function
  | `Assoc fields -> _parse_price_fields fields
  | _ -> Status.error_invalid_argument "Invalid price format"

let _parse_json_prices body_str =
  try
    match Yojson.Safe.from_string body_str with
    | `List prices ->
        let results = List.map prices ~f:_parse_json_price in
        Result.all results
    | _ -> Status.error_invalid_argument "Invalid response format"
  with Yojson.Json_error msg ->
    Status.error_invalid_argument ("Invalid JSON: " ^ msg)

let get_historical_price ~token ~params ?(fetch = _fetch_body) () :
    Types.Daily_price.t list Status.status_or Deferred.t =
  let uri = _historical_price_uri params in
  let uri = Uri.add_query_param' uri ("api_token", token) in
  fetch uri >>| Result.bind ~f:_parse_json_prices

let _parse_bulk_last_day_price = function
  | `Assoc fields ->
      let open Result.Let_syntax in
      let%bind code = _find_field fields "code" >>= _string_of_yojson in
      let%bind price = _parse_json_price (`Assoc fields) in
      Ok (code, price)
  | _ -> Status.error_invalid_argument "Invalid price format"

let _parse_bulk_last_day_prices body_str =
  try
    match Yojson.Safe.from_string body_str with
    | `List prices ->
        let results = List.map prices ~f:_parse_bulk_last_day_price in
        Result.all results
    | _ -> Status.error_invalid_argument "Invalid response format"
  with Yojson.Json_error msg ->
    Status.error_invalid_argument ("Invalid JSON: " ^ msg)

let get_bulk_last_day ~token ~exchange ?(fetch = _fetch_body) () :
    (string * Types.Daily_price.t) list Status.status_or Deferred.t =
  let uri =
    Uri.make ~scheme:"https" ~host:_api_host
      ~path:("/api/eod-bulk-last-day/" ^ exchange)
      ~query:[ ("api_token", [ token ]); ("fmt", [ "json" ]) ]
      ()
  in
  fetch uri >>| Result.bind ~f:_parse_bulk_last_day_prices

(* Index symbols *)

let _parse_symbol_codes body =
  Result.map (_parse_symbols_response body) ~f:(List.map ~f:(fun m -> m.code))

let get_index_symbols ~token ~index ?(fetch = _fetch_body) () :
    string list Status.status_or Deferred.t =
  let uri =
    Uri.make ~scheme:"https" ~host:_api_host
      ~path:("/api/exchange-symbol-list/" ^ index)
      ~query:[ ("api_token", [ token ]); ("fmt", [ "json" ]) ]
      ()
  in
  fetch uri >>| Result.bind ~f:_parse_symbol_codes
