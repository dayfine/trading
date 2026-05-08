(** Per-section helpers for the optimal-strategy counterfactual report.

    Pure markdown renderers called by [Optimal_strategy_report.render]. All
    functions are pure: same input -> same output; no I/O. *)

val divergence_section :
  actual_round_trips:Trading_simulation.Metrics.trade_metrics list ->
  constrained_round_trips:Optimal_types.optimal_round_trip list ->
  string list
(** [divergence_section ~actual_round_trips ~constrained_round_trips] renders
    the "Per-Friday divergence" section. Returns a list of markdown lines
    covering only Fridays where the actual and constrained-counterfactual picks
    differ. Empty-divergence case emits a one-line notice. *)

val missed_section :
  actual_round_trips:Trading_simulation.Metrics.trade_metrics list ->
  constrained_round_trips:Optimal_types.optimal_round_trip list ->
  cascade_rejections:(string * string) list ->
  string list
(** [missed_section ~actual_round_trips ~constrained_round_trips
     ~cascade_rejections] renders the "Trades the actual missed" section.
    Symbols absent from the actual run but present in the constrained
    counterfactual are listed with their realized R-multiple, P&L, and
    cascade-rejection reason (when available). *)

val implications_section :
  actual_initial_cash:float ->
  actual_final_portfolio_value:float ->
  constrained_summary:Optimal_types.optimal_summary ->
  string list
(** [implications_section ~actual_initial_cash ~actual_final_portfolio_value
     ~constrained_summary] renders the "Implications" narrative section. The
    narrative is keyed off the ratio of optimal to actual total return. *)
