open Core
open Async

let read_file_as_string filename =
  In_channel.with_file filename ~f:In_channel.input_all

let fetch_data ~(token: string) ~(symbol: string) =
  let uri =
    Eodhd.Http_client.Params.make ~symbol |> Eodhd.Http_client.Params.to_uri
  in
  Eodhd.Http_client.get_body ~token ~uri >>= fun body ->
    print_endline ("Received body\n" ^ body);
  return ()

let main () = 
  let token = read_file_as_string "secrets" |> String.rstrip in
  fetch_data ~token ~symbol:"GOOG"

let () =
  Command.async ~summary:"Minimal Async example" (Command.Param.return main)
  |> Command_unix.run
