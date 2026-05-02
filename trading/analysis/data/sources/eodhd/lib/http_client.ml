open Async
open Core

type fetch_fn = Uri.t -> string Status.status_or Deferred.t

type historical_price_params = {
  symbol : string;
  start_date : Date.t option;
  end_date : Date.t option;
  period : Types.Cadence.t;
}

type fundamentals = {
  symbol : string;
  name : string;
  sector : string;
  industry : string;
  market_cap : float;
  exchange : string;
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

let _extract_symbol_from_json = function
  | `Assoc fields -> (
      match List.find fields ~f:(fun (k, _) -> String.equal k "Code") with
      | Some (_, `String code) -> Ok code
      | Some (_, _) ->
          Status.error_invalid_argument "Code field is not a string"
      | None -> Status.error_not_found "Code field not found")
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
    string list Status.status_or Deferred.t =
  let uri = _make_symbols_uri token in
  fetch uri >>| Result.bind ~f:_parse_symbols_response

let _float_of_yojson = function
  | `Float f -> Ok f
  | `Int i -> Ok (float_of_int i)
  | v ->
      Status.error_invalid_argument
        ("Expected float or int, got: " ^ Yojson.Safe.to_string v)

let _float_or_null_of_yojson = function
  | `Float f -> Ok f
  | `Int i -> Ok (float_of_int i)
  | `Null -> Ok 0.0
  | v ->
      Status.error_invalid_argument
        ("Expected float, int, or null, got: " ^ Yojson.Safe.to_string v)

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
  Ok
    {
      Types.Daily_price.date;
      open_price;
      high_price;
      low_price;
      close_price;
      volume;
      adjusted_close;
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

(* Fundamentals parsing *)

let _parse_general_section symbol general =
  let open Result.Let_syntax in
  let find_str key =
    match List.Assoc.find ~equal:String.equal general key with
    | Some v -> _string_or_null_of_yojson v
    | None -> Ok ""
  in
  let find_float key =
    match List.Assoc.find ~equal:String.equal general key with
    | Some v -> _float_or_null_of_yojson v
    | None -> Ok 0.0
  in
  let%bind name = find_str "Name" in
  let%bind sector = find_str "Sector" in
  let%bind industry = find_str "Industry" in
  let%bind market_cap = find_float "MarketCapitalization" in
  let%bind exchange = find_str "Exchange" in
  Ok { symbol; name; sector; industry; market_cap; exchange }

let _parse_general_field symbol = function
  | Some (`Assoc general) -> _parse_general_section symbol general
  | Some _ -> Status.error_invalid_argument "General field is not an object"
  | None -> Status.error_not_found "General section not found in response"

let _parse_fundamentals_response symbol body_str =
  try
    match Yojson.Safe.from_string body_str with
    | `Assoc fields ->
        let general = List.Assoc.find ~equal:String.equal fields "General" in
        _parse_general_field symbol general
    | _ -> Status.error_invalid_argument "Invalid response format"
  with Yojson.Json_error msg ->
    Status.error_invalid_argument ("Invalid JSON: " ^ msg)

let get_fundamentals ~token ~symbol ?(fetch = _fetch_body) () :
    fundamentals Status.status_or Deferred.t =
  let uri =
    Uri.make ~scheme:"https" ~host:_api_host
      ~path:("/api/fundamentals/" ^ symbol)
      ~query:
        [
          ("api_token", [ token ]);
          ("filter", [ "General" ]);
          ("fmt", [ "json" ]);
        ]
      ()
  in
  fetch uri >>| Result.bind ~f:(_parse_fundamentals_response symbol)

(* Index symbols *)

let get_index_symbols ~token ~index ?(fetch = _fetch_body) () :
    string list Status.status_or Deferred.t =
  let uri =
    Uri.make ~scheme:"https" ~host:_api_host
      ~path:("/api/exchange-symbol-list/" ^ index)
      ~query:[ ("api_token", [ token ]); ("fmt", [ "json" ]) ]
      ()
  in
  fetch uri >>| Result.bind ~f:_parse_symbols_response
