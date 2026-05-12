(** Floor-widening primitive for [Initial] stops, separated from
    {!Weinstein_stops} to keep that module under the file-length linter limit.

    Used by {!Entry_audit_helpers.initial_stop_and_kind} to plumb
    {!Screener.candidate_params.installed_stop_min_pct} into the installed-stop
    path — restores the G15-severed coupling between a screener-recommended
    fraction and the actual placed stop without touching G15's sizing-off-
    installed-stop invariant. *)

open Trading_base.Types
open Stop_types

val widen_initial_to_min_distance :
  config:config ->
  side:position_side ->
  entry_price:float ->
  min_distance_pct:float ->
  stop_state ->
  stop_state
(** [widen_initial_to_min_distance ~config ~side ~entry_price ~min_distance_pct
     state] is a no-op when [min_distance_pct <= 0.0] or when [state] is not
    [Initial _]. Otherwise it ensures the [Initial] stop is at least
    [min_distance_pct] away from [entry_price] (below for [Long], above for
    [Short]); if the existing [stop_level] is already at least that far, [state]
    is returned unchanged. When widening, the new [stop_level] is set to
    [entry_price *. (1 -. pct)] (long) or [entry_price *. (1 +. pct)] (short),
    and [reference_level] is set to the value at which
    {!Weinstein_stops.compute_initial_stop} would re-produce the new
    [stop_level] bit-equally for [config.min_correction_pct]. This keeps the
    [Initial] record self-consistent for downstream split-adjust and
    trailing-state code.

    Floor semantic: the result is always at least as wide as the input.
    Preserves the G15 sizing contract (sizing reads installed [stop_level]
    only). *)
