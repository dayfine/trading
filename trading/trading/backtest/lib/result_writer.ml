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

let _exit_trigger_label (trigger : Stop_log.exit_trigger) =
  match trigger with
  | Stop_loss _ -> "stop_loss"
  | Take_profit _ -> "take_profit"
  | Signal_reversal _ -> "signal_reversal"
  | Time_expired _ -> "time_expired"
  | Underperforming _ -> "underperforming"
  | Portfolio_rebalancing -> "rebalancing"
  | Strategy_signal { label; _ } -> label
  | End_of_period -> "end_of_period"

(** Build a (symbol, exit_date) -> reason map from force-liquidation events.
    [trades.csv] rows are post-processed: when a row's (symbol, exit_date)
    matches a recorded force-liquidation, the [exit_trigger] column is
    overridden from the generic stop-loss label to the force-liquidation label.
    The pair (symbol, exit_date) is unique enough in practice — a single
    position cannot be force-closed twice and the same symbol can only re-enter
    on a different date. *)
let _build_force_liq_index
    (events : Portfolio_risk.Force_liquidation.event list) =
  List.fold events
    ~init:(Map.empty (module String))
    ~f:(fun acc (e : Portfolio_risk.Force_liquidation.event) ->
      let key = e.symbol ^ "|" ^ Date.to_string e.date in
      Map.set acc ~key ~data:e.reason)

let _force_liq_label (reason : Portfolio_risk.Force_liquidation.reason) =
  match reason with
  | Per_position -> "force_liquidation_position"
  | Portfolio_floor -> "force_liquidation_portfolio"

let _fmt_float_opt = function Some s -> sprintf "%.2f" s | None -> ""

let _stop_fields (info : Stop_log.stop_info option) =
  match info with
  | None -> ("", "", "")
  | Some i ->
      ( _fmt_float_opt i.entry_stop,
        _fmt_float_opt i.exit_stop,
        Option.value_map i.exit_trigger ~default:"" ~f:_exit_trigger_label )

(** Direction label for a round-trip's entry leg, surfaced as the [side] column
    in [trades.csv]. [LONG] = Buy→Sell round-trip; [SHORT] = Sell→Buy round-trip
    (closing buy covers the short). *)
let _side_label = function
  | Trading_base.Types.Buy -> "LONG"
  | Trading_base.Types.Sell -> "SHORT"

let _trades_csv_header =
  let base =
    [
      "symbol";
      "side";
      "entry_date";
      "exit_date";
      "days_held";
      "entry_price";
      "exit_price";
      "quantity";
      "pnl_dollars";
      "pnl_percent";
      "entry_stop";
      "exit_stop";
      "exit_trigger";
    ]
  in
  String.concat ~sep:"," (base @ Trade_context.csv_header_fields)

let _write_trade_row oc force_liq_index ~ctx_pre (t : Metrics.trade_metrics) =
  (* Resolve the stop_info via the same position-keyed join {!Trade_context}
     uses for [stop_trigger_kind], so [entry_stop] / [exit_stop] / [exit_trigger]
     stay consistent with it. The prior symbol-keyed FIFO pop misaligned against
     that join on re-traded symbols (Nth position got the wrong trigger). *)
  let info = Trade_context.stop_info_for_trade ctx_pre ~trade:t in
  let entry_stop, exit_stop, base_exit_trigger = _stop_fields info in
  let force_liq_key = t.symbol ^ "|" ^ Date.to_string t.exit_date in
  let exit_trigger =
    match Map.find force_liq_index force_liq_key with
    | Some reason -> _force_liq_label reason
    | None -> base_exit_trigger
  in
  let ctx = Trade_context.of_precomputed ctx_pre ~trade:t in
  let base_cells =
    [
      t.symbol;
      _side_label t.side;
      Date.to_string t.entry_date;
      Date.to_string t.exit_date;
      Int.to_string t.days_held;
      sprintf "%.2f" t.entry_price;
      sprintf "%.2f" t.exit_price;
      sprintf "%.0f" t.quantity;
      sprintf "%.2f" t.pnl_dollars;
      sprintf "%.2f" t.pnl_percent;
      entry_stop;
      exit_stop;
      exit_trigger;
    ]
  in
  let cells = base_cells @ Trade_context.csv_row_fields ctx in
  fprintf oc "%s\n" (String.concat ~sep:"," cells)

