(** Pure functions for the M1 T1.4 cheap-vs-expensive proxy-fidelity calibration
    step.

    The Spearman rank correlation between Cell E's per-fold metric on the cheap
    proxy spec (6 folds) and the same metric on the expensive walk-forward spec
    (26 folds) must be {b ρ ≥ 0.7} for the cheap proxy to be acceptable as a
    BO-search-time substitute for the expensive set (per
    `dev/plans/tuning-research-driven-program-v2-2026-05-25.md` §M1 T1.4
    acceptance row).

    This module contains the pure-math primitive {!spearman_rho} plus the
    {!matched_pairs} helper that joins two per-fold lists by [fold_name]. The
    CLI driver and sexp I/O live in {!Tuner_bin.Proxy_calibration}. *)

val acceptance_threshold : float
(** The proxy is accepted at [ρ ≥ acceptance_threshold]. Plan §M1 T1.4 fixes
    this at [0.7]; exposed as a named constant so callers / docs can introspect
    rather than scatter the literal in code. *)

val spearman_rho : float array -> float array -> float
(** [spearman_rho xs ys] returns the Spearman rank correlation coefficient
    between paired observations [(xs.(i), ys.(i))].

    Computed by: 1. Convert each input to ranks. Equal values receive the
    average of the ranks they would occupy if distinguishable (standard mid-rank
    tie handling). 2. Compute the Pearson correlation coefficient of the rank
    vectors.

    Return value range is [-1.0] (perfect anti-monotone) through [0.0]
    (uncorrelated) to [1.0] (perfect monotone).

    Edge cases:
    - When either input has zero variance after ranking (all values equal),
      returns [0.0]. This matches the convention used by SciPy when the Pearson
      denominator collapses.
    - [n = 0] returns [0.0] (no signal to correlate).
    - [n = 1] returns [0.0] (a single point has no rank variance).

    @raise Invalid_argument when [Array.length xs <> Array.length ys]. *)

(** {1 Fold-actual joining} *)

type fold_pair = { fold_name : string; cheap : float; expensive : float }
(** A single matched (cheap, expensive) per-fold observation. *)

val matched_pairs :
  ?variant_label:string ->
  cheap_actuals:Walk_forward.Walk_forward_types.fold_actual list ->
  expensive_actuals:Walk_forward.Walk_forward_types.fold_actual list ->
  metric:[ `Sharpe | `Total_return_pct | `Calmar | `CAGR | `Max_drawdown_pct ] ->
  unit ->
  fold_pair list
(** [matched_pairs ?variant_label ~cheap_actuals ~expensive_actuals ~metric ()]
    returns the intersection by [fold_name] of the two per-fold actual lists,
    projected onto the chosen metric.

    Matching is by [fold_name], not positional. Order in the returned list
    follows the order of [cheap_actuals] for stability. Folds present in only
    one side are silently dropped — the caller asserts the resulting size is
    meaningful (T1.4 expects ~6 matched folds for the canonical 6-vs-26 spec).

    [metric] selects which per-fold field of
    {!Walk_forward.Walk_forward_types.fold_actual} is differenced. [`Sharpe] is
    the default T1.4 metric per the plan.

    [variant_label] (optional) filters both inputs to entries whose
    [variant_label] matches. T1.4 expects [variant_label = "cell-E"] since Cell
    E is the only relevant variant for the calibration step. Defaults to no
    filter — useful when the caller has already restricted upstream. When a file
    carries multiple variants (e.g. both Cell E and a candidate), omitting the
    filter leads to last-writer-wins on duplicate fold_names, which is rarely
    what the caller wants. *)

(** {1 Verdict} *)

(** Acceptance verdict after applying the calibration threshold. *)
type verdict = Pass | Fail [@@deriving show, eq]

val classify : threshold:float -> rho:float -> verdict
(** [classify ~threshold ~rho] returns [Pass] when [rho >= threshold], else
    [Fail]. NaN [rho] (only reachable via abuse — the public {!spearman_rho}
    never returns NaN given non-NaN inputs) classifies as [Fail]. *)
