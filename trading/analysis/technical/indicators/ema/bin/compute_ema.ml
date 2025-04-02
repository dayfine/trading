open Core
open Ema
open Csv_storage.Parser
open Indicator_types
open Time_period.Conversion

let daily_prices_to_indicator_values prices =
  List.map prices ~f:(fun p ->
      { date = p.Types.Daily_price.date; value = p.adjusted_close })

let main input_file period weekly () =
  Ta_ocaml.Ta.initialize ();
  Exn.protect
    ~f:(fun () ->
      match read_file input_file with
      | Ok data ->
          let indicator_values =
            if weekly then
              let weekly_data = daily_to_weekly data in
              daily_prices_to_indicator_values weekly_data
            else daily_prices_to_indicator_values data
          in
          let ema_values = calculate_ema indicator_values period in
          List.iter ema_values ~f:(fun v ->
              Printf.printf "%d-%02d-%02d: %.2f\n" (Date.year v.date)
                (Month.to_int (Date.month v.date))
                (Date.day v.date) v.value);
          exit 0
      | Error msg ->
          Printf.eprintf "Error reading file: %s\n" msg;
          exit 1)
    ~finally:(fun () -> Ta_ocaml.Ta.shutdown ())

let command =
  Command.basic ~summary:"Calculate EMA from daily price data"
    (let%map_open.Command input_file =
       flag "input" (required string)
         ~doc:"FILE Input CSV file with daily price data"
     and period =
       flag "period"
         (optional_with_default 30 int)
         ~doc:"INT Number of periods for EMA calculation (default: 30)"
     and weekly =
       flag "weekly" no_arg ~doc:"Calculate weekly EMA instead of daily"
     in
     main input_file period weekly)

let () = Command_unix.run command
