open Core
open Trading_simulation

let _pair k v = Sexp.List [ Sexp.Atom k; v ]
let _atom s = Sexp.Atom s
let _float f = Sexp.Atom (sprintf "%.2f" f)
let _int i = Sexp.Atom (Int.to_string i)
let _commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }

let _code_version () =
  try
    let ic = Core_unix.open_process_in "git rev-parse HEAD" in
    let line = In_channel.input_line ic in
    let _ = Core_unix.close_process_in ic in
    Option.value line ~default:"unknown"
  with _ -> "unknown"

let _commission_sexp () =
  Sexp.List
    [
      _pair "per_share" (_float _commission.per_share);
      _pair "minimum" (_float _commission.minimum);
    ]

let _write_params ~output_dir (result : Runner.result) =
  let data_dir = Fpath.to_string (Data_path.default_data_dir ()) in
  let base =
    [
      _pair "code_version" (_atom (_code_version ()));
      _pair "start_date" (_atom (Date.to_string result.summary.start_date));
      _pair "end_date" (_atom (Date.to_string result.summary.end_date));
      _pair "initial_cash" (_float result.summary.initial_cash);
      _pair "universe_size" (_int result.summary.universe_size);
      _pair "data_dir" (_atom data_dir);
      _pair "commission" (_commission_sexp ());
    ]
  in
  let with_overrides =
    if List.is_empty result.overrides then base
    else base @ [ _pair "overrides" (Sexp.List result.overrides) ]
  in
  Sexp.save_hum (output_dir ^ "/params.sexp") (Sexp.List with_overrides)

let _write_trades ~output_dir ~(round_trips : Metrics.trade_metrics list) =
  let path = output_dir ^ "/trades.csv" in
  let oc = Out_channel.create path in
  fprintf oc
    "symbol,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars,pnl_percent\n";
  List.iter round_trips ~f:(fun (t : Metrics.trade_metrics) ->
      fprintf oc "%s,%s,%s,%d,%.2f,%.2f,%.0f,%.2f,%.2f\n" t.symbol
        (Date.to_string t.entry_date)
        (Date.to_string t.exit_date)
        t.days_held t.entry_price t.exit_price t.quantity t.pnl_dollars
        t.pnl_percent);
  Out_channel.close oc

let _write_equity_curve ~output_dir
    ~(steps : Trading_simulation_types.Simulator_types.step_result list) =
  let path = output_dir ^ "/equity_curve.csv" in
  let oc = Out_channel.create path in
  fprintf oc "date,portfolio_value\n";
  List.iter steps
    ~f:(fun (s : Trading_simulation_types.Simulator_types.step_result) ->
      fprintf oc "%s,%.2f\n" (Date.to_string s.date) s.portfolio_value);
  Out_channel.close oc

let write ~output_dir (result : Runner.result) =
  _write_params ~output_dir result;
  Sexp.save_hum
    (output_dir ^ "/summary.sexp")
    (Summary.sexp_of_t result.summary);
  _write_trades ~output_dir ~round_trips:result.round_trips;
  _write_equity_curve ~output_dir ~steps:result.steps
