(** Post-sweep knob-sensitivity sweep for a finished BO sweep.

    After a Bayesian-optimisation sweep converges, this exe loads the
    checkpoint, identifies the best observation, and generates ±5% and ±10%
    perturbations of each knob's value (clipped to the spec's per-knob bounds).
    It then runs each perturbed candidate through the walk-forward executor,
    scores it with the same scoring formula the BO used
    ({!Tuner_bin.Bayesian_runner_scoring.score_cell_with_penalty}), and writes a
    markdown table that flags any knob whose perturbation drops the score by
    more than 50% of the best cell's improvement over baseline.

    {b Knob count math.} 11 knobs × 4 perturbations (±5%, ±10%) = 44 candidates.
    The earlier doc-stub overcounted at 110; the math here is pinned at four
    perturbations per knob.

    Plan: [dev/notes/next-session-priorities-2026-05-26.md] — post-v7-sweep
    analysis scripts.

    Usage:

    {v
      sensitivity_sweep_main.exe --checkpoint <bo_checkpoint.sexp>
                                 --walk-forward-spec <spec.sexp>
                                 --baseline-aggregate <aggregate.sexp>
                                 --out <report.md>
                                 [--fixtures-root <path>]
                                 [--parallel N]   (default 1, max 16)
    v}

    {b Out of scope.} This module does NOT drive the executor itself — the
    library exposes the perturbation-generation, scoring-table assembly, and
    markdown-render helpers; the CLI wrapper ([sensitivity_sweep_main.ml])
    threads them to {!Walk_forward.Walk_forward_executor.execute_spec} for one
    walk-forward run per candidate. *)

(** {1 Perturbation generation} *)

val perturbation_pcts : float list
(** The four per-knob perturbation percentages applied, in order:
    [[ -0.10; -0.05; +0.05; +0.10 ]]. Pinned at four values so the report layout
    is predictable and the per-knob row-count is constant across sweeps. *)

