open Core
open Async

let read_file_as_string filename =
  In_channel.with_file filename ~f:In_channel.input_all

let fetch_data ~token ~symbol =
  let params : Eodhd.Http_client.historical_price_params =
    { symbol; start_date = None; end_date = None }
  in
  Eodhd.Http_client.get_historical_price ~token ~params ()

let handle_response ~symbol = function
  | Ok prices ->
      printf "Received %d prices for %s\n" (List.length prices) symbol;
      List.iter prices ~f:(fun price ->
          printf "%s\n" (Types.Daily_price.show price))
  | Error status ->
      eprintf "Error fetching data for %s: %s\n" symbol (Status.show status)

let main symbol () =
  let secrets_path = "trading/analysis/data/sources/eodhd/secrets" in
  let token = read_file_as_string secrets_path |> String.rstrip in
  fetch_data ~token ~symbol >>= fun result ->
  handle_response ~symbol result;
  return ()

let command =
  Command.async ~summary:"Fetch historical price data from EODHD"
    (let%map_open.Command symbol =
       flag "symbol" (required string) ~aliases:[ "s" ]
         ~doc:"SYMBOL Stock symbol to fetch (e.g. GOOG)"
     in
     main symbol)

let () = Command_unix.run command
