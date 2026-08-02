open Core
open Weinstein_snapshot

let for_candidate ~stops_config ~initial_stop_buffer ~bar_reader ~as_of
    ~(side : Trading_base.Types.position_side) (c : Weekly_snapshot.candidate) :
    Weekly_snapshot.candidate =
  let daily =
    Weinstein_strategy.Bar_reader.daily_bars_for bar_reader ~symbol:c.symbol
      ~as_of
  in
  if List.is_empty daily then c
  else
    (* Classify structural-vs-fallback through the SAME internal path the stop
       level below is computed from ([floor_is_structural] and
       [compute_initial_stop_with_floor] share [_floor_callbacks]), so the flag
       always agrees with the level under both [support_floor_anchor_mode] and
       [split_safe_floors]. Keying it off the Wick-only bar-list
       [find_recent_level] (as this did before) silently disagreed under a
       [Close]-anchored or split-safe level (#2167 QC finding). *)
    let is_structural =
      Weinstein_stops.floor_is_structural ~config:stops_config ~side ~bars:daily
        ~as_of
    in
    let state =
      Weinstein_stops.compute_initial_stop_with_floor ~config:stops_config ~side
        ~entry_price:c.entry ~bars:daily ~as_of
        ~fallback_buffer:initial_stop_buffer
    in
    {
      c with
      stop = Weinstein_stops.get_stop_level state;
      stop_is_structural = is_structural;
    }

let for_held_long ~stops_config ~initial_stop_buffer ~entry_price ~bars ~as_of =
  if List.is_empty bars then None
  else
    let state =
      Weinstein_stops.compute_initial_stop_with_floor ~config:stops_config
        ~side:Trading_base.Types.Long ~entry_price ~bars ~as_of
        ~fallback_buffer:initial_stop_buffer
    in
    Some (Weinstein_stops.get_stop_level state)
