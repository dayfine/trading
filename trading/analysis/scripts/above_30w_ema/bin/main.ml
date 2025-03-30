open Core
open Async
open Above_30w_ema

let read_token () =
  let file = "trading/analysis/data/sources/eodhd/secrets" in
  match In_channel.read_all file with
  | token -> String.strip token
  | exception _ -> failwith "Failed to read API token from secrets file"

let main () =
  let token = read_token () in
  above_30w_ema ~token () >>| print_results >>= fun () -> return ()

let command =
  Command.async ~summary:"Find S&P 500 stocks trading above their 30-week EMA"
    (let%map_open.Command () = return () in
     main)

let () = Command_unix.run command
