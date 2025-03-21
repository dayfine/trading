open Core
open Weekly_indicators.Ema

let parse_file filename =
  try
    let lines = In_channel.read_lines filename in
    let results = List.map ~f:Csv_storage.Parser.parse_line lines in
    let errors, oks = List.partition_map ~f:(fun r -> match r with
      | Ok v -> Second v
      | Error e -> First e) results in
    match errors with
    | [] -> Ok oks
    | _ -> Error "Failed to parse some lines in the CSV file"
  with
  | Sys_error msg -> Error msg

let () =
  Ta_ocaml.Ta.initialize ();
  match parse_file "/workspaces/trading-1/trading/analysis/testdata/test_data.csv" with
  | Ok data ->
      let ema_values = calculate_30_week_ema data in
      List.iter ema_values ~f:(fun (date, value) ->
        Printf.printf "%d-%02d-%02d: %.2f\n"
          (Date.year date)
          (Month.to_int (Date.month date))
          (Date.day date)
          value)
  | Error msg ->
      Printf.eprintf "Error reading file: %s\n" msg;
      exit 1;
  Ta_ocaml.Ta.shutdown ()
