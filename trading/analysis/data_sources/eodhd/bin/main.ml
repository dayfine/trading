open Core
open Async

let read_file_as_string filename =
  In_channel.with_file filename ~f:In_channel.input_all

let fetch_data ~(token : string) ~(symbol : string) =
  Eodhd.Http_client.get_historical_price ~token
    ~params:{ symbol; start_date = None; end_date = None }
  >>= function
  | Ok body ->
      print_endline ("Received body\n" ^ body);
      return ()
  | Error error ->
      print_endline ("Error: " ^ error);
      return ()

let main () =
  let token = read_file_as_string "secrets" |> String.rstrip in
  fetch_data ~token ~symbol:"GOOG"

(* TODO: make this symbol a flag?*)
let () =
  Command.async ~summary:"Minimal Async example" (Command.Param.return main)
  |> Command_unix.run