type perturbation = {
  knob : string;
      (** Knob name being perturbed (e.g. ["initial_stop_buffer"]). *)
  pct : float;
      (** Signed perturbation as a fraction, e.g. [-0.05] for -5%. One of
          {!perturbation_pcts}. *)
  perturbed_value : float;
      (** [best_value * (1.0 + pct)], clipped to the knob's [(min, max)] bounds.
          When the clip fires the actual value differs from the unclipped
          target; the renderer surfaces this. *)
  clipped : bool;
      (** [true] when the unclipped [best_value * (1.0 + pct)] fell outside the
          knob's bounds and was pulled back. *)
  parameters : (string * float) list;
      (** Full knob assignment for the executor: [best_params] with only [knob]
          replaced by [perturbed_value]. Keys are in the same order as
          [best_params]. *)
}
[@@deriving sexp, show, eq]
(** One perturbation candidate against the best cell. *)

val generate_perturbations :
  best_params:(string * float) list ->
  bounds:(string * (float * float)) list ->
  perturbation list
(** [generate_perturbations ~best_params ~bounds] returns one {!perturbation}
    per (knob, percentage) pair where knob ∈ [best_params] {b and} knob ∈
    [bounds] (the spec's bounds list). Knobs missing from either side are
    silently dropped from the perturbation set with a diagnostic surfaced
    through the eventual report.

    Ordering: outer = knobs in [best_params] order; inner = {!perturbation_pcts}
    order. With 11 knobs × 4 pcts = 44 rows.

    Each [perturbed_value] is computed as [v * (1 + pct)] then clipped to the
    knob's [(min, max)] bounds. Zero-valued knobs (where [v = 0]) produce
    [perturbed_value = 0] for every pct — the perturbation has no effect, and
    [clipped = false] (no bound violation). The CLI surfaces a warning in the
    report for such zero knobs so the operator knows the rows are no-ops. *)

(** {1 Spec construction} *)

val build_spec_with_baseline :
  candidate_label:string ->
  candidate_overrides:Core.Sexp.t list ->
  template:Walk_forward.Spec.t ->
  Walk_forward.Spec.t
(** [build_spec_with_baseline ~candidate_label ~candidate_overrides ~template]
    returns a copy of [template] whose [variants] list is exactly
    [[ baseline; candidate ]] where:

    - [baseline] uses [template.baseline_label] with empty overrides — the
      unperturbed reference cell;
    - [candidate] uses the supplied [candidate_label] and [candidate_overrides].

    The baseline variant is mandatory because
    {!Walk_forward.Walk_forward_executor.execute_spec} eventually calls
    {!Walk_forward.Walk_forward_report.compute}, which raises [Failure] when
    [spec.baseline_label] is not present in the per-fold actuals. Building each
    perturbation's spec with only the candidate variant — as the v7 sensitivity
    sweep did initially — crashes mid-sweep with that exception (observed
    2026-05-28 against the 11-knob v7 checkpoint).

    Re-running the baseline alongside each perturbation is the cost; the
    alternative (scoring perturbations against a precomputed baseline aggregate
    without re-running) would require restructuring the executor's
    aggregate-building contract. *)

(** {1 Scoring} *)

type scored_row = {
  knob : string;
  pct : float;
  perturbed_value : float;
  clipped : bool;
  score : float;
  delta_vs_best : float;
      (** [score - best_score]. Negative means worse than the unperturbed best;
          positive means the perturbation improves the score (which would
          indicate the BO didn't fully converge or the surface is locally
          non-convex). *)
  sensitive : bool;
      (** [true] when [score < best_score - 0.5 * (best_score - baseline_score)]
          AND [best_score > baseline_score]. The threshold is half the
          improvement of the best cell over baseline; a knob whose perturbation
          crosses that threshold is "sensitive" — losing half the BO's
          discovered improvement to a 5% / 10% jitter signals overfit. *)
}
[@@deriving sexp, show, eq]
(** One row of the per-perturbation table, including the score the executor
    returned (paired with the candidate aggregate via
    {!Tuner_bin.Bayesian_runner_scoring.score_cell_with_penalty}). *)

val sensitivity_threshold :
  best_score:float -> baseline_score:float -> float option
(** [sensitivity_threshold ~best_score ~baseline_score] returns the absolute
    score-floor below which a perturbation is flagged sensitive.

    Returns:

    - [Some (best_score - 0.5 *. (best_score - baseline_score))] when
      [best_score > baseline_score] (the formula is meaningful only when the
      best cell improved on baseline);
    - [None] otherwise — the "50% of improvement" rule has no anchor when there
      is no improvement to measure, so no row is flagged sensitive. *)

(** {1 Report assembly} *)

type report = {
  candidate_label_prefix : string;
      (** The candidate label prefix the CLI used (e.g.
          ["sensitivity-knob-N-pct-M"]). Echoed for diagnostic traceability; the
          renderer surfaces this in the header so the operator can correlate
          report rows to a specific executor run if needed. *)
  baseline_label : string;
      (** Walk-forward variant label of the baseline cell. *)
  best_iteration_index : int;
      (** 0-based position of the best observation in the checkpoint. *)
  best_score : float;
      (** BO-loop score of the unperturbed best cell, as computed by
          {!Tuner_bin.Bayesian_runner_scoring.score_cell_with_penalty} applied
          to the best cell's freshly-re-executed walk-forward result (NOT the
          [metric] field of the checkpoint, which may differ from a re-execution
          if the scorer's formula has since been updated). *)
  baseline_score : float;
      (** Score of the baseline cell against itself — always [0.0] for the
          composite objective by definition, but surfaced explicitly so the
          report self-documents the "50% improvement" arithmetic. *)
  rows : scored_row list;  (** One row per (knob, perturbation) pair. *)
}
[@@deriving sexp, show, eq]

val build_rows :
  best_score:float ->
  baseline_score:float ->
  perturbations:perturbation list ->
  scores:float list ->
  scored_row list
(** [build_rows ~best_score ~baseline_score ~perturbations ~scores] zips
    [perturbations] with [scores] and applies the {!sensitivity_threshold} to
    each row.

    @raise Invalid_argument
      when [List.length perturbations <> List.length scores]. *)

val render_report :
  report ->
  checkpoint_path:string ->
  walk_forward_spec_path:string ->
  baseline_aggregate_path:string ->
  string
(** Render the report as a markdown table. Sections:

    + Title + the checkpoint / walk-forward / baseline paths.
    + Best cell summary: iteration index + best score + baseline score +
      sensitivity threshold.
    + Per-perturbation table: knob, pct, perturbed value, clipped flag, score, Δ
      vs best, sensitive flag.
    + Sensitivity summary: count of sensitive rows + list of sensitive knobs.

    Deterministic — no time / env reads. *)
