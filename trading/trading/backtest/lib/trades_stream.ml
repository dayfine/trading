(** [trades.csv] one-shot + incremental writer — see [trades_stream.mli]. *)

open Core
module Sim_types = Trading_simulation_types.Simulator_types

type batch = {
  round_trips : Trading_simulation.Metrics.trade_metrics list;
  stop_infos : Stop_log.stop_info list;
  audit : Trade_audit.audit_record list;
  force_liquidations : Portfolio_risk.Force_liquidation.event list;
}

let default_every_n_fridays = 4

(* ------------------------------------------------------------------ *)
(* Row rendering (moved verbatim from [result_writer.ml])              *)
(* ------------------------------------------------------------------ *)

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

let header =
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

let _write_trade_row oc force_liq_index ~ctx_pre
    (t : Trading_simulation.Metrics.trade_metrics) =
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

(** Render [round_trips] onto [oc] using the audit/stop-log indexes built once
    for the whole batch. Without the hoist, [Trade_context] rebuilt its audit
    map per row — O(N²) on a 15y cell (~3 700 round-trips × ~3 700 audit
    records). The same [ctx_pre] backs the per-row stop_info join, so
    [exit_trigger] and [stop_trigger_kind] resolve against one index. *)
let _write_rows oc ~(batch : batch) ~round_trips =
  let force_liq_index = _build_force_liq_index batch.force_liquidations in
  let ctx_pre =
    Trade_context.precompute ~audit:batch.audit ~stop_infos:batch.stop_infos
  in
  List.iter round_trips ~f:(_write_trade_row oc force_liq_index ~ctx_pre)

let _path ~output_dir = output_dir ^ "/trades.csv"

let write_all ~output_dir batch =
  let oc = Out_channel.create (_path ~output_dir) in
  fprintf oc "%s\n" header;
  _write_rows oc ~batch ~round_trips:batch.round_trips;
  Out_channel.close oc

(* ------------------------------------------------------------------ *)
(* Incremental appender                                                 *)
(* ------------------------------------------------------------------ *)

type t = {
  oc : Out_channel.t;
  every_n_fridays : int;
  snapshot : steps_rev:Sim_types.step_result list -> batch;
  mutable steps_rev : Sim_types.step_result list;
  mutable fridays_seen : int;
  mutable emitted_per_symbol : int String.Map.t;
  mutable rows_written : int;
  mutable closed : bool;
}

let create ~output_dir ?(every_n_fridays = default_every_n_fridays) ~snapshot ()
    =
  let oc = Out_channel.create (_path ~output_dir) in
  fprintf oc "%s\n" header;
  Out_channel.flush oc;
  {
    oc;
    every_n_fridays = Int.max 1 every_n_fridays;
    snapshot;
    steps_rev = [];
    fridays_seen = 0;
    emitted_per_symbol = String.Map.empty;
    rows_written = 0;
    closed = false;
  }

let rows_written t = t.rows_written

(** Group [round_trips] by symbol, preserving each symbol's chronological order.
    [Map.add_multi] prepends, hence the per-key reverse. *)
let _by_symbol round_trips =
  List.fold round_trips ~init:String.Map.empty
    ~f:(fun acc (rt : Trading_simulation.Metrics.trade_metrics) ->
      Map.add_multi acc ~key:rt.symbol ~data:rt)
  |> Map.map ~f:List.rev

(** Round-trips not yet emitted, plus the updated per-symbol emitted counts.
    Within a symbol the extractor's output only grows at the tail, so dropping
    the already-emitted prefix is exact. *)
let _fresh_round_trips ~emitted round_trips =
  Map.fold (_by_symbol round_trips) ~init:([], emitted)
    ~f:(fun ~key:symbol ~data:rts (fresh, counts) ->
      let already = Map.find counts symbol |> Option.value ~default:0 in
      ( List.drop rts already @ fresh,
        Map.set counts ~key:symbol ~data:(List.length rts) ))

(** Batch-local ordering: exit date first so a mid-run reader sees the file grow
    roughly chronologically, then symbol + entry date for determinism. *)
let _row_order (a : Trading_simulation.Metrics.trade_metrics)
    (b : Trading_simulation.Metrics.trade_metrics) =
  match Date.compare a.exit_date b.exit_date with
  | 0 -> (
      match String.compare a.symbol b.symbol with
      | 0 -> Date.compare a.entry_date b.entry_date
      | n -> n)
  | n -> n

let _flush t =
  let batch = t.snapshot ~steps_rev:t.steps_rev in
  let fresh, emitted =
    _fresh_round_trips ~emitted:t.emitted_per_symbol batch.round_trips
  in
  t.emitted_per_symbol <- emitted;
  let rows = List.sort fresh ~compare:_row_order in
  _write_rows t.oc ~batch ~round_trips:rows;
  t.rows_written <- t.rows_written + List.length rows;
  Out_channel.flush t.oc

let _is_friday date = Day_of_week.equal (Date.day_of_week date) Day_of_week.Fri

let record_step t ~date ~step =
  if not t.closed then (
    t.steps_rev <- step :: t.steps_rev;
    if _is_friday date then (
      t.fridays_seen <- t.fridays_seen + 1;
      if t.fridays_seen % t.every_n_fridays = 0 then _flush t))

let close t =
  if not t.closed then (
    t.closed <- true;
    Out_channel.close t.oc)
