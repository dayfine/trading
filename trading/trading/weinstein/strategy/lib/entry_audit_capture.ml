(** Entry-side trade-audit capture. See [entry_audit_capture.mli]. *)

open Core
open Trading_strategy

type entry_meta = {
  position_id : string;
  shares : int;
  installed_stop : float;
  stop_floor_kind : Audit_recorder.stop_floor_kind;
  effective_entry_price : float;
}

(** Outcome of an attempt to construct an entry transition for one candidate.
    Distinguishes the two pre-cash gates the strategy applies in
    {!make_entry_transition}: a stop wider than
    [stops_config.max_stop_distance_pct] (G15 step 3 — Weinstein book §5.1
    "reject if stop > 15%") and round-share sizing collapsing to zero. The
    caller's classifier maps these directly into [Audit_recorder.skip_reason]s
    so the audit row records WHICH gate fired. *)
type entry_attempt_result =
  | Entry_ok of Position.transition * entry_meta
  | Stop_too_wide
  | Sized_zero

type candidate_decision =
  | Kept of Position.transition * entry_meta
  | Skipped of Audit_recorder.skip_reason

let classify_stop_floor_kind ~stops_config ~callbacks ~side :
    Audit_recorder.stop_floor_kind =
  match
    Weinstein_stops.Support_floor.find_recent_level_with_callbacks ~callbacks
      ~side ~min_pullback_pct:stops_config.Weinstein_stops.min_correction_pct
  with
  | Some _ -> Support_floor
  | None -> Buffer_fallback

(* ------------------------------------------------------------------ *)
(* Per-candidate entry construction                                     *)
(* ------------------------------------------------------------------ *)

let _position_counter = ref 0

let gen_position_id symbol =
  Int.incr _position_counter;
  Printf.sprintf "%s-wein-%d" symbol !_position_counter

let _sizing_side_of_cand_side (side : Trading_base.Types.position_side) =
  match side with Long -> `Long | Short -> `Short

(** Size the candidate and, on success, register the stop and build the
    transition + meta. Returns [Sized_zero] when share count rounds to 0. *)
let _size_and_build_entry ~portfolio_risk_config ~portfolio_value ~stop_states
    ~current_date ~effective_entry ~initial_stop ~stop_floor_kind ~id
    ~stop_distance_pct ~max_stop_distance_pct (cand : Screener.scored_candidate)
    : entry_attempt_result =
  let installed_stop_level = Weinstein_stops.get_stop_level initial_stop in
  let sizing =
    Portfolio_risk.compute_position_size ~config:portfolio_risk_config
      ~portfolio_value
      ~side:(_sizing_side_of_cand_side cand.side)
      ~entry_price:effective_entry ~stop_price:installed_stop_level ()
  in
  if sizing.shares = 0 then (
    Entry_audit_helpers.emit_candidate_trace ~ticker:cand.ticker
      ~score:cand.score ~rationale:cand.rationale ~effective_entry
      ~installed_stop:installed_stop_level ~stop_distance_pct
      ~max_stop_distance_pct ~outcome:"Sized_zero";
    Sized_zero)
  else (
    Entry_audit_helpers.emit_candidate_trace ~ticker:cand.ticker
      ~score:cand.score ~rationale:cand.rationale ~effective_entry
      ~installed_stop:installed_stop_level ~stop_distance_pct
      ~max_stop_distance_pct ~outcome:"Pass";
    stop_states := Map.set !stop_states ~key:cand.ticker ~data:initial_stop;
    let trans =
      Entry_audit_helpers.build_entry_transition ~id ~current_date
        ~effective_entry ~shares:sizing.shares cand
    in
    let meta : entry_meta =
      {
        position_id = id;
        shares = sizing.shares;
        installed_stop = installed_stop_level;
        stop_floor_kind;
        effective_entry_price = effective_entry;
      }
    in
    Entry_ok (trans, meta))

