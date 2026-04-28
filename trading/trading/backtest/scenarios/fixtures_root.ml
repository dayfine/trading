let resolve ?fixtures_root () =
  match fixtures_root with
  | Some p -> p
  | None ->
      let data_dir = Data_path.default_data_dir () |> Fpath.to_string in
      Filename.concat data_dir "backtest_scenarios"
