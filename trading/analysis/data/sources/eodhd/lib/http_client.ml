open Async
open Core

(* https://eodhd.com/financial-apis/api-for-historical-data-and-volumes *)
let api_host = "eodhd.com"
let as_str (date : Date.t) = Date.to_string date

let get_and_parse uri parse_body =
  Cohttp_async.Client.get uri >>= fun (resp, body) ->
  match Cohttp.Response.status resp with
  | `OK -> Cohttp_async.Body.to_string body >>| parse_body
  | status ->
      let status_str = Cohttp.Code.string_of_status status in
      Cohttp_async.Body.to_string body >>| fun body_str ->
      Error (Printf.sprintf "Error: %s\n%s" status_str body_str)

let make_symbols_uri token =
  Uri.make ~scheme:"https" ~host:api_host ~path:"/api/exchange-symbol-list/US"
    ~query:[ ("api_token", [ token ]); ("fmt", [ "json" ]) ]
    ()

let extract_symbol_from_json = function
  | `Assoc fields -> (
      match List.find fields ~f:(fun (k, _) -> String.equal k "Code") with
      | Some (_, `String code) -> Ok code
      | Some (_, _) -> Error "Code field is not a string"
      | None -> Error "Code field not found")
  | _ -> Error "Invalid symbol format"

let parse_symbols_response body_str =
  match Yojson.Safe.from_string body_str with
  | `List symbols ->
      let results = List.map symbols ~f:extract_symbol_from_json in
      let errors =
        List.filter_map results ~f:(function Error e -> Some e | Ok _ -> None)
      in
      if List.is_empty errors then
        Ok
          (List.filter_map results ~f:(function
            | Ok s -> Some s
            | Error _ -> None))
      else Error (String.concat ~sep:", " errors)
  | _ -> Error "Invalid response format"

let get_symbols ~token : (string list, string) Result.t Deferred.t =
  let uri = make_symbols_uri token in
  get_and_parse uri parse_symbols_response

let historical_price_uri ?(testonly_today = None) (params : Http_params.t) =
  let uri =
    Uri.make ~scheme:"https" ~host:api_host
      ~path:("/api/eod/" ^ params.symbol)
      ~query:[ ("fmt", [ "csv" ]); ("period", [ "d" ]); ("order", [ "a" ]) ]
      ()
  in
  let uri' =
    match params.start_date with
    | None -> uri
    | Some start_date -> Uri.add_query_param' uri ("from", start_date |> as_str)
  in
  let today =
    Option.value testonly_today ~default:(Date.today ~zone:Time_float.Zone.utc)
  in
  Uri.add_query_param' uri'
    ("to", Option.value params.end_date ~default:today |> as_str)

let get_historical_price ~(token : string) ~(params : Http_params.t) :
    (string, string) Result.t Deferred.t =
  let uri = historical_price_uri params in
  let uri' = Uri.add_query_param' uri ("api_token", token) in
  get_and_parse uri' (fun body_str -> Ok body_str)
