open Core
open Ema

let parse_file filename =
  try
    let lines = In_channel.read_lines filename in
    let results = List.map ~f:Csv_storage.Parser.parse_line lines in
    let errors, oks =
      List.partition_map
        ~f:(fun r -> match r with Ok v -> Second v | Error e -> First e)
        results
    in
    match errors with
    | [] -> Ok oks
    | errs ->
        Error
          (Printf.sprintf "Failed to parse some lines in the CSV file:\n%s"
             (String.concat ~sep:"\n" errs))
  with Sys_error msg -> Error msg

let main input_file period () =
  Ta_ocaml.Ta.initialize ();
  match parse_file input_file with
  | Ok data ->
      let ema_values = calculate_ema_from_daily data period in
      List.iter ema_values ~f:(fun (date, value) ->
          Printf.printf "%d-%02d-%02d: %.2f\n" (Date.year date)
            (Month.to_int (Date.month date))
            (Date.day date) value);
      Ta_ocaml.Ta.shutdown ();
      exit 0
  | Error msg ->
      Printf.eprintf "Error reading file: %s\n" msg;
      Ta_ocaml.Ta.shutdown ();
      exit 1

let command =
  Command.basic ~summary:"Calculate EMA from daily price data"
    (let%map_open.Command input_file =
       flag "input" (required string)
         ~doc:"FILE Input CSV file with daily price data"
     and period =
       flag "period"
         (optional_with_default 30 int)
         ~doc:"INT Number of weeks for EMA calculation (default: 30)"
     in
     main input_file period)

let () = Command_unix.run command
