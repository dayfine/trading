(** Pure [Position.transition] builders for the SPY-only Weinstein strategy.

    Extracted from [spy_only_weinstein_strategy.ml] so the strategy module stays
    under the file-length limit. Each builder is a thin record constructor over
    today's [bar]; no behaviour lives here. *)

open Trading_strategy

val build_entry :
  position_id:string ->
  symbol:string ->
  bar:Types.Daily_price.t ->
  target_quantity:float ->
  Position.transition
(** Stage-2 entry: a [CreateEntering] long transition for [symbol] at
    [bar.close_price], tagged with the SPY-only Weinstein entry reasoning.
    [position_id] is the strategy's deterministic id for the symbol. *)

val build_exit :
  pos:Position.t ->
  bar:Types.Daily_price.t ->
  label:string ->
  Position.transition
(** Stage-based exit: a [TriggerExit] with a [StrategySignal] reason carrying
    [label] (e.g. ["stage4_exit"]), exiting [pos] at [bar.close_price]. *)

val build_stop_exit :
  pos:Position.t ->
  bar:Types.Daily_price.t ->
  stop_level:float ->
  Position.transition
(** Stop-triggered exit: a [TriggerExit] with a [StopLoss] reason recording
    [stop_level] as the stop price and [bar.close_price] as the actual exit
    price. *)
