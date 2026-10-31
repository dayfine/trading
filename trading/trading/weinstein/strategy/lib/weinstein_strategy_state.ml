open Core

type t = {
  stop_states : Weinstein_stops.stop_state String.Map.t ref;
  last_stop_out_dates : Date.t Hashtbl.M(String).t;
  prior_macro : Weinstein_types.market_trend ref;
  peak_tracker : Portfolio_risk.Force_liquidation.Peak_tracker.t;
  prior_macro_result : Macro.result option ref;
  prior_decline_character : Decline_character.t ref;
  prior_stages : Weinstein_types.stage Hashtbl.M(String).t;
  prior_stage_ma_values : float Hashtbl.M(String).t;
  sector_prior_stages : Weinstein_types.stage Hashtbl.M(String).t;
  stage3_streaks : int Hashtbl.M(String).t;
  laggard_streaks : int Hashtbl.M(String).t;
  pending_entry_e : Entry_freeze.t;
  suspended_tickets : Entry_ticket_suspend.t;
}

let init ~initial_stop_states =
  {
    stop_states = ref initial_stop_states;
    last_stop_out_dates = Hashtbl.create (module String);
    prior_macro = ref Weinstein_types.Neutral;
    peak_tracker = Portfolio_risk.Force_liquidation.Peak_tracker.create ();
    prior_macro_result = ref None;
    (* Most recent index decline-character; updated at the macro step, read
       strictly-prior by the next tick's stops pass to arm the fast-crash
       stop. *)
    prior_decline_character = ref Decline_character.Not_declining;
    prior_stages = Hashtbl.create (module String);
    prior_stage_ma_values = Hashtbl.create (module String);
    sector_prior_stages = Hashtbl.create (module String);
    stage3_streaks = Hashtbl.create (module String);
    laggard_streaks = Hashtbl.create (module String);
    pending_entry_e = Entry_freeze.create ();
    suspended_tickets = Entry_ticket_suspend.create ();
  }

type snapshot = {
  stop_states : Weinstein_stops.stop_state String.Map.t;
  last_stop_out_dates : (string * Date.t) list;
  prior_macro : Weinstein_types.market_trend;
  peak : float;
  halt_state : Portfolio_risk.Force_liquidation.halt_state;
  prior_macro_result : Macro.result option;
  prior_decline_character : Decline_character.t;
  prior_stages : (string * Weinstein_types.stage) list;
  prior_stage_ma_values : (string * float) list;
  sector_prior_stages : (string * Weinstein_types.stage) list;
  stage3_streaks : (string * int) list;
  laggard_streaks : (string * int) list;
  pending_entry_e : Entry_freeze.snapshot;
  suspended_tickets : Entry_ticket_suspend.snapshot;
  position_counter : int;
}
[@@deriving sexp]

(* Key-sorted, so the sexp does not depend on hash-bucket order. *)
let _alist tbl =
  Hashtbl.to_alist tbl
  |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)

let _table alist = Hashtbl.of_alist_exn (module String) alist

module Peak = Portfolio_risk.Force_liquidation.Peak_tracker

let capture (t : t) : snapshot =
  {
    stop_states = !(t.stop_states);
    last_stop_out_dates = _alist t.last_stop_out_dates;
    prior_macro = !(t.prior_macro);
    peak = Peak.peak t.peak_tracker;
    halt_state = Peak.halt_state t.peak_tracker;
    prior_macro_result = !(t.prior_macro_result);
    prior_decline_character = !(t.prior_decline_character);
    prior_stages = _alist t.prior_stages;
    prior_stage_ma_values = _alist t.prior_stage_ma_values;
    sector_prior_stages = _alist t.sector_prior_stages;
    stage3_streaks = _alist t.stage3_streaks;
    laggard_streaks = _alist t.laggard_streaks;
    pending_entry_e = Entry_freeze.capture t.pending_entry_e;
    suspended_tickets = Entry_ticket_suspend.capture t.suspended_tickets;
    position_counter = Entry_audit_capture.position_counter ();
  }

let _restored_peak_tracker (snap : snapshot) =
  let peak_tracker = Peak.create () in
  Peak.restore peak_tracker ~peak:snap.peak ~halt_state:snap.halt_state;
  peak_tracker

let restore (snap : snapshot) : t =
  Entry_audit_capture.set_position_counter snap.position_counter;
  {
    stop_states = ref snap.stop_states;
    last_stop_out_dates = _table snap.last_stop_out_dates;
    prior_macro = ref snap.prior_macro;
    peak_tracker = _restored_peak_tracker snap;
    prior_macro_result = ref snap.prior_macro_result;
    prior_decline_character = ref snap.prior_decline_character;
    prior_stages = _table snap.prior_stages;
    prior_stage_ma_values = _table snap.prior_stage_ma_values;
    sector_prior_stages = _table snap.sector_prior_stages;
    stage3_streaks = _table snap.stage3_streaks;
    laggard_streaks = _table snap.laggard_streaks;
    pending_entry_e = Entry_freeze.restore snap.pending_entry_e;
    suspended_tickets = Entry_ticket_suspend.restore snap.suspended_tickets;
  }
