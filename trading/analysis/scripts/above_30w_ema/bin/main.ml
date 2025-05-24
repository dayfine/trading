open Core
open Async
open Above_30w_ema

let read_token () =
  let file = "trading/analysis/data/sources/eodhd/secrets" in
  match In_channel.read_all file with
  | token -> String.strip token
  | exception _ -> failwith "Failed to read API token from secrets file"

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

let main ~num_symbols () =
  let token = read_token () in
  Eodhd.Http_client.get_symbols ~token >>= function
  | Ok all_symbols ->
      let symbols = random_sample ~n:num_symbols all_symbols in
      above_30w_ema ~token ~symbols () >>| print_results >>= fun () -> return ()
  | Error status ->
      printf "Error fetching symbols: %s\n" (Status.show status);
      return ()

let command =
  Command.async ~summary:"Find stocks trading above their 30-week EMA"
    (let%map_open.Command num_symbols =
       flag "num-symbols"
         (optional_with_default 100 int)
         ~doc:
           "Number of random symbols to analyze (use -1 for all symbols, \
            default: 100)"
     in
     fun () -> main ~num_symbols ())

let () = Command_unix.run command
