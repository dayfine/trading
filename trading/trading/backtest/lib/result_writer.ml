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

let _write_trade_row oc stop_index force_liq_index ~audit ~stop_infos
    (t : Metrics.trade_metrics) =
  let info = _pop_stop_info stop_index ~symbol:t.symbol in
  let entry_stop, exit_stop, base_exit_trigger = _stop_fields info in
  let force_liq_key = t.symbol ^ "|" ^ Date.to_string t.exit_date in
  let exit_trigger =
    match Map.find force_liq_index force_liq_key with
    | Some reason -> _force_liq_label reason
    | None -> base_exit_trigger
  in
  let ctx = Trade_context.of_audit_and_stop_log ~audit ~stop_infos ~trade:t in
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
  let stop_index = ref (_build_stop_index stop_infos) in
  let force_liq_index = _build_force_liq_index force_liquidations in
  List.iter round_trips
    ~f:(_write_trade_row oc stop_index force_liq_index ~audit ~stop_infos);
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

(* ------------------------------------------------------------------ *)
(* Reconciler-producer artefacts                                        *)
(*                                                                      *)
(* The external [trading-reconciler] tool consumes three additional     *)
(* per-scenario CSVs to verify cash-floor / held-through-split /        *)
(* unrealized-P&L accounting. Schemas are pinned by                     *)
(* [~/Projects/trading-reconciler/PHASE_1_SPEC.md] §3 + §4 + §3.3 — the *)
(* reconciler exits 2 on any header drift so the writers below          *)
(* deliberately use literal header strings to land in the diff if       *)
(* drifted.                                                             *)
(* ------------------------------------------------------------------ *)

(** [LONG] for net-positive quantity, [SHORT] for net-negative. Used in
    [open_positions.csv] — case-sensitive per spec. *)
let _open_position_side_label (qty : float) =
  if Float.( > ) qty 0.0 then "LONG" else "SHORT"

(** Earliest acquisition date across the position's lots — the position's "entry
    date" in the PHASE_1_SPEC sense. The {!Trading_portfolio.Types.position_lot}
    invariant ([lots] sorted ascending by [acquisition_date]) means this is
    [(List.hd_exn lots).acquisition_date], but we [List.min_elt] defensively in
    case future refactors break the sort. *)
let _entry_date_of (pos : Trading_portfolio.Types.portfolio_position) =
  match
    List.min_elt pos.lots ~compare:(fun a b ->
        Date.compare a.acquisition_date b.acquisition_date)
  with
  | Some lot -> lot.acquisition_date
  | None -> failwithf "position %s has no lots" pos.symbol ()

(** One row per [Holding] position at run end. PHASE_1_SPEC §3:
    [symbol,side,entry_date,entry_price,quantity]. [entry_price] is the average
    cost per share (positive for both longs and shorts); [quantity] is the
    absolute share count. *)
let _write_open_positions ~output_dir ~steps =
  let open Trading_simulation_types.Simulator_types in
  let path = output_dir ^ "/open_positions.csv" in
  let oc = Out_channel.create path in
  fprintf oc "symbol,side,entry_date,entry_price,quantity\n";
  (match List.last steps with
  | None -> ()
  | Some last_step ->
      List.iter last_step.portfolio.Trading_portfolio.Portfolio.positions
        ~f:(fun (pos : Trading_portfolio.Types.portfolio_position) ->
          let qty = Trading_portfolio.Calculations.position_quantity pos in
          let avg_cost =
            Trading_portfolio.Calculations.avg_cost_of_position pos
          in
          let side = _open_position_side_label qty in
          let entry_date = _entry_date_of pos in
          fprintf oc "%s,%s,%s,%.2f,%.0f\n" pos.symbol side
            (Date.to_string entry_date)
            avg_cost (Float.abs qty)));
  Out_channel.close oc

(** One row per symbol present in [open_positions.csv]. PHASE_1_SPEC §3.3:
    [symbol,price]. Symbols held at run end without an entry in [final_prices]
    (e.g. delisted on the final calendar day) are silently dropped — the
    reconciler's join is left-anti and surfaces these as "missing final price"
    diagnostics. *)
let _write_final_prices ~output_dir ~steps
    ~(final_prices : (string * float) list) =
  let open Trading_simulation_types.Simulator_types in
  let path = output_dir ^ "/final_prices.csv" in
  let oc = Out_channel.create path in
  fprintf oc "symbol,price\n";
  let held_symbols =
    match List.last steps with
    | None -> String.Set.empty
    | Some last_step ->
        last_step.portfolio.Trading_portfolio.Portfolio.positions
        |> List.map ~f:(fun (p : Trading_portfolio.Types.portfolio_position) ->
            p.symbol)
        |> String.Set.of_list
  in
  let price_map =
    Map.of_alist_reduce (module String) final_prices ~f:(fun a _ -> a)
  in
  Set.iter held_symbols ~f:(fun sym ->
      match Map.find price_map sym with
      | Some price -> fprintf oc "%s,%.2f\n" sym price
      | None -> ());
  Out_channel.close oc

(** Format a split factor for [splits.csv]. PHASE_1_SPEC §4 examples show plain
    decimal output: [4.0] for forward 4:1, [0.125] for reverse 1:8. Strategy:
    integer factors render as [N.0] (via [%.1f]); fractional factors use [%.6g],
    which produces canonical [0.125] / [1.5] without trailing zeros. [%g] alone
    prints integer factors as ["4"] without a decimal point, which trips
    reconciler parsers expecting a float. *)
let _format_split_factor (f : float) =
  if Float.( = ) f (Float.round_down f) then sprintf "%.1f" f
  else sprintf "%.6g" f

(** All split events that fired during the run. Pulled from
    [step_result.splits_applied] across every step the simulator produced (the
    simulator only logs splits for symbols actively held that day, so no further
    filtering is needed). PHASE_1_SPEC §4: [symbol,date,factor]. *)
let _write_splits ~output_dir ~steps =
  let open Trading_simulation_types.Simulator_types in
  let path = output_dir ^ "/splits.csv" in
  let oc = Out_channel.create path in
  fprintf oc "symbol,date,factor\n";
  List.iter steps ~f:(fun (s : step_result) ->
      List.iter s.splits_applied
        ~f:(fun (e : Trading_portfolio.Split_event.t) ->
          fprintf oc "%s,%s,%s\n" e.symbol (Date.to_string e.date)
            (_format_split_factor e.factor)));
  Out_channel.close oc

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
  _write_open_positions ~output_dir ~steps:result.steps;
  _write_final_prices ~output_dir ~steps:result.steps
    ~final_prices:result.final_prices;
  _write_splits ~output_dir ~steps:result.steps;
  _write_universe ~output_dir ~universe:result.universe;
  Macro_trend_writer.write ~output_dir result.cascade_summaries
