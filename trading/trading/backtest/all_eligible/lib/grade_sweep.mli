(** Grade-sweep + per-cell-emission helpers for the all-eligible runner.

    Owns the {b post-scan-and-score} half of the all-eligible pipeline: filter
    scored candidates by [min_grade], dedup re-firings, project into
    {!All_eligible.trade_record}s, and emit per-cell + cross-cell artefacts.

    Splitting this out of [All_eligible_runner] keeps the runner focused on the
    {b expensive, side-effect-heavy} half (snapshot construction + per-Friday
    scan + forward-walk scoring) while consolidating the pure-aggregation +
    per-cell-IO logic in one cohesive module.

    The CSV + per-cell-summary renderers live in [All_eligible_runner] and are
    passed in via {!cell_inputs} closures — this keeps grade_sweep free of
    duplication while preserving the runner's existing public renderer surface
    for tests / external consumers.

    See {!All_eligible_runner} for the upstream pipeline. *)

open Core

type cell_inputs = {
  base_config : All_eligible.config;
      (** Template config (entry-dollars / return-buckets) used for every cell.
          The per-cell [min_grade] is overwritten in {!build_cell}. *)
  scored : Backtest_optimal.Optimal_types.scored_candidate list;
      (** Scan-and-score output — re-used across cells. *)
  scenario : Scenario_lib.Scenario.t;
      (** Scenario context for the rendered summary header. *)
  out_dir : string;  (** Top-level directory; cells land in subdirs. *)
  write_trades_csv : path:string -> All_eligible.result -> unit;
      (** CSV writer — typically {!All_eligible_runner.write_trades_csv}. *)
  format_summary_md :
    scenario_name:string ->
    start_date:Date.t ->
    end_date:Date.t ->
    result:All_eligible.result ->
    string;
      (** Per-cell summary-md renderer — typically
          {!All_eligible_runner.format_summary_md}. *)
}
(** Inputs threaded through {!emit_single_cell} and {!emit_grade_sweep}. Bundled
    into a record so the call sites don't have to repeat seven labelled
    arguments. *)

val emit_single_cell : inputs:cell_inputs -> unit
(** [emit_single_cell ~inputs] runs {!build_cell} once for
    [inputs.base_config.min_grade] and writes the three per-cell artefacts to
    [inputs.out_dir/grade-<G>/]. *)

val emit_grade_sweep : inputs:cell_inputs -> unit
(** [emit_grade_sweep ~inputs] iterates [sweep_grades], runs {!build_cell} for
    each, writes per-cell artefacts to [inputs.out_dir/grade-<G>/], and writes a
    top-level [inputs.out_dir/summary.md] with the cross-grade table. *)