let _write_trades ~output_dir ~(round_trips : Metrics.trade_metrics list)
    ~(stop_infos : Stop_log.stop_info list)
    ~(audit : Trade_audit.audit_record list)
    ~(force_liquidations : Portfolio_risk.Force_liquidation.event list) =
  let path = output_dir ^ "/trades.csv" in
  let oc = Out_channel.create path in
  fprintf oc "%s\n" _trades_csv_header;
  let force_liq_index = _build_force_liq_index force_liquidations in
  (* Build the audit + stop-log indexes once, not per row. Without this hoist,
     [Trade_context.of_audit_and_stop_log] rebuilt the audit_idx Map every
     call — turning [trades.csv] writing into O(N²) on Cell E 15 y
     (~3 700 round-trips × ~3 700 audit records). The same [ctx_pre] also backs
     the per-row stop_info join, so [exit_trigger] and [stop_trigger_kind]
     resolve against one index. *)
  let ctx_pre = Trade_context.precompute ~audit ~stop_infos in
  List.iter round_trips ~f:(_write_trade_row oc force_liq_index ~ctx_pre);
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

(** Persist [result.audit] + [result.cascade_summaries] as [trade_audit.sexp]
    when either is non-empty. No file is written when both are empty — that's
    the live-mode / unwired-capture default and downstream consumers must
    tolerate its absence.

    The on-disk format is the {!Trade_audit.audit_blob} envelope, which holds
    both lists in a single sexp record so a single file load returns both the
    per-trade decision trail and the per-Friday cascade activity. *)
let _write_trade_audit ~output_dir ~(audit : Trade_audit.audit_record list)
    ~(cascade_summaries : Trade_audit.cascade_summary list) =
  match (audit, cascade_summaries) with
  | [], [] -> ()
  | _, _ ->
      let blob : Trade_audit.audit_blob =
        { audit_records = audit; cascade_summaries }
      in
      Sexp.save_hum
        (output_dir ^ "/trade_audit.sexp")
        (Trade_audit.sexp_of_audit_blob blob)

(** Persist [result.force_liquidations] as [force_liquidations.sexp] when
    non-empty. Empty list (the common case — the policy did not fire) produces
    no file rather than an empty-record sexp; downstream consumers tolerate the
    file's absence. *)
let _write_force_liquidations ~output_dir
    ~(force_liquidations : Portfolio_risk.Force_liquidation.event list) =
  match force_liquidations with
  | [] -> ()
  | evs ->
      let blob : Force_liquidation_log.artefact = { events = evs } in
      Sexp.save_hum
        (output_dir ^ "/force_liquidations.sexp")
        (Force_liquidation_log.sexp_of_artefact blob)

(** Persist [result.stale_holds] as [stale_holds.sexp] when non-empty. Empty
    list (the common case — every held position kept producing bars through
    end-of-run) produces no file. Each event records (symbol, step date,
    last_bar_date, last_close, days_since_last_bar, quantity, cost_basis) so a
    release-gate consumer can audit corporate-action exposure without re-running
    the simulator. See {!Trading_simulation.Stale_hold}. *)
let _write_stale_holds ~output_dir
    ~(stale_holds : Trading_simulation.Stale_hold.event list) =
  match stale_holds with
  | [] -> ()
  | evs ->
      let blob : Trading_simulation.Stale_hold.artefact = { events = evs } in
      Sexp.save_hum
        (output_dir ^ "/stale_holds.sexp")
        (Trading_simulation.Stale_hold.sexp_of_artefact blob)

(** Write [universe.txt]: one symbol per line, no header. Captures the post-cap
    universe the simulator actually traded over (excluding the primary index and
    sector ETFs) so downstream counterfactual tooling — [optimal_strategy] in
    particular — can scope its analysis to the same set rather than reading the
    full [data/sectors.csv]. The file is always written, even when
    [result.universe] is empty (header-less / row-less file in that degenerate
    case). *)
let _write_universe ~output_dir ~(universe : string list) =
  let path = output_dir ^ "/universe.txt" in
  let oc = Out_channel.create path in
  List.iter universe ~f:(fun sym -> fprintf oc "%s\n" sym);
  Out_channel.close oc

let write ~output_dir (result : Runner.result) =
  _write_params ~output_dir result;
  Sexp.save_hum
    (output_dir ^ "/summary.sexp")
    (Summary.sexp_of_t result.summary);
  _write_trades ~output_dir ~round_trips:result.round_trips
    ~stop_infos:result.stop_infos ~audit:result.audit
    ~force_liquidations:result.force_liquidations;
  _write_equity_curve ~output_dir ~steps:result.steps;
  _write_trade_audit ~output_dir ~audit:result.audit
    ~cascade_summaries:result.cascade_summaries;
  _write_force_liquidations ~output_dir
    ~force_liquidations:result.force_liquidations;
  _write_stale_holds ~output_dir ~stale_holds:result.stale_holds;
  Reconciler_writer.write_open_positions ~output_dir
    ~final_portfolio:result.final_portfolio;
  Reconciler_writer.write_final_prices ~output_dir
    ~final_portfolio:result.final_portfolio ~final_prices:result.final_prices;
  Reconciler_writer.write_splits ~output_dir ~steps:result.steps;
  _write_universe ~output_dir ~universe:result.universe;
  Macro_trend_writer.write ~output_dir result.cascade_summaries
