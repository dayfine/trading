open Core
open Async
open Fetch_prices
open Eodhd.Http_client

let read_token () =
  let file = "trading/analysis/data/sources/eodhd/secrets" in
  try Ok (String.strip (In_channel.read_all file))
  with Sys_error msg -> Error (sprintf "Failed to read API token: %s" msg)

let pick_random_elements x lst =
  Random.self_init ();
  lst
  |> List.map ~f:(fun e -> (Random.bits (), e))
  |> List.sort ~compare:(fun (r1, _) (r2, _) -> Int.compare r1 r2)
  |> List.map ~f:(fun (_, e) -> e)
  |> fun l -> List.take l x

let random_sample ~n symbols =
  let len = List.length symbols in
  if n = -1 || n >= len then symbols else pick_random_elements n symbols

let print_results results =
  let successes, failures =
    List.partition_map results ~f:(fun (symbol, res) ->
        match res with
        | Ok () -> Either.First symbol
        | Error status -> Either.Second (symbol, Status.show status))
  in
  printf "\nSuccessfully saved prices for %d symbols:\n" (List.length successes);
  List.iter successes ~f:(fun symbol -> printf "✓ %s\n" symbol);
  if not (List.is_empty failures) then (
    printf "\nFailed to save prices for %d symbols:\n" (List.length failures);
    List.iter failures ~f:(fun (symbol, msg) -> printf "✗ %s: %s\n" symbol msg))

let main ~num_symbols () =
  match read_token () with
  | Error msg ->
      printf "Error: %s\n" msg;
      return ()
  | Ok token -> (
      get_symbols ~token () >>= function
      | Error status ->
          printf "Error fetching symbols: %s\n" (Status.show status);
          return ()
      | Ok symbols ->
          let selected_symbols = random_sample ~n:num_symbols symbols in
          fetch_and_save_prices ~token ~symbols:selected_symbols ()
          >>| print_results)

let command =
  Command.async ~summary:"Fetch and save historical prices for multiple symbols"
    (let%map_open.Command num_symbols =
       flag "num-symbols"
         (optional_with_default 100 int)
         ~doc:
           "Number of random symbols to analyze (use -1 for all symbols, \
            default: 100)"
     in
     fun () -> main ~num_symbols ())

let () = Command_unix.run command
