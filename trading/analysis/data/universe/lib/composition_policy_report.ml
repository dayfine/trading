open Core
module CPT = Composition_policy_types

let _asset_type_for ~asset_type symbol =
  match Hashtbl.find asset_type symbol with
  | Some t -> t
  | None -> Eodhd.Asset_type.Common_stock

(* Absent volume (or no [dollar_volume] map) defaults to +inf so the ADR floor
   never drops a symbol whose volume is unknown. *)
let _dollar_volume_for ~dollar_volume symbol =
  match dollar_volume with
  | None -> Float.infinity
  | Some tbl -> Option.value (Hashtbl.find tbl symbol) ~default:Float.infinity

let _candidate_of_entry ~asset_type ~dollar_volume rank (e : Snapshot.entry) :
    CPT.candidate =
  {
    symbol = e.symbol;
    asset_type = _asset_type_for ~asset_type e.symbol;
    sector = e.sector;
    avg_dollar_volume = _dollar_volume_for ~dollar_volume e.symbol;
    rank;
  }

let candidates_of_snapshot (snapshot : Snapshot.t) ~equity_like:_ ~asset_type
    ?dollar_volume () : CPT.candidate list =
  List.mapi snapshot.entries ~f:(_candidate_of_entry ~asset_type ~dollar_volume)

(* ------------------------------------------------------------------ *)
(* Report rendering                                                    *)
(* ------------------------------------------------------------------ *)

let _render_reason (reason : CPT.drop_reason) =
  match reason with
  | Dual_class_duplicate { kept_symbol } ->
      Printf.sprintf "dual-class duplicate of %s" kept_symbol
  | Reit_excluded -> "REIT excluded"
  | Adr_below_liquidity_floor { floor; avg_dollar_volume } ->
      Printf.sprintf "ADR below liquidity floor (%.0f < %.0f)" avg_dollar_volume
        floor
  | Preferred_excluded -> "preferred stock excluded"

let _render_drop (d : CPT.drop) =
  Printf.sprintf "    - %s: %s" d.symbol (_render_reason d.reason)

let _render_one_report (rep : CPT.filter_report) =
  let header =
    Printf.sprintf "[%s] dropped %d, kept %d" rep.filter
      (List.length rep.dropped) rep.kept_count
  in
  let lines = List.map rep.dropped ~f:_render_drop in
  String.concat ~sep:"\n" (header :: lines)

let render_reports (result : CPT.result) =
  let sections = List.map result.reports ~f:_render_one_report in
  let total_dropped =
    List.sum (module Int) result.reports ~f:(fun r -> List.length r.dropped)
  in
  let totals =
    Printf.sprintf "TOTAL: kept %d, dropped %d" (List.length result.kept)
      total_dropped
  in
  String.concat ~sep:"\n" (sections @ [ totals ])
