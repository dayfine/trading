open Async
open Core

type dividend = { date : Date.t; amount : float } [@@deriving show, eq]

let _api_host = "eodhd.com"
let _default_exchange = "US"

let _make_uri ~token ~symbol ~exchange =
  Uri.make ~scheme:"https" ~host:_api_host
    ~path:("/api/div/" ^ symbol ^ "." ^ exchange)
    ~query:[ ("api_token", [ token ]); ("fmt", [ "json" ]) ]
    ()

let _find_field fields name =
  match List.Assoc.find ~equal:String.equal fields name with
  | Some v -> Ok v
  | None -> Status.error_not_found ("Field " ^ name ^ " not found")

let _string_of_yojson = function
  | `String s -> Ok s
  | v ->
      Status.error_invalid_argument
        ("Expected string, got: " ^ Yojson.Safe.to_string v)

let _float_of_yojson = function
  | `Float f -> Ok f
  | `Int i -> Ok (Float.of_int i)
  | `String s -> (
      try Ok (Float.of_string s)
      with _ -> Status.error_invalid_argument ("Invalid numeric string: " ^ s))
  | v ->
      Status.error_invalid_argument
        ("Expected number, got: " ^ Yojson.Safe.to_string v)

let _parse_date_string s =
  try Ok (Date.of_string s)
  with _ -> Status.error_invalid_argument ("Invalid date: " ^ s)

let _parse_dividend_row = function
  | `Assoc fields ->
      let open Result.Let_syntax in
      let%bind date_str = _find_field fields "date" >>= _string_of_yojson in
      let%bind date = _parse_date_string date_str in
      let%bind amount = _find_field fields "value" >>= _float_of_yojson in
      Ok { date; amount }
  | v ->
      Status.error_invalid_argument
        ("Expected dividend row object, got: " ^ Yojson.Safe.to_string v)

let _parse_response body_str =
  try
    match Yojson.Safe.from_string body_str with
    | `List rows -> Result.all (List.map rows ~f:_parse_dividend_row)
    | _ -> Status.error_invalid_argument "Expected JSON array of dividend rows"
  with Yojson.Json_error msg ->
    Status.error_invalid_argument ("Invalid JSON: " ^ msg)

let get_dividends ~token ~symbol ?(exchange = _default_exchange)
    ?(fetch = Http_client.default_fetch) () :
    dividend list Status.status_or Deferred.t =
  let uri = _make_uri ~token ~symbol ~exchange in
  fetch uri >>| Result.bind ~f:_parse_response
