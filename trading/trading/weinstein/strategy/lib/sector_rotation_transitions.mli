(** Holding-exit and entry transition builders for the sector-rotation Weinstein
    strategy.

    Extracted from [sector_rotation_weinstein_strategy.ml] so the strategy
    module stays under the file-length limit. These helpers wrap the
    {!Sector_rotation_stops} stop machinery + {!Spy_only_transitions} +
    {!Spy_only_signals} into the two transition kinds the strategy emits on each
    tick: exits (for live holdings) and entries (for target symbols not yet
    held).

    The helpers thread the strategy's two pieces of closure-scoped mutable state
    — a per-symbol stop-state map and a per-symbol prior-stage map — by
    reference. A symbol's stop state is cleared on any exit so a re-entry
    re-seeds. *)

open Core
open Trading_strategy

val holding_exits :
  stops_config:Weinstein_stops.config ->
  stage_config:Stage.config ->
  weekly_window:int ->
  bar_reader:Bar_reader.t ->
  fallback_buffer:float ->
  stop_state:Weinstein_stops.stop_state String.Map.t ref ->
  prior_stage:Weinstein_types.stage String.Map.t ref ->
  target:String.Set.t ->
  holdings:Position.t String.Map.t ->
  get_price:(string -> Types.Daily_price.t option) ->
  Position.transition list
(** [holding_exits ...] runs the holding branch for every live holding,
    accumulating exits. The stop check runs every day; the stage / rotation exit
    only on a weekly close. The stop takes precedence. Mutates [stop_state] /
    [prior_stage]; clears [stop_state] for the symbol on any exit. *)

val entry_transitions :
  cash:float ->
  target:String.Set.t ->
  holdings:Position.t String.Map.t ->
  get_price:(string -> Types.Daily_price.t option) ->
  Position.transition list
(** [entry_transitions ~cash ~target ~holdings ~get_price] builds the entry
    transitions for target symbols not yet held. Cash is split equally across
    the open slots — degenerating to all-cash sizing when only one slot is open
    ([k = 1]). Symbols with no price today, or too little per-slot cash for a
    whole share, are skipped. *)
