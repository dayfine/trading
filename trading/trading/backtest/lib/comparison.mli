(** Side-by-side comparison of two backtest runs (baseline + variant).

    Used by the experiment-runner [--baseline] mode: run with default config,
    run again with overrides, then write [comparison.sexp] (machine-readable)
    and [comparison.md] (human-readable) showing per-metric deltas.

    Pure module — no I/O outside the explicit [write_*] functions. *)

open Core

type metric_diff = {
  name : string;
      (** Lowercase + underscored metric label (e.g. ["total_pnl"],
          ["sharpe_ratio"], ["max_drawdown"]). Hand-rolled and stable so the
          comparison-output schema is independent of refactors to the underlying
          [Metric_type] enum. *)
  baseline : float option;
      (** Baseline metric value; [None] when the baseline summary did not
          publish this metric (vestigial code path or simulator skipped it). *)
  variant : float option;  (** Variant metric value; [None] like above. *)
  delta : float option;
      (** [variant - baseline] when both sides exist; [None] otherwise. *)
}
(** A per-metric delta row. *)

type t = {
  baseline_summary : Summary.t;
  variant_summary : Summary.t;
  metric_diffs : metric_diff list;
      (** Stable-sorted by [Metric_type] enum order. Includes one entry per
          metric present in either summary; rows where both sides are [None] are
          filtered out (would be vestigial). *)
  scalar_diffs : (string * float) list;
      (** Non-metric scalar diffs derived from the [Summary.t] header:
          [final_portfolio_value], [n_round_trips], [n_steps]. Computed as
          [variant - baseline]. *)
}
(** Comparison record holding both summaries and the computed deltas. *)

val compute : baseline:Summary.t -> variant:Summary.t -> t
(** Build a [t] from two summaries. Pure — same input gives same output. *)

val all_metric_types : Trading_simulation_types.Metric_types.Metric_type.t list
(** All [Metric_type] variants known to the comparison-output registry, in
    stable enum order. Exposed for tests so the variant-coverage test does not
    have to duplicate the registry. Production callers should never need this —
    use [compute] which iterates internally. *)

val metric_label : Trading_simulation_types.Metric_types.Metric_type.t -> string
(** [metric_label mt] returns the lowercase + underscored output label for
    metric variant [mt] (e.g. [TotalPnl] → ["total_pnl"]). Stable across
    refactors of the underlying [Metric_type] enum.

    Exposed so sibling modules ({!Fuzz_distribution} in particular) that emit
    per-metric outputs use the same label table without duplicating the
    registry. Raises if [mt] is not in the registry — which would only happen
    after adding a new variant without updating the table inside
    [comparison.ml]. *)

val to_sexp : t -> Sexp.t
(** Render [t] as a machine-readable sexp suitable for diffing or downstream
    tooling. Shape:
    {[
      ((baseline_summary <summary-sexp>)
       (variant_summary  <summary-sexp>)
       (metric_diffs     ((<name> ((baseline <f>) (variant <f>) (delta <f>))) ...))
       (scalar_diffs     ((<name> <delta>) ...)))
    ]}
    [None] floats are written as the atom [-]. *)

val to_markdown : t -> string
(** Render [t] as a human-readable Markdown table. The table columns are
    [Metric | Baseline | Variant | Delta]. Run dates and key headline numbers
    appear in a leading paragraph. *)

val write_sexp : output_path:string -> t -> unit
(** [write_sexp ~output_path t] writes the sexp form to [output_path] (must be
    inside an existing directory). *)

val write_markdown : output_path:string -> t -> unit
(** [write_markdown ~output_path t] writes the Markdown form to [output_path]
    (must be inside an existing directory). *)
