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

val catastrophic_exit_label : string
(** ["catastrophic_stop"] — the [StrategySignal] label every fast-crash
    absolute-stop exit carries (issue #3101), and the [exit_trigger] token
    trades.csv shows for it. *)

val make_catastrophic_exit_transition :
  ?on_close:bool ->
  pos:Position.t ->
  current_date:Core.Date.t ->
  trigger_level:float ->
  trailing_high:float ->
  pct:float ->
  bar:Types.Daily_price.t ->
  unit ->
  Position.transition
(** [TriggerExit] for the fast-crash absolute stop
    ({!Weinstein_stops.Catastrophic_stop}), at the same {!trigger_fill_price}
    the structural exit uses.

    The reason is [StrategySignal { label = catastrophic_exit_label; detail }],
    where [detail] is ["stop_price=<trigger_level>,trailing_high=<h>,pct=<p>"].
    It is never a [StopLoss]: until #3101 this exit reused
    {!make_exit_transition}, so it was recorded as a structural stop-loss at the
    structural level, which its bar never reached. Downstream tools then read
    such exits as stops that filled above their stop. Because it is not a
    [StopLoss], the simulator's trigger-bar stop fill does not re-type its
    order. It never did before either, since the bar never reached the
    structural level, so fills are unchanged. *)
