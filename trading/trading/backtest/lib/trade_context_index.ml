(** Join indexes backing [Trade_context]'s per-trade projection. See [.mli]. *)

open Core

type t = {
  audit_by_position_id :
    (string, Trade_audit.audit_record, String.comparator_witness) Map.t;
  audit_by_key :
    (string, Trade_audit.audit_record, String.comparator_witness) Map.t;
  audit_by_symbol :
    (string, Trade_audit.audit_record list, String.comparator_witness) Map.t;
  stop_by_position_id :
    (string, Stop_log.stop_info, String.comparator_witness) Map.t;
  stop_first_by_symbol :
    (string, Stop_log.stop_info, String.comparator_witness) Map.t;
}

let audit_key ~symbol ~entry_date = symbol ^ "|" ^ Date.to_string entry_date

(* Position ids are unique per strategy position, so at most one record lands
   per key. *)
let _build_audit_by_position_id (audit : Trade_audit.audit_record list) =
  List.fold audit
    ~init:(Map.empty (module String))
    ~f:(fun acc (record : Trade_audit.audit_record) ->
      Map.set acc ~key:record.entry.position_id ~data:record)

let _build_audit_by_key (audit : Trade_audit.audit_record list) =
  List.fold audit
    ~init:(Map.empty (module String))
    ~f:(fun acc (record : Trade_audit.audit_record) ->
      let key =
        audit_key ~symbol:record.entry.symbol
          ~entry_date:record.entry.entry_date
      in
      Map.set acc ~key ~data:record)

(** Group audit records by symbol, sorted by [entry.entry_date] descending
    (newest first), so the caller's date-window fallback can take the closest
    prior record with a plain [List.find]. *)
let _build_audit_by_symbol (audit : Trade_audit.audit_record list) =
  List.fold audit
    ~init:(Map.empty (module String))
    ~f:(fun acc (record : Trade_audit.audit_record) ->
      Map.update acc record.entry.symbol ~f:(function
        | None -> [ record ]
        | Some xs -> record :: xs))
  |> Map.map ~f:(fun records ->
      List.sort records ~compare:(fun (a : Trade_audit.audit_record) b ->
          Date.compare b.entry.entry_date a.entry.entry_date))

let _build_stop_by_position_id (stop_infos : Stop_log.stop_info list) =
  List.fold stop_infos
    ~init:(Map.empty (module String))
    ~f:(fun acc (info : Stop_log.stop_info) ->
      Map.set acc ~key:info.position_id ~data:info)

(** Map symbol -> first {!Stop_log.stop_info} encountered for that symbol. The
    fallback path this replaced picked the first matching info via [List.find];
    preserving those head-first semantics means we only insert when the key is
    absent. *)
let _build_stop_first_by_symbol (stop_infos : Stop_log.stop_info list) =
  List.fold stop_infos
    ~init:(Map.empty (module String))
    ~f:(fun acc (info : Stop_log.stop_info) ->
      Map.update acc info.symbol ~f:(function
        | Some existing -> existing
        | None -> info))

let build ~(audit : Trade_audit.audit_record list)
    ~(stop_infos : Stop_log.stop_info list) : t =
  {
    audit_by_position_id = _build_audit_by_position_id audit;
    audit_by_key = _build_audit_by_key audit;
    audit_by_symbol = _build_audit_by_symbol audit;
    stop_by_position_id = _build_stop_by_position_id stop_infos;
    stop_first_by_symbol = _build_stop_first_by_symbol stop_infos;
  }
