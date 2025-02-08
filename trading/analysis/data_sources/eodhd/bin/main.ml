open Core
open Async
open Eodhd

let fetch_url url =
  let uri = Uri.of_string url in
  Http_client.get_body ~uri >>= fun body ->
  print_endline ("Received body\n" ^ body);
  return ()

let main () = fetch_url "https://www.google.com/"

let () =
  Command.async ~summary:"Minimal Async example" (Command.Param.return main)
  |> Command_unix.run
