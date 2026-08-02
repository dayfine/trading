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

(* Rescale one raw-OHLC bar onto its split/dividend-adjusted basis: scale O/H/L
   by the per-bar factor [f = adjusted_close /. close_price] and set
   [close_price := adjusted_close]. Inlined mirror of
   [Adjusted_basis.to_adjusted_basis] (analysis/weinstein/snapshot_pipeline) —
   this A2-forbidden layer cannot import analysis/, and the factor is derivable
   from [Daily_price.adjusted_close], already carried on every bar. The guard is
   one-sided: a non-positive / NaN raw close admits no factor ([f = 1.0], O/H/L
   stay raw) so a corrupt raw close never blows up the rescale. Keep in sync
   with [Adjusted_basis._factor] by hand if that formula ever changes. *)
let _to_adjusted_basis_bar (b : Types.Daily_price.t) : Types.Daily_price.t =
  let f =
    if Float.is_nan b.close_price || Float.( <= ) b.close_price 0.0 then 1.0
    else b.adjusted_close /. b.close_price
  in
  {
    b with
    open_price = b.open_price *. f;
    high_price = b.high_price *. f;
    low_price = b.low_price *. f;
    close_price = b.adjusted_close;
  }

(* Build the support-floor callbacks the bar-list stop path scans. Single source
   for both [compute_initial_stop_with_floor] and [floor_is_structural] so the
   installed stop level and its [stop_is_structural] classification always read
   the same window. When [config.split_safe_floors] the bars are first rescaled
   onto their adjusted basis (see [_to_adjusted_basis_bar]); default-off feeds
   the raw bars unchanged (bit-identical). *)
let _floor_callbacks ~config ~bars ~as_of =
  let bars =
    if config.split_safe_floors then List.map bars ~f:_to_adjusted_basis_bar
    else bars
  in
  callbacks_from_bars ~config ~bars ~as_of

let compute_initial_stop_with_floor_with_callbacks ~config ~side ~entry_price
    ~callbacks ~fallback_buffer =
  let reference_level =
    match
      Support_floor.find_recent_level_with_callbacks
        ~anchor_mode:config.support_floor_anchor_mode ~callbacks ~side
        ~min_pullback_pct:config.min_correction_pct ()
    with
    | Some level -> level
    | None -> _fallback_reference ~side ~entry_price ~fallback_buffer
  in
  compute_initial_stop ~config ~side ~reference_level

let compute_initial_stop_with_floor ~config ~side ~entry_price ~bars ~as_of
    ~fallback_buffer =
  let callbacks = _floor_callbacks ~config ~bars ~as_of in
  compute_initial_stop_with_floor_with_callbacks ~config ~side ~entry_price
    ~callbacks ~fallback_buffer

let floor_is_structural ~config ~side ~bars ~as_of =
  let callbacks = _floor_callbacks ~config ~bars ~as_of in
  Option.is_some
    (Support_floor.find_recent_level_with_callbacks
       ~anchor_mode:config.support_floor_anchor_mode ~callbacks ~side
       ~min_pullback_pct:config.min_correction_pct ())
