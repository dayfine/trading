open Core
open Async

let read_file_as_string filename =
  In_channel.with_file filename ~f:In_channel.input_all

let save_to_csv ~filename ~data =
  Out_channel.write_all filename ~data

let fetch_data ~(token : string) ~(symbol : string) =
  Eodhd.Http_client.get_historical_price ~token
    ~params:{ symbol; start_date = None; end_date = None }

let handle_response ~symbol ~output_file response =
  match response with
  | Ok body ->
      print_endline ("Received data for " ^ symbol);
      (match output_file with
      | Some filename ->
          save_to_csv ~filename ~data:body;
          print_endline ("Saved data to " ^ filename);
          return ()
      | None ->
          print_endline body;
          return ())
  | Error error ->
      print_endline ("Error: " ^ error);
      return ()

let main symbol output_file () =
  let token = read_file_as_string "secrets" |> String.rstrip in
  fetch_data ~token ~symbol >>= handle_response ~symbol ~output_file

let command =
  Command.async ~summary:"Fetch historical price data from EODHD"
    (let%map_open.Command symbol =
       flag "symbol" (required string)
         ~aliases:["s"]
         ~doc:"SYMBOL Stock symbol to fetch (e.g. GOOG)"
     and output_file =
       flag "output" (optional string)
         ~aliases:["o"]
         ~doc:"FILE Optional output CSV file path"
     in
     main symbol output_file)

let () = Command_unix.run command
