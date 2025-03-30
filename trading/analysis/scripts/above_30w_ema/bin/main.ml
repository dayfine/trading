open Async
open Above_30w_ema

let main token =
  above_30w_ema ~token ()
  >>| print_results
  >>= fun () -> return ()

let () =
  Command_unix.run
    (Command.async
      ~summary:"Find S&P 500 stocks trading above their 30-week EMA"
      Command.Param.(
        map
          (flag "-token" (required string)
             ~doc:"API token for market data")
          ~f:(fun token () -> main token)))
