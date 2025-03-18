open Async
open CalendarLib

(* https://eodhd.com/financial-apis/api-for-historical-data-and-volumes *)
let api_host = "eodhd.com"
let query_base = [ ("fmt", [ "csv" ]); ("period", [ "d" ]); ("order", [ "a" ]) ]

let as_str (date : Date.t) =
  Printf.sprintf "%04d-%02d-%02d" (Date.year date)
    (Date.int_of_month @@ Date.month date)
    (Date.days_in_month date)

let to_uri ?(testonly_today = None) (params : Http_params.t) =
  let uri =
    Uri.make ~scheme:"https" ~host:api_host
      ~path:("/api/eod/" ^ params.symbol)
      ~query:query_base ()
  in
  let uri' =
    match params.start_date with
    | None -> uri
    | Some start_date -> Uri.add_query_param' uri ("from", start_date |> as_str)
  in
  let today = Option.value testonly_today ~default:(Date.today ()) in
  Uri.add_query_param' uri'
    ("to", Option.value params.end_date ~default:today |> as_str)

let get_historical_price ~(token : string) ~(params : Http_params.t) :
    (string, string) Result.t Deferred.t =
  let uri = to_uri params in
  let uri' = Uri.add_query_param' uri ("api_token", token) in
  Cohttp_async.Client.get uri' >>= fun (resp, body) ->
  match Cohttp.Response.status resp with
  | `OK -> Cohttp_async.Body.to_string body >>| fun body_str -> Ok body_str
  | status ->
      let status_str = Cohttp.Code.string_of_status status in
      Cohttp_async.Body.to_string body >>| fun body_str ->
      Error (Printf.sprintf "Error: %s\n%s" status_str body_str)
