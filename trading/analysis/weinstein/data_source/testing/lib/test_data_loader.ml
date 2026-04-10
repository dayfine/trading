open Core

let _run_deferred d = Async.Thread_safe.block_on_async_exn (fun () -> d)

let load_daily_bars ~symbol ~start_date ~end_date =
  let data_dir = Fpath.to_string (Data_path.default_data_dir ()) in
  let config : Historical_source.config =
    { data_dir; simulation_date = end_date }
  in
  let ds = Historical_source.make config in
  let module DS = (val ds : Data_source.DATA_SOURCE) in
  let query : Data_source.bar_query =
    {
      symbol;
      period = Types.Cadence.Daily;
      start_date = Some start_date;
      end_date = Some end_date;
    }
  in
  match _run_deferred (DS.get_bars ~query ()) with
  | Ok bars -> bars
  | Error e ->
      failwith
        (Printf.sprintf
           "Failed to load %s (%s to %s): %s\n\
            Fix: run fetch_symbols.exe --symbols %s --api-key <key>"
           symbol
           (Date.to_string start_date)
           (Date.to_string end_date) (Status.show e) symbol)

let load_weekly_bars ~symbol ~start_date ~end_date =
  let daily = load_daily_bars ~symbol ~start_date ~end_date in
  Time_period.Conversion.daily_to_weekly ~include_partial_week:false daily