let make_entry_transition ~portfolio_risk_config ~stops_config
    ~initial_stop_buffer ~stop_states ~bar_reader ~portfolio_value ~current_date
    (cand : Screener.scored_candidate) : entry_attempt_result =
  let effective_entry =
    Entry_audit_helpers.effective_entry_price ~bar_reader ~current_date cand
  in
  let initial_stop, stop_floor_kind =
    Entry_audit_helpers.initial_stop_and_kind ~stops_config ~initial_stop_buffer
      ~bar_reader ~current_date ~effective_entry cand
  in
  let installed_stop_level = Weinstein_stops.get_stop_level initial_stop in
  let stop_distance_pct =
    Entry_audit_helpers.stop_distance_pct ~effective_entry
      ~installed_stop:installed_stop_level
  in
  let max_stop_distance_pct =
    stops_config.Weinstein_stops.max_stop_distance_pct
  in
  if Float.( > ) stop_distance_pct max_stop_distance_pct then (
    Entry_audit_helpers.emit_candidate_trace ~ticker:cand.ticker
      ~score:cand.score ~rationale:cand.rationale ~effective_entry
      ~installed_stop:installed_stop_level ~stop_distance_pct
      ~max_stop_distance_pct ~outcome:"Stop_too_wide";
    Stop_too_wide)
  else
    (* G15 step 3: size off the INSTALLED stop, not [cand.suggested_stop]. The
       support-floor-derived [installed_stop] may sit further from entry than
       the screener's pre-fill suggestion, in which case risk-per-share is
       larger and share count must shrink accordingly so total
       risk-to-stop = config.risk_per_trade_pct * portfolio_value (the
       fixed-risk-sizing contract). *)
    let id = gen_position_id cand.ticker in
    _size_and_build_entry ~portfolio_risk_config ~portfolio_value ~stop_states
      ~current_date ~effective_entry ~initial_stop ~stop_floor_kind ~id
      ~stop_distance_pct ~max_stop_distance_pct cand

let check_cash_and_deduct ~remaining_cash
    ((trans : Position.transition), (meta : entry_meta)) =
  match trans.kind with
  | Position.CreateEntering e ->
      let cost = e.target_quantity *. e.entry_price in
      if Float.( > ) cost !remaining_cash then None
      else (
        remaining_cash := !remaining_cash -. cost;
        Some (trans, meta))
  | _ -> Some (trans, meta)

(** G15 step 2: aggregate short-notional cap evaluated at entry-decision time.

    The aggregate cap is checked on a running [short_notional_acc] that starts
    at the existing short notional in the portfolio (computed once by the caller
    from the [Holding] state of every short position) and grows as short
    candidates are admitted within this Friday's entry walk.

    For [Long] candidates the gate is a no-op pass-through: longs cannot push
    the cap up, and the strategy still admits them via the cash check.

    Pure side effect on [short_notional_acc]: bumped only on a [Short] candidate
    that passes — that way later [Short] candidates within the same walk see the
    up-to-date running total and the cap is enforced monotonically across the
    cascade. *)
let check_short_notional_cap ~short_notional_acc ~short_notional_cap
    ((trans : Position.transition), (meta : entry_meta))
    (cand : Screener.scored_candidate) =
  match cand.side with
  | Trading_base.Types.Long -> Some (trans, meta)
  | Trading_base.Types.Short ->
      let candidate_notional =
        Float.of_int meta.shares *. meta.effective_entry_price
      in
      let projected = !short_notional_acc +. candidate_notional in
      if Float.( > ) projected short_notional_cap then None
      else (
        short_notional_acc := projected;
        Some (trans, meta))

(* Refund the cash tentatively deducted by [check_cash_and_deduct] when the
   notional-cap gate subsequently rejects the candidate. This keeps the running
   cash balance correct for later candidates in the same walk. *)
let _refund_cash_for_trans ~remaining_cash (trans : Position.transition) =
  remaining_cash :=
    !remaining_cash
    +.
    match trans.kind with
    | Position.CreateEntering e -> e.target_quantity *. e.entry_price
    | _ -> 0.0

(** Check the short-notional cap for a cash-cleared entry. Returns [Kept] or
    [Skipped Short_notional_cap], refunding the tentatively deducted cash on
    rejection so subsequent cash gates see the correct running balance. *)
