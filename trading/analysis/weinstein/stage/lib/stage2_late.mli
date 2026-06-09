(** Late-Stage-2 detection: the MA-deceleration warning that fires while a
    position is still in Stage 2 but the 30-week MA's slope is decelerating — an
    early top-warning consumed by held-position risk logic. Pure; extracted from
    [stage.ml] to keep that declared-large coordinator under its line cap. *)

val is_late_stage2 :
  get_ma:(week_offset:int -> float option) ->
  decel_threshold:float ->
  slope_lookback:int ->
  bool
(** [is_late_stage2 ~get_ma ~decel_threshold ~slope_lookback] reads the MA at
    offsets [2*slope_lookback-1] (old), [slope_lookback-1] (mid), and [0] (cur);
    returns [true] when the MA was rising (old slope > 0) and the recent slope
    has decelerated below [old_slope * (1 - decel_threshold)]. Returns [false]
    if any of the three MA reads is undefined. *)
