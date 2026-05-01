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

(** G14 fix B: pin the entry price the strategy installs into [Position.t] state
    to the most recent raw close from [bar_reader]. The screener's
    [cand.suggested_entry] is a buffered breakout level (typically dollars above
    the actual current price) and historically diverged sharply from the
    broker's fill price for symbols whose lookback spanned a split boundary
    (e.g. PANW pre-split [cand.suggested_entry] in pre-split raw space vs broker
    fill in current raw space — see the G14 deep-dive in [dev/notes/] for the
    cascade timeline).

    Falls back to [cand.suggested_entry] when [bar_reader] returns no bars for
    [cand.ticker] (preserves the test/empty-bars edge). The
    [cand.suggested_entry] field itself remains the screener's audit metadata in
    [build_entry_event]; only the position-state and sizing/stop dollar
    quantities switch to the realised entry. *)
let _effective_entry_price ~bar_reader ~current_date
    (cand : Screener.scored_candidate) : float =
  let bars =
    Bar_reader.daily_bars_for bar_reader ~symbol:cand.ticker ~as_of:current_date
  in
  match List.last bars with
  | None -> cand.suggested_entry
  | Some bar -> bar.Types.Daily_price.close_price

(** Compute the support-floor-aware initial stop for [cand] entering at
    [effective_entry], plus the [stop_floor_kind] tag for audit. *)
let _initial_stop_and_kind ~stops_config ~initial_stop_buffer ~bar_reader
    ~current_date ~effective_entry (cand : Screener.scored_candidate) =
  let daily_view =
    Bar_reader.daily_view_for bar_reader ~symbol:cand.ticker ~as_of:current_date
      ~lookback:stops_config.Weinstein_stops.support_floor_lookback_bars
  in
  let callbacks =
    Panel_callbacks.support_floor_callbacks_of_daily_view daily_view
  in
  let initial_stop =
    Weinstein_stops.compute_initial_stop_with_floor_with_callbacks
      ~config:stops_config ~side:cand.side ~entry_price:effective_entry
      ~callbacks ~fallback_buffer:initial_stop_buffer
  in
  let stop_floor_kind =
    classify_stop_floor_kind ~stops_config ~callbacks ~side:cand.side
  in
  (initial_stop, stop_floor_kind)

(** Build the [CreateEntering] transition + [entry_meta] given the pre-computed
    sizing, initial stop, and effective entry. *)
let _build_transition_and_meta ~id ~current_date ~effective_entry ~shares
    ~initial_stop ~stop_floor_kind (cand : Screener.scored_candidate) =
  let description =
    Printf.sprintf "Weinstein %s: %s"
      (Weinstein_types.grade_to_string cand.grade)
      (String.concat ~sep:"; " cand.rationale)
  in
  let kind =
    Position.CreateEntering
      {
        symbol = cand.ticker;
        side = cand.side;
        target_quantity = Float.of_int shares;
        entry_price = effective_entry;
        reasoning = Position.ManualDecision { description };
      }
  in
  let transition = { Position.position_id = id; date = current_date; kind } in
  let meta : entry_meta =
    {
      position_id = id;
      shares;
      installed_stop = Weinstein_stops.get_stop_level initial_stop;
      stop_floor_kind;
      effective_entry_price = effective_entry;
    }
  in
  (transition, meta)

(** G15 step 3: distance between [installed_stop] and [effective_entry] as a
    fraction of [effective_entry]. Symmetric for longs and shorts — both can
    have a structurally wide initial stop when the recent counter-move floor
    sits far from current price. *)
let _stop_distance_pct ~effective_entry ~installed_stop =
  Float.abs (installed_stop -. effective_entry) /. effective_entry

