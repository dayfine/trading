(** Cross-validate the Q2-A composition path's annual [aggregate_period_return]
    against Shiller's S&P composite total return for the same anchor-to-anchor
    window.

    {1 Methodology caveat}

    The composition snapshots emit an equal-weight (uniform [1/N]) basket of the
    top-N symbols ranked by trailing 60-day average daily dollar-volume
    ([close × volume], unadjusted), per the 2026-05-17 pivot in
    [dev/plans/custom-universe-bidirectional-2026-05-17.md] §Q2-A PR2. The
    Shiller series is the canonical cap-weighted S&P composite. The two series
    therefore should {b not} match bit-exactly even in a perfectly- calibrated
    system: equal-weight typically outperforms cap-weight in mid-cap-heavy
    decades and underperforms when the largest-cap names lead (e.g. late-1990s
    dotcom, post-2017 mega-cap tech).

    This module's purpose is a {b ballpark sanity check}: if our composition
    pipeline is bug-free, the per-year drift should be small enough to be
    explained by the equal-vs-cap-weight differential alone (typically ±10-15 pp
    on a one-year window, occasionally larger in extreme decades). A median
    absolute drift above ~25 pp, or a single-year drift above ~50 pp not
    explained by a known equal-weight-vs-cap-weight regime, indicates a
    methodology bug.

    {1 Window contract}

    Each composition golden is anchored at [YYYY-05-31] and reports the realized
    return over the following ~365 calendar days. The Shiller return mirrors
    that exactly: filter monthly observations to [[date, date + 365]], take the
    price at the window head and tail, plus the sum of monthly-accrued dividends
    ([dividend / 12] per row; [dividend] is annualized in Shiller's series).
    This is the {b same} formula used by {!Universe.Build_from_index} when it
    anchors the decomposition path's synthesized aggregate return to Shiller, so
    the two paths are compared on a like-for-like basis. *)

module SC = Shiller.Shiller_client

type drift_cell = {
  year : int;  (** Reconstitution year (the [YYYY] in [top-N-YYYY.sexp]). *)
  composition_return : float;
      (** Composition golden's [aggregate_period_return], in decimal (0.05 =
          +5%). *)
  shiller_return : float;
      (** Shiller's total return over [[YYYY-05-31, (YYYY+1)-05-31]], computed
          as [((p_end + div_total) / p_start) - 1.0] with
          [div_total = sum (dividend / 12)] over the 13 in-window monthly
          observations. *)
  drift : float;
      (** [composition_return -. shiller_return]. Positive ⇒ composition
          outperformed Shiller for the window. *)
}
[@@deriving sexp, show, eq]
(** One year's composition-vs-Shiller comparison. *)

type report = {
  cells : drift_cell list;
      (** One cell per year for which {b both} a composition golden and a full
          Shiller window were available. Years missing either side are dropped
          (not error). Cells are ordered by ascending [year]. *)
  mean_drift : float;
      (** Arithmetic mean of [drift] across cells. Sign-preserving: positive ⇒
          composition outperformed on average. *)
  median_drift : float;  (** Median of [drift] across cells. Sign-preserving. *)
  max_abs_drift : float;  (** [max |drift|] across cells. *)
  worst_year : int;
      (** The [year] whose [|drift|] equals [max_abs_drift]. Ties broken by
          earliest year. Equals [0] when [cells = []]. *)
}
[@@deriving sexp, show, eq]
(** Aggregate report across the [start_year..end_year] window. *)

val compute :
  composition_dir:string ->
  shiller_obs:SC.monthly_observation list ->
  size:int ->
  start_year:int ->
  end_year:int ->
  report Status.status_or
(** [compute ~composition_dir ~shiller_obs ~size ~start_year ~end_year] walks
    [year] in [[start_year..end_year]], loads
    [composition_dir/top-{size}-{year}.sexp] (skipping years where the file is
    missing), computes the Shiller window total return for
    [[YYYY-05-31, (YYYY+1)-05-31]] (skipping years where the window has fewer
    than 2 in-window observations), and produces a [report] of per-year drifts.

    Returns [Error _] when [start_year > end_year] or when the composition
    directory exists but produces zero usable cells. Missing-file / short-
    window cases for individual years are silently skipped — the report surfaces
    only the years that have both inputs. *)

val format_markdown : report -> string
(** [format_markdown report] renders [report] as a Markdown document with a
    summary block (mean / median / max-abs / worst-year) followed by a per-year
    table ([| Year | Composition | Shiller | Drift (pp) |]). Returns a
    placeholder body when [report.cells = []]. *)

val save_sexp : report -> path:string -> unit Status.status_or
(** [save_sexp report ~path] writes [Sexp.to_string_hum] of [report] to [path]
    atomically (temp-file + rename). Returns [Error Status.Internal] on any
    filesystem failure. *)
