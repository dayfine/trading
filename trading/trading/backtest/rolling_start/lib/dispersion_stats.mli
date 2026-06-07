(** Pure dispersion statistics over a [float list].

    The rock-solid numeric core of the rolling-start evaluation harness (plan
    [dev/plans/evaluation-objective-and-metrics-2026-06-07.md] §2 P1). The
    harness runs a backtest from many start dates to a fixed end and collects
    one metric value (CAGR, capital-relative drawdown, etc.) per start; this
    module turns that raw [float list] of per-start outcomes into a {!summary} —
    median, 10th percentile, IQR spread, min, max, n — so a strategy can be
    judged on the {b distribution} of outcomes rather than a single full-window
    number.

    Robustness (sensitivity to start time) is the primary evaluation lens (plan
    §1.3): a robust strategy shows a tight, positive distribution; a fragile one
    shows huge spread. These statistics make that measurable.

    Every function here is pure (same input -> same output, no I/O), so it is
    unit-tested directly against hand-computed values without running any
    backtest. NaN handling and the empty-list case are documented per function;
    callers downstream filter or surface NaN explicitly rather than silently
    dropping it. *)

val percentile : float list -> p:float -> float
(** [percentile xs ~p] is the [p]-th percentile of [xs] (0.0 <= [p] <= 100.0)
    using linear interpolation between closest ranks (the "linear" / type-7
    method, matching NumPy's default and most spreadsheet [PERCENTILE]).

    The input need not be sorted — it is sorted internally (ascending). For a
    sorted [xs] of length [n], the value at rank [r = p/100 * (n - 1)] is
    [xs.(floor r) + (r - floor r) * (xs.(ceil r) - xs.(floor r))].

    - [p = 0.0] returns the minimum, [p = 100.0] the maximum, [p = 50.0] the
      median (identical to {!median}).
    - A singleton list returns its only element for every [p].
    - Returns [Float.nan] when [xs] is empty.

    @raise Invalid_argument if [p < 0.0] or [p > 100.0]. *)

val median : float list -> float
(** [median xs] is the 50th percentile of [xs] — the middle element for odd [n],
    the mean of the two middle elements for even [n]. The input need not be
    sorted. Returns [Float.nan] when [xs] is empty. Equivalent to
    [percentile xs ~p:50.0]. *)

val iqr : float list -> float
(** [iqr xs] is the inter-quartile range: the 75th percentile minus the 25th
    percentile (both via {!percentile}). A small IQR means a tight,
    start-insensitive distribution; a large IQR is the fragility tell. Returns
    [Float.nan] when [xs] is empty. Never negative for a non-empty list. *)

type summary = {
  n : int;  (** Number of samples the summary was computed over. *)
  median : float;  (** 50th percentile. [Float.nan] when [n = 0]. *)
  p10 : float;
      (** 10th percentile — the pessimistic-tail outcome the robustness lens
          cares about most (plan §1.4 reports median + 10th pct + spread).
          [Float.nan] when [n = 0]. *)
  iqr : float;
      (** Inter-quartile range (p75 - p25). [Float.nan] when [n = 0]. *)
  min : float;  (** Smallest sample. [Float.nan] when [n = 0]. *)
  max : float;  (** Largest sample. [Float.nan] when [n = 0]. *)
}
[@@deriving sexp, equal]
(** The dispersion dashboard for one metric across all start dates. Built by
    {!summarize}. *)

val summarize : float list -> summary
(** [summarize xs] computes the full {!summary} for [xs]. For an empty [xs]
    every float field is [Float.nan] and [n = 0] — the caller decides how to
    render "no data" rather than this module inventing a sentinel. *)
