(** Decision-trail recorder. See [audit_recorder.mli] for the contract. *)

open Core

type skip_reason =
  | Insufficient_cash
  | Already_held
  | Sized_to_zero
  | Short_notional_cap
  | Stop_too_wide

type alternative_input = {
  candidate : Screener.scored_candidate;
  reason : skip_reason;
}

type stop_floor_kind = Support_floor | Buffer_fallback

type entry_event = {
  position_id : string;
  candidate : Screener.scored_candidate;
  macro : Macro.result;
  current_date : Date.t;
  installed_stop : float;
  stop_floor_kind : stop_floor_kind;
  shares : int;
  initial_position_value : float;
  initial_risk_dollars : float;
  alternatives : alternative_input list;
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
}

type cascade_event = {
  date : Date.t;
  diagnostics : Screener.cascade_diagnostics;
  entered : int;
}

type force_liquidation_event = Portfolio_risk.Force_liquidation.event

type t = {
  record_entry : entry_event -> unit;
  record_exit : exit_event -> unit;
  record_cascade_summary : cascade_event -> unit;
  record_force_liquidation : force_liquidation_event -> unit;
}

let noop : t =
  {
    record_entry = (fun _ -> ());
    record_exit = (fun _ -> ());
    record_cascade_summary = (fun _ -> ());
    record_force_liquidation = (fun _ -> ());
  }