let _apply_notional_cap_gate ~remaining_cash ~short_notional_acc
    ~short_notional_cap ~emit (cand : Screener.scored_candidate) trans meta :
    candidate_decision =
  match
    check_short_notional_cap ~short_notional_acc ~short_notional_cap
      (trans, meta) cand
  with
  | Some (trans, meta) ->
      emit "Kept";
      Kept (trans, meta)
  | None ->
      _refund_cash_for_trans ~remaining_cash trans;
      emit "Short_notional_cap";
      Skipped Short_notional_cap

(** Apply the cash and short-notional-cap gates to an [Entry_ok] result. Returns
    [Kept] on double-pass or the appropriate [Skipped] variant. *)
let _apply_entry_ok_gates ~remaining_cash ~short_notional_acc
    ~short_notional_cap ~emit ~(cand : Screener.scored_candidate) trans meta :
    candidate_decision =
  match check_cash_and_deduct ~remaining_cash (trans, meta) with
  | None ->
      emit "Insufficient_cash";
      Skipped Insufficient_cash
  | Some (trans, meta) ->
      _apply_notional_cap_gate ~remaining_cash ~short_notional_acc
        ~short_notional_cap ~emit cand trans meta

let classify_candidate ~held_set ~make_entry ~remaining_cash ~short_notional_acc
    ~short_notional_cap (c : Screener.scored_candidate) : candidate_decision =
  let emit decision =
    Entry_audit_helpers.emit_decision_trace ~ticker:c.ticker ~side:c.side
      ~decision ~remaining_cash:!remaining_cash
      ~short_notional_acc:!short_notional_acc
  in
  if Set.mem held_set c.ticker then (
    emit "Already_held";
    Skipped Already_held)
  else
    match make_entry c with
    | Stop_too_wide ->
        emit "Stop_too_wide";
        Skipped Stop_too_wide
    | Sized_zero ->
        emit "Sized_to_zero";
        Skipped Sized_to_zero
    | Entry_ok (trans, meta) ->
        _apply_entry_ok_gates ~remaining_cash ~short_notional_acc
          ~short_notional_cap ~emit ~cand:c trans meta

let _alternative_of_decision ~exclude_position_id (candidate, decision) :
    Audit_recorder.alternative_input option =
  match decision with
  | Skipped reason -> Some { Audit_recorder.candidate; reason }
  | Kept (_, meta) ->
      if String.equal meta.position_id exclude_position_id then None else None

let alternatives_of_decisions ~decisions ~exclude_position_id :
    Audit_recorder.alternative_input list =
  List.filter_map decisions ~f:(_alternative_of_decision ~exclude_position_id)

let build_entry_event ~(macro : Macro.result) ~current_date
    ~(candidate : Screener.scored_candidate) ~(meta : entry_meta)
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
    installed_stop = meta.installed_stop;
    stop_floor_kind = meta.stop_floor_kind;
    shares = meta.shares;
    initial_position_value;
    initial_risk_dollars;
    alternatives;
  }

(** Record one audit entry for a [Kept] decision. [Skipped] decisions are
    silently ignored — they appear only in the [alternatives] lists of other
    entries. *)
let _emit_kept_decision ~(audit_recorder : Audit_recorder.t) ~macro
    ~current_date ~decisions candidate meta =
  let alternatives =
    alternatives_of_decisions ~decisions ~exclude_position_id:meta.position_id
  in
  let event =
    build_entry_event ~macro ~current_date ~candidate ~meta ~alternatives
  in
  audit_recorder.record_entry event

(** Dispatch one decision: emit an audit entry if [Kept], skip if [Skipped]. *)
let _dispatch_one_decision ~audit_recorder ~macro ~current_date ~decisions
    (candidate, d) =
  match d with
  | Skipped _ -> ()
  | Kept (_, meta) ->
      _emit_kept_decision ~audit_recorder ~macro ~current_date ~decisions
        candidate meta

let emit_entries ~(audit_recorder : Audit_recorder.t)
    ~(macro : Macro.result option) ~current_date ~decisions =
  match macro with
  | None -> ()
  | Some macro ->
      let dispatch =
        _dispatch_one_decision ~audit_recorder ~macro ~current_date ~decisions
      in
      List.iter decisions ~f:dispatch
