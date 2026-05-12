open Core
open Trading_base.Types
open Stop_types

(* Helpers for {!widen_initial_to_min_distance}. Side-direction-aware so they
   work bit-equally for [Long] and [Short]. *)

let _target_for_floor ~side ~entry ~pct =
  match side with
  | Long -> entry *. (1.0 -. pct)
  | Short -> entry *. (1.0 +. pct)

let _is_too_tight ~side ~current ~target =
  match side with
  | Long -> Float.( > ) current target
  | Short -> Float.( < ) current target

(* Synthetic [reference_level] s.t. [Weinstein_stops.compute_initial_stop
   ~config ~side ~ref] re-produces [target] bit-equally — keeps the [Initial]
   record self-consistent for downstream split-adjust + trailing code. *)
let _synth_reference ~side ~delta ~target =
  match side with
  | Long -> target /. (1.0 -. delta)
  | Short -> target /. (1.0 +. delta)

let widen_initial_to_min_distance ~config ~side ~entry_price ~min_distance_pct
    (state : stop_state) =
  match (state, Float.( <= ) min_distance_pct 0.0) with
  | _, true | (Trailing _ | Tightened _), _ -> state
  | Initial { stop_level; _ }, false ->
      let target =
        _target_for_floor ~side ~entry:entry_price ~pct:min_distance_pct
      in
      if not (_is_too_tight ~side ~current:stop_level ~target) then state
      else
        let delta = config.min_correction_pct /. 2.0 in
        let new_ref = _synth_reference ~side ~delta ~target in
        Initial { stop_level = target; reference_level = new_ref }
