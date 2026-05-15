(** Pure aggregate + markdown renderer for walk-forward CV results.

    Consumes a flat list of per-(fold, variant) measurements + a baseline label
    + a {!Fold_gate.t}, and produces:

    - {!compute} — a structured {!aggregate} record (per-variant stability,
      per-variant gate verdict, win-counts on the gate metric) suitable for
      programmatic consumption by Phase 3's Bayesian optimizer.
    - {!render} — a four-section markdown report: per-fold metrics, stability,
      cross-fold sensitivity, go/no-go verdict. Internally calls {!compute} and
      delegates the markdown emission to {!Walk_forward_render}. *)

include module type of Walk_forward_types
(** The type surface ({!fold_actual}, {!aggregate}, {!variant_stability},
    {!variant_sensitivity}, {!per_metric_stats}) lives in {!Walk_forward_types}
    and is re-exported here unchanged. *)

val compute :
  baseline_label:string ->
  gate:Fold_gate.t ->
  fold_actuals:fold_actual list ->
  aggregate
(** [compute ~baseline_label ~gate ~fold_actuals] returns the structured
    aggregate.

    Validation matches {!render}: raises [Failure] if [fold_actuals] is empty or
    if [baseline_label] is not present among the variant labels in
    [fold_actuals].

    The stability list aggregates by variant label in first-appearance order.
    The sensitivity and verdicts lists exclude the baseline. Each verdict is a
    synthetic Fail with a "fold-pair count mismatch" reason when the (variant,
    baseline) fold-pair count doesn't match [gate.n] — the gate's [evaluate]
    would raise in that case; we produce a uniform diagnostic surface for
    downstream consumers instead. *)

val render :
  baseline_label:string ->
  gate:Fold_gate.t ->
  fold_actuals:fold_actual list ->
  string
(** [render ~baseline_label ~gate ~fold_actuals] returns a markdown report
    string. Internally calls {!compute} then {!Walk_forward_render.to_markdown}.

    Deterministic — same inputs produce byte-identical output (modulo timestamp,
    which is intentionally omitted).

    Raises [Failure] under the same conditions as {!compute}. *)
