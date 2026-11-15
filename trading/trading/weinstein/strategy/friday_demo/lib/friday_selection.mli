(** Stages 7 and 8 of {!Friday_pipeline.run}: the ranking and the entry walk,
    rebuilt for display from what the strategy recorded. *)

val initial_stop_buffer :
  Weinstein_strategy.Weinstein_strategy_config.config ->
  macro:Macro.result ->
  float
(** This Friday's fallback stop buffer: the per-breadth-state multiplier when
    the config sets one for [macro]'s breadth state, else [initial_stop_buffer].
    The same resolution the entry walk makes. *)

val walk_rows :
  Weinstein_strategy.Weinstein_strategy_config.config ->
  bar_reader:Weinstein_strategy.Bar_reader.t ->
  date:Core.Date.t ->
  macro:Macro.result ->
  cash:float ->
  entries:Weinstein_strategy.Audit_recorder.entry_event list ->
  Weinstein_strategy.Audit_recorder.walk_decision list ->
  Friday_trace.walk_row list
(** One row per decision of the walk, in walk order. The outcome is the walk's
    own; the stop measurement is
    {!Weinstein_strategy.Entry_stop_width_order.gate_stop} under this Friday's
    fallback buffer; cash starts at [cash] and drops by each placed ticket's
    cost, as the walk charges it. *)

val ranking :
  Weinstein_strategy.Weinstein_strategy_config.config ->
  date:Core.Date.t ->
  walk:Friday_trace.walk_row list ->
  Weinstein_strategy.Audit_recorder.cascade_drop list ->
  Friday_trace.ranked_row list
(** Every candidate that cleared the grade gate, longs then shorts, each side
    sorted by {!Screener.compare_rankable} under the config's ranking mode, seed
    and [date]. Which side of the cut a name falls on is the cascade's own
    outcome ([Admitted] or [Dropped_at_top_n]). Under [Price_band_seeded] a name
    below the cut is placed by its close, as its ticket price was never set. *)
