(** {!Stop_width_mode.Demote_over_max} ordering pass. See
    [entry_stop_width_order.mli]. *)

open Core
open Weinstein_strategy_config

(* The structural stop distance this candidate would install, recomputed through
   the same helpers [Entry_audit_capture.make_entry_transition] uses so the
   ordering and the gate cannot disagree at the boundary. [None] when no bars are
   resident and the distance is therefore unmeasurable. *)
let _distance_at ~config ~bar_reader ~current_date ~trigger_at_suggested
    ~effective_entry (cand : Screener.scored_candidate) =
  let initial_stop, _kind, _basis =
    Entry_audit_helpers.initial_stop_and_kind
      ~min_stop_distance_pct:
        (Entry_stop_distance.min_stop_distance_for ~config ~bar_reader
           ~current_date cand)
      ~reanchor_to_entry_base:
        (config.stop_anchor_at_entry_base && trigger_at_suggested)
      ~stops_config:config.stops_config
      ~initial_stop_buffer:config.initial_stop_buffer ~bar_reader ~current_date
      ~effective_entry cand
  in
  Entry_audit_helpers.stop_distance_pct ~effective_entry
    ~installed_stop:(Weinstein_stops.get_stop_level initial_stop)

let _stop_distance_pct_for ~config ~bar_reader ~current_date
    (cand : Screener.scored_candidate) =
  let close = Entry_audit_helpers.latest_close ~bar_reader ~current_date cand in
  let trigger_at_suggested =
    config.sim_entry_trigger_at_suggested && config.enable_sim_entry_stoplimit
  in
  let effective_entry =
    Entry_audit_helpers.effective_entry_of_close ~trigger_at_suggested ~close
      cand
  in
  if Float.( <= ) effective_entry 0.0 then None
  else
    Some
      (_distance_at ~config ~bar_reader ~current_date ~trigger_at_suggested
         ~effective_entry cand)

(* [true] when this candidate's stop is wider than the §5.1 limit — measured
   through the same helpers the gate uses, so the two cannot disagree. A symbol
   with no bars is NOT special-cased: it falls through to the
   [initial_stop_buffer] stop and is classified by that width, exactly as the
   gate would classify it. The only [None] case is a non-positive effective
   entry, where the ratio is undefined; it keeps its rank rather than being
   demoted on a division with no answer. *)
let _is_wide ~config ~bar_reader ~current_date cand =
  match _stop_distance_pct_for ~config ~bar_reader ~current_date cand with
  | None -> false
  | Some stop_distance_pct ->
      Stop_width_mode.over_book_limit
        ~max_stop_distance_pct:
          config.stops_config.Weinstein_stops.max_stop_distance_pct
        ~stop_distance_pct

let prefer_narrow_stops ~config ~bar_reader ~current_date candidates =
  let policy : Stop_width_mode.policy =
    {
      mode = config.stop_width_mode;
      size_down_max_pct = config.stop_width_size_down_max_pct;
    }
  in
  if not (Stop_width_mode.demotes ~policy) then candidates
  else
    let wide, narrow =
      List.partition_tf candidates
        ~f:(_is_wide ~config ~bar_reader ~current_date)
    in
    List.append narrow wide
