(** Stop gate on the uncapped trigger. See [entry_cap_stop_gate.mli]. *)

open Core
open Weinstein_strategy_config

let _armed config =
  config.entry_cap_stop_gate_on_uncapped
  && config.entry_cap_local_range_weeks > 0

(* A long whose ticket the cap lowered: the [Local_range_top] arm, which fires
   for the cap alone while the replace anchor is off ({!validate}). *)
let _capped_long (cand : Screener.scored_candidate) =
  match (cand.side, Screener.entry_anchor_kind cand) with
  | Trading_base.Types.Long, Screener.Local_range_top -> true
  | _ -> false

(* The cap-off trigger: the [Breakout] arm's level, built the way the screener
   builds it ([Screener._build_candidate]). *)
let _uncapped_trigger ~config (cand : Screener.scored_candidate) =
  let entry_buffer_pct =
    config.screening_config.candidate_params.entry_buffer_pct
  in
  if _capped_long cand then
    Option.map cand.analysis.breakout_price
      ~f:(Screener.suggested_entry ~entry_buffer_pct)
  else None

let gate_entry ~config cand =
  let entry_is_trigger =
    config.sim_entry_trigger_at_suggested && config.enable_sim_entry_stoplimit
  in
  if _armed config && entry_is_trigger then _uncapped_trigger ~config cand
  else None

let validate config =
  if _armed config && config.entry_anchor_local_range_weeks > 0 then
    failwith
      "entry_cap_stop_gate_on_uncapped needs entry_anchor_local_range_weeks = \
       0: the uncapped replace anchor is not carried on the candidate";
  if _armed config && config.freeze_entry_at_first_breakout then
    failwith
      "entry_cap_stop_gate_on_uncapped needs freeze_entry_at_first_breakout \
       off: a frozen ticket's cap-off trigger is not carried on the candidate"
