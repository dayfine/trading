(** Matrix-aware cross-variant ranking for walk-forward CV results.

    [Fold_gate] is a per-variant go/no-go against ONE baseline. A variant matrix
    of N cells is N trials, so picking "the best" is a multiple-testing /
    selection-bias problem. This module adds a cross-variant layer on top of the
    per-variant gate:

    - {!rank} — Pareto dominance over three objectives (Sharpe up, Calmar up,
      MaxDrawdown down). Surfaces the non-dominated frontier rather than one
      blessed scalar, so the operator sees the Sharpe-vs-drawdown trade-off.
    - {!render} — a deterministic markdown report: a frontier table plus a
      per-variant table carrying a Deflated-Sharpe column (the best-of-N
      selection-bias correction from {!Backtest_stats.Deflated_sharpe}).

    Consumes the {!Walk_forward_types.variant_stability} the walk-forward runner
    already emits in its [aggregate.sexp] — no parallel metric type is invented.
    Gap C of [dev/plans/experiment-platform-2026-05-29.md]. *)

type ranked_variant = {
  label : string;
  stability : Walk_forward_types.variant_stability;
      (** The variant's cross-fold metric summary, carried through unchanged so
          the renderer / caller can read every objective without a second
          lookup. *)
  on_frontier : bool;
      (** [true] iff no other variant dominates this one — i.e. it sits on the
          Pareto frontier. *)
  dominated_by : string list;
      (** Labels of the variants that strictly dominate this one (empty iff
          [on_frontier]). Order follows the input variant order. *)
}
[@@deriving sexp]
(** One variant's place in the cross-variant ranking. *)

type ranking = {
  variants : ranked_variant list;
      (** Every input variant, in input order, annotated with its frontier
          status. *)
  frontier : string list;
      (** Labels of the frontier variants, in input order. A convenience
          projection of [variants] filtered to [on_frontier]. *)
}
[@@deriving sexp]
(** The full cross-variant ranking. *)

val dominates :
  Walk_forward_types.variant_stability ->
  Walk_forward_types.variant_stability ->
  bool
(** [dominates a b] is [true] iff [a] Pareto-dominates [b] over the three
    objectives (Sharpe up, Calmar up, MaxDrawdown% down): [a] is at least as
    good as [b] on all three and strictly better on at least one. Compares the
    [.mean] of each metric's cross-fold [per_metric_stats]. NaN means on either
    side are treated as not-comparable on that axis (a NaN never beats and is
    never beaten), so a variant with a NaN objective can still be dominated via
    the other two axes but never dominates on the NaN axis. *)

val rank : Walk_forward_types.variant_stability list -> ranking
(** [rank stabilities] computes the Pareto ranking. For each variant it records
    whether any other variant dominates it ([on_frontier] = none do) and the
    labels of those that do ([dominated_by]). Pure and order-stable: the output
    [variants] follow input order and [frontier] is the input-order subset of
    non-dominated variants. Raises [Invalid_argument] if two variants share a
    label (the label is the identity used in [dominated_by] / [frontier]). *)

val render : ranking -> deflated_sharpe_by_label:(string * float) list -> string
(** [render ranking ~deflated_sharpe_by_label] returns a deterministic markdown
    report: a frontier section (the non-dominated variants) and a per-variant
    table with Sharpe / Calmar / MaxDD% means, a frontier marker, and a Deflated
    Sharpe column looked up from [deflated_sharpe_by_label] (printed as "n/a"
    when a label is absent — e.g. a single-fold variant for which DSR is
    undefined). Same inputs produce byte-identical output. *)
