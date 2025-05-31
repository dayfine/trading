open Async
open Core

type fetch_fn = Uri.t -> string Status.status_or Deferred.t

type historical_price_params = {
  symbol : string;
  start_date : Date.t option;
  end_date : Date.t option;
}

let _api_host = "eodhd.com"

let _fetch_body uri : string Status.status_or Deferred.t =
  Cohttp_async.Client.get uri >>= fun (resp, body) ->
  match Cohttp.Response.status resp with
  | `OK -> Cohttp_async.Body.to_string body >>| fun body_str -> Ok body_str
  | status ->
      let status_str = Cohttp.Code.string_of_status status in
      Cohttp_async.Body.to_string body >>| fun body_str ->
      Error (Status.internal_error ("Error: " ^ status_str ^ "\n" ^ body_str))

let _historical_price_uri (params : historical_price_params) =
  let uri =
    Uri.make ~scheme:"https" ~host:_api_host
      ~path:("/api/eod/" ^ params.symbol)
      ~query:[ ("fmt", [ "json" ]); ("period", [ "d" ]); ("order", [ "a" ]) ]
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

let _find_field fields name =
  match List.Assoc.find ~equal:String.equal fields name with
  | Some v -> Ok v
  | None -> Status.error_not_found ("Field " ^ name ^ " not found")

let _parse_json_price = function
  | `Assoc fields ->
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
