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
  ]

let _fmt_float4_opt = function Some f -> Printf.sprintf "%.4f" f | None -> ""
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
  ]

type precomputed = {
  audit_by_key :
    (string, Trade_audit.audit_record, String.comparator_witness) Map.t;
  stop_by_position_id :
    (string, Stop_log.stop_info, String.comparator_witness) Map.t;
  stop_first_by_symbol :
    (string, Stop_log.stop_info, String.comparator_witness) Map.t;
}

let _audit_key ~symbol ~entry_date = symbol ^ "|" ^ Date.to_string entry_date

let _build_audit_by_key (audit : Trade_audit.audit_record list) =
  List.fold audit
    ~init:(Map.empty (module String))
    ~f:(fun acc (record : Trade_audit.audit_record) ->
      let key =
        _audit_key ~symbol:record.entry.symbol
          ~entry_date:record.entry.entry_date
      in
      Map.set acc ~key ~data:record)

let _build_stop_by_position_id (stop_infos : Stop_log.stop_info list) =
  List.fold stop_infos
    ~init:(Map.empty (module String))
    ~f:(fun acc (info : Stop_log.stop_info) ->
      Map.set acc ~key:info.position_id ~data:info)

(** Map symbol -> first {!Stop_log.stop_info} encountered for that symbol. The
    fallback path in [_stop_info_for] picks the first matching info via
    [List.find]; preserving the head-first semantics here means we only insert
    when the key is absent. *)
let _build_stop_first_by_symbol (stop_infos : Stop_log.stop_info list) =
  List.fold stop_infos
    ~init:(Map.empty (module String))
    ~f:(fun acc (info : Stop_log.stop_info) ->
      Map.update acc info.symbol ~f:(function
        | Some existing -> existing
        | None -> info))

let precompute ~(audit : Trade_audit.audit_record list)
    ~(stop_infos : Stop_log.stop_info list) : precomputed =
  {
    audit_by_key = _build_audit_by_key audit;
    stop_by_position_id = _build_stop_by_position_id stop_infos;
    stop_first_by_symbol = _build_stop_first_by_symbol stop_infos;
  }

let _stop_info_for ~position_id ~symbol (pre : precomputed) :
    Stop_log.stop_info option =
  match position_id with
  | Some pid -> Map.find pre.stop_by_position_id pid
  | None -> Map.find pre.stop_first_by_symbol symbol

let _stop_initial_distance_pct (entry : Trade_audit.entry_decision) =
  if Float.( <= ) entry.suggested_entry 0.0 then None
  else
    Some
      (Float.abs (entry.suggested_entry -. entry.installed_stop)
      /. entry.suggested_entry)

let _days_to_first_stop_trigger ~(entry_date : Date.t) ~(exit_date : Date.t)
    ~(trigger : Stop_log.exit_trigger option) =
  match trigger with
  | Some (Stop_loss _) -> Some (Date.diff exit_date entry_date)
  | _ -> None

let of_precomputed (pre : precomputed)
    ~(trade : Trading_simulation.Metrics.trade_metrics) : t =
  let key = _audit_key ~symbol:trade.symbol ~entry_date:trade.entry_date in
  let audit_record = Map.find pre.audit_by_key key in
  let entry =
    Option.map audit_record ~f:(fun (r : Trade_audit.audit_record) -> r.entry)
  in
  let position_id = Option.map entry ~f:(fun e -> e.position_id) in
  let stop_info = _stop_info_for ~position_id ~symbol:trade.symbol pre in
  let entry_stage = Option.map entry ~f:(fun e -> stage_label e.stage) in
  let entry_volume_ratio = Option.bind entry ~f:(fun e -> e.volume_ratio) in
  let stop_initial_distance_pct =
    Option.bind entry ~f:_stop_initial_distance_pct
  in
  let screener_score_at_entry =
    Option.map entry ~f:(fun e -> e.cascade_score)
  in
  let trigger =
    Option.bind stop_info ~f:(fun (i : Stop_log.stop_info) -> i.exit_trigger)
  in
  let side =
    Option.value_map entry ~default:Trading_base.Types.Long ~f:(fun e -> e.side)
  in
  let stop_trigger_kind =
    Option.map trigger ~f:(fun t ->
        stop_trigger_kind_label (Stop_log.classify_stop_trigger_kind ~side t))
  in
  let days_to_first_stop_trigger =
    _days_to_first_stop_trigger ~entry_date:trade.entry_date
      ~exit_date:trade.exit_date ~trigger
  in
  {
    symbol = trade.symbol;
    entry_date = trade.entry_date;
    entry_stage;
    entry_volume_ratio;
    stop_initial_distance_pct;
    stop_trigger_kind;
    days_to_first_stop_trigger;
    screener_score_at_entry;
  }

(** Convenience wrapper: builds [precomputed] inline. Per-trade callers in a
    loop should use [precompute] + [of_precomputed] directly to avoid rebuilding
    the indexes every call (the original O(N²) regression on Cell E 15 y came
    from this site rebuilding [audit_idx] per trade row). *)
let of_audit_and_stop_log ~audit ~stop_infos
    ~(trade : Trading_simulation.Metrics.trade_metrics) : t =
  let pre = precompute ~audit ~stop_infos in
  of_precomputed pre ~trade
