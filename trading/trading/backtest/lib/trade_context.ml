(** Per-trade context columns for [trades.csv] export. See [.mli]. *)

open Core

type t = {
  symbol : string;
  entry_date : Date.t;
  entry_stage : string option;
  entry_volume_ratio : float option;
  stop_initial_distance_pct : float option;
  stop_trigger_kind : string option;
  days_to_first_stop_trigger : int option;
  screener_score_at_entry : int option;
  position_id : string option;
  stop_fill_distance_pct : float option;
  max_stop : float option;
  n_stop_raises : int option;
}
[@@deriving sexp]

let stage_label (s : Weinstein_types.stage) =
  match s with
  | Stage1 _ -> "Stage1"
  | Stage2 { late = true; _ } -> "Stage2_late"
  | Stage2 _ -> "Stage2"
  | Stage3 _ -> "Stage3"
  | Stage4 _ -> "Stage4"

let stop_trigger_kind_label (k : Stop_log.stop_trigger_kind) =
  match k with
  | Gap_down -> "gap_down"
  | Intraday -> "intraday"
  | End_of_period -> "end_of_period"
  | Non_stop_exit -> "non_stop_exit"

let csv_header_fields =
  [
    "entry_stage";
    "entry_volume_ratio";
    "stop_initial_distance_pct";
    "stop_trigger_kind";
    "days_to_first_stop_trigger";
    "screener_score_at_entry";
    Trades_csv_schema.position_id_column_name;
    "stop_fill_distance_pct";
    "max_stop";
    "n_stop_raises";
  ]

let _fmt_float4_opt = function Some f -> Printf.sprintf "%.4f" f | None -> ""

(* Price precision, matching the [entry_stop] / [exit_stop] columns the result
   writer emits, rather than the ratio precision used above. *)
let _fmt_price_opt = function Some f -> Printf.sprintf "%.2f" f | None -> ""
let _fmt_int_opt = function Some i -> Int.to_string i | None -> ""
let _fmt_string_opt = function Some s -> s | None -> ""

let csv_row_fields (t : t) =
  [
    _fmt_string_opt t.entry_stage;
    _fmt_float4_opt t.entry_volume_ratio;
    _fmt_float4_opt t.stop_initial_distance_pct;
    _fmt_string_opt t.stop_trigger_kind;
    _fmt_int_opt t.days_to_first_stop_trigger;
    _fmt_int_opt t.screener_score_at_entry;
    _fmt_string_opt t.position_id;
    _fmt_float4_opt t.stop_fill_distance_pct;
    _fmt_price_opt t.max_stop;
    _fmt_int_opt t.n_stop_raises;
  ]

(* Index construction lives in [Trade_context_index]; the lookup / fallback
   policy that reads those maps stays here, where the join-order contract is
   documented. *)
type precomputed = Trade_context_index.t

let precompute = Trade_context_index.build
let _audit_key = Trade_context_index.audit_key

(* Tolerance for the date-window fallback: a Friday decision whose fill lands a
   step or two later, plus long-weekend / holiday slack. Deliberately NOT
   widened to cover long-resting tickets — see the [.mli]'s join-order section
   for why that would attach wrong records rather than missing ones. *)
let _audit_lookup_window_days = 7

(* Predicate: audit record's entry_date is within the lookup window before
   [trade_entry_date]. Pulled out of [_lookup_audit_for_trade] to flatten its
   nesting. *)
let _within_audit_window ~trade_entry_date (r : Trade_audit.audit_record) =
  Date.( <= ) r.entry.entry_date trade_entry_date
  && Date.diff trade_entry_date r.entry.entry_date <= _audit_lookup_window_days

(* Fallback path: scan the per-symbol audit list for the most recent record
   inside the lookup window. List is pre-sorted newest-first, so [List.find]
   returns the closest match. *)
let _audit_window_fallback (pre : precomputed) ~symbol ~trade_entry_date =
  Option.bind
    (Map.find pre.audit_by_symbol symbol)
    ~f:(List.find ~f:(_within_audit_window ~trade_entry_date))

(* Legacy date-proximity join, kept as the fallback for round-trips carrying no
   position id: exact (symbol, entry_date), else the most recent record for
   [symbol] within [_audit_lookup_window_days] before the fill. *)
let _lookup_audit_by_date (pre : precomputed) ~symbol ~entry_date =
  let key = _audit_key ~symbol ~entry_date in
  match Map.find pre.audit_by_key key with
  | Some _ as r -> r
  | None -> _audit_window_fallback pre ~symbol ~trade_entry_date:entry_date

(* Prefer the exact [position_id] join; fall back to the date join when the
   round-trip has no position id, or one no audit record claims. *)
let _lookup_audit_for_trade (pre : precomputed) ~position_id ~symbol ~entry_date
    : Trade_audit.audit_record option =
  match Option.bind position_id ~f:(Map.find pre.audit_by_position_id) with
  | Some _ as r -> r
  | None -> _lookup_audit_by_date pre ~symbol ~entry_date

let _stop_info_for ~position_id ~symbol (pre : precomputed) :
    Stop_log.stop_info option =
  match position_id with
  | Some pid -> Map.find pre.stop_by_position_id pid
  | None -> Map.find pre.stop_first_by_symbol symbol

(* E-basis distance: measured against the screener's [suggested_entry], NOT the
   fill. In arms whose fill diverges from E (market-at-close vs a chased E) this
   overstates stop depth vs cost — see the 2026-08-07 confound resolution
   (fill-model findings §4 RESOLVED). Kept for backwards-compat; gate-basis
   analysis should read [stop_fill_distance_pct]. *)
