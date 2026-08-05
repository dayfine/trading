open Core
open Stop_types
open Trading_base.Types

(* Round-number nudging lives in {!Stop_nudge}. This adapts it to the stops
   config's [round_number_nudge] distance. *)
let _nudge_round_number ~config ~side price =
  Stop_nudge.nudge_round_number ~nudge:config.round_number_nudge ~side price

let compute_initial_stop ~config ~side ~reference_level =
  (* Half the min-correction threshold: places the initial stop modestly inside
     the reference level without using the full correction distance, which would
     be too loose for an entry stop. *)
  let delta = config.min_correction_pct /. 2.0 in
  let raw_stop =
    match side with
    | Long -> reference_level *. (1.0 -. delta)
    | Short -> reference_level *. (1.0 +. delta)
  in
  Initial
    { stop_level = _nudge_round_number ~config ~side raw_stop; reference_level }

(* Fallback reference when the bar history yields no qualifying counter-move.
   Mirrors the pre-primitive caller behaviour: push the reference point into
   the position's favour by the configured buffer. *)
let _fallback_reference ~side ~entry_price ~fallback_buffer =
  match side with
  | Long -> entry_price *. fallback_buffer
  | Short -> entry_price /. fallback_buffer

type callbacks = Support_floor.callbacks

let callbacks_from_bars ~config ~bars ~as_of =
  Support_floor.callbacks_from_bars ~bars ~as_of
    ~lookback_bars:config.support_floor_lookback_bars

(* Per-bar split/dividend factor [f = adjusted_close /. close_price] at
   [day_offset]. The guard is one-sided: a non-positive / NaN raw close admits
   no factor ([f = 1.0], the bar stays raw) so a corrupt raw close never blows
   up the rescale. A missing adjusted close (offset out of window) is likewise
   [1.0]; a present-but-NaN adjusted close propagates NaN, matching the
   bar-list behaviour where [Daily_price.adjusted_close] is taken as given. *)
let _adjusted_factor (cbs : callbacks) ~day_offset =
  match (cbs.get_close ~day_offset, cbs.get_adjusted_close ~day_offset) with
  | Some raw, Some adj when not (Float.is_nan raw || Float.( <= ) raw 0.0) ->
      adj /. raw
  | _, _ -> 1.0

(* Rescale a whole callbacks bundle onto its split/dividend-adjusted basis:
   scale the high / low by the per-bar factor and replace the close with the
   adjusted close outright (not [raw *. f], so the result is exactly the value
   the data source published). Inlined mirror of
   [Adjusted_basis.to_adjusted_basis] (analysis/weinstein/snapshot_pipeline) —
   this A2-forbidden layer cannot import analysis/, and the factor is derivable
   from the [get_adjusted_close] accessor every bundle carries. Keep in sync
   with [Adjusted_basis._factor] by hand if that formula ever changes.

   Idempotent: after one pass [get_close] already returns the adjusted close, so
   a second pass computes [f = adj /. adj = 1.0] and changes nothing.

   Applying the rescale at the bundle level rather than the bar level is what
   lets the panel/callback path share it — a [daily_view] has no
   [Daily_price.t] to rewrite, only accessors. The bar-list path is unaffected
   in value terms: scaling [high_price] / [low_price] and setting
   [close_price := adjusted_close] on each bar produces exactly these
   accessors. *)
let _to_adjusted_basis (cbs : callbacks) : callbacks =
  let scaled get ~day_offset =
    Option.map (get ~day_offset) ~f:(fun v ->
        v *. _adjusted_factor cbs ~day_offset)
  in
  {
    cbs with
    get_high = scaled cbs.get_high;
    get_low = scaled cbs.get_low;
    get_close =
      (fun ~day_offset ->
        match cbs.get_adjusted_close ~day_offset with
        | Some _ as adj -> adj
        | None -> cbs.get_close ~day_offset);
  }

(* The bundle the support-floor scan actually reads. Single source for every
   floor consumer — [compute_initial_stop_with_floor_with_callbacks] and
   [floor_is_structural_with_callbacks] — so the installed stop level and its
   [stop_is_structural] classification can never disagree. Under
   [config.split_safe_floors] the bundle is first rescaled onto the adjusted
   basis; default-off returns it untouched (bit-identical). *)
let _scan_callbacks ~config ~callbacks =
  if config.split_safe_floors then _to_adjusted_basis callbacks else callbacks

let _find_level ~config ~side ~callbacks =
  Support_floor.find_recent_level_with_callbacks
    ~anchor_mode:config.support_floor_anchor_mode
    ~callbacks:(_scan_callbacks ~config ~callbacks)
    ~side ~min_pullback_pct:config.min_correction_pct ()

let compute_initial_stop_with_floor_with_callbacks ~config ~side ~entry_price
    ~callbacks ~fallback_buffer =
  let reference_level =
    match _find_level ~config ~side ~callbacks with
    | Some level -> level
    | None -> _fallback_reference ~side ~entry_price ~fallback_buffer
  in
  compute_initial_stop ~config ~side ~reference_level

let floor_is_structural_with_callbacks ~config ~side ~callbacks =
  Option.is_some (_find_level ~config ~side ~callbacks)

let compute_initial_stop_with_floor ~config ~side ~entry_price ~bars ~as_of
    ~fallback_buffer =
  let callbacks = callbacks_from_bars ~config ~bars ~as_of in
  compute_initial_stop_with_floor_with_callbacks ~config ~side ~entry_price
    ~callbacks ~fallback_buffer

let floor_is_structural ~config ~side ~bars ~as_of =
  let callbacks = callbacks_from_bars ~config ~bars ~as_of in
  floor_is_structural_with_callbacks ~config ~side ~callbacks
