(** Runner-path bridge for the {!Fold_health} divergence guard (#1553/#1557).

    {!Fold_health.check_divergence} is pure over two counts; this module derives
    those counts from a completed {!Runner.result} and surfaces the finding.
    Kept out of {!Runner} itself so the wiring (open-position counting +
    divergence union) has its own home and {!Runner} stays at its module
    boundary. *)

val open_position_count : Trading_portfolio.Portfolio.t -> int
(** Count of open positions in [portfolio] — the length of
    [portfolio.positions]. Fully-closed positions are already dropped from that
    list by {!Trading_portfolio.Portfolio.apply_trades}, so every element is a
    genuinely-open position (matching the per-row semantics
    {!Reconciler_writer.write_open_positions} uses for [open_positions.csv]). *)

val divergence_findings :
  config:Fold_health.config -> Runner.result -> Fold_health.finding list
(** [divergence_findings ~config result] runs {!Fold_health.check_divergence}
    over [result] — deriving the open-position count from
    [result.final_portfolio] via {!open_position_count} and the stop-eligible
    count from [result.n_stop_eligible_positions]. Returns a singleton
    [Stuck_held_positions] finding when the portfolio holds more open positions
    than the strategy still monitors under stop evaluation (the gap exceeds
    [config.max_stuck_held_positions]), else the empty list (#1553). The
    runner-path bridge the scenario runner unions with the {!Fold_health.check}
    findings; additive and purely diagnostic. *)
