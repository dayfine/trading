(** Position transitions emitted by the stops pass — the pure mapping from a
    stop trigger / {!Weinstein_stops.stop_event} to the [TriggerExit] /
    [UpdateRiskParams] transitions {!Stops_runner} hands the strategy. Extracted
    from [Stops_runner] (file-length); no behaviour change. *)

open Trading_strategy

val trigger_fill_price :
  ?on_close:bool ->
  side:Trading_base.Types.position_side ->
  bar:Types.Daily_price.t ->
  unit ->
  float
(** Worst-case fill price when a stop trigger fires: the bar's low for a long
    (stop crossed going down), the bar's high for a short (crossed going up) —
    the G1 audit-record contract. With [on_close = true] (the weekly-close
    trigger rule) the close price is used for both sides. *)

val make_exit_transition :
  ?on_close:bool ->
  pos:Position.t ->
  current_date:Core.Date.t ->
  state:Weinstein_stops.stop_state ->
  bar:Types.Daily_price.t ->
  unit ->
  Position.transition
(** [TriggerExit] with a [StopLoss] reason at {!trigger_fill_price}; the
    recorded [stop_price] is [state]'s current level. *)

val make_adjust_transition :
  pos:Position.t ->
  current_date:Core.Date.t ->
  risk_params:Position.risk_params ->
  new_level:float ->
  Position.transition
(** [UpdateRiskParams] raising [stop_loss_price] to [new_level]; take-profit /
    max-hold carry over from [risk_params]. *)

val handle_trigger_only :
  on_close:bool ->
  pos:Position.t ->
  state:Weinstein_stops.stop_state ->
  bar:Types.Daily_price.t ->
  current_date:Core.Date.t ->
  Position.transition option * Position.transition option
(** Trigger-check-only branch (weekly cadence, non-Friday bar): the state
    machine is not advanced; an (exit, adjust) pair with the exit populated when
    the bar crosses the existing stop level. Book §Stop-Loss Rules — the GTC
    stop sits in the market every day; only its placement re-evaluation is
    weekly. *)

val of_stop_event :
  on_close:bool ->
  pos:Position.t ->
  risk_params:Position.risk_params ->
  state:Weinstein_stops.stop_state ->
  bar:Types.Daily_price.t ->
  current_date:Core.Date.t ->
  event:Weinstein_stops.stop_event ->
  Position.transition option * Position.transition option
(** Translate a {!Weinstein_stops.stop_event} into the (exit, adjust) transition
    pair for one position: [Stop_hit] → exit at the pre-advance [state]'s level,
    [Stop_raised] → adjust to the new level, anything else → neither. *)
