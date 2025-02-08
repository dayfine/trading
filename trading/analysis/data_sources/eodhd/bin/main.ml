open Core
open Async

let fetch_data symbol =
  let uri =
    Eodhd.Http_client.Params.make ~symbol |> Eodhd.Http_client.Params.to_uri
  in
  Eodhd.Http_client.get_body ~token:"123" ~uri >>= fun body ->
  print_endline ("Received body\n" ^ body);
  return ()

let main () = fetch_data "GOOG"

let () =
  Command.async ~summary:"Minimal Async example" (Command.Param.return main)
  |> Command_unix.run
