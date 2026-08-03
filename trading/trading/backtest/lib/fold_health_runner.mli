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

val all_findings :
  config:Fold_health.config -> Runner.result -> Fold_health.finding list
(** [all_findings ~config result] is the complete fold-health finding list for a
    completed [result]: the {!Fold_health.check} degenerate-fold invariants
    (derived from [result.summary] plus the per-step equity curve built from
    [result.steps]'s [portfolio_value]s) unioned with {!divergence_findings}
    (the #1553 stuck-[Exiting] guard), in that order. An empty list means the
    fold looks healthy on every axis. Purely diagnostic — reads [result] only,
    computes no side effects, changes no metric. *)

val emit :
  ?config:Fold_health.config -> output_dir:string -> Runner.result -> unit
(** [emit ?config ~output_dir result] surfaces {!all_findings} for a completed
    run as the two canonical fold-health artefacts: each finding is printed to
    stderr with a [WARN: fold-health:] prefix (via
    {!Fold_health.finding_to_string}), and the full list is written to
    [<output_dir>/fold_health.sexp] (an empty list on a healthy run, so the
    artefact's presence is uniform across runs). [config] defaults to
    {!Fold_health.default_config}. This is the single emission point shared by
    every runner-path caller (the scenario runner and the [backtest_runner]
    binary), so the divergence guard fires in real backtests and not only in the
    scenario catalog (#1557). Purely a reporting post-step: it changes no metric
    and never aborts the run. *)
