(** Grid search over a parameter spec, evaluated against a list of scenarios.

    The first concrete tuner under the [tuner] track. Decoupled from the actual
    backtest runner via the {!evaluator} callback — callers are expected to wire
    the runner (or a stub for tests) themselves. This keeps the search loop
    pure, deterministic, and unit-testable without spinning up a real backtest.

    Surface:
    - {!param_spec} — list of [(key_path, values)] pairs. The full grid is the
      Cartesian product of the value lists.
    - {!objective} — what to maximize. Single named metric or a weighted
      [Composite] of metrics.
    - {!run} — evaluate every cell against every scenario, return all rows + the
      argmax cell.
    - {!write_csv}, {!write_best_sexp}, {!write_sensitivity_md} — emit the three
      artefacts named in the M5.5 T-A roadmap entry.

    Determinism: cells are enumerated in lexicographic order of the param-spec
    list; scenarios are evaluated in the order they were passed. Given a
    deterministic evaluator, two runs with the same inputs produce
    byte-identical outputs. *)

open Core

(** {1 Parameter spec} *)

type param_values = float list
(** Candidate values for a single parameter. Floats only — discrete (int / bool
    / string) parameters are out of scope for T-A. *)

type param_spec = (string * param_values) list
(** [(key_path, values)] pairs. [key_path] is a dotted path consumed by
    {!Backtest.Config_override.parse_to_sexp} (e.g. ["screening.weights.rs"]).
    [values] is the list of candidate values for that key. The Cartesian product
    over all entries forms the cell space.

    Example:
    {[
    [
      ("screening.weights.rs", [ 0.2; 0.3; 0.4 ]);
      ("screening.weights.volume", [ 0.2; 0.3; 0.4 ]);
      ("screening.weights.breakout", [ 0.2; 0.3; 0.4 ]);
      ("screening.weights.sector", [ 0.2; 0.3; 0.4 ]);
    ]
    ]}

    yields a 3 × 3 × 3 × 3 = 81-cell grid. *)

type cell = (string * float) list
(** A single point in parameter space — one value per key, in the same order as
    the spec. *)

(** {1 Objectives} *)

(** What to maximize. [Composite] is a weighted sum of named metrics; a negative
    weight effectively converts a metric to a minimization target (e.g.
    "minimize drawdown" becomes [(MaxDrawdown, -1.0)]). All weights are applied
    to the raw metric values — callers are responsible for normalising before
    composing if that matters for their use case. *)
type objective =
  | Sharpe
  | Calmar
  | TotalReturn
  | Concavity_coef
  | Composite of
      (Trading_simulation_types.Metric_types.metric_type * float) list

val objective_label : objective -> string
(** Short name for an objective. Used in CSV / sensitivity headers. *)

val objective_metric_type :
  objective -> Trading_simulation_types.Metric_types.metric_type option
(** Underlying [metric_type] for the simple objectives ([Sharpe], [Calmar],
    [TotalReturn], [Concavity_coef]). [None] for [Composite] — that one is
    aggregated across multiple metrics by {!evaluate_objective}. *)

val evaluate_objective :
  objective -> Trading_simulation_types.Metric_types.metric_set -> float
(** [evaluate_objective o metrics] returns the scalar score for [metrics] under
    objective [o]. For simple objectives, the underlying metric value is
    returned ([0.0] when missing). For [Composite weights], returns the weighted
    sum [Σ wᵢ · metricsᵢ] (missing metrics contribute [0.0]). *)

(** {1 Cells} *)

val cells_of_spec : param_spec -> cell list
(** Cartesian product of the param spec, enumerated in lexicographic order
    (innermost = last spec entry varies fastest). [cells_of_spec []] returns
    [[[]]] — the single empty cell, representing "no overrides". An empty
    [values] list for any spec entry yields the empty cell list. *)

val cell_to_overrides : cell -> Sexp.t list
(** Convert a cell to the list of partial-config sexps consumed by
    [Backtest.Runner.run_backtest]'s [overrides] argument. Each [(key, value)]
    becomes one sexp via {!Backtest.Config_override.parse_to_sexp}; a malformed
    [key_path] raises [Failure]. *)

(** {1 Evaluation} *)

type evaluator =
  cell -> scenario:string -> Trading_simulation_types.Metric_types.metric_set
(** A function from [(cell, scenario_name)] to the cell's metric set on that
    scenario. The standard wiring is to call [Backtest.Runner.run_backtest]
    inside this callback with the cell's overrides applied; tests substitute a
    pure stub. *)

type row = {
  cell : cell;
  scenario : string;
  metrics : Trading_simulation_types.Metric_types.metric_set;
  objective_value : float;
}
(** One row of the grid output: a cell × scenario × its metric set + the
    scalarised objective value. *)

type result = {
  rows : row list;
      (** All [(cell, scenario)] rows in enumeration order. Length =
          [|cells| × |scenarios|]. *)
  best_cell : cell;
      (** The cell with the highest mean-across-scenarios objective. Tie-broken
          by enumeration order (first cell wins). [[]] when [rows] is empty. *)
  best_score : float;
      (** Mean objective across scenarios for [best_cell]. [Float.neg_infinity]
          when [rows] is empty. *)
}

val run :
  param_spec ->
  scenarios:string list ->
  objective:objective ->
  evaluator:evaluator ->
  result
(** [run spec ~scenarios ~objective ~evaluator] enumerates every cell in [spec],
    evaluates each cell against every scenario via [evaluator], scalarises with
    [objective], and returns the full row table plus the argmax cell.

    Scoring rule for the argmax: a cell's score is the mean of its objective
    values across scenarios. This handles the multi-scenario case symmetrically
    — no scenario weighting in T-A.

    Raises [Invalid_argument] when [scenarios = []]. *)

(** {1 Sensitivity analysis} *)

type sensitivity_row = {
  param : string;
  varied_values : (float * float) list;
      (** [(value, mean_objective_across_scenarios)] for each candidate value of
          [param], with all other params held at their best-cell setting. Sorted
          by [value] ascending. *)
}
(** Per-parameter marginal effect on the objective: holding other params at
    their best-cell value, the objective value as the focal param sweeps its
    candidate values. *)

val compute_sensitivity : param_spec -> result -> sensitivity_row list
(** [compute_sensitivity spec result] returns one [sensitivity_row] per param in
    [spec]. For each param, holds all other params at their best-cell value and
    averages the objective across scenarios for each candidate value of the
    focal param. The order of [sensitivity_row]s matches the order of [spec]. *)

(** {1 Output} *)

val write_csv : output_path:string -> objective:objective -> result -> unit
(** Write [result.rows] to a CSV at [output_path]. Header columns: each param
    name from the cell, then [scenario], then every [Metric_type] label from
    {!Backtest.Comparison.metric_label}, then [objective_<label>]. Rows ordered
    by enumeration. *)

val write_best_sexp : output_path:string -> result -> unit
(** Write [result.best_cell] as a list of partial-config sexps (one per param)
    to [output_path]. The output file shape is
    [((<key1> <value1>) (<key2> <value2>) ...)] where each entry is the
    {!Backtest.Config_override.parse_to_sexp} of the cell's binding — the same
    shape consumed by [Backtest.Runner.run_backtest]'s [overrides]. *)

val write_sensitivity_md :
  output_path:string -> objective:objective -> sensitivity_row list -> unit
(** Write the sensitivity rows as a Markdown document at [output_path]. One
    section per param, each containing a two-column table (value + mean
    objective). The section header names the param; the document title names the
    objective. *)
