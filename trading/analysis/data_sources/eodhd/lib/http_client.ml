open Async
open Cohttp
open Cohttp_async

let get_body ~uri =
  let%bind resp, body = Cohttp_async.Client.get uri in
  let code = resp |> Cohttp.Response.status |> Code.code_of_status in
  printf "Response code: %d\n" code;
  printf "Headers: %s\n"
    (resp |> Cohttp.Response.headers |> Header.to_string);
  Body.to_string body

