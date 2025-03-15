open Weekly_indicators.Ema

let () =
  Ta_ocaml.Ta.initialize ();
  let data = read_csv_file "/workspaces/trading-1/trading/analysis/testdata/test_data.csv" in
  let ema_values = calculate_30_week_ema data in
  List.iter (fun (date, value) ->
    Printf.printf "%d-%02d-%02d: %.2f\n"
      date.year date.month date.day value
  ) ema_values;
  Ta_ocaml.Ta.shutdown ()
