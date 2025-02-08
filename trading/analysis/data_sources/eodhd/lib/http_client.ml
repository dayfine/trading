open Async
open Cohttp
open Cohttp_async

let api_host = "https://eodhd.com/api/eod/"

module Params = struct
  type t = { symbol : string }

  let make ~(symbol : string) = { symbol }

  (* https://eodhd.com/financial-apis/api-for-historical-data-and-volumes *)
  let to_uri (params : t) =
    Uri.make ~scheme:"https" ~host:api_host ~path:params.symbol
      ~query:[ ("fmt", [ "csv" ]); ("period", [ "d" ]); ("order", [ "a" ]) ]
      ()
end

let get_body ~token ~uri =
  let uri' = Uri.add_query_param' uri ("api_token", token) in
  let%bind resp, body = Cohttp_async.Client.get uri' in
  let code = resp |> Cohttp.Response.status |> Code.code_of_status in
  printf "Response code: %d\n" code;
  printf "Headers: %s\n" (resp |> Cohttp.Response.headers |> Header.to_string);
  Body.to_string body
