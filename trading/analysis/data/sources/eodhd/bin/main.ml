open Core
open Async

let read_file_as_string filename =
  In_channel.with_file filename ~f:In_channel.input_all

let save_to_csv ~filename ~data = Out_channel.write_all filename ~data

let fetch_data ~(token : string) ~(symbol : string) =
  Eodhd.Http_client.get_historical_price ~token
    ~params:{ symbol; start_date = None; end_date = None }

let handle_response ~symbol ~output_file response =
  match response with
  | Ok body -> (
      Async.Log.Global.info "Received data for %s" symbol;
      match output_file with
      | Some filename ->
          save_to_csv ~filename ~data:body;
          Async.Log.Global.info "Saved data to %s" filename;
          return ()
      | None ->
          Async.Log.Global.info "Data:\n%s" body;
          return ())
  | Error error ->
      Async.Log.Global.error "Error: %s" error;
      return ()

let main symbol output_file () =
  let secrets_path = "trading/analysis/data/sources/eodhd/secrets" in
  let token = read_file_as_string secrets_path |> String.rstrip in
  fetch_data ~token ~symbol >>= handle_response ~symbol ~output_file

let command =
  Command.async ~summary:"Fetch historical price data from EODHD"
    (let%map_open.Command symbol =
       flag "symbol" (required string) ~aliases:[ "s" ]
         ~doc:"SYMBOL Stock symbol to fetch (e.g. GOOG)"
     and output_file =
       flag "output" (optional string) ~aliases:[ "o" ]
         ~doc:"FILE Optional output CSV file path"
     in
     main symbol output_file)

let () = Command_unix.run command
