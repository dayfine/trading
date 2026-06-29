open Core
module BEU = Universe.Build_eligible_universe

type result = {
  written_path : string;
  entry_count : int;
  staleness_report : BEU.staleness_report;
}
[@@deriving show, eq]

let _symbol_types_path ~csv_data_dir =
  Filename.concat csv_data_dir "symbol_types.sexp"

let _sectors_csv_path ~csv_data_dir = Filename.concat csv_data_dir "sectors.csv"

(* The live-universe spec config with the caller-supplied gate values. *)
let _config ~inventory_path ~csv_data_dir ~min_price ~min_avg_dollar_volume
    ~max_staleness_trading_days =
  {
    (BEU.spec_config ~bars_root:csv_data_dir
       ~symbol_types_path:(_symbol_types_path ~csv_data_dir)
       ~sectors_csv_path:(_sectors_csv_path ~csv_data_dir)
       ~inventory_path)
    with
    min_price;
    min_avg_dollar_volume;
    max_staleness_trading_days;
  }

let run ~inventory_path ~csv_data_dir ~date ~min_price ~min_avg_dollar_volume
    ~max_staleness_trading_days ~output_path =
  let open Result.Let_syntax in
  let config =
    _config ~inventory_path ~csv_data_dir ~min_price ~min_avg_dollar_volume
      ~max_staleness_trading_days
  in
  let%bind snapshot, staleness_report =
    BEU.build_with_staleness_report ~date ~config
  in
  let%bind () = Universe.Snapshot.save snapshot ~path:output_path in
  Ok
    {
      written_path = output_path;
      entry_count = List.length snapshot.entries;
      staleness_report;
    }
