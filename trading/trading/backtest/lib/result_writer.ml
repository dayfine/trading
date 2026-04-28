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

let _build_stop_index (stop_infos : Stop_log.stop_info list) =
  List.fold stop_infos
    ~init:(Map.empty (module String))
    ~f:(fun acc (info : Stop_log.stop_info) ->
      let existing = Map.find acc info.symbol |> Option.value ~default:[] in
      Map.set acc ~key:info.symbol ~data:(existing @ [ info ]))

let _exit_trigger_label (trigger : Stop_log.exit_trigger) =
  match trigger with
  | Stop_loss _ -> "stop_loss"
  | Take_profit _ -> "take_profit"
  | Signal_reversal _ -> "signal_reversal"
  | Time_expired _ -> "time_expired"
  | Underperforming _ -> "underperforming"
  | Portfolio_rebalancing -> "rebalancing"

let _pop_stop_info stop_index ~symbol =
  match Map.find !stop_index symbol with
  | Some (info :: rest) ->
      stop_index := Map.set !stop_index ~key:symbol ~data:rest;
      Some info
  | _ -> None

let _fmt_float_opt = function Some s -> sprintf "%.2f" s | None -> ""

let _stop_fields (info : Stop_log.stop_info option) =
  match info with
  | None -> ("", "", "")
  | Some i ->
      ( _fmt_float_opt i.entry_stop,
        _fmt_float_opt i.exit_stop,
        Option.value_map i.exit_trigger ~default:"" ~f:_exit_trigger_label )

let _write_trade_row oc stop_index (t : Metrics.trade_metrics) =
  let info = _pop_stop_info stop_index ~symbol:t.symbol in
  let entry_stop, exit_stop, exit_trigger = _stop_fields info in
  fprintf oc "%s,%s,%s,%d,%.2f,%.2f,%.0f,%.2f,%.2f,%s,%s,%s\n" t.symbol
    (Date.to_string t.entry_date)
    (Date.to_string t.exit_date)
    t.days_held t.entry_price t.exit_price t.quantity t.pnl_dollars
    t.pnl_percent entry_stop exit_stop exit_trigger

let _write_trades ~output_dir ~(round_trips : Metrics.trade_metrics list)
    ~(stop_infos : Stop_log.stop_info list) =
  let path = output_dir ^ "/trades.csv" in
  let oc = Out_channel.create path in
  let header =
    "symbol,entry_date,exit_date,days_held,entry_price,exit_price,"
    ^ "quantity,pnl_dollars,pnl_percent,entry_stop,exit_stop,exit_trigger"
  in
  fprintf oc "%s\n" header;
  let stop_index = ref (_build_stop_index stop_infos) in
  List.iter round_trips ~f:(_write_trade_row oc stop_index);
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

(** Persist [result.audit] as [trade_audit.sexp] when the collector captured any
    records. No file is written when the list is empty — that's the pre-PR-2
    default (capture sites not yet wired) and any consumer of the artefact must
    tolerate its absence. *)
let _write_trade_audit ~output_dir ~(audit : Trade_audit.audit_record list) =
  match audit with
  | [] -> ()
  | _ ->
      Sexp.save_hum
        (output_dir ^ "/trade_audit.sexp")
        (Trade_audit.sexp_of_audit_records audit)

let write ~output_dir (result : Runner.result) =
  _write_params ~output_dir result;
  Sexp.save_hum
    (output_dir ^ "/summary.sexp")
    (Summary.sexp_of_t result.summary);
  _write_trades ~output_dir ~round_trips:result.round_trips
    ~stop_infos:result.stop_infos;
  _write_equity_curve ~output_dir ~steps:result.steps;
  _write_trade_audit ~output_dir ~audit:result.audit
