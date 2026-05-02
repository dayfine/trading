(** Aggregate per-metric distribution stats across N fuzz variants.

    A fuzz run produces N {!Summary.t} values (one per variant).
    [Fuzz_distribution] folds them into a per-metric distribution: median, p25,
    p75, std, min, max, plus the raw values list — written as
    [fuzz_distribution.sexp] + [fuzz_distribution.md] alongside the per-variant
    subdirs.

    The point: distribution width tells you whether the parameter is a robust
    signal (narrow band) or a single-run lottery (wide band). The per-metric
    Markdown table shapes the same insight for human review.

    Pure module — no I/O outside the explicit [write_*] functions. *)

open Core

type metric_stats = {
  name : string;
      (** Lowercase + underscored metric label (matches
          {!Comparison.metric_diff.name} naming: ["total_pnl"],
          ["sharpe_ratio"], etc.). *)
  values : float list;
      (** Raw per-variant values in variant order (variant 1 first). Length
          equals the number of variants whose summary published this metric —
          entries where the metric was missing are silently dropped, so
          [List.length values <= n_variants] is possible. *)
  median : float;  (** 50th percentile via linear interpolation. *)
  p25 : float;  (** 25th percentile via linear interpolation. *)
  p75 : float;  (** 75th percentile via linear interpolation. *)
  std : float;
      (** Sample standard deviation (Bessel-corrected: divides by n-1). [0.0]
          when [values] has fewer than 2 entries. *)
  min : float;  (** Smallest value in [values]; [0.0] for empty list. *)
  max : float;  (** Largest value in [values]; [0.0] for empty list. *)
}
[@@deriving sexp_of]

type t = {
  fuzz_spec_raw : string;
      (** The original [--fuzz] spec string, echoed for reproducibility. *)
  variant_labels : string list;
      (** Per-variant labels in variant order — joined with [values] for
          downstream consumers that want to plot value-vs-label. *)
  metric_stats : metric_stats list;
      (** Stable-sorted by [Metric_type] enum order (same ordering as
          {!Comparison.all_metric_types}). Includes one entry per metric present
          in {b at least one} summary; rows with zero values across all variants
          are filtered out (no all-empty noise). *)
}
[@@deriving sexp_of]

val compute : fuzz_spec_raw:string -> (string * Summary.t) list -> t
(** [compute ~fuzz_spec_raw labelled_summaries] folds [labelled_summaries] (each
    [(label, summary)] pair) into a {!t}. Order of pairs is preserved in
    [variant_labels] and [metric_stats.values].

    Pure — same input gives same output. Percentile stats use Type-7 linear
    interpolation between adjacent ordered values (R's [quantile(.., type=7)],
    NumPy's [np.percentile(.., method='linear')]). *)

val to_sexp : t -> Sexp.t
(** Render [t] as a machine-readable sexp. Shape:
    {[
      ((fuzz_spec_raw <string>)
       (variant_labels (<l1> <l2> ...))
       (metric_stats   ((<name>
                         ((median <f>) (p25 <f>) (p75 <f>) (std <f>)
                          (min <f>) (max <f>)
                          (values (<v1> <v2> ...)))) ...)))
    ]} *)

val to_markdown : t -> string
(** Render [t] as a human-readable Markdown summary. Includes:
    - Header echoing [fuzz_spec_raw] and N (variant count)
    - Per-metric table: Metric | Median | p25 | p75 | Std | Min | Max | N

    The table is the headline output — eyeballing the spread column-by-column is
    the fastest way to triage robust-vs-lottery metrics. *)

val write_sexp : output_path:string -> t -> unit
(** [write_sexp ~output_path t] writes the sexp form (must be inside an existing
    directory). *)

val write_markdown : output_path:string -> t -> unit
(** [write_markdown ~output_path t] writes the Markdown form (must be inside an
    existing directory). *)
