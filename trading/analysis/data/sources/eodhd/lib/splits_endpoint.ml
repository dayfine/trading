open Async
open Core

type split = { date : Date.t; factor : float } [@@deriving show, eq]

let _api_host = "eodhd.com"
let _default_exchange = "US"

let _make_uri ~token ~symbol ~exchange =
  Uri.make ~scheme:"https" ~host:_api_host
    ~path:("/api/splits/" ^ symbol ^ "." ^ exchange)
    ~query:[ ("api_token", [ token ]); ("fmt", [ "json" ]) ]
    ()

(* Parse a string like "4.000000/1.000000" or "4/1" into the float ratio
   [N/M = 4.0]. Tolerant of extra whitespace and integer numerators /
   denominators. *)
let _parse_factor_string raw =
  let trimmed = String.strip raw in
  match String.split trimmed ~on:'/' with
  | [ n; m ] -> (
      try
        let num = Float.of_string (String.strip n) in
        let denom = Float.of_string (String.strip m) in
        if Float.( = ) denom 0.0 then
          Status.error_invalid_argument ("Split denominator is zero: " ^ trimmed)
        else Ok (num /. denom)
      with _ ->
        Status.error_invalid_argument ("Invalid split factor: " ^ trimmed))
  | _ ->
      Status.error_invalid_argument
        ("Split factor must be N/M form, got: " ^ trimmed)

let _find_field fields name =
  match List.Assoc.find ~equal:String.equal fields name with
  | Some v -> Ok v
  | None -> Status.error_not_found ("Field " ^ name ^ " not found")

let _string_of_yojson = function
  | `String s -> Ok s
  | v ->
      Status.error_invalid_argument
        ("Expected string, got: " ^ Yojson.Safe.to_string v)

let _parse_date_string s =
  try Ok (Date.of_string s)
  with _ -> Status.error_invalid_argument ("Invalid date: " ^ s)

let _parse_split_row = function
  | `Assoc fields ->
      let open Result.Let_syntax in
      let%bind date_str = _find_field fields "date" >>= _string_of_yojson in
      let%bind date = _parse_date_string date_str in
      let%bind factor_str = _find_field fields "split" >>= _string_of_yojson in
      let%bind factor = _parse_factor_string factor_str in
      Ok { date; factor }
  | v ->
      Status.error_invalid_argument
        ("Expected split row object, got: " ^ Yojson.Safe.to_string v)

let _parse_response body_str =
  try
    match Yojson.Safe.from_string body_str with
    | `List rows -> Result.all (List.map rows ~f:_parse_split_row)
    | _ -> Status.error_invalid_argument "Expected JSON array of split rows"
  with Yojson.Json_error msg ->
    Status.error_invalid_argument ("Invalid JSON: " ^ msg)

let get_splits ~token ~symbol ?(exchange = _default_exchange)
    ?(fetch = Http_client.default_fetch) () :
    split list Status.status_or Deferred.t =
  let uri = _make_uri ~token ~symbol ~exchange in
  fetch uri >>| Result.bind ~f:_parse_response