let make_entry_transition ~portfolio_risk_config ~stops_config
    ~initial_stop_buffer ~stop_states ~bar_reader ~portfolio_value ~current_date
    (cand : Screener.scored_candidate) : entry_attempt_result =
  let effective_entry = _effective_entry_price ~bar_reader ~current_date cand in
  let initial_stop, stop_floor_kind =
    _initial_stop_and_kind ~stops_config ~initial_stop_buffer ~bar_reader
      ~current_date ~effective_entry cand
  in
  let installed_stop_level = Weinstein_stops.get_stop_level initial_stop in
  let stop_distance_pct =
    _stop_distance_pct ~effective_entry ~installed_stop:installed_stop_level
  in
  if
    Float.( > ) stop_distance_pct
      stops_config.Weinstein_stops.max_stop_distance_pct
  then Stop_too_wide
  else
    (* G15 step 3: size off the INSTALLED stop, not [cand.suggested_stop]. The
       support-floor-derived [installed_stop] may sit further from entry than
       the screener's pre-fill suggestion, in which case risk-per-share is
       larger and share count must shrink accordingly so total
       risk-to-stop = config.risk_per_trade_pct * portfolio_value (the
       fixed-risk-sizing contract). *)
    let sizing =
      Portfolio_risk.compute_position_size ~config:portfolio_risk_config
        ~portfolio_value
        ~side:(_sizing_side_of_cand_side cand.side)
        ~entry_price:effective_entry ~stop_price:installed_stop_level ()
    in
    if sizing.shares = 0 then Sized_zero
    else
      let id = gen_position_id cand.ticker in
      stop_states := Map.set !stop_states ~key:cand.ticker ~data:initial_stop;
      let trans, meta =
        _build_transition_and_meta ~id ~current_date ~effective_entry
          ~shares:sizing.shares ~initial_stop ~stop_floor_kind cand
      in
      Entry_ok (trans, meta)

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

let classify_candidate ~held_set ~make_entry ~remaining_cash ~short_notional_acc
    ~short_notional_cap (c : Screener.scored_candidate) : candidate_decision =
  if Set.mem held_set c.ticker then Skipped Already_held
  else
    match make_entry c with
    | Stop_too_wide -> Skipped Stop_too_wide
    | Sized_zero -> Skipped Sized_to_zero
    | Entry_ok (trans, meta) -> (
        match check_cash_and_deduct ~remaining_cash (trans, meta) with
        | None -> Skipped Insufficient_cash
        | Some (trans, meta) -> (
            match
              check_short_notional_cap ~short_notional_acc ~short_notional_cap
                (trans, meta) c
            with
            | Some (trans, meta) -> Kept (trans, meta)
            | None ->
                (* Refund the cash we tentatively deducted in the cash check
                   so subsequent candidates' cash gates see the correct
                   running balance. The candidate was admissible on cash
                   grounds but is being dropped on the short-notional cap. *)
                (remaining_cash :=
                   !remaining_cash
                   +.
                   match trans.kind with
                   | Position.CreateEntering e ->
                       e.target_quantity *. e.entry_price
                   | _ -> 0.0);
                Skipped Short_notional_cap))

let alternatives_of_decisions ~decisions ~exclude_position_id :
    Audit_recorder.alternative_input list =
  List.filter_map decisions ~f:(fun (candidate, decision) ->
      match decision with
      | Skipped reason -> Some { Audit_recorder.candidate; reason }
      | Kept (_, meta) ->
          if String.equal meta.position_id exclude_position_id then None
          else None)

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

let emit_entries ~(audit_recorder : Audit_recorder.t)
    ~(macro : Macro.result option) ~current_date ~decisions =
  match macro with
  | None -> ()
  | Some macro ->
      List.iter decisions ~f:(fun (candidate, d) ->
          match d with
          | Skipped _ -> ()
          | Kept (_, meta) ->
              let alternatives =
                alternatives_of_decisions ~decisions
                  ~exclude_position_id:meta.position_id
              in
              let event =
                build_entry_event ~macro ~current_date ~candidate ~meta
                  ~alternatives
              in
              audit_recorder.record_entry event)
