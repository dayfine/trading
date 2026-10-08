(** Entry-side audit emission. See [entry_audit_emit.mli]. *)

open Core

let _alternative_of_decision ~exclude_position_id (candidate, decision) :
    Audit_recorder.alternative_input option =
  match (decision : Entry_audit_capture.candidate_decision) with
  | Entry_audit_capture.Skipped reason ->
      Some { Audit_recorder.candidate; reason }
  | Kept (_, meta) ->
      if String.equal meta.position_id exclude_position_id then None else None

let alternatives_of_decisions ~decisions ~exclude_position_id :
    Audit_recorder.alternative_input list =
  List.filter_map decisions ~f:(_alternative_of_decision ~exclude_position_id)

let walk_decisions_of ~decisions : Audit_recorder.walk_decision list =
  List.map decisions ~f:(fun (ranked, decision) ->
      let outcome : Audit_recorder.walk_outcome =
        match (decision : Entry_audit_capture.candidate_decision) with
        | Entry_audit_capture.Kept _ -> Placed
        | Entry_audit_capture.Skipped reason -> Skipped reason
      in
      { Audit_recorder.ranked; outcome })

let all_alternatives_of_decisions ~decisions :
    Audit_recorder.alternative_input list =
  List.filter_map decisions ~f:(fun (candidate, decision) ->
      match (decision : Entry_audit_capture.candidate_decision) with
      | Entry_audit_capture.Skipped reason ->
          Some { Audit_recorder.candidate; reason }
      | Kept _ -> None)

let build_entry_event ~(macro : Macro.result) ~current_date
    ~(candidate : Screener.scored_candidate)
    ~(meta : Entry_audit_capture.entry_meta)
    ~(alternatives : Audit_recorder.alternative_input list) :
    Audit_recorder.entry_event =
  (* G14 fix B: dollar quantities key off the realised entry price (the most
     recent close from bar_reader at order placement) rather than the
     screener's [suggested_entry] (a buffered breakout level that can sit
     dollars above current price, or, in the cross-split-boundary case,
     orders of magnitude away). The candidate is still passed through to
     the audit row verbatim so [candidate.suggested_entry] remains visible
     as the screener's intent — only the position_value / risk_dollars
     fields are anchored to what actually got committed to capital. *)
  let initial_position_value =
    Float.of_int meta.shares *. meta.effective_entry_price
  in
  let initial_risk_dollars =
    Float.of_int meta.shares
    *. Float.abs (meta.effective_entry_price -. meta.installed_stop)
  in
  {
    Audit_recorder.position_id = meta.position_id;
    candidate;
    macro;
    current_date;
    close_at_decision = meta.close_at_decision;
    adjusted_close_at_decision = meta.adjusted_close_at_decision;
    installed_stop = meta.installed_stop;
    stop_floor_kind = meta.stop_floor_kind;
    split_safe_basis = meta.split_safe_basis;
    shares = meta.shares;
    initial_position_value;
    initial_risk_dollars;
    sized_down_wide_stop = meta.sized_down_wide_stop;
    entry_anchor = Screener.entry_anchor_kind candidate;
    freshness_basis =
      Entry_ticket_tags.freshness_basis_of_analysis candidate.analysis;
    triple_confirmation =
      Entry_ticket_tags.triple_confirmation_of_analysis candidate.analysis;
    alternatives;
  }

(** Record one audit entry for a [Kept] decision. [Skipped] decisions are
    silently ignored — they appear only in the [alternatives] lists of other
    entries. *)
let _emit_kept_decision ~(audit_recorder : Audit_recorder.t) ~pending_entry_e
    ~macro ~current_date ~decisions candidate
    (meta : Entry_audit_capture.entry_meta) =
  let alternatives =
    alternatives_of_decisions ~decisions ~exclude_position_id:meta.position_id
  in
  let event =
    build_entry_event ~macro ~current_date ~candidate ~meta ~alternatives
  in
  (* #3089: a frozen candidate's ticket rests at the pinned [E], so record the
     arm pinned with it rather than the one the current analysis selects. *)
  let event =
    {
      event with
      entry_anchor = Entry_freeze.anchor_kind pending_entry_e candidate;
    }
  in
  audit_recorder.record_entry event

(** Dispatch one decision: emit an audit entry if [Kept], skip if [Skipped]. *)
let _dispatch_one_decision ~audit_recorder ~pending_entry_e ~macro ~current_date
    ~decisions (candidate, (d : Entry_audit_capture.candidate_decision)) =
  match d with
  | Entry_audit_capture.Skipped _ -> ()
  | Kept (_, meta) ->
      _emit_kept_decision ~audit_recorder ~pending_entry_e ~macro ~current_date
        ~decisions candidate meta

let emit_entries ~(audit_recorder : Audit_recorder.t) ~pending_entry_e
    ~(macro : Macro.result option) ~current_date ~decisions =
  match macro with
  | None -> ()
  | Some macro ->
      let dispatch =
        _dispatch_one_decision ~audit_recorder ~pending_entry_e ~macro
          ~current_date ~decisions
      in
      List.iter decisions ~f:dispatch
