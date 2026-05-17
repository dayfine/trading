open Async
open Core

type fundamentals = {
  symbol : string;
  name : string;
  sector : string;
  industry : string;
  market_cap : float;
  exchange : string;
  shares_outstanding : float;
}
[@@deriving show, eq]

let _api_host = "eodhd.com"

let _string_or_null_of_yojson = function
  | `String s -> Ok s
  | `Null -> Ok ""
  | v ->
      Status.error_invalid_argument
        ("Expected string or null, got: " ^ Yojson.Safe.to_string v)

let _float_or_null_of_yojson = function
  | `Float f -> Ok f
  | `Int i -> Ok (float_of_int i)
  | `Null -> Ok 0.0
  | v ->
      Status.error_invalid_argument
        ("Expected float, int, or null, got: " ^ Yojson.Safe.to_string v)

let _find_str_in fields key =
  match List.Assoc.find ~equal:String.equal fields key with
  | Some v -> _string_or_null_of_yojson v
  | None -> Ok ""

let _find_float_in fields key =
  match List.Assoc.find ~equal:String.equal fields key with
  | Some v -> _float_or_null_of_yojson v
  | None -> Ok 0.0

let _find_section fields name =
  match List.Assoc.find ~equal:String.equal fields name with
  | Some (`Assoc kvs) -> Ok (Some kvs)
  | Some `Null -> Ok None
  | Some _ ->
      Status.error_invalid_argument
        (Printf.sprintf "fundamentals: %s field is not an object" name)
  | None -> Ok None

(* [SharesStats] is optional on the response — older / sparser symbols may
   omit it entirely. Missing section -> [shares_outstanding = 0.0], matching
   the "no fundamentals data" sentinel documented on the [fundamentals]
   record. *)
let _shares_outstanding_from_shares_stats = function
  | None -> Ok 0.0
  | Some kvs -> _find_float_in kvs "SharesOutstanding"

let _parse_fundamentals_sections symbol ~general ~shares_stats =
  let open Result.Let_syntax in
  let%bind name = _find_str_in general "Name" in
  let%bind sector = _find_str_in general "Sector" in
  let%bind industry = _find_str_in general "Industry" in
  let%bind market_cap = _find_float_in general "MarketCapitalization" in
  let%bind exchange = _find_str_in general "Exchange" in
  let%bind shares_outstanding =
    _shares_outstanding_from_shares_stats shares_stats
  in
  Ok
    { symbol; name; sector; industry; market_cap; exchange; shares_outstanding }

let _require_general_section symbol = function
  | Some general -> Ok general
  | None ->
      Status.error_not_found
        (Printf.sprintf "fundamentals[%s]: General section missing" symbol)

let _parse_assoc_fields symbol fields =
  let open Result.Let_syntax in
  let%bind general_opt = _find_section fields "General" in
  let%bind general = _require_general_section symbol general_opt in
  let%bind shares_stats = _find_section fields "SharesStats" in
  _parse_fundamentals_sections symbol ~general ~shares_stats

let _parse_yojson_root symbol = function
  | `Assoc fields -> _parse_assoc_fields symbol fields
  | _ -> Status.error_invalid_argument "Invalid response format"

let _parse_response symbol body_str =
  match Yojson.Safe.from_string body_str with
  | exception Yojson.Json_error msg ->
      Status.error_invalid_argument ("Invalid JSON: " ^ msg)
  | json -> _parse_yojson_root symbol json

(* Two-section filter: keeps the response small (drops Earnings, Highlights,
   Splits, etc.) while still returning the SharesOutstanding number under
   [SharesStats]. *)
let _query token =
  [
    ("api_token", [ token ]);
    ("filter", [ "General,SharesStats" ]);
    ("fmt", [ "json" ]);
  ]

let _make_uri ~token ~symbol =
  let path = "/api/fundamentals/" ^ symbol in
  Uri.make ~scheme:"https" ~host:_api_host ~path ~query:(_query token) ()

let get_fundamentals ~token ~symbol ?(fetch = Http_client.default_fetch) () :
    fundamentals Status.status_or Deferred.t =
  let uri = _make_uri ~token ~symbol in
  fetch uri >>| Result.bind ~f:(_parse_response symbol)
