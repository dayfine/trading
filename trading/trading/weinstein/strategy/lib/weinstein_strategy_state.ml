open Core

type t =
  Weinstein_stops.stop_state String.Map.t ref
  * Date.t Hashtbl.M(String).t
  * Weinstein_types.market_trend ref
  * Portfolio_risk.Force_liquidation.Peak_tracker.t
  * Macro.result option ref
  * Decline_character.t ref
  * Weinstein_types.stage Hashtbl.M(String).t
  * float Hashtbl.M(String).t
  * Weinstein_types.stage Hashtbl.M(String).t
  * int Hashtbl.M(String).t
  * int Hashtbl.M(String).t
  * Macro.ad_bar list

let init ~initial_stop_states ~ad_bars =
  let stop_states = ref initial_stop_states in
  let last_stop_out_dates : Date.t Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let prior_macro = ref Weinstein_types.Neutral in
  let peak_tracker = Portfolio_risk.Force_liquidation.Peak_tracker.create () in
  let prior_macro_result : Macro.result option ref = ref None in
  (* Most recent index decline-character; updated at the macro step, read
     strictly-prior by the next tick's stops pass to arm the fast-crash stop. *)
  let prior_decline_character = ref Decline_character.Not_declining in
  let prior_stages = Hashtbl.create (module String) in
  let prior_stage_ma_values : float Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let sector_prior_stages : Weinstein_types.stage Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let stage3_streaks : int Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let laggard_streaks : int Hashtbl.M(String).t =
    Hashtbl.create (module String)
  in
  let weekly_ad_bars = Ad_bars_aggregation.daily_to_weekly ad_bars in
  ( stop_states,
    last_stop_out_dates,
    prior_macro,
    peak_tracker,
    prior_macro_result,
    prior_decline_character,
    prior_stages,
    prior_stage_ma_values,
    sector_prior_stages,
    stage3_streaks,
    laggard_streaks,
    weekly_ad_bars )