let _stop_initial_distance_pct (entry : Trade_audit.entry_decision) =
  if Float.( <= ) entry.suggested_entry 0.0 then None
  else
    Some
      (Float.abs (entry.suggested_entry -. entry.installed_stop)
      /. entry.suggested_entry)

(* Fill-basis distance: |installed_stop - fill| / fill, the exact quantity the
   strategy's [Stop_too_wide] gate bounds (measured vs [effective_entry] at
   decision time) and the basis the V12 validator checks. [fill] is the round
   trip's realized entry price. *)
let _stop_fill_distance_pct ~fill (entry : Trade_audit.entry_decision) =
  if Float.( <= ) fill 0.0 || Float.( <= ) entry.installed_stop 0.0 then None
  else Some (Float.abs (entry.installed_stop -. fill) /. fill)

let _days_to_first_stop_trigger ~(entry_date : Date.t) ~(exit_date : Date.t)
    ~(trigger : Stop_log.exit_trigger option) =
  match trigger with
  | Some (Stop_loss _) -> Some (Date.diff exit_date entry_date)
  | _ -> None

(* Position ID for [trade]: the one the round-trip carries, else the one on the
   date-matched audit record. Every stop-derived column resolves through it. *)
let _position_id_for_trade (pre : precomputed)
    ~(trade : Trading_simulation.Metrics.trade_metrics) : string option =
  match trade.position_id with
  | Some _ as pid -> pid
  | None ->
      _lookup_audit_by_date pre ~symbol:trade.symbol
        ~entry_date:trade.entry_date
      |> Option.map ~f:(fun (r : Trade_audit.audit_record) ->
          r.entry.position_id)

let stop_info_for_trade (pre : precomputed)
    ~(trade : Trading_simulation.Metrics.trade_metrics) :
    Stop_log.stop_info option =
  let position_id = _position_id_for_trade pre ~trade in
  _stop_info_for ~position_id ~symbol:trade.symbol pre

(* The two stop-log-derived columns. They share a [trigger] and the entry side
   that classifies it, so they resolve together. *)
let _stop_columns ~entry ~stop_info ~entry_date ~exit_date =
  let trigger =
    Option.bind stop_info ~f:(fun (i : Stop_log.stop_info) -> i.exit_trigger)
  in
  let side =
    Option.value_map entry ~default:Trading_base.Types.Long
      ~f:(fun (e : Trade_audit.entry_decision) -> e.side)
  in
  ( Option.map trigger ~f:(fun t ->
        stop_trigger_kind_label (Stop_log.classify_stop_trigger_kind ~side t)),
    _days_to_first_stop_trigger ~entry_date ~exit_date ~trigger )

(* The two stop-ratchet observability columns. [n_stop_raises] stays [None] —
   not [Some 0] — when no stop-log record joined, so "never ratcheted" and "no
   record" remain distinguishable in the export. *)
let _stop_ratchet_columns (stop_info : Stop_log.stop_info option) =
  ( Option.bind stop_info ~f:(fun (i : Stop_log.stop_info) -> i.max_stop),
    Option.map stop_info ~f:(fun (i : Stop_log.stop_info) -> i.n_stop_raises) )

let of_precomputed (pre : precomputed)
    ~(trade : Trading_simulation.Metrics.trade_metrics) : t =
  let audit_record =
    _lookup_audit_for_trade pre ~position_id:trade.position_id
      ~symbol:trade.symbol ~entry_date:trade.entry_date
  in
  let entry =
    Option.map audit_record ~f:(fun (r : Trade_audit.audit_record) -> r.entry)
  in
  let position_id =
    Option.first_some trade.position_id
      (Option.map entry ~f:(fun e -> e.position_id))
  in
  let stop_info = stop_info_for_trade pre ~trade in
  let entry_stage = Option.map entry ~f:(fun e -> stage_label e.stage) in
  let entry_volume_ratio = Option.bind entry ~f:(fun e -> e.volume_ratio) in
  let stop_initial_distance_pct =
    Option.bind entry ~f:_stop_initial_distance_pct
  in
  let stop_fill_distance_pct =
    Option.bind entry ~f:(_stop_fill_distance_pct ~fill:trade.entry_price)
  in
  let screener_score_at_entry =
    Option.map entry ~f:(fun e -> e.cascade_score)
  in
  let stop_trigger_kind, days_to_first_stop_trigger =
    _stop_columns ~entry ~stop_info ~entry_date:trade.entry_date
      ~exit_date:trade.exit_date
  in
  let max_stop, n_stop_raises = _stop_ratchet_columns stop_info in
  {
    symbol = trade.symbol;
    entry_date = trade.entry_date;
    entry_stage;
    entry_volume_ratio;
    stop_initial_distance_pct;
    stop_trigger_kind;
    days_to_first_stop_trigger;
    screener_score_at_entry;
    position_id;
    stop_fill_distance_pct;
    max_stop;
    n_stop_raises;
  }

(** Convenience wrapper: builds [precomputed] inline. Per-trade callers in a
    loop should use [precompute] + [of_precomputed] directly to avoid rebuilding
    the indexes every call (the original O(N²) regression on Cell E 15 y came
    from this site rebuilding [audit_idx] per trade row). *)
let of_audit_and_stop_log ~audit ~stop_infos
    ~(trade : Trading_simulation.Metrics.trade_metrics) : t =
  let pre = precompute ~audit ~stop_infos in
  of_precomputed pre ~trade
