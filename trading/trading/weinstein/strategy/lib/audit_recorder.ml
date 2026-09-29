(** Decision-trail recorder. See [audit_recorder.mli] for the contract. *)

open Core

type skip_reason =
  | Insufficient_cash
  | Already_held
  | Sized_to_zero
  | Short_notional_cap
  | Stop_too_wide
  | Sector_exposure_cap
  | Long_exposure_cap
  | No_structural_stop
  | Share_class_held

type alternative_input = {
  candidate : Screener.scored_candidate;
  reason : skip_reason;
}

type stop_floor_kind = Support_floor | Buffer_fallback

type split_safe_basis = Weinstein_stops.split_safe_basis =
  | Flag_off
  | Adjusted
  | Raw_fallback
  | Empty_window

(* Declared before the other event records on purpose: they share the
   [position_id] / [symbol] / [date] labels, and OCaml resolves an unannotated
   label to the LAST type declaring it — defining this one first leaves every
   existing unannotated access resolving exactly as before. *)
type stop_move_event = {
  position_id : string;
  symbol : string;
  date : Date.t;
  stop_level : float;
}

type entry_event = {
  position_id : string;
  candidate : Screener.scored_candidate;
  macro : Macro.result;
  current_date : Date.t;
  close_at_decision : float option;
  adjusted_close_at_decision : float option;
  installed_stop : float;
  stop_floor_kind : stop_floor_kind;
  split_safe_basis : split_safe_basis;
  shares : int;
  initial_position_value : float;
  initial_risk_dollars : float;
  sized_down_wide_stop : bool;
  freshness_basis : Entry_freshness.basis;
  triple_confirmation : Entry_ticket_tags.triple_confirmation;
  alternatives : alternative_input list;
}

type fill_volume_outcome = Ejected | Skipped_other_exit | Held

type fill_volume_event = {
  position_id : string;
  confirmation : Volume.breakout_confirmation option;
  outcome : fill_volume_outcome;
}

type exit_event = {
  position_id : string;
  symbol : string;
  exit_date : Date.t;
  exit_price : float;
  exit_reason : Trading_strategy.Position.exit_reason;
  macro_trend_at_exit : Weinstein_types.market_trend;
  macro_confidence_at_exit : float;
  stage_at_exit : Weinstein_types.stage;
  rs_trend_at_exit : Weinstein_types.rs_trend option;
  distance_from_ma_pct : float;
  max_favorable_excursion_pct : float;
  max_adverse_excursion_pct : float;
}

type cascade_drop = {
  analysis : Stock_analysis.t;
  sector : Screener.sector_context;
  side : Trading_base.Types.position_side;
  outcome : Screener.candidate_outcome;
}

type cascade_event = {
  date : Date.t;
  diagnostics : Screener.cascade_diagnostics;
  breadth_state : Weinstein_types.breadth_state;
  entered : int;
  candidates : alternative_input list;
  drops : cascade_drop list;
}

type force_liquidation_event = Portfolio_risk.Force_liquidation.event

type reissue_event = {
  reissued_position_id : string;
  original_position_id : string;
  reissue_date : Date.t;
}

type t = {
  record_entry : entry_event -> unit;
  record_exit : exit_event -> unit;
  record_cascade_summary : cascade_event -> unit;
  record_force_liquidation : force_liquidation_event -> unit;
  record_fill_volume : fill_volume_event -> unit;
  record_stop_move : stop_move_event -> unit;
  record_reissue : reissue_event -> unit;
  record_stop_decision : Weinstein_stops.Stop_decision.t -> unit;
  capture_candidates : bool;
}

let noop : t =
  {
    record_entry = (fun _ -> ());
    record_exit = (fun _ -> ());
    record_cascade_summary = (fun _ -> ());
    record_force_liquidation = (fun _ -> ());
    record_fill_volume = (fun _ -> ());
    record_stop_move = (fun _ -> ());
    record_stop_decision = (fun _ -> ());
    record_reissue = (fun _ -> ());
    capture_candidates = false;
  }
